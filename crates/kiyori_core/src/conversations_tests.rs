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
        Self(std::env::temp_dir().join(format!(
                "kiyori-conversation-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
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
    assert_eq!(snapshot.messages.len(), 4);
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        reopened.conversation_catalog().unwrap().active_id,
        Some(id.clone())
    );
    assert_eq!(reopened.conversation(id).unwrap(), snapshot);
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
        store.connection.lock().unwrap().execute_batch("DROP TABLE conversation_messages;DROP TABLE conversation_runs;DROP TABLE conversation_state;DROP TABLE conversations; PRAGMA user_version=8;").unwrap();
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
