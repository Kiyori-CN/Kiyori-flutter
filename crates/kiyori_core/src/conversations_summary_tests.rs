use super::*;
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};

type Fixture = (
    String,
    Arc<AtomicUsize>,
    std::thread::JoinHandle<Vec<(String, Value)>>,
);
fn server(bodies: Vec<String>) -> Fixture {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let endpoint = format!("http://{}", listener.local_addr().unwrap());
    let entered = Arc::new(AtomicUsize::new(0));
    let count = entered.clone();
    let worker = std::thread::spawn(move || {
        let mut requests = Vec::new();
        for body in bodies {
            let deadline = std::time::Instant::now() + Duration::from_secs(8);
            let (mut socket, _) = loop {
                match listener.accept() {
                    Ok(s) => break s,
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(std::time::Instant::now() < deadline);
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(e) => panic!("{e}"),
                }
            };
            socket.set_nonblocking(false).unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut data = Vec::new();
            let mut buffer = [0; 4096];
            loop {
                let n = socket.read(&mut buffer).unwrap();
                assert!(n > 0);
                data.extend_from_slice(&buffer[..n]);
                if let Some(end) = data.windows(4).position(|b| b == b"\r\n\r\n") {
                    let headers = String::from_utf8_lossy(&data[..end]).into_owned();
                    let length: usize = headers
                        .lines()
                        .find_map(|l| {
                            l.to_ascii_lowercase()
                                .strip_prefix("content-length: ")
                                .map(str::to_owned)
                        })
                        .unwrap()
                        .parse()
                        .unwrap();
                    if data.len() >= end + 4 + length {
                        requests.push((
                            headers,
                            serde_json::from_slice(&data[end + 4..end + 4 + length]).unwrap(),
                        ));
                        break;
                    }
                }
            }
            count.fetch_add(1, Ordering::SeqCst);
            if body.starts_with("delay:") {
                std::thread::sleep(Duration::from_millis(350));
            }
            let body = body.strip_prefix("delay:").unwrap_or(&body);
            if body == "cancel" {
                std::thread::sleep(Duration::from_millis(300));
                continue;
            }
            if body == "fail" {
                write!(
                    socket,
                    "HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                )
                .unwrap();
            } else {
                write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
            }
        }
        requests
    });
    (endpoint, entered, worker)
}
fn setup(runtime: &Runtime, endpoint: String, enabled: bool) -> String {
    configure(runtime, endpoint.clone());
    let mut config = runtime.model_catalog().unwrap().configs.remove(0);
    config.draft.options.summary_enabled = enabled;
    config.draft.options.summary_count = 1;
    config.draft.options.summary_rules = "保留测试口令KIYORI_SYNTHETIC".into();
    runtime
        .save_model_config(config.id, config.revision, config.draft, None, None)
        .unwrap();
    let id = runtime.create_model_config("独立总结".into()).unwrap();
    let mut config = runtime
        .model_catalog()
        .unwrap()
        .configs
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    config.draft.endpoint = endpoint;
    config.draft.models = vec!["summary-fixture".into()];
    let lease = runtime.begin_model_secrets().unwrap();
    let reference = runtime
        .reserve_model_secret(id.clone(), config.revision, &lease)
        .unwrap();
    runtime
        .save_model_config(
            id.clone(),
            config.revision,
            config.draft,
            Some(reference),
            None,
        )
        .unwrap();
    lease.close();
    runtime
        .select_function_model("summary".into(), id, "summary-fixture".into())
        .unwrap();
    runtime.create_conversation().unwrap()
}
fn summary_payload() -> String {
    payload().replace("local-fixture", "summary-credential")
}
async fn send(runtime: &Runtime, id: &str, text: &str) -> Vec<chat::ChatEvent> {
    drain(
        &runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.into()).unwrap(),
                text.into(),
                payload(),
                Some(summary_payload()),
                None,
                None,
                None,
            )
            .unwrap(),
    )
    .await
}

fn manual(runtime: &Runtime, id: &str, index: usize) -> Result<chat::ChatRun, CoreError> {
    let snap = runtime.conversation(id.into()).unwrap();
    runtime.start_summary(
        runtime.prepare_summary(
            id.into(),
            snap.messages[index].id.clone(),
            snap.conversation.revision,
        )?,
        summary_payload(),
    )
}

