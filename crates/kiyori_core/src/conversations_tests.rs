use super::*;
use serde_json::{Value, json};
use std::{
    io::{Read, Write},
    net::TcpListener,
    time::Duration,
};
struct Directory(std::path::PathBuf);
impl Directory {
    fn new() -> Self {
        static SEQUENCE: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        Self(std::env::temp_dir().join(format!(
                "kiyori-conversation-{}-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos(),
                SEQUENCE.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            )))
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn payload() -> String {
    json!({"version":3,"apiKey":"local-fixture","headers":{},"usePool":false,"keys":[],"rotation":"ROUND_ROBIN"}).to_string()
}
fn fixture(count: usize, body: String) -> (String, std::thread::JoinHandle<Vec<Value>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!("http://{}", listener.local_addr().unwrap());
    let worker = std::thread::spawn(move || {
        let mut requests = vec![];
        for _ in 0..count {
            let (mut socket, _) = listener.accept().unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut bytes = vec![];
            let mut buffer = [0; 4096];
            loop {
                let n = socket.read(&mut buffer).unwrap();
                assert!(n > 0);
                bytes.extend_from_slice(&buffer[..n]);
                if let Some(end) = bytes.windows(4).position(|b| b == b"\r\n\r\n") {
                    let headers = String::from_utf8_lossy(&bytes[..end]).to_ascii_lowercase();
                    let len: usize = headers
                        .lines()
                        .find_map(|l| l.strip_prefix("content-length: "))
                        .unwrap()
                        .parse()
                        .unwrap();
                    if bytes.len() >= end + 4 + len {
                        requests
                            .push(serde_json::from_slice(&bytes[end + 4..end + 4 + len]).unwrap());
                        break;
                    }
                }
            }
            write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",body.len(),body).unwrap();
        }
        requests
    });
    (endpoint, worker)
}
fn response(text: &str, reason: &str) -> String {
    format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"choices":[{"index":0,"delta":{"content":text},"finish_reason":null}]}),
        json!({"choices":[{"index":0,"delta":{},"finish_reason":reason}]})
    )
}
fn configure(runtime: &Runtime, endpoint: String) {
    let config = runtime.model_catalog().unwrap().configs.remove(0);
    let mut draft = config.draft;
    draft.endpoint = endpoint;
    draft.models = vec!["chosen-model".into()];
    draft.options.parameters.push(models::ModelParameter {
        name: "seed".into(),
        enabled: true,
        value_type: "integer".into(),
        value: "42".into(),
        category: "custom".into(),
    });
    runtime
        .save_model_config(
            config.id,
            config.revision,
            draft,
            None,
            Some("chosen-model".into()),
        )
        .unwrap();
}
async fn drain(run: &chat::ChatRun) -> Vec<chat::ChatEvent> {
    let mut events = vec![];
    while let Some(e) = run.next_event().await.unwrap() {
        events.push(e);
    }
    run.cancel_and_wait().await;
    events
}

