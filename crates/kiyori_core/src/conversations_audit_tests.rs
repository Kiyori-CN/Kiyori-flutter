use super::*;
use crate::conversation_audit;
use base64::{Engine, engine::general_purpose::STANDARD};

pub(super) fn audit_payloads(runtime: &Runtime, id: &str) -> Vec<(String, Value)> {
    runtime.with_store(|store| {
        let c = store.connection.lock().unwrap();
        Ok(c.prepare("SELECT event_type,payload FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence")
            .unwrap().query_map([id], |row| Ok((row.get::<_,String>(0)?,
                serde_json::from_str::<Value>(&row.get::<_,String>(1)?).unwrap())))
            .unwrap().collect::<Result<Vec<_>,_>>().unwrap())
    }).unwrap()
}

#[tokio::test]
async fn provider_audit_freezes_the_sent_body_and_redacts_credentials_before_storage() {
    let dir = Directory::new();
    let (endpoint, worker) = fixture(1, response("合成回复", "stop"));
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    let prepared = runtime.prepare_conversation(id.clone()).unwrap();
    let credentials = json!({"version":3,"apiKey":"local-fixture","headers":{"x-diagnostic":"diagnostic-secret"},"usePool":false,"keys":[],"rotation":"ROUND_ROBIN"}).to_string();
    let run = runtime
        .start_conversation(
            prepared,
            "记录JSON {\"password\":\"synthetic-password\"} local-fixture diagnostic-secret 😀"
                .into(),
            credentials,
        )
        .unwrap();
    let terminal = loop {
        let event = run.next_event().await.unwrap().unwrap();
        if matches!(
            event,
            chat::ChatEvent::Completed { .. } | chat::ChatEvent::Failed(_)
        ) {
            break event;
        }
    };
    assert!(matches!(terminal, chat::ChatEvent::Completed { .. }));
    // 不用cancel_and_wait掩盖锁释放；收到产品终态即可开始下一轮准备。
    drop(runtime.prepare_conversation(id.clone()).unwrap());
    let sent = worker.join().unwrap().remove(0);
    let events = audit_payloads(&runtime, &id);
    let provider: Vec<_> = events
        .iter()
        .filter(|(kind, _)| {
            kind.starts_with("PROVIDER_") || kind == "FINAL_PROVIDER_SEMANTIC_REQUEST"
        })
        .collect();
    assert_eq!(
        provider
            .iter()
            .map(|(kind, _)| kind.as_str())
            .collect::<Vec<_>>(),
        [
            "FINAL_PROVIDER_SEMANTIC_REQUEST",
            "PROVIDER_ATTEMPT_STARTED",
            "PROVIDER_RESPONSE_HEADERS",
            "PROVIDER_ATTEMPT_FINISHED"
        ]
    );
    let snapshot = &provider[0].1;
    assert_eq!(snapshot["requestBody"]["seed"], sent["seed"]);
    assert_eq!(snapshot["requestBody"]["model"], sent["model"]);
    assert_eq!(
        snapshot["requestBody"]["messages"]
            .as_array()
            .unwrap()
            .len(),
        sent["messages"].as_array().unwrap().len()
    );
    let encoded = snapshot.to_string();
    assert!(!encoded.contains("local-fixture"));
    assert!(!encoded.contains("diagnostic-secret"));
    assert!(!encoded.contains("synthetic-password"));
    assert!(encoded.contains("😀"));
    assert_eq!(provider[2].1["responseStatusCode"], 200);
    assert_eq!(provider[3].1["terminalState"], "COMPLETED");
    assert_eq!(provider[3].1["retrySafety"], "NO_AUTOMATIC_RETRY");
    assert_eq!(events.last().unwrap().0, "RUN_FINISHED");
    runtime.export_conversation_audit(id, "zip".into()).unwrap();
    runtime.close();
}

#[test]
fn audit_redaction_preserves_unicode_and_covers_inline_credentials() {
    let input = r#"正文😀 {"password":"synthetic-pass","content":"下一段"} api_key=test-key&suffix=保留 Bearer test-token Basic dXNlcjpwYXNz https://user:pass@example.test/path?signature=synthetic-signature&mode=保留"#;
    let masked = conversation_audit::redact(input);
    for secret in [
        "synthetic-pass",
        "test-key",
        "test-token",
        "dXNlcjpwYXNz",
        "user:pass",
        "synthetic-signature",
    ] {
        assert!(!masked.contains(secret), "{masked}");
    }
    for text in [
        "正文😀",
        "下一段",
        "suffix=保留",
        "mode=保留",
        "example.test/path",
    ] {
        assert!(masked.contains(text), "{masked}");
    }
    assert_eq!(conversation_audit::redact(&masked), masked);
    assert!(!conversation_audit::redact("before -----BEGIN RSA PRIVATE KEY-----\nprivate-fixture\n-----END RSA PRIVATE KEY----- after").contains("private-fixture"));
}