#[tokio::test]
async fn manual_summary_obeys_user_and_assistant_boundaries_and_preserves_reopen_branch_usage() {
    for boundary in [1, 2, 3] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, _, worker) = server(vec![
            response("第一答", "stop"),
            response("第二答", "stop"),
            response("手动摘要", "stop"),
            response("续答", "stop"),
        ]);
        let id = setup(&runtime, endpoint, false);
        send(&runtime, &id, "第一问").await;
        send(&runtime, &id, "第二问").await;
        let original = runtime.conversation(id.clone()).unwrap();
        assert!(
            drain(&manual(&runtime, &id, boundary).unwrap())
                .await
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Completed { .. }))
        );
        let snapshot = runtime.conversation(id.clone()).unwrap();
        let insertion = if boundary == 3 { 4 } else { 2 };
        assert_eq!(snapshot.messages[insertion].role, "summary");
        assert_eq!(snapshot.messages[insertion].content, "手动摘要");
        assert_eq!(
            snapshot
                .messages
                .iter()
                .filter(|m| m.role != "summary")
                .cloned()
                .collect::<Vec<_>>(),
            original.messages
        );
        assert_eq!(
            runtime
                .conversation_statistics(id.clone())
                .unwrap()
                .requests,
            3
        );
        assert!(
            !runtime
                .conversation_statistics(id.clone())
                .unwrap()
                .recent_model
                .contains("summary")
        );
        send(&runtime, &id, "下一问").await;
        let requests = worker.join().unwrap();
        assert!(requests[2].0.contains("Bearer summary-credential"));
        assert_eq!(requests[2].1["model"], "summary-fixture");
        let summary_messages = requests[2].1["messages"].as_array().unwrap();
        assert!(summary_messages.iter().any(|m| m["content"] == "第一答"));
        assert_eq!(
            summary_messages.iter().any(|m| m["content"] == "第二问"),
            boundary == 3
        );
        let continuation = requests[3].1["messages"].as_array().unwrap();
        assert!(!continuation.iter().any(|m| m["content"] == "第一问"));
        assert!(continuation.iter().any(|m| m["content"] == "手动摘要"));
        assert_eq!(
            continuation.iter().any(|m| m["content"] == "第二问"),
            boundary != 3
        );
        runtime.close();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let restored = runtime.conversation(id.clone()).unwrap();
        assert_eq!(restored.messages.len(), 7);
        let checkpoint = &restored.messages[insertion];
        runtime
            .change_message(
                id.clone(),
                runtime
                    .conversation(id.clone())
                    .unwrap()
                    .conversation
                    .revision,
                checkpoint.id.clone(),
                "branch".into(),
                "".into(),
            )
            .unwrap();
        let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
        assert_eq!(
            runtime
                .conversation(branch.clone())
                .unwrap()
                .messages
                .last()
                .unwrap()
                .role,
            "summary"
        );
        assert!(
            !runtime
                .conversation_statistics(branch)
                .unwrap()
                .recent_model
                .contains("summary")
        );
        runtime
            .change_message(
                id.clone(),
                runtime
                    .conversation(id.clone())
                    .unwrap()
                    .conversation
                    .revision,
                checkpoint.id.clone(),
                "edit".into(),
                "修订摘要".into(),
            )
            .unwrap();
        let updated = runtime.conversation(id.clone()).unwrap();
        assert_eq!(updated.messages[insertion].content, "修订摘要");
        runtime
            .change_message(
                id.clone(),
                updated.conversation.revision,
                checkpoint.id.clone(),
                "delete".into(),
                "".into(),
            )
            .unwrap();
        assert_eq!(runtime.conversation(id).unwrap().messages.len(), 6);
    }
}

#[tokio::test]
async fn manual_failure_empty_incomplete_and_cancel_never_insert_partial_checkpoints() {
    for body in [
        "fail".to_owned(),
        response("", "stop"),
        response("截断摘要", "length"),
        "cancel".to_owned(),
    ] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, count, worker) = server(vec![response("原答", "stop"), body.clone()]);
        let id = setup(&runtime, endpoint, false);
        send(&runtime, &id, "原问").await;
        let before = runtime.conversation(id.clone()).unwrap();
        assert!(
            runtime
                .prepare_summary(
                    id.clone(),
                    before.messages[0].id.clone(),
                    before.conversation.revision
                )
                .is_err()
        );
        let run = manual(&runtime, &id, 1).unwrap();
        let other = Runtime::with_data_dir(&dir.0).unwrap();
        assert!(manual(&other, &id, 1).is_err());
        if body == "cancel" {
            while count.load(Ordering::SeqCst) < 2 {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
            run.cancel_and_wait().await;
        } else {
            let events = drain(&run).await;
            assert!(
                events
                    .iter()
                    .any(|e| matches!(e, chat::ChatEvent::Failed(_)))
            );
        }
        assert_eq!(
            runtime.conversation(id.clone()).unwrap().messages,
            before.messages
        );
        let store = runtime.persistent_store().unwrap();
        assert!(
            !store
                .connection
                .lock()
                .unwrap()
                .query_row(
                    "SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE state='running')",
                    [],
                    |r| r.get::<_, bool>(0)
                )
                .unwrap()
        );
        worker.join().unwrap();
    }
}