#[tokio::test]
async fn real_two_turns_freeze_selected_config_role_history_and_reopen() {
    let dir = Directory::new();
    let (endpoint, worker) = fixture(2, response("合成回复", "stop"));
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    for text in ["第一轮合成输入", "继续合成输入"] {
        let prepared = runtime.prepare_conversation(id.clone()).unwrap();
        assert!(runtime.begin_model_secrets().is_err());
        let run = runtime
            .start_conversation(prepared, text.into(), payload())
            .unwrap();
        assert!(runtime.begin_model_secrets().is_ok());
        assert!(matches!(
            drain(&run).await.last(),
            Some(chat::ChatEvent::Completed { .. })
        ));
    }
    let requests = worker.join().unwrap();
    assert_eq!(requests[0]["model"], "chosen-model");
    assert_eq!(requests[0]["seed"], 42);
    assert_eq!(requests[0]["messages"][0]["role"], "system");
    assert_eq!(requests[1]["messages"].as_array().unwrap().len(), 4);
    assert_eq!(requests[1]["messages"][2]["content"], "合成回复");
    let snapshot = runtime.conversation(id.clone()).unwrap();
    let stats = runtime.conversation_statistics(id.clone()).unwrap();
    assert_eq!(stats.requests, 2);
    assert_eq!(stats.reported_requests, 0);
    assert_eq!(stats.input_tokens, None);
    assert_eq!(stats.output_tokens, None);
    assert!(stats.first_output_ms.is_some());
    let expected_context: i64 = requests[1]["messages"]
        .as_array()
        .unwrap()
        .iter()
        .map(|m| chat::observation::estimate(m["content"].as_str().unwrap()))
        .sum();
    assert_eq!(stats.context_tokens, Some(expected_context));
    assert_eq!(stats.tokens_per_second, None); // 单分片不得伪造速度。
    assert_eq!(snapshot.messages.len(), 4);
    assert_eq!(
        runtime.search_conversations("合成回复").unwrap(),
        vec![id.clone()]
    );
    assert_eq!(
        runtime.search_conversations("  继续合成输入  ").unwrap(),
        vec![id.clone()]
    );
    assert!(runtime.search_conversations("%_").unwrap().is_empty());
    let other = runtime.create_conversation().unwrap();
    runtime
        .change_conversation(other.clone(), 1, "rename".into(), "Unique%_title".into())
        .unwrap();
    assert_eq!(runtime.search_conversations("%_").unwrap(), vec![other]);
    runtime.select_conversation(id.clone()).unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    let restored_stats = reopened.conversation_statistics(id.clone()).unwrap();
    assert!(restored_stats.recent_model.is_empty());
    assert_eq!(restored_stats.context_tokens, None);
    assert_eq!(restored_stats.first_output_ms, None);
    assert_eq!(
        reopened.conversation_catalog().unwrap().active_id,
        Some(id.clone())
    );
    assert_eq!(reopened.conversation(id).unwrap(), snapshot);
    reopened.close();
}

#[test]
fn usage_distinguishes_reported_zero_and_unknown_across_schema9_migration() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    runtime.with_store(|store| {
        let connection = store.connection.lock().unwrap();
        connection.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at,input_tokens,output_tokens) VALUES('old',?1,'completed','default',1,'old-model',1,12,3)",[&id]).unwrap();
        connection.execute_batch("ALTER TABLE conversation_runs DROP COLUMN cache_read_tokens; ALTER TABLE conversation_runs DROP COLUMN cache_write_tokens; ALTER TABLE conversation_runs DROP COLUMN reasoning_tokens; DROP TABLE conversation_variants; ALTER TABLE conversation_messages DROP COLUMN variant; ALTER TABLE conversation_runs DROP COLUMN role_id; ALTER TABLE conversation_runs DROP COLUMN role_name; ALTER TABLE conversation_runs DROP COLUMN usage_reported; ALTER TABLE conversation_runs DROP COLUMN first_output_at; ALTER TABLE conversations DROP COLUMN folder; ALTER TABLE conversations DROP COLUMN pinned; ALTER TABLE conversations DROP COLUMN locked; ALTER TABLE conversations DROP COLUMN sort_order; DROP TABLE conversation_folders; DROP TABLE chat_preferences; PRAGMA user_version=9;").unwrap();
        Ok(())
    }).unwrap();
    runtime.close();
    let upgraded = Runtime::with_data_dir(&dir.0).unwrap();
    let stats = upgraded.conversation_statistics(id.clone()).unwrap();
    assert_eq!(stats.reported_requests, 1);
    assert_eq!(stats.input_tokens, Some(12));
    assert_eq!(stats.first_output_ms, None);
    upgraded.with_store(|store| {
        store.connection.lock().unwrap().execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at) VALUES('zero',?1,'running','default',1,'zero-model',2)",[&id]).unwrap();
        store.persist_conversation_event("zero",chat::ChatEvent::Usage {input:0,output:0,total:0,cache_read:None,cache_write:None,reasoning:None,output_reported:true})?;
        store.persist_conversation_event("zero",chat::ChatEvent::Cancelled)?;
        Ok(())
    }).unwrap();
    let stats = upgraded
        .with_store(|store| store.conversation_statistics(&id))
        .unwrap();
    assert_eq!(stats.requests, 2);
    assert_eq!(stats.reported_requests, 2);
    assert_eq!(stats.recent_input_tokens, Some(0));
    assert_eq!(stats.recent_output_tokens, Some(0));
    assert_eq!(stats.input_tokens, Some(12));
    assert!(stats.duration_ms.is_some());
    upgraded.close();
}