#[tokio::test]
async fn provider_attempt_failure_and_cancel_have_one_terminal_before_run_end() {
    for cancelled in [false, true] {
        let dir = Directory::new();
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        configure(
            &runtime,
            format!("http://{}", listener.local_addr().unwrap()),
        );
        let (entered, received) = tokio::sync::oneshot::channel();
        let worker = std::thread::spawn(move || {
            let (mut socket, _) = listener.accept().unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut bytes = Vec::new();
            let mut buffer = [0; 4096];
            loop {
                let count = socket.read(&mut buffer).unwrap();
                assert!(count > 0);
                bytes.extend_from_slice(&buffer[..count]);
                if let Some(end) = bytes.windows(4).position(|b| b == b"\r\n\r\n") {
                    let headers = String::from_utf8_lossy(&bytes[..end]).to_ascii_lowercase();
                    let len: usize = headers
                        .lines()
                        .find_map(|l| l.strip_prefix("content-length: "))
                        .unwrap()
                        .parse()
                        .unwrap();
                    if bytes.len() >= end + 4 + len {
                        break;
                    }
                }
            }
            let _ = entered.send(());
            if cancelled {
                std::thread::sleep(Duration::from_millis(80));
            } else {
                socket.write_all(b"HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").unwrap();
            }
        });
        let id = runtime.create_conversation().unwrap();
        let run = runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "合成测试".into(),
                payload(),
            )
            .unwrap();
        received.await.unwrap();
        if cancelled {
            run.cancel_and_wait().await;
        }
        let events = drain(&run).await;
        assert!(if cancelled {
            matches!(events.last(), Some(chat::ChatEvent::Cancelled))
        } else {
            matches!(events.last(),Some(chat::ChatEvent::Failed(e)) if e.http_status==Some(503))
        });
        worker.join().unwrap();
        let events = audit_payloads(&runtime, &id);
        let finishes: Vec<_> = events
            .iter()
            .filter(|(kind, _)| kind == "PROVIDER_ATTEMPT_FINISHED")
            .collect();
        assert_eq!(finishes.len(), 1);
        assert_eq!(
            finishes[0].1["terminalState"],
            if cancelled { "CANCELLED" } else { "FAILED" }
        );
        assert_eq!(events.last().unwrap().0, "RUN_FINISHED");
        runtime.close();
    }
}

#[tokio::test]
async fn rejected_attempt_audit_rolls_back_semantic_request_and_prevents_http() {
    let dir = Directory::new();
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    configure(
        &runtime,
        format!("http://{}", listener.local_addr().unwrap()),
    );
    let id = runtime.create_conversation().unwrap();
    runtime.with_store(|s| {
        s.connection.lock().unwrap().execute_batch("CREATE TRIGGER reject_attempt BEFORE INSERT ON conversation_audit_events WHEN NEW.event_type='PROVIDER_ATTEMPT_STARTED' BEGIN SELECT RAISE(ABORT,'fixture'); END;").unwrap();
        Ok(())
    }).unwrap();
    let run = runtime
        .start_conversation(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "合成测试".into(),
            payload(),
        )
        .unwrap();
    assert!(matches!(
        drain(&run).await.last(),
        Some(chat::ChatEvent::Failed(_))
    ));
    assert_eq!(
        listener.accept().unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    assert!(
        !audit_payloads(&runtime, &id)
            .iter()
            .any(|(kind, _)| kind == "FINAL_PROVIDER_SEMANTIC_REQUEST")
    );
    runtime.close();
}

#[test]
fn audit_notes_search_unicode_paging_signature_and_reopen_are_real() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    let first: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(first["status"], "BASIC");
    assert_eq!(first["eventCount"], 1);
    let note = format!("全文😀{}尾部", "界".repeat(9000));
    runtime
        .append_conversation_note(id.clone(), note.clone())
        .unwrap();
    let p0 = runtime
        .conversation_audit_payload(id.clone(), 2, 0)
        .unwrap();
    let p1 = runtime
        .conversation_audit_payload(id.clone(), 2, 1)
        .unwrap();
    let complete: Value = serde_json::from_str(&(p0 + &p1)).unwrap();
    assert_eq!(complete["note"], note);
    for index in 0..101 {
        runtime
            .append_conversation_note(id.clone(), format!("page-note-{index}"))
            .unwrap();
    }
    let page: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(page["events"].as_array().unwrap().len(), 100);
    assert_eq!(page["hasOlder"], true);
    let older: Value = serde_json::from_str(
        &runtime
            .conversation_audit(
                id.clone(),
                page["events"][0]["sequence"].as_i64().unwrap(),
                String::new(),
            )
            .unwrap(),
    )
    .unwrap();
    assert_eq!(older["events"].as_array().unwrap().len(), 3);
    let found: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, "全文 尾部".into())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(found["events"].as_array().unwrap().len(), 1);
    assert!(
        runtime
            .conversation_audit(id.clone(), -1, String::new())
            .is_err()
    );
    assert!(
        runtime
            .append_conversation_note(id.clone(), " ".into())
            .is_err()
    );
    let bytes = runtime
        .export_conversation_audit(id.clone(), "zip".into())
        .unwrap();
    let mut zip = zip::ZipArchive::new(std::io::Cursor::new(bytes)).unwrap();
    let mut contents = std::collections::BTreeMap::new();
    for index in 0..zip.len() {
        let mut entry = zip.by_index(index).unwrap();
        let name = entry.name().to_owned();
        let mut bytes = Vec::new();
        entry.read_to_end(&mut bytes).unwrap();
        contents.insert(name, bytes);
    }
    assert_eq!(contents.len(), 4);
    let seal: Value = serde_json::from_slice(&contents["seal.json"]).unwrap();
    assert_eq!(
        seal["eventsSha256"],
        conversation_audit::hash(&contents["events.json"])
    );
    assert_eq!(
        seal["messagesSha256"],
        conversation_audit::hash(&contents["messages.json"])
    );
    let signature: Value = serde_json::from_slice(&contents["signature.json"]).unwrap();
    let key = STANDARD
        .decode(signature["publicKey"].as_str().unwrap())
        .unwrap();
    let sig = STANDARD
        .decode(signature["signature"].as_str().unwrap())
        .unwrap();
    ring::signature::UnparsedPublicKey::new(&ring::signature::ED25519, key)
        .verify(&contents["seal.json"], &sig)
        .unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    let again: Value = serde_json::from_str(
        &reopened
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(again["chainHead"], page["chainHead"]);
    reopened.with_store(|store|{let c=store.connection.lock().unwrap();assert!(c.execute("UPDATE conversation_audit_events SET summary='tamper' WHERE sequence=1",[]).is_err());c.execute_batch("DROP TRIGGER conversation_audit_no_update;UPDATE conversation_audit_events SET summary='tamper' WHERE sequence=1;").unwrap();Ok(())}).unwrap();
    assert!(
        reopened
            .export_conversation_audit(id, "zip".into())
            .is_err()
    );
    reopened.close();
}

