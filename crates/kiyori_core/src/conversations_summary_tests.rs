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
        .execute_batch("DROP TABLE conversation_summary_usage; DROP TABLE conversation_summaries; PRAGMA user_version=14;")
        .unwrap();
    drop(store);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(runtime.conversation(id.clone()).unwrap().messages.len(), 0);
    let store = runtime.persistent_store().unwrap();
    let conn = store.connection.lock().unwrap();
    assert_eq!(
        conn.pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0))
            .unwrap(),
        17
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