#[test]
fn usage_details_replace_samples_survive_reopen_and_migrate_unknown() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    runtime.with_store(|store| {
        store.connection.lock().unwrap().execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at,input_tokens,output_tokens,usage_reported) VALUES('old',?1,'completed','default',1,'old-model',1,100,20,1)",[&id]).unwrap();
        store.connection.lock().unwrap().execute_batch("ALTER TABLE conversation_runs DROP COLUMN cache_read_tokens; ALTER TABLE conversation_runs DROP COLUMN cache_write_tokens; ALTER TABLE conversation_runs DROP COLUMN reasoning_tokens; PRAGMA user_version=13;").unwrap();
        Ok(())
    }).unwrap();
    runtime.close();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let migrated = runtime.conversation_statistics(id.clone()).unwrap();
    assert_eq!(migrated.cache_read_tokens, None);
    assert_eq!(migrated.cache_reported_requests, 0);
    assert_eq!(migrated.uncached_input_tokens, Some(100));
    runtime.with_store(|store| {
        store.connection.lock().unwrap().execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at) VALUES('new',?1,'running','default',1,'model',2)",[&id]).unwrap();
        for read in [50,60,60] {
            store.persist_conversation_event("new",chat::ChatEvent::Usage {input:200,output:30,total:230,cache_read:Some(read),cache_write:Some(10),reasoning:Some(20),output_reported:true})?;
        }
        let active = store.conversation_statistics(&id)?;
        assert_eq!(active.reported_requests,1);
        assert_eq!(active.recent_cache_read_tokens,Some(60));
        store.persist_conversation_event("new",chat::ChatEvent::Cancelled)?;
        Ok(())
    }).unwrap();
    let stats = runtime.conversation_statistics(id.clone()).unwrap();
    assert_eq!(stats.requests, 2);
    assert_eq!(stats.reported_requests, 2);
    assert_eq!(stats.input_tokens, Some(300));
    assert_eq!(stats.cache_read_tokens, Some(60));
    assert_eq!(stats.cache_write_tokens, Some(10));
    assert_eq!(stats.reasoning_tokens, Some(20));
    assert_eq!(stats.cache_input_tokens, Some(200));
    assert_eq!(stats.uncached_input_tokens, Some(230));
    assert_eq!(stats.cache_reported_requests, 1);
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(reopened.conversation_statistics(id.clone()).unwrap(), stats);
    reopened
        .with_store(|store| {
            store.connection.lock().unwrap().execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at) VALUES('zero',?1,'running','default',1,'model',3)",[&id]).unwrap();
            store.persist_conversation_event(
                "zero",
                chat::ChatEvent::Usage {
                    input: 200,
                    output: 30,
                    output_reported: true,
                    total: 230,
                    cache_read: Some(0),
                    cache_write: Some(0),
                    reasoning: Some(0),
                },
            )?;
            store.persist_conversation_event("zero",chat::ChatEvent::Cancelled)?;
            Ok(())
        })
        .unwrap();
    assert_eq!(
        reopened
            .conversation_statistics(id.clone())
            .unwrap()
            .recent_input_tokens,
        None
    );
    let zero = reopened
        .with_store(|store| store.conversation_statistics(&id))
        .unwrap();
    assert_eq!(zero.recent_cache_read_tokens, Some(0));
    assert_eq!(zero.recent_cache_write_tokens, Some(0));
    assert_eq!(zero.recent_reasoning_tokens, Some(0));
    assert_eq!(zero.cache_read_tokens, Some(60));
    // 旧版累计对写入与推理0保留未提供，最近请求能区分0。
    assert_eq!(zero.cache_write_tokens, Some(10));
    assert_eq!(zero.reasoning_tokens, Some(20));
    reopened.close();
}

