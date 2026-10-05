//! 正式QuickJS/HTTP下按提供方窗口触发总结；不触发不能消耗总结密钥或用量。
use super::*;

fn complete(outcome: &[ChatEvent], expected: &str) {
    assert!(
        !outcome
            .iter()
            .any(|e| matches!(e, ChatEvent::Failed(_) | ChatEvent::Cancelled)),
        "{outcome:?}"
    );
    assert!(
        outcome
            .iter()
            .any(|e| matches!(e,ChatEvent::Completed{reason,..} if reason=="stop")),
        "{outcome:?}"
    );
    let text = outcome
        .iter()
        .filter_map(|e| {
            if let ChatEvent::Text(s) = e {
                Some(s.as_str())
            } else {
                None
            }
        })
        .collect::<String>();
    assert_eq!(text, expected);
}

const SOURCE: &str = r#"exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'窗口夹具',description:'',listModels:{function:()=>[]},testConnection:{function:()=>true},
calculateInputTokens:{function:e=>{const h=e.eventPayload.chatHistory,last=h[h.length-1].content;
 if(last==='over-limit'&&h.some(t=>t.content==='summary-marker'))return 2048;
 if(last==='trigger'&&h.some(t=>t.content==='summary-marker'))return 10;
 if(last==='trigger'||last==='trigger-again')return 900;
 if(last==='over-limit')return 900;
 return 10;}},
sendMessage:{function:async e=>{const p=e.eventPayload,c=p.config;return (await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({history:p.chatHistory},'json').build().execute({})).json();}}});"#;

fn setup(fixture: &Fixture, endpoint: String) {
    fixture.configure(endpoint, true);
    let mut config = fixture.runtime.model_catalog().unwrap().configs.remove(0);
    config.draft.options.summary_by_count = false;
    config.draft.options.context_length = 1.;
    config.draft.options.summary_threshold = 0.5;
    fixture
        .runtime
        .save_model_config(config.id, config.revision, config.draft, None, None)
        .unwrap();
}