#[tokio::test]
async fn manual_late_configuration_and_history_changes_reject_result() {
    for history in [false, true] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, count, worker) = server(vec![
            response("原答", "stop"),
            format!("delay:{}", response("迟到摘要", "stop")),
        ]);
        let id = setup(&runtime, endpoint, false);
        send(&runtime, &id, "原问").await;
        let run = manual(&runtime, &id, 1).unwrap();
        while count.load(Ordering::SeqCst) < 2 {
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        if history {
            // 故障注入绕过应用OS锁，确认提交仍复核冻结原文。
            runtime.persistent_store().unwrap().connection.lock().unwrap().execute("UPDATE conversation_messages SET content='外部变更' WHERE conversation_id=?1 AND role='user'",[&id]).unwrap();
        } else {
            let pref = runtime.chat_preferences().unwrap();
            runtime
                .change_chat_preference(
                    pref.revision,
                    "thinking".into(),
                    (!pref.value.thinking).to_string(),
                )
                .unwrap();
        }
        assert!(
            drain(&run)
                .await
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Failed(_)))
        );
        assert_eq!(runtime.conversation(id).unwrap().messages.len(), 2);
        worker.join().unwrap();
    }
}

#[tokio::test]
async fn manual_checkpoints_inherit_and_become_invalid_after_original_edit() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![
        response("第一答", "stop"),
        response("第一摘要", "stop"),
        response("第二答", "stop"),
        response("第二摘要", "stop"),
        response("修订后答", "stop"),
    ]);
    let id = setup(&runtime, endpoint, false);
    send(&runtime, &id, "第一问").await;
    drain(&manual(&runtime, &id, 1).unwrap()).await;
    send(&runtime, &id, "第二问").await;
    drain(&manual(&runtime, &id, 4).unwrap()).await;
    let snapshot = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_message(
            id.clone(),
            snapshot.conversation.revision,
            snapshot.messages[0].id.clone(),
            "edit".into(),
            "修订第一问".into(),
        )
        .unwrap();
    assert!(
        runtime
            .conversation(id.clone())
            .unwrap()
            .messages
            .iter()
            .filter(|m| m.role == "summary")
            .all(|m| m.state == "invalidated")
    );
    send(&runtime, &id, "修订后问").await;
    let requests = worker.join().unwrap();
    assert!(
        requests[3].1["messages"][0]["content"]
            .as_str()
            .unwrap()
            .contains("第一摘要")
    );
    let latest = requests[4].1["messages"].as_array().unwrap();
    assert!(latest.iter().any(|m| m["content"] == "修订第一问"));
    assert!(!latest.iter().any(|m| m["content"] == "第二摘要"));
}

#[tokio::test]
async fn manual_commit_storage_failure_rolls_back_position_moves_and_recovers_without_replay() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) =
        server(vec![response("原答", "stop"), response("完整摘要", "stop")]);
    let id = setup(&runtime, endpoint, false);
    send(&runtime, &id, "原问").await;
    let before = runtime.conversation(id.clone()).unwrap();
    let store = runtime.persistent_store().unwrap();
    store.connection.lock().unwrap().execute_batch("CREATE TRIGGER reject_summary BEFORE INSERT ON conversation_messages WHEN NEW.role='summary' BEGIN SELECT RAISE(ABORT,'fixture'); END;").unwrap();
    assert!(
        drain(&manual(&runtime, &id, 1).unwrap())
            .await
            .iter()
            .any(|e| matches!(e, chat::ChatEvent::Failed(_)))
    );
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().messages,
        before.messages
    );
    assert_eq!(
        store
            .connection
            .lock()
            .unwrap()
            .query_row(
                "SELECT max(position) FROM conversation_messages WHERE conversation_id=?1",
                [&id],
                |r| r.get::<_, i64>(0)
            )
            .unwrap(),
        1
    );
    assert_eq!(
        store
            .connection
            .lock()
            .unwrap()
            .query_row(
                "SELECT state FROM conversation_runs WHERE kind='summary'",
                [],
                |r| r.get::<_, String>(0)
            )
            .unwrap(),
        "interrupted"
    );
    worker.join().unwrap();
}