#[tokio::test]
async fn empty_incomplete_and_disconnect_keep_real_status_and_partial_text() {
    for (text, reason, body) in [
        ("", "stop", response("", "stop")),
        ("部分", "length", response("部分", "length")),
        (
            "部分",
            "disconnect",
            format!(
                "data: {}\n\n",
                json!({"choices":[{"index":0,"delta":{"content":"部分"},"finish_reason":null}]})
            ),
        ),
    ] {
        let dir = Directory::new();
        let (endpoint, worker) = fixture(1, body);
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        configure(&runtime, endpoint);
        let id = runtime.create_conversation().unwrap();
        let run = runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "test".into(),
                payload(),
            )
            .unwrap();
        let events = drain(&run).await;
        assert!(
            matches!(events.last(), Some(chat::ChatEvent::Failed(_))),
            "{reason}"
        );
        let snap = runtime.conversation(id).unwrap();
        assert_eq!(snap.messages[1].content, text);
        assert_eq!(snap.messages[1].state, "failed");
        assert!(!snap.messages[1].error.is_empty());
        worker.join().unwrap();
        runtime.close();
    }
}

#[tokio::test]
async fn cancel_unsubscribed_backpressure_close_and_cross_instance_recovery() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    configure(&runtime, "http://127.0.0.1:1".into());
    let id = runtime.create_conversation().unwrap();
    let run = runtime
        .start_conversation(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "test".into(),
            payload(),
        )
        .unwrap();
    let other = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        other.conversation(id.clone()).unwrap().messages[1].state,
        "running"
    );
    assert!(
        other
            .start_conversation(
                other.prepare_conversation(id.clone()).unwrap(),
                "duplicate".into(),
                payload()
            )
            .is_err()
    );
    runtime.close();
    tokio::time::timeout(Duration::from_secs(3), run.cancel_and_wait())
        .await
        .unwrap();
    assert_eq!(
        other.conversation(id.clone()).unwrap().messages[1].state,
        "cancelled"
    );
    drop(run);
    // 崩溃夹具留下running行但不持有OS锁；活跃实例的行在上面不会被误恢复。
    other.with_store(|s|{s.connection.lock().unwrap().execute_batch("UPDATE conversation_runs SET state='running'; UPDATE conversation_messages SET state='running' WHERE role='assistant';").unwrap();Ok(())}).unwrap();
    assert_eq!(
        other.conversation(id).unwrap().messages[1].state,
        "interrupted"
    );
    other.close();
}

#[tokio::test]
async fn stale_configuration_or_role_rejected_without_messages_or_secret_leak() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    let prepared = runtime.prepare_conversation(id.clone()).unwrap();
    let config = runtime.model_catalog().unwrap().configs.remove(0);
    let mut draft = config.draft;
    draft.name = "changed".into();
    runtime
        .save_model_config(config.id, config.revision, draft, None, None)
        .unwrap();
    let error = runtime
        .start_conversation(prepared, "test".into(), payload())
        .err()
        .unwrap();
    assert!(!error.message.contains("local-fixture"));
    assert!(
        runtime
            .conversation(id.clone())
            .unwrap()
            .messages
            .is_empty()
    );
    let prepared = runtime.prepare_conversation(id.clone()).unwrap();
    let mut card = runtime.prompt_catalog().unwrap().characters.remove(0);
    card.draft.custom = "new system".into();
    runtime
        .save_character(Some(card.id), Some(card.revision), card.draft)
        .unwrap();
    assert!(
        runtime
            .start_conversation(prepared, "test".into(), payload())
            .is_err()
    );
    assert!(runtime.conversation(id).unwrap().messages.is_empty());
    runtime.close();
}