async fn send(fixture: &Fixture, id: &str, text: &str, summary: Option<String>) -> Vec<ChatEvent> {
    let run = fixture
        .runtime
        .start_conversation_with_summary(
            fixture.runtime.prepare_conversation(id.into()).unwrap(),
            text.into(),
            CREDENTIALS.into(),
            summary,
            None,
            None,
            None,
        )
        .unwrap();
    events(&run).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn provider_window_overrides_byte_estimate_recounts_summary_and_preserves_usage_history() {
    for (second, summarized) in [("trigger".to_owned(), true), ("x".repeat(5000), false)] {
        let fixture = Fixture::new(SOURCE).await;
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        setup(
            &fixture,
            format!(
                "http://{}/v1/chat/completions",
                listener.local_addr().unwrap()
            ),
        );
        let expected = second.clone();
        let server = std::thread::spawn(move || {
            let (mut socket, _, body) = read(&listener);
            assert_eq!(
                body["history"].as_array().unwrap().last().unwrap()["content"],
                "first"
            );
            respond(
                &mut socket,
                r#"{"text":"first-answer","usage":{"input":4,"output":2}}"#,
            );
            if summarized {
                let (mut socket, _, body) = read(&listener);
                assert_eq!(
                    body["history"].as_array().unwrap().last().unwrap()["content"],
                    "请根据以上对话内容生成完整的对话摘要。"
                );
                assert!(body.to_string().contains("first-answer"));
                assert!(!body.to_string().contains("trigger"));
                respond(
                    &mut socket,
                    r#"{"text":"summary-marker","usage":{"input":6,"output":3}}"#,
                );
            }
            let (mut socket, _, body) = read(&listener);
            assert_eq!(
                body["history"].as_array().unwrap().last().unwrap()["content"],
                expected
            );
            assert_eq!(body.to_string().contains("summary-marker"), summarized);
            assert_eq!(body.to_string().contains("first-answer"), !summarized);
            respond(
                &mut socket,
                r#"{"text":"second-answer","usage":{"input":5,"output":1}}"#,
            );
            assert!(listener.accept().is_err());
        });
        let id = fixture.runtime.create_conversation().unwrap();
        complete(&send(&fixture, &id, "first", None).await, "first-answer");
        complete(&send(&fixture, &id, &second, None).await, "second-answer");
        let snapshot = fixture.runtime.conversation(id.clone()).unwrap();
        assert_eq!(snapshot.messages.len(), 4);
        assert_eq!(snapshot.messages[0].content, "first");
        assert_eq!(snapshot.messages[1].content, "first-answer");
        assert_eq!(snapshot.messages[2].content, second);
        assert_eq!(snapshot.summary.is_some(), summarized);
        let stats = fixture.runtime.conversation_statistics(id.clone()).unwrap();
        assert_eq!(stats.context_tokens, Some(10));
        assert_eq!(stats.recent_input_tokens, Some(5));
        assert_eq!(stats.input_tokens, Some(if summarized { 15 } else { 9 }));
        assert_eq!(stats.output_tokens, Some(if summarized { 6 } else { 3 }));
        assert_eq!(stats.reported_requests, if summarized { 3 } else { 2 });
        server.join().unwrap();
        fixture.runtime.close();
        let reopened = Runtime::with_data_dir(&fixture.root).unwrap();
        assert_eq!(reopened.conversation(id).unwrap(), snapshot);
        reopened.close();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn conditional_count_cancellation_and_late_config_change_never_start_summary() {
    use std::sync::atomic::{AtomicBool, Ordering};
    let source = r#"exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'窗口夹具',description:'',listModels:{function:()=>[]},testConnection:{function:()=>true},
calculateInputTokens:{function:async e=>{const c=e.eventPayload.config;return (await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({phase:'count'},'json').build().execute({})).json();}},
sendMessage:{function:async e=>{const c=e.eventPayload.config;return (await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({phase:'send'},'json').build().execute({})).json();}}});"#;
    for cancel in [true, false] {
        let fixture = Fixture::new(source).await;
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        setup(
            &fixture,
            format!(
                "http://{}/v1/chat/completions",
                listener.local_addr().unwrap()
            ),
        );
        let ready = Arc::new(AtomicBool::new(false));
        let signal = ready.clone();
        let (resume, resumed) = std::sync::mpsc::channel();
        let server = std::thread::spawn(move || {
            let (mut socket, _, body) = read(&listener);
            assert_eq!(body["phase"], "count");
            respond(&mut socket, "10");
            let (mut socket, _, body) = read(&listener);
            assert_eq!(body["phase"], "send");
            respond(&mut socket, r#"{"text":"first-answer"}"#);
            let (mut socket, _, body) = read(&listener);
            assert_eq!(body["phase"], "count");
            signal.store(true, Ordering::Release);
            resumed.recv_timeout(Duration::from_secs(5)).unwrap();
            if cancel {
                assert_eq!(socket.read(&mut [0; 16]).unwrap(), 0);
            } else {
                respond(&mut socket, "900");
            }
            assert!(listener.accept().is_err());
        });
        let id = fixture.runtime.create_conversation().unwrap();
        complete(&send(&fixture, &id, "first", None).await, "first-answer");
        let run = fixture
            .runtime
            .start_conversation(
                fixture.runtime.prepare_conversation(id.clone()).unwrap(),
                "keep-original".into(),
                CREDENTIALS.into(),
            )
            .unwrap();
        tokio::time::timeout(Duration::from_secs(5), async {
            while !ready.load(Ordering::Acquire) {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
        })
        .await
        .unwrap();
        if cancel {
            run.cancel_and_wait().await;
        } else {
            let mut config = fixture.runtime.model_catalog().unwrap().configs.remove(0);
            config.draft.options.summary_rules = "changed while counting".into();
            fixture
                .runtime
                .save_model_config(config.id, config.revision, config.draft, None, None)
                .unwrap();
        }
        resume.send(()).unwrap();
        let outcome = events(&run).await;
        if cancel {
            assert!(outcome.iter().any(|e| matches!(e, ChatEvent::Cancelled)));
        } else {
            assert!(
                outcome.iter().any(
                    |e| matches!(e,ChatEvent::Failed(f) if f.kind==ChatFailureKind::InvalidInput)
                ),
                "{outcome:?}"
            );
        }
        assert!(!outcome.iter().any(|e| matches!(
            e,
            ChatEvent::Text(_) | ChatEvent::Usage { .. } | ChatEvent::Completed { .. }
        )));
        let snapshot = fixture.runtime.conversation(id).unwrap();
        assert!(snapshot.summary.is_none());
        assert_eq!(snapshot.messages[0].content, "first");
        assert_eq!(snapshot.messages[2].content, "keep-original");
        server.join().unwrap();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn untriggered_summary_does_not_require_or_rotate_independent_credentials() {
    let fixture = Fixture::new(SOURCE).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    setup(&fixture, endpoint.clone());
    let summary_id = fixture
        .runtime
        .create_model_config("独立总结".into())
        .unwrap();
    let mut draft = fixture
        .runtime
        .model_catalog()
        .unwrap()
        .configs
        .remove(0)
        .draft;
    draft.name = "独立总结".into();
    draft.options.summary_enabled = false;
    fixture
        .runtime
        .save_model_config(summary_id.clone(), 1, draft, None, None)
        .unwrap();
    fixture
        .runtime
        .select_function_model("summary".into(), summary_id, "fixture-model".into())
        .unwrap();
    let server = std::thread::spawn(move || {
        for answer in ["first-answer", "second-answer"] {
            let (mut socket, _, _) = read(&listener);
            respond(
                &mut socket,
                &json!({"text":answer,"usage":{"input":5,"output":1}}).to_string(),
            );
        }
        for (key, question) in [
            ("synthetic-summary-first", "trigger"),
            ("synthetic-summary-second", "trigger-again"),
        ] {
            let (mut socket, headers, body) = read_with_key(&listener, key);
            assert!(
                headers
                    .to_ascii_lowercase()
                    .contains(&format!("authorization: bearer {key}"))
            );
            assert_eq!(
                body["history"].as_array().unwrap().last().unwrap()["content"],
                "请根据以上对话内容生成完整的对话摘要。"
            );
            respond(
                &mut socket,
                r#"{"text":"summary-marker","usage":{"input":6,"output":2}}"#,
            );
            let (mut socket, _, body) = read(&listener);
            assert_eq!(
                body["history"].as_array().unwrap().last().unwrap()["content"],
                question
            );
            respond(
                &mut socket,
                r#"{"text":"answer","usage":{"input":5,"output":1}}"#,
            );
        }
        assert!(listener.accept().is_err());
    });
    let credentials = json!({"version":3,"apiKey":"","headers":{},"usePool":true,"rotation":"ROUND_ROBIN","keys":[
        {"id":"first","key":"synthetic-summary-first","enabled":true,"availability":"AVAILABLE"},
        {"id":"second","key":"synthetic-summary-second","enabled":true,"availability":"AVAILABLE"}]}).to_string();
    let id = fixture.runtime.create_conversation().unwrap();
    complete(&send(&fixture, &id, "first", None).await, "first-answer");
    // 没有独立凭据也能发送低窗口请求；第二次提供池，但不提前消耗其首项。
    complete(
        &send(&fixture, &id, &"x".repeat(5000), Some(credentials.clone())).await,
        "second-answer",
    );
    complete(
        &send(&fixture, &id, "trigger", Some(credentials.clone())).await,
        "answer",
    );
    complete(
        &send(&fixture, &id, "trigger-again", Some(credentials)).await,
        "answer",
    );
    server.join().unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn summarized_projection_still_over_limit_fails_without_sending_chat_or_losing_original() {
    let fixture = Fixture::new(SOURCE).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    setup(
        &fixture,
        format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        ),
    );
    let server = std::thread::spawn(move || {
        let (mut socket, _, _) = read(&listener);
        respond(
            &mut socket,
            r#"{"text":"first-answer","usage":{"input":4,"output":2}}"#,
        );
        let (mut socket, _, body) = read(&listener);
        assert!(!body.to_string().contains("over-limit"));
        respond(
            &mut socket,
            r#"{"text":"summary-marker","usage":{"input":6,"output":2}}"#,
        );
        assert!(listener.accept().is_err());
    });
    let id = fixture.runtime.create_conversation().unwrap();
    complete(&send(&fixture, &id, "first", None).await, "first-answer");
    let outcome = send(&fixture, &id, "over-limit", None).await;
    assert!(
        outcome
            .iter()
            .any(|e| matches!(e,ChatEvent::Failed(f) if f.kind==ChatFailureKind::InvalidInput)),
        "{outcome:?}"
    );
    assert!(!outcome.iter().any(|e| matches!(
        e,
        ChatEvent::Text(_) | ChatEvent::Usage { .. } | ChatEvent::Completed { .. }
    )));
    let snapshot = fixture.runtime.conversation(id.clone()).unwrap();
    assert_eq!(snapshot.messages[0].content, "first");
    assert_eq!(snapshot.messages[2].content, "over-limit");
    assert!(snapshot.messages[3].content.is_empty());
    assert_eq!(
        fixture
            .runtime
            .conversation_statistics(id)
            .unwrap()
            .context_tokens,
        Some(2048)
    );
    server.join().unwrap();
}