#[tokio::test]
async fn schema17_migration_keeps_original_runs_and_bulk_deletion_invalidates_earlier_checkpoints()
{
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![
        response("原答", "stop"),
        response("原摘要", "stop"),
        response("后答", "stop"),
    ]);
    let id = setup(&runtime, endpoint, false);
    send(&runtime, &id, "原问").await;
    drain(&manual(&runtime, &id, 1).unwrap()).await;
    send(&runtime, &id, "后问").await;
    let before = runtime.conversation(id.clone()).unwrap();
    let store = runtime.persistent_store().unwrap();
    // 真实17版本没有手动摘要；先移除测试新增消息/Run，再构造旧列集合。
    crate::extensions::remove_schema_for_fixture(&store.connection.lock().unwrap());
    store.connection.lock().unwrap().execute_batch("DELETE FROM conversation_messages WHERE role='summary'; DELETE FROM conversation_runs WHERE kind='summary'; ALTER TABLE conversation_runs DROP COLUMN kind; PRAGMA user_version=17;").unwrap();
    runtime.close();
    drop(store);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let restored = runtime.conversation(id.clone()).unwrap();
    assert_eq!(
        restored.messages,
        before
            .messages
            .into_iter()
            .filter(|m| m.role != "summary")
            .collect::<Vec<_>>()
    );
    assert!(
        !runtime
            .persistent_store()
            .unwrap()
            .connection
            .lock()
            .unwrap()
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE kind<>'chat')",
                [],
                |r| r.get::<_, bool>(0)
            )
            .unwrap()
    );
    // 人为注入一个原问之后检查点，primary选择较晚消息但批量包含较早原问。
    runtime.persistent_store().unwrap().connection.lock().unwrap().execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state) VALUES('checkpoint',?1,2,'summary','保留原问','completed')",[&id]).unwrap();
    let snap = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_message(
            id.clone(),
            snap.conversation.revision,
            snap.messages.last().unwrap().id.clone(),
            "delete_selected".into(),
            json!([
                snap.messages.last().unwrap().id,
                snap.messages.first().unwrap().id
            ])
            .to_string(),
        )
        .unwrap();
    assert_eq!(
        runtime
            .conversation(id)
            .unwrap()
            .messages
            .iter()
            .find(|m| m.id == "checkpoint")
            .unwrap()
            .state,
        "invalidated"
    );
    worker.join().unwrap();
}

#[tokio::test]
async fn regeneration_summarizes_only_history_before_the_target_user_and_keeps_later_versions() {
    for (enabled, cache_position) in [
        (false, None),
        (true, None),
        (true, Some(2)),
        (true, Some(1)),
    ] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let mut bodies = vec![
            response("第一答", "stop"),
            response("第二答", "stop"),
            response("后续答", "stop"),
        ];
        if enabled && cache_position != Some(1) {
            bodies.push(response("更早历史摘要", "stop"));
        }
        bodies.push(response("第二答新版本", "stop"));
        let (endpoint, _, worker) = server(bodies);
        let id = setup(&runtime, endpoint, false);
        for text in ["第一问", "必须独立保留的第二问", "不参与重生成的后续问"]
        {
            send(&runtime, &id, text).await;
        }
        let mut config = runtime.model_catalog().unwrap().configs.remove(0);
        config.draft.options.summary_enabled = enabled;
        runtime
            .save_model_config(config.id, config.revision, config.draft, None, None)
            .unwrap();
        let before = runtime.conversation(id.clone()).unwrap();
        if let Some(position) = cache_position {
            runtime
                .persistent_store()
                .unwrap()
                .connection
                .lock()
                .unwrap()
                .execute(
                    "INSERT INTO conversation_summaries VALUES(?1,?2,'缓存摘要')",
                    params![id, position],
                )
                .unwrap();
        }
        let target = before.messages[3].id.clone();
        let run = runtime
            .start_conversation_with_summary(
                runtime
                    .prepare_conversation_target(id.clone(), Some(target.clone()))
                    .unwrap(),
                "必须独立保留的第二问".into(),
                payload(),
                Some(summary_payload()),
                Some(target.clone()),
                Some(before.conversation.revision),
                None,
            )
            .unwrap();
        let events = drain(&run).await;
        assert!(
            events
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Completed { .. }))
        );
        let requests = worker.join().unwrap();
        let messages = requests.last().unwrap().1["messages"].as_array().unwrap();
        assert_eq!(messages.last().unwrap()["role"], "user");
        assert_eq!(messages.last().unwrap()["content"], "必须独立保留的第二问");
        assert!(
            !messages
                .iter()
                .any(|m| m["content"] == "不参与重生成的后续问")
        );
        if enabled {
            if cache_position == Some(1) {
                assert_eq!(requests.len(), 4);
                assert!(messages.iter().any(|m| m["content"] == "缓存摘要"));
            } else {
                let input = requests[3].1["messages"].to_string();
                assert!(input.contains("第一问"));
                assert!(!input.contains("必须独立保留的第二问"));
                assert!(!input.contains("缓存摘要"));
            }
            assert_eq!(cached(&runtime, &id).unwrap().0, 1);
        } else {
            assert!(cached(&runtime, &id).is_none());
            assert!(messages.iter().any(|m| m["content"] == "第一问"));
        }
        let after = runtime.conversation(id.clone()).unwrap();
        assert_eq!(after.messages.len(), before.messages.len());
        assert_eq!(after.messages[..3], before.messages[..3]);
        assert_eq!(after.messages[4..], before.messages[4..]);
        assert_eq!(after.messages[3].variant_count, 2);
        runtime
            .change_message(
                id.clone(),
                after.conversation.revision,
                target,
                "variant".into(),
                "0".into(),
            )
            .unwrap();
        assert_eq!(
            runtime.conversation(id).unwrap().messages[3].content,
            "第二答"
        );
        runtime.close();
    }
}