#[test]
fn history_selection_rename_delete_conflict_and_schema8_migration() {
    let dir = Directory::new();
    {
        let store = AppStore::open(&dir.0).unwrap();
        store.connection.lock().unwrap().execute_batch("DROP TABLE conversation_variants;DROP TABLE conversation_messages;DROP TABLE conversation_runs;DROP TABLE conversation_state;DROP TABLE conversations;DROP TABLE conversation_folders;DROP TABLE chat_preferences; PRAGMA user_version=8;").unwrap();
    }
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let a = runtime.create_conversation().unwrap();
    let b = runtime.create_conversation().unwrap();
    runtime.select_conversation(a.clone()).unwrap();
    runtime
        .change_conversation(a.clone(), 1, "rename".into(), "重命名".into())
        .unwrap();
    assert!(
        runtime
            .change_conversation(a.clone(), 1, "delete".into(), "".into())
            .is_err()
    );
    runtime
        .change_conversation(a, 2, "delete".into(), "".into())
        .unwrap();
    let catalog = runtime.conversation_catalog().unwrap();
    assert_eq!(catalog.active_id, None);
    assert_eq!(catalog.conversations[0].id, b);
    runtime.close();
}

#[test]
fn folders_flags_order_and_metadata_are_persistent_and_atomic() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let a = runtime.create_conversation().unwrap();
    let b = runtime.create_conversation().unwrap();
    let prefs = runtime.chat_preferences().unwrap();
    assert_eq!(prefs.value.history_mode, "folder");
    assert!(prefs.value.memory_auto);
    let prefs = runtime
        .change_chat_preference(prefs.revision, "create_folder".into(), "学习".into())
        .unwrap();
    runtime
        .change_conversation(
            a.clone(),
            1,
            "metadata".into(),
            json!({"title":"first","folder":"学习"}).to_string(),
        )
        .unwrap();
    assert!(
        runtime
            .change_conversation(
                a.clone(),
                2,
                "metadata".into(),
                json!({"title":"must not save","folder":"missing"}).to_string()
            )
            .is_err()
    );
    assert_eq!(
        runtime.conversation(a.clone()).unwrap().conversation.title,
        "first"
    );
    runtime
        .change_conversation(a.clone(), 2, "locked".into(), "true".into())
        .unwrap();
    assert!(
        runtime
            .change_conversation(a.clone(), 3, "delete".into(), String::new())
            .is_err()
    );
    runtime
        .change_conversation(a.clone(), 3, "pinned".into(), "true".into())
        .unwrap();
    assert_eq!(
        runtime.conversation_catalog().unwrap().conversations[0].id,
        a
    );
    runtime
        .change_chat_preference(prefs.revision, "delete_folder".into(), "学习".into())
        .unwrap();
    let current = runtime.conversation(a.clone()).unwrap().conversation;
    assert_eq!(current.folder, "");
    assert!(current.locked && current.pinned);
    runtime
        .change_conversation(a.clone(), current.revision, "pinned".into(), "false".into())
        .unwrap();
    let current = runtime.conversation(a.clone()).unwrap().conversation;
    runtime
        .change_conversation(a.clone(), current.revision, "bottom".into(), String::new())
        .unwrap();
    assert_eq!(
        runtime.conversation_catalog().unwrap().conversations[0].id,
        b
    );
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert!(reopened.conversation(a).unwrap().conversation.locked);
    assert!(reopened.chat_preferences().unwrap().folders.is_empty());
    reopened.close();
}