#[test]
fn audit_message_revisions_do_not_change_usage_and_migration_preserves_messages() {
    let dir = Directory::new();
    let r = Runtime::with_data_dir(&dir.0).unwrap();
    let id = r.create_conversation().unwrap();
    r.with_store(|s|{let c=s.connection.lock().unwrap();c.execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state) VALUES('note',?1,0,'user','原始消息','completed')",[&id]).unwrap();Ok(())}).unwrap();
    let item = r.conversation(id.clone()).unwrap().conversation;
    r.change_message(
        id.clone(),
        item.revision,
        "note".into(),
        "edit".into(),
        "修改消息".into(),
    )
    .unwrap();
    let markdown = String::from_utf8(
        r.export_conversation_audit(id.clone(), "markdown".into())
            .unwrap(),
    )
    .unwrap();
    assert!(markdown.contains("原始消息"));
    assert!(markdown.contains("修改消息"));
    assert_eq!(r.conversation_statistics(id.clone()).unwrap().requests, 0);
    r.with_store(|s| {
        let c = s.connection.lock().unwrap();
        conversation_audit::remove_schema_for_fixture(&c);
        c.execute_batch("PRAGMA user_version=19").unwrap();
        Ok(())
    })
    .unwrap();
    r.close();
    let upgraded = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        upgraded.conversation(id.clone()).unwrap().messages[0].content,
        "修改消息"
    );
    assert_eq!(
        serde_json::from_str::<Value>(&upgraded.conversation_audit(id, 0, String::new()).unwrap())
            .unwrap()["status"],
        "BASIC"
    );
    upgraded.close();
}

#[test]
fn deletion_stays_in_binding_and_inherits_folder_but_group_delete_does_not() {
    let dir = Directory::new();
    let r = Runtime::with_data_dir(&dir.0).unwrap();
    let a = r.create_conversation().unwrap();
    let default = r.prompt_catalog().unwrap().characters.remove(0);
    let mut draft = default.draft;
    draft.name = "另一个角色".into();
    let role = r.save_character(None, None, draft).unwrap();
    r.activate_prompt("character".into(), role).unwrap();
    let unrelated = r.create_conversation().unwrap();
    r.select_conversation(a.clone()).unwrap();
    r.change_chat_preference(
        r.chat_preferences().unwrap().revision,
        "create_folder".into(),
        "保留分组".into(),
    )
    .unwrap();
    let a_item = r.conversation(a.clone()).unwrap().conversation;
    r.change_conversation(
        a.clone(),
        a_item.revision,
        "folder".into(),
        "保留分组".into(),
    )
    .unwrap();
    let a_item = r.conversation(a.clone()).unwrap().conversation;
    r.change_conversation(a, a_item.revision, "delete".into(), String::new())
        .unwrap();
    let next = r.conversation_catalog().unwrap().active_id.unwrap();
    assert_ne!(next, unrelated);
    let replacement = r.conversation(next).unwrap().conversation;
    assert_eq!(replacement.character_id, crate::prompts::DEFAULT_CHARACTER);
    assert_eq!(replacement.folder, "保留分组");
    r.close();
}