#[tokio::test]
async fn summary_uses_own_binding_inherits_restores_and_retains_original_history() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![
        response("第一原文", "stop"),
        response("摘要A", "stop"),
        response("第二原文", "stop"),
        response("摘要B", "stop"),
        response("第三原文", "stop"),
    ]);
    let id = setup(&runtime, endpoint, true);
    let prepared = runtime.prepare_conversation(id.clone()).unwrap();
    assert!(prepared.summary_secret_reference().is_some());
    drop(prepared);
    send(&runtime, &id, "第一问").await;
    send(&runtime, &id, "第二问").await;
    assert_eq!(runtime.conversation(id.clone()).unwrap().messages.len(), 4);
    runtime.close();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    send(&runtime, &id, "第三问").await;
    let requests = worker.join().unwrap();
    assert!(
        requests[1]
            .0
            .to_ascii_lowercase()
            .contains("authorization: bearer summary-credential")
    );
    assert_eq!(requests[1].1["model"], "summary-fixture");
    assert!(
        requests[1].1["messages"][0]["content"]
            .as_str()
            .unwrap()
            .contains("KIYORI_SYNTHETIC")
    );
    assert_eq!(requests[2].1["messages"][1]["content"], "摘要A");
    assert!(!requests[2].1["messages"].to_string().contains("第一问"));
    assert!(
        requests[3].1["messages"][0]["content"]
            .as_str()
            .unwrap()
            .contains("摘要A")
    );
    let snapshot = runtime.conversation(id.clone()).unwrap();
    assert_eq!(snapshot.messages.len(), 6);
    assert_eq!(snapshot.messages[1].content, "第一原文");
    runtime
        .change_message(
            id.clone(),
            snapshot.conversation.revision,
            snapshot.messages[0].id.clone(),
            "edit".into(),
            "更正第一问".into(),
        )
        .unwrap();
    assert!(
        summary::cached(
            &runtime
                .persistent_store()
                .unwrap()
                .connection
                .lock()
                .unwrap(),
            &id
        )
        .unwrap()
        .is_none()
    );
    runtime.close();
}

#[tokio::test]
async fn disabled_summary_never_uses_own_credentials_or_network() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![response("正文", "stop"), response("正文", "stop")]);
    let id = setup(&runtime, endpoint, false);
    assert!(
        runtime
            .prepare_conversation(id.clone())
            .unwrap()
            .summary_secret_reference()
            .is_none()
    );
    send(&runtime, &id, "一").await;
    send(&runtime, &id, "二").await;
    assert!(
        worker
            .join()
            .unwrap()
            .iter()
            .all(|(_, r)| r["model"] == "chosen-model")
    );
    runtime.close();
}

#[tokio::test]
async fn summary_failure_and_cancel_keep_history_without_sending_chat() {
    for ending in ["fail", "cancel"] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, entered, worker) = server(vec![response("原文", "stop"), ending.into()]);
        let id = setup(&runtime, endpoint, true);
        send(&runtime, &id, "第一問").await;
        let run = runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "第二問".into(),
                payload(),
                Some(summary_payload()),
                None,
                None,
                None,
            )
            .unwrap();
        if ending == "cancel" {
            while entered.load(Ordering::SeqCst) < 2 {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
            run.cancel_and_wait().await;
        }
        let events = drain(&run).await;
        assert!(
            events
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Failed(_) | chat::ChatEvent::Cancelled))
        );
        assert!(!events.iter().any(|e| matches!(e, chat::ChatEvent::Text(_))));
        let snapshot = runtime.conversation(id.clone()).unwrap();
        assert_eq!(snapshot.messages.len(), 4);
        assert_eq!(snapshot.messages[1].content, "原文");
        assert!(
            summary::cached(
                &runtime
                    .persistent_store()
                    .unwrap()
                    .connection
                    .lock()
                    .unwrap(),
                &id
            )
            .unwrap()
            .is_none()
        );
        assert_eq!(worker.join().unwrap().len(), 2);
        runtime.close();
    }
}