#[test]
fn thinking_contract_preserves_explicit_parameters_and_rejects_unknown_models() {
    let mut request = chat::ChatRequest {
        provider: String::new(),
        continuation_credentials: None,
        google_search: false,
        claude_cache: false,
        admission: None,
        stream: true,
        probe: None,
        protocol: "responses".into(),
        endpoint: "http://127.0.0.1".into(),
        model: "deepseek-flash".into(),
        api_key: String::new(),
        headers: vec![],
        messages: vec![],
        parameters: "{}".into(),
        timeout_ms: 1000,
    };
    let mut preferences = crate::chat_preferences::Preferences::default();
    apply_thinking(&mut request, &preferences).unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&request.parameters).unwrap()["reasoning"]["effort"],
        "none"
    );
    preferences.thinking = true;
    preferences.thinking_quality = 5;
    // 显式配置优先于输入栏偏好，不覆盖用户额度或其它字段。
    request.parameters = r#"{"reasoning":{"effort":"low"},"max_output_tokens":128}"#.into();
    let explicit = request.parameters.clone();
    apply_thinking(&mut request, &preferences).unwrap();
    assert_eq!(request.parameters, explicit);
    for name in [
        "deepseek-flash",
        "alias/deepseek-v4.1-pro-2026-09-25",
        "deepseek-chat",
    ] {
        request.model = name.into();
        request.parameters = "{}".into();
        apply_thinking(&mut request, &preferences).unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&request.parameters).unwrap()["reasoning"]["effort"],
            "max"
        );
    }
    for name in [
        "deepseek-unknown",
        "deepseek-flash-preview",
        "deepseek-pro-xx",
        "unrecognized",
    ] {
        request.model = name.into();
        request.parameters = "{}".into();
        assert!(apply_thinking(&mut request, &preferences).is_err());
        assert_eq!(request.parameters, "{}");
    }
    request.model = "deepseek-flash".into();
    request.protocol = "chat".into();
    request.parameters = "{}".into();
    apply_thinking(&mut request, &preferences).unwrap();
    let p: Value = serde_json::from_str(&request.parameters).unwrap();
    assert_eq!(p["thinking"]["type"], "enabled");
    assert_eq!(p["reasoning_effort"], "max");
    for protocol in ["chat", "responses"] {
        request.protocol = protocol.into();
        request.model = "alias/gpt-6.1-sol-2026-10-01".into();
        for (index, effort) in ["low", "medium", "high", "xhigh", "max"].iter().enumerate() {
            request.parameters = "{}".into();
            preferences.thinking_quality = index as u32 + 1;
            apply_thinking(&mut request, &preferences).unwrap();
            let p: Value = serde_json::from_str(&request.parameters).unwrap();
            assert_eq!(
                if protocol == "chat" {
                    &p["reasoning_effort"]
                } else {
                    &p["reasoning"]["effort"]
                },
                effort
            );
        }
        preferences.thinking = false;
        request.parameters = "{}".into();
        assert!(apply_thinking(&mut request, &preferences).is_err());
        assert_eq!(request.parameters, "{}");
        preferences.thinking = true;
    }
    request.model = "gpt-6.1-sol-unknown".into();
    request.parameters = "{}".into();
    assert!(apply_thinking(&mut request, &preferences).is_err());
}

#[test]
fn character_selection_keeps_history_binding_and_switches_atomically_by_preferences() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let original = runtime.prompt_catalog().unwrap().characters.remove(0);
    let mut draft = original.draft;
    draft.name = "第二角色".into();
    let other = runtime.save_character(None, None, draft).unwrap();
    let a = runtime.create_conversation().unwrap();
    runtime.select_chat_character(other.clone()).unwrap();
    assert_eq!(
        runtime.conversation_catalog().unwrap().active_id,
        Some(a.clone())
    );
    assert_eq!(
        runtime
            .conversation(a.clone())
            .unwrap()
            .conversation
            .character_id,
        original.id
    );
    assert_eq!(
        runtime.prompt_catalog().unwrap().active_character,
        Some(other.clone())
    );
    let prefs = runtime.chat_preferences().unwrap();
    let prefs = runtime
        .change_chat_preference(prefs.revision, "auto_chat".into(), "true".into())
        .unwrap();
    runtime.select_chat_character(other.clone()).unwrap();
    let b = runtime.conversation_catalog().unwrap().active_id.unwrap();
    assert_ne!(a, b);
    assert_eq!(
        runtime
            .conversation(b.clone())
            .unwrap()
            .conversation
            .character_id,
        other
    );
    runtime.select_conversation(a.clone()).unwrap();
    assert_eq!(
        runtime.prompt_catalog().unwrap().active_character,
        Some(other.clone())
    );
    runtime
        .change_chat_preference(prefs.revision, "auto_character".into(), "true".into())
        .unwrap();
    runtime.select_conversation(a).unwrap();
    assert_eq!(
        runtime.prompt_catalog().unwrap().active_character,
        Some(original.id)
    );
    runtime.select_chat_character(other).unwrap();
    assert_eq!(runtime.conversation_catalog().unwrap().active_id, Some(b));
    runtime.close();
}

#[tokio::test]
async fn reply_and_branch_keep_complete_content_and_independent_history() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let content = format!("<sample>{}</sample>", "完整正文".repeat(60));
    let (endpoint, worker) = fixture(2, response(&content, "stop"));
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    let run = runtime
        .start_conversation(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "第一轮".into(),
            payload(),
        )
        .unwrap();
    drain(&run).await;
    let before = runtime.conversation(id.clone()).unwrap();
    let assistant = before.messages[1].id.clone();
    assert_eq!(before.messages[1].role_name.as_deref(), Some("Kiyori"));
    assert!(before.messages[1].sent_at.is_some());
    assert!(before.messages[1].first_output_ms.is_some());
    assert!(before.messages[1].duration_ms.is_some());
    assert_eq!(before.messages[1].input_tokens, None);
    let mut renamed = runtime.prompt_catalog().unwrap().characters.remove(0);
    renamed.draft.name = "新名称".into();
    runtime
        .save_character(Some(renamed.id), Some(renamed.revision), renamed.draft)
        .unwrap();
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().messages[1]
            .role_name
            .as_deref(),
        Some("Kiyori")
    );
    let renamed_snapshot = runtime.conversation(id.clone()).unwrap();
    // 混入失效ID或重复ID时，先前已执行的DELETE也必须整个回滚。
    for ids in [
        json!([before.messages[0].id, "missing"]),
        json!([assistant, assistant]),
    ] {
        assert!(
            runtime
                .change_message(
                    id.clone(),
                    before.conversation.revision,
                    assistant.clone(),
                    "delete_selected".into(),
                    ids.to_string()
                )
                .is_err()
        );
        assert_eq!(runtime.conversation(id.clone()).unwrap(), renamed_snapshot);
    }
    let other = runtime.create_conversation().unwrap();
    assert!(
        runtime
            .start_conversation_replying(
                runtime.prepare_conversation(other.clone()).unwrap(),
                "不可跨会话引用".into(),
                payload(),
                None,
                None,
                Some(assistant.clone())
            )
            .is_err()
    );
    assert!(runtime.conversation(other).unwrap().messages.is_empty());
    let run = runtime
        .start_conversation_replying(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "继续".into(),
            payload(),
            None,
            None,
            Some(assistant.clone()),
        )
        .unwrap();
    drain(&run).await;
    let requests = worker.join().unwrap();
    let sent = requests[1]["messages"].as_array().unwrap().last().unwrap()["content"]
        .as_str()
        .unwrap();
    assert!(sent.contains(&"完整正文".repeat(60)));
    assert!(sent.contains("&lt;sample&gt;"));
    let current = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_message(
            id.clone(),
            current.conversation.revision,
            assistant.clone(),
            "branch".into(),
            String::new(),
        )
        .unwrap();
    let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
    assert_ne!(branch, id);
    let branched = runtime.conversation(branch.clone()).unwrap();
    assert_eq!(branched.messages.len(), 2);
    assert_eq!(branched.messages[1].content, content);
    assert_ne!(branched.messages[1].run_id, before.messages[1].run_id);
    let source = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_conversation(
            id,
            source.conversation.revision,
            "delete".into(),
            String::new(),
        )
        .unwrap();
    assert_eq!(runtime.conversation(branch).unwrap(), branched);
    runtime.close();
}