#[test]
fn summary_count_ratio_budget_and_schema14_migration_preserve_history() {
    let mut options = models::ModelOptions {
        summary_by_count: false,
        ..Default::default()
    };
    let messages = vec![chat::ChatMessage {
        role: "user".into(),
        content: "a".repeat(717),
    }];
    assert!(summary::triggered(&options, &messages, 0, 1.));
    options.summary_enabled = false;
    assert!(!summary::triggered(&options, &messages, 99, 1.));
    options.summary_enabled = true;
    options.summary_by_count = true;
    options.summary_count = 2;
    assert!(!summary::triggered(&options, &[], 1, 64.));
    assert!(summary::triggered(&options, &[], 2, 64.));
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    runtime.close();
    let store = AppStore::open(&dir.0).unwrap();
    crate::downloads::remove_schema_for_fixture(&store.connection.lock().unwrap());
    store
        .connection
        .lock()
        .unwrap()
        .execute_batch("ALTER TABLE conversation_runs DROP COLUMN kind; DROP TABLE conversation_summary_usage; DROP TABLE conversation_summaries; PRAGMA user_version=14;")
        .unwrap();
    drop(store);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(runtime.conversation(id.clone()).unwrap().messages.len(), 0);
    let store = runtime.persistent_store().unwrap();
    let conn = store.connection.lock().unwrap();
    assert_eq!(
        conn.pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0))
            .unwrap(),
        19
    );
    assert!(summary::cached(&conn, &id).unwrap().is_none());
    drop(conn);
    runtime.close();
}

#[tokio::test]
async fn missing_summary_credentials_reject_before_mutating_history_or_advancing_chat_cursor() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![response("原文", "stop")]);
    let id = setup(&runtime, endpoint, true);
    send(&runtime, &id, "第一问").await;
    worker.join().unwrap();
    let before = runtime.conversation(id.clone()).unwrap();
    assert!(
        runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "第二问".into(),
                payload()
            )
            .is_err()
    );
    assert_eq!(runtime.conversation(id).unwrap(), before);
    runtime.close();
}

#[tokio::test]
async fn summary_rejects_empty_incomplete_and_oversized_projection_without_chat() {
    for (content, reason) in [
        (" ", "stop"),
        ("截断", "length"),
        (&"长".repeat(50_000), "stop"),
    ] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, _, worker) =
            server(vec![response("原文", "stop"), response(content, reason)]);
        let id = setup(&runtime, endpoint, true);
        send(&runtime, &id, "一").await;
        let events = send(&runtime, &id, "二").await;
        assert!(
            events
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Failed(_)))
        );
        assert!(!events.iter().any(|e| matches!(e, chat::ChatEvent::Text(_))));
        let snapshot = runtime.conversation(id.clone()).unwrap();
        assert_eq!(snapshot.messages[1].content, "原文");
        assert_eq!(snapshot.messages[3].state, "failed");
        assert!(cached(&runtime, &id).is_none());
        assert_eq!(worker.join().unwrap().len(), 2);
        runtime.close();
    }
}

fn cached(runtime: &Runtime, id: &str) -> Option<(i64, String)> {
    summary::cached(
        &runtime
            .persistent_store()
            .unwrap()
            .connection
            .lock()
            .unwrap(),
        id,
    )
    .unwrap()
}

#[tokio::test]
async fn late_summary_rejects_configuration_binding_and_preference_changes() {
    for change in ["config", "binding", "preferences"] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, entered, worker) = server(vec![
            response("原文", "stop"),
            format!("delay:{}", response("摘要", "stop")),
        ]);
        let id = setup(&runtime, endpoint, true);
        send(&runtime, &id, "一").await;
        let run = runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "二".into(),
                payload(),
                Some(summary_payload()),
                None,
                None,
                None,
            )
            .unwrap();
        while entered.load(Ordering::SeqCst) < 2 {
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        match change {
            "config" => {
                let mut c = runtime.model_catalog().unwrap().configs.remove(0);
                c.draft.options.summary_rules = "改变规则".into();
                runtime
                    .save_model_config(c.id, c.revision, c.draft, None, None)
                    .unwrap();
            }
            "binding" => {
                runtime
                    .select_function_model(
                        "summary".into(),
                        "default".into(),
                        "chosen-model".into(),
                    )
                    .unwrap();
            }
            _ => {
                let prefs = runtime.chat_preferences().unwrap();
                runtime
                    .change_chat_preference(prefs.revision, "disable_stream".into(), "true".into())
                    .unwrap();
            }
        }
        let events = drain(&run).await;
        assert!(
            events
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Failed(_)))
        );
        assert!(cached(&runtime, &id).is_none());
        assert_eq!(worker.join().unwrap().len(), 2);
        runtime.close();
    }
}

#[tokio::test]
async fn summary_branch_delete_variant_and_resend_have_consistent_boundaries() {
    for action in [
        "branch",
        "deleteFrom",
        "delete_selected",
        "resend",
        "variant",
    ] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, _, worker) = server(vec![
            response("原文", "stop"),
            response("摘要", "stop"),
            response("第二答", "stop"),
        ]);
        let id = setup(&runtime, endpoint, true);
        send(&runtime, &id, "一").await;
        send(&runtime, &id, "二").await;
        worker.join().unwrap();
        let snapshot = runtime.conversation(id.clone()).unwrap();
        assert_eq!(cached(&runtime, &id).unwrap().0, 1);
        if action == "resend" {
            let (endpoint, _, worker) = server(vec![response("重发答", "stop")]);
            let mut c = runtime.model_catalog().unwrap().configs.remove(0);
            c.draft.endpoint = endpoint;
            runtime
                .save_model_config(c.id, c.revision, c.draft, None, None)
                .unwrap();
            let run = runtime
                .start_conversation_with_summary(
                    runtime.prepare_conversation(id.clone()).unwrap(),
                    "新一".into(),
                    payload(),
                    Some(summary_payload()),
                    Some(snapshot.messages[0].id.clone()),
                    Some(snapshot.conversation.revision),
                    None,
                )
                .unwrap();
            drain(&run).await;
            worker.join().unwrap();
            assert_eq!(runtime.conversation(id.clone()).unwrap().messages.len(), 2);
        } else {
            if action == "variant" {
                let store = runtime.persistent_store().unwrap();
                store.connection.lock().unwrap().execute("INSERT INTO conversation_variants(message_id,variant,run_id,content,state) VALUES(?1,1,NULL,'备选','completed')", [&snapshot.messages[1].id]).unwrap();
            }
            runtime
                .change_message(
                    id.clone(),
                    snapshot.conversation.revision,
                    snapshot.messages[1].id.clone(),
                    action.into(),
                    if action == "variant" {
                        "1".into()
                    } else if action == "delete_selected" {
                        json!([snapshot.messages[1].id]).to_string()
                    } else {
                        String::new()
                    },
                )
                .unwrap();
        }
        if action == "branch" {
            let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
            assert_eq!(cached(&runtime, &branch), cached(&runtime, &id));
            assert_eq!(runtime.conversation(branch).unwrap().messages.len(), 2);
        } else {
            assert!(cached(&runtime, &id).is_none());
        }
        runtime.close();
    }
}

#[tokio::test]
async fn disabling_summary_uses_full_history_then_enabling_inherits_cache() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![
        response("原文", "stop"),
        response("摘要A", "stop"),
        response("第二答", "stop"),
        response("第三答", "stop"),
        response("摘要B", "stop"),
        response("第四答", "stop"),
    ]);
    let id = setup(&runtime, endpoint, true);
    send(&runtime, &id, "一").await;
    send(&runtime, &id, "二").await;
    for enabled in [false, true] {
        let mut c = runtime.model_catalog().unwrap().configs.remove(0);
        c.draft.options.summary_enabled = enabled;
        runtime
            .save_model_config(c.id, c.revision, c.draft, None, None)
            .unwrap();
        send(&runtime, &id, if enabled { "四" } else { "三" }).await;
    }
    let requests = worker.join().unwrap();
    assert_eq!(requests[3].1["messages"].as_array().unwrap().len(), 6);
    assert!(
        requests[4].1["messages"][0]["content"]
            .as_str()
            .unwrap()
            .contains("摘要A")
    );
    assert_eq!(runtime.conversation(id).unwrap().messages.len(), 8);
    runtime.close();
}

#[tokio::test]
async fn cancelled_queued_summary_and_runtime_close_release_execution() {
    for queued in [true, false] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let mut bodies = vec![response("原文", "stop")];
        if !queued {
            bodies.push("cancel".into());
        }
        let (endpoint, entered, worker) = server(bodies);
        let id = setup(&runtime, endpoint, true);
        send(&runtime, &id, "一").await;
        let summary = runtime
            .model_catalog()
            .unwrap()
            .configs
            .into_iter()
            .find(|c| c.id != "default")
            .unwrap();
        let gate = runtime
            .model_limits
            .configure(&summary.id, summary.revision, 0, 1);
        let permit = if queued {
            Some(gate.acquire().await)
        } else {
            None
        };
        let run = runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "二".into(),
                payload(),
                Some(summary_payload()),
                None,
                None,
                None,
            )
            .unwrap();
        if queued {
            tokio::time::sleep(Duration::from_millis(30)).await;
        } else {
            while entered.load(Ordering::SeqCst) < 2 {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
            runtime.close();
        }
        tokio::time::timeout(Duration::from_secs(2), run.cancel_and_wait())
            .await
            .unwrap();
        drop(permit);
        let restored = Runtime::with_data_dir(&dir.0).unwrap();
        let snapshot = restored.conversation(id.clone()).unwrap();
        assert_eq!(snapshot.messages[3].state, "cancelled");
        assert!(snapshot.summary.is_none());
        assert_eq!(worker.join().unwrap().len(), if queued { 1 } else { 2 });
        restored.close();
        runtime.close();
    }
}