#[test]
fn reorder_is_scoped_to_visible_character_and_folder_rename_is_atomic() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let original = runtime.prompt_catalog().unwrap().characters.remove(0);
    let a = runtime.create_conversation().unwrap();
    let b = runtime.create_conversation().unwrap();
    let mut draft = original.draft.clone();
    draft.name = "其它角色".into();
    let other = runtime.save_character(None, None, draft).unwrap();
    runtime.select_chat_character(other).unwrap();
    let c = runtime.create_conversation().unwrap();
    let untouched = runtime.conversation(c.clone()).unwrap();
    let p = runtime.chat_preferences().unwrap();
    let p = runtime
        .change_chat_preference(p.revision, "history_mode".into(), "character".into())
        .unwrap();
    runtime
        .change_conversation(a.clone(), 1, "before".into(), b.clone())
        .unwrap();
    assert_eq!(runtime.conversation(c.clone()).unwrap(), untouched);
    assert!(
        runtime
            .change_conversation(a.clone(), 2, "before".into(), c)
            .is_err()
    );
    let ids: Vec<_> = runtime
        .conversation_catalog()
        .unwrap()
        .conversations
        .into_iter()
        .filter(|c| c.character_id == original.id)
        .map(|c| c.id)
        .collect();
    assert_eq!(ids, vec![a.clone(), b]);
    let p = runtime
        .change_chat_preference(p.revision, "create_folder".into(), "A".into())
        .unwrap();
    let p = runtime
        .change_chat_preference(p.revision, "create_folder".into(), "B".into())
        .unwrap();
    runtime
        .change_conversation(a.clone(), 2, "folder".into(), "A".into())
        .unwrap();
    assert!(
        runtime
            .change_chat_preference(
                p.revision,
                "rename_folder".into(),
                json!(["A", "B"]).to_string()
            )
            .is_err()
    );
    assert_eq!(
        runtime.conversation(a.clone()).unwrap().conversation.folder,
        "A"
    );
    runtime
        .change_chat_preference(
            p.revision,
            "rename_folder".into(),
            json!(["A", "C"]).to_string(),
        )
        .unwrap();
    assert_eq!(runtime.conversation(a).unwrap().conversation.folder, "C");
    assert_eq!(runtime.chat_preferences().unwrap().folders, vec!["B", "C"]);
    runtime.close();
}

#[tokio::test]
async fn regeneration_adds_version_without_deleting_later_messages() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, worker) = fixture(3, response("版本正文", "stop"));
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    for text in ["第一问", "后续提问"] {
        let run = runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                text.into(),
                payload(),
            )
            .unwrap();
        drain(&run).await;
    }
    let before = runtime.conversation(id.clone()).unwrap();
    let target = before.messages[1].id.clone();
    let mut other = runtime.prompt_catalog().unwrap().characters.remove(0).draft;
    other.name = "其它角色".into();
    let other = runtime.save_character(None, None, other).unwrap();
    runtime.select_chat_character(other).unwrap();
    let run = runtime
        .start_conversation_replacing(
            runtime
                .prepare_conversation_target(id.clone(), Some(target.clone()))
                .unwrap(),
            "第一问".into(),
            payload(),
            Some(target.clone()),
            Some(before.conversation.revision),
        )
        .unwrap();
    drain(&run).await;
    let requests = worker.join().unwrap();
    assert!(!requests[2]["messages"].to_string().contains("后续提问"));
    let current = runtime.conversation(id.clone()).unwrap();
    assert_eq!(current.messages.len(), 4);
    assert_eq!(current.messages[2..], before.messages[2..]);
    assert_eq!(current.messages[1].variant, 1);
    assert_eq!(current.messages[1].variant_count, 2);
    assert_eq!(current.messages[1].role_name.as_deref(), Some("Kiyori"));
    runtime
        .change_message(
            id.clone(),
            current.conversation.revision,
            target.clone(),
            "variant".into(),
            "0".into(),
        )
        .unwrap();
    let previous = runtime.conversation(id.clone()).unwrap();
    assert_eq!(previous.messages[1].run_id, before.messages[1].run_id);
    assert_eq!(previous.messages[1].content, before.messages[1].content);
    assert_eq!(previous.messages[1].variant_count, 2);
    runtime
        .change_message(
            id.clone(),
            previous.conversation.revision,
            target.clone(),
            "branch".into(),
            String::new(),
        )
        .unwrap();
    let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
    let branched = runtime.conversation(branch.clone()).unwrap();
    runtime
        .change_message(
            branch.clone(),
            branched.conversation.revision,
            branched.messages[1].id.clone(),
            "variant".into(),
            "1".into(),
        )
        .unwrap();
    assert_eq!(runtime.conversation(branch).unwrap().messages[1].variant, 1);
    let latest = runtime.conversation(id.clone()).unwrap();
    runtime
        .change_message(
            id.clone(),
            latest.conversation.revision,
            target,
            "delete_variant".into(),
            String::new(),
        )
        .unwrap();
    let latest = runtime.conversation(id).unwrap();
    assert_eq!(latest.messages[1].variant_count, 1);
    assert_eq!(latest.messages[1].variant, 0);
    runtime.close();
}