#[tokio::test]
async fn summary_usage_is_counted_once_without_replacing_chat_sample_and_branches_restore_it() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let usage = json!({"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":3,"prompt_tokens_details":{"cached_tokens":2}}});
    let summary_response = response("摘要", "stop").replace(
        "data: [DONE]",
        &format!("data: {usage}\n\ndata: {usage}\n\ndata: [DONE]"),
    );
    let (endpoint, _, worker) = server(vec![
        response("原文", "stop"),
        summary_response,
        response("后答", "stop"),
    ]);
    let id = setup(&runtime, endpoint, true);
    send(&runtime, &id, "一").await;
    let events = send(&runtime, &id, "二").await;
    assert!(
        !events
            .iter()
            .any(|e| matches!(e, chat::ChatEvent::Failed(_))),
        "{events:?}"
    );
    worker.join().unwrap();
    let stats = runtime.conversation_statistics(id.clone()).unwrap();
    assert_eq!(stats.requests, 3);
    assert_eq!(stats.reported_requests, 1);
    assert_eq!(stats.input_tokens, Some(10));
    assert_eq!(stats.output_tokens, Some(3));
    assert_eq!(stats.cache_read_tokens, Some(2));
    assert_eq!(stats.recent_input_tokens, None);
    let snapshot = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_message(
            id,
            snapshot.conversation.revision,
            snapshot.messages[3].id.clone(),
            "branch".into(),
            String::new(),
        )
        .unwrap();
    let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
    runtime.close();
    let restored = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        restored
            .conversation_statistics(branch.clone())
            .unwrap()
            .input_tokens,
        Some(10)
    );
    let snapshot = restored.conversation(branch.clone()).unwrap();
    restored
        .change_conversation(
            branch.clone(),
            snapshot.conversation.revision,
            "clear".into(),
            String::new(),
        )
        .unwrap();
    assert!(
        restored
            .conversation(branch.clone())
            .unwrap()
            .summary
            .is_none()
    );
    assert_eq!(
        restored.conversation_statistics(branch).unwrap().requests,
        0
    );
    restored.close();
}

#[tokio::test]
async fn independent_summary_budget_rejects_before_network_and_history_mutation() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![response("原文", "stop")]);
    let id = setup(&runtime, endpoint, true);
    send(&runtime, &id, &"长".repeat(600)).await;
    worker.join().unwrap();
    let mut c = runtime
        .model_catalog()
        .unwrap()
        .configs
        .into_iter()
        .find(|c| c.id != "default")
        .unwrap();
    c.draft.options.context_length = 1.;
    runtime
        .save_model_config(c.id, c.revision, c.draft, None, None)
        .unwrap();
    let before = runtime.conversation(id.clone()).unwrap();
    assert!(
        runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "二".into(),
                payload(),
                Some(summary_payload()),
                None,
                None,
                None
            )
            .is_err()
    );
    assert_eq!(runtime.conversation(id).unwrap(), before);
    runtime.close();
}

#[tokio::test]
async fn same_configuration_summary_releases_single_slot_and_rotates_shared_pool() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, _, worker) = server(vec![
        response("原文", "stop"),
        response("摘要", "stop"),
        response("后答", "stop"),
    ]);
    let id = setup(&runtime, endpoint, true);
    let mut c = runtime.model_catalog().unwrap().configs.remove(0);
    c.draft.options.concurrent_limit = 1;
    runtime
        .save_model_config(c.id, c.revision, c.draft, None, None)
        .unwrap();
    runtime
        .select_function_model("summary".into(), "default".into(), "chosen-model".into())
        .unwrap();
    let credentials = json!({"version":3,"apiKey":"","headers":{},"usePool":true,"rotation":"ROUND_ROBIN","keys":[{"id":"a","key":"candidate-a","enabled":true,"availability":"UNTESTED"},{"id":"b","key":"candidate-b","enabled":true,"availability":"UNTESTED"}]}).to_string();
    for text in ["一", "二"] {
        let run = runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                text.into(),
                credentials.clone(),
                Some(String::new()),
                None,
                None,
                None,
            )
            .unwrap();
        let events = tokio::time::timeout(Duration::from_secs(2), drain(&run))
            .await
            .unwrap();
        assert!(
            events
                .iter()
                .any(|e| matches!(e, chat::ChatEvent::Completed { .. }))
        );
    }
    let requests = worker.join().unwrap();
    for (request, key) in requests
        .iter()
        .zip(["candidate-a", "candidate-a", "candidate-b"])
    {
        assert!(
            request
                .0
                .to_ascii_lowercase()
                .contains(&format!("authorization: bearer {key}"))
        );
    }
    runtime.close();
}
