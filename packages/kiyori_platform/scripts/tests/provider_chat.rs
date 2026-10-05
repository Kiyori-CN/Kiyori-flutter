#![cfg(any(target_os = "windows", target_os = "android"))]
use kiyori_core::{
    chat::{self, ChatEvent, ChatFailureKind},
    runtime::Runtime,
};
use kiyori_scripts::NativeScripts;
use serde_json::{Value, json};
use std::{
    io::{Cursor, Read, Write},
    net::{TcpListener, TcpStream},
    sync::Arc,
    time::{Duration, Instant},
};
use zip::{ZipWriter, write::SimpleFileOptions};

const SOURCE: &str = r#"
exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'正式供应商',description:'',
listModels:{function:async e=>{const c=e.eventPayload.config;return {models:(await OkHttp.newBuilder().build().newRequest()
 .url(c.apiEndpoint.replace('/chat/completions','/models')).method('GET').headers({Authorization:'Bearer '+c.apiKey}).build().execute({})).json().data};}},
testConnection:{function:()=>({success:true})},calculateInputTokens:{function:()=>({tokens:7})},
sendMessage:{function:async e=>{const p=e.eventPayload,c=p.config;let buffer='',text='',usage;
 if(c.apiKey!=='__kiyori_credential_reference__'||!Array.isArray(p.modelParameters)||typeof p.enableThinking!=='boolean')throw Error('payload');
 const result=await OkHttp.newBuilder().readTimeout(10000).build().newRequest().url(c.apiEndpoint).method('POST')
 .headers({Authorization:'Bearer '+c.apiKey,'Content-Type':'application/json'})
 .body({model:c.modelName,messages:p.chatHistory.map(t=>({role:t.kind.toLowerCase(),content:t.content})),stream:p.stream},'json')
 .build().execute(p.stream?{onIntermediateResult:e=>{buffer+=e.chunk;let end;while((end=buffer.indexOf('\n\n'))>=0){
 const part=buffer.slice(0,end).slice(5).trim();buffer=buffer.slice(end+2);if(part==='[DONE]')continue;const value=JSON.parse(part);
 if(value.usage)usage={input:value.usage.prompt_tokens,output:value.usage.completion_tokens,cachedInput:1};
 const chunk=value.choices?.[0]?.delta?.content;if(chunk){text+=chunk;sendIntermediateResult({chunk});}}}}:{});
 if(!p.stream){const value=result.json();text=value.choices[0].message.content;usage={input:value.usage.prompt_tokens,output:value.usage.completion_tokens,cachedInput:1};}
 return {text,usage};}}});
"#;
const CREDENTIALS: &str = r#"{"version":3,"apiKey":"synthetic-fixture-key","headers":{},"usePool":false,"keys":[],"rotation":"ROUND_ROBIN"}"#;
#[path = "provider_chat/threshold.rs"]
mod threshold;
struct Fixture {
    root: std::path::PathBuf,
    runtime: Arc<Runtime>,
}
static FIXTURE_SEQUENCE: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
impl Fixture {
    async fn new(source: &str) -> Self {
        let root = std::env::temp_dir().join(format!(
            "kiyori-provider-chat-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            FIXTURE_SEQUENCE.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        let runtime = Arc::new(Runtime::with_data_dir(&root).unwrap());
        runtime.set_script_adapter(Arc::new(NativeScripts)).unwrap();
        let mut zip = ZipWriter::new(Cursor::new(vec![]));
        zip.start_file("manifest.json", SimpleFileOptions::default())
            .unwrap();
        zip.write_all(br#"{"schema_version":1,"toolpkg_id":"fixture","version":"1.0.0","main":"main.js","enabled_by_default":true}"#).unwrap();
        zip.start_file("main.js", SimpleFileOptions::default())
            .unwrap();
        zip.write_all(source.as_bytes()).unwrap();
        let import = runtime.begin_extension_import().unwrap();
        import.append(zip.finish().unwrap().into_inner()).unwrap();
        import.finish().await.unwrap();
        drop(import);
        Self { root, runtime }
    }
    fn configure(&self, endpoint: String, summary: bool) {
        let mut config = self.runtime.model_catalog().unwrap().configs.remove(0);
        config.draft.provider = "TOOLPKG:fixture:fixture".into();
        config.draft.protocol = "native".into();
        config.draft.endpoint = endpoint;
        config.draft.models = vec!["fixture-model".into()];
        config.draft.options.summary_enabled = summary;
        config.draft.options.summary_count = 1;
        config.draft.options.concurrent_limit = 1;
        self.runtime
            .save_model_config(
                config.id.clone(),
                config.revision,
                config.draft,
                None,
                Some("fixture-model".into()),
            )
            .unwrap();
        for function in ["chat", "summary"] {
            self.runtime
                .select_function_model(function.into(), config.id.clone(), "fixture-model".into())
                .unwrap();
        }
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        self.runtime.close();
        std::fs::remove_dir_all(&self.root).unwrap();
    }
}
fn read(listener: &TcpListener) -> (TcpStream, String, Value) {
    read_with_key(listener, "synthetic-fixture-key")
}
fn read_with_key(listener: &TcpListener, expected_key: &str) -> (TcpStream, String, Value) {
    let start = Instant::now();
    let mut socket = loop {
        match listener.accept() {
            Ok((s, _)) => break s,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                assert!(start.elapsed() < Duration::from_secs(15));
                std::thread::sleep(Duration::from_millis(1));
            }
            Err(e) => panic!("{e}"),
        }
    };
    socket.set_nonblocking(false).unwrap();
    socket
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let mut bytes = vec![];
    let mut part = [0; 4096];
    while !bytes.windows(4).any(|w| w == b"\r\n\r\n") {
        let n = socket.read(&mut part).unwrap();
        assert!(n > 0);
        bytes.extend_from_slice(&part[..n]);
    }
    let end = bytes.windows(4).position(|w| w == b"\r\n\r\n").unwrap() + 4;
    let headers = String::from_utf8(bytes[..end].to_vec()).unwrap();
    assert!(
        headers
            .to_lowercase()
            .contains(&format!("authorization: bearer {expected_key}"))
    );
    assert!(!headers.contains("__kiyori_"));
    let length = headers
        .lines()
        .find_map(|line| {
            line.to_lowercase()
                .strip_prefix("content-length: ")
                .and_then(|s| s.parse::<usize>().ok())
        })
        .unwrap_or(0);
    while bytes.len() - end < length {
        let n = socket.read(&mut part).unwrap();
        assert!(n > 0);
        bytes.extend_from_slice(&part[..n]);
    }
    let body = if length == 0 {
        Value::Null
    } else {
        serde_json::from_slice(&bytes[end..end + length]).unwrap()
    };
    assert!(
        !body.to_string().contains("synthetic-fixture-key")
            && !body.to_string().contains(expected_key)
            && !body.to_string().contains("__kiyori_")
    );
    (socket, headers, body)
}
fn respond(socket: &mut TcpStream, body: &str) {
    socket
        .write_all(
            format!(
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            )
            .as_bytes(),
        )
        .unwrap();
    for part in body.as_bytes().chunks(11) {
        socket.write_all(part).unwrap();
    }
}
async fn events(run: &chat::ChatRun) -> Vec<ChatEvent> {
    tokio::time::timeout(Duration::from_secs(15), async {
        let mut events = vec![];
        while let Some(e) = run.next_event().await.unwrap() {
            events.push(e);
        }
        events
    })
    .await
    .unwrap()
}
fn complete(events: &[ChatEvent], expected: &str) {
    assert!(
        !events.iter().any(|e| matches!(e, ChatEvent::Failed(_))),
        "{events:?}"
    );
    assert!(
        events
            .iter()
            .any(|e| matches!(e,ChatEvent::Completed{reason,..} if reason=="stop")),
        "{events:?}"
    );
    let text = events
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
    assert!(events.iter().any(|e| matches!(
        e,
        ChatEvent::Usage {
            input: 4,
            output: 2,
            cache_read: Some(1),
            ..
        }
    )));
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn directory_stream_buffered_probes_conversation_summary_and_reopen_use_formal_owner() {
    let fixture = Fixture::new(SOURCE).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    fixture.configure(
        format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        ),
        true,
    );
    let server = std::thread::spawn(move || {
        for index in 0..7 {
            let (mut socket, headers, body) = read(&listener);
            if index == 0 {
                assert!(headers.starts_with("GET /v1/models "));
                respond(
                    &mut socket,
                    r#"{"data":[{"id":"fixture-model","name":"模型"}]}"#,
                );
                continue;
            }
            assert!(headers.starts_with("POST /v1/chat/completions "));
            assert_eq!(body["model"], "fixture-model");
            let messages = body["messages"].as_array().unwrap();
            let answer = match index {
                1 => {
                    assert_eq!(messages.last().unwrap()["content"], "Hi");
                    "你好".to_owned()
                }
                2 => {
                    assert_eq!(body["stream"], false);
                    let system = messages[0]["content"].as_str().unwrap();
                    system
                        .strip_prefix("Reply with exactly ")
                        .unwrap()
                        .strip_suffix(" and nothing else.")
                        .unwrap()
                        .to_owned()
                }
                3 => {
                    assert_eq!(messages.last().unwrap()["content"], "one");
                    "第一轮".into()
                }
                4 => {
                    assert!(
                        messages
                            .iter()
                            .any(|m| m["content"].as_str().unwrap().contains("one"))
                    );
                    "摘要：one和第一轮".into()
                }
                5 => {
                    assert_eq!(messages.last().unwrap()["content"], "two");
                    assert!(
                        messages
                            .iter()
                            .any(|m| m["content"].as_str().unwrap().contains("摘要：one"))
                    );
                    "第二轮".into()
                }
                _ => "手动摘要：one和two".into(),
            };
            let usage = json!({"prompt_tokens":4,"completion_tokens":2});
            let response = if body["stream"] == true {
                format!(
                    "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
                    json!({"choices":[{"delta":{"content":answer}}]}),
                    json!({"usage":usage,"choices":[{"delta":{},"finish_reason":"stop"}]})
                )
            } else {
                json!({"choices":[{"message":{"content":answer},"finish_reason":"stop"}],"usage":usage}).to_string()
            };
            respond(&mut socket, &response);
        }
    });
    let runtime = &fixture.runtime;
    let directory = events(
        &runtime
            .start_configured_model_directory("default".into(), 2, CREDENTIALS.into())
            .unwrap(),
    )
    .await;
    assert!(
        directory.iter().any(
            |e| matches!(e,ChatEvent::Models(models) if models.len()==1&&models[0].name=="模型")
        ),
        "{directory:?}"
    );
    let chat = events(
        &runtime
            .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
            .unwrap(),
    )
    .await;
    complete(&chat, "你好");
    let config = runtime.model_catalog().unwrap().configs.remove(0);
    let mut input = chat::probe::prepare(
        config.draft,
        "synthetic-fixture-key".into(),
        vec![],
        "system",
    )
    .unwrap();
    input.stream = false;
    let system = events(&runtime.start_chat(input).unwrap()).await;
    assert!(
        system.iter().any(|e| matches!(
            e,
            ChatEvent::Completed {
                verified: Some(true),
                ..
            }
        )),
        "{system:?}"
    );
    let id = runtime.create_conversation().unwrap();
    for (prompt, answer) in [("one", "第一轮"), ("two", "第二轮")] {
        let run = runtime
            .start_conversation_with_summary(
                runtime.prepare_conversation(id.clone()).unwrap(),
                prompt.into(),
                CREDENTIALS.into(),
                Some(CREDENTIALS.into()),
                None,
                None,
                None,
            )
            .unwrap();
        complete(&events(&run).await, answer);
        let statistics = runtime.conversation_statistics(id.clone()).unwrap();
        assert_eq!(statistics.context_tokens, Some(7));
        assert_eq!(statistics.recent_input_tokens, Some(4));
    }
    let snapshot = runtime.conversation(id.clone()).unwrap();
    assert_eq!(snapshot.messages.len(), 4);
    assert_eq!(
        snapshot.summary.as_ref().unwrap().content,
        "摘要：one和第一轮"
    );
    let summary = runtime
        .prepare_summary(
            id.clone(),
            snapshot.messages.last().unwrap().id.clone(),
            snapshot.conversation.revision,
        )
        .unwrap();
    let manual = runtime.start_summary(summary, CREDENTIALS.into()).unwrap();
    complete(&events(&manual).await, "手动摘要：one和two");
    server.join().unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&fixture.root).unwrap();
    let final_snapshot = reopened.conversation(id).unwrap();
    assert_eq!(final_snapshot.messages[..4], snapshot.messages);
    assert_eq!(
        final_snapshot.messages.last().unwrap().content,
        "手动摘要：one和two"
    );
    assert_eq!(reopened.extension_providers().unwrap().len(), 1);
    reopened.close();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn disabling_provider_cancels_active_and_queued_chat_without_second_post() {
    use std::sync::atomic::{AtomicBool, Ordering};
    let fixture = Fixture::new(SOURCE).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    fixture.configure(
        format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        ),
        false,
    );
    let connected = Arc::new(AtomicBool::new(false));
    let signal = connected.clone();
    let closed = Arc::new(AtomicBool::new(false));
    let stopped = closed.clone();
    let server = std::thread::spawn(move || {
        let (mut socket, _, _) = read(&listener);
        socket
            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\n")
            .unwrap();
        signal.store(true, Ordering::Release);
        let mut bytes = [0; 1024];
        assert_eq!(socket.read(&mut bytes).unwrap(), 0);
        stopped.store(true, Ordering::Release);
        std::thread::sleep(Duration::from_millis(50));
        assert!(listener.accept().is_err());
    });
    let runtime = &fixture.runtime;
    let active = runtime
        .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
        .unwrap();
    tokio::time::timeout(Duration::from_secs(5), async {
        while !connected.load(Ordering::Acquire) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    let queued = runtime
        .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
        .unwrap();
    tokio::time::sleep(Duration::from_millis(30)).await;
    tokio::time::timeout(
        Duration::from_secs(5),
        runtime.change_extension("fixture".into(), 1, Some(false)),
    )
    .await
    .unwrap()
    .unwrap();
    for run in [&active, &queued] {
        let outcome = events(run).await;
        assert!(
            outcome
                .iter()
                .any(|e| matches!(e,ChatEvent::Failed(f) if f.kind==ChatFailureKind::Interrupted)),
            "{outcome:?}"
        );
    }
    server.join().unwrap();
    assert!(closed.load(Ordering::Acquire));
    assert!(runtime.extension_providers().unwrap().is_empty());
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn malformed_usage_and_missing_or_forged_final_fail_without_false_success() {
    for (handler, accepted) in [
        (
            "sendIntermediateResult({chunk:'prefix'});return {text:'forged'};",
            false,
        ),
        (
            "sendIntermediateResult({chunk:'prefix'});return {usage:{input:2}};",
            false,
        ),
        ("return {text:'valid',usage:{input:-1,output:1}};", false),
        (
            "return {text:'valid',usage:{input:2,inputTokens:3,output:1}};",
            false,
        ),
        ("return {text:'valid',usage:{input:2,output:1.5}};", false),
        (
            "sendIntermediateResult({usage:{input:2,output:1}});return {text:'valid',usage:{input:4,output:2,cachedInput:1}};",
            true,
        ),
    ] {
        let source = format!(
            "exports.registerToolPkg=()=>ToolPkg.registerAiProvider({{id:'fixture',displayName:'夹具',description:'',listModels:{{function:()=>[]}},testConnection:{{function:()=>true}},calculateInputTokens:{{function:()=>1}},sendMessage:{{function:()=>{{{handler}}}}}}});"
        );
        let fixture = Fixture::new(&source).await;
        fixture.configure("http://127.0.0.1:1/v1/chat/completions".into(), false);
        let outcome = events(
            &fixture
                .runtime
                .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
                .unwrap(),
        )
        .await;
        if accepted {
            complete(&outcome, "valid");
        } else {
            assert!(
                outcome
                    .iter()
                    .any(|e| matches!(e,ChatEvent::Failed(f) if f.kind==ChatFailureKind::Protocol)),
                "{outcome:?}"
            );
            assert!(
                !outcome
                    .iter()
                    .any(|e| matches!(e, ChatEvent::Completed { .. }))
            );
        }
    }
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn caught_http_failure_cannot_be_returned_as_success_and_stream_timeout_keeps_kind() {
    for timeout in [false, true] {
        let source = r#"exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'夹具',description:'',
listModels:{function:()=>[]},testConnection:{function:()=>true},calculateInputTokens:{function:()=>1},
sendMessage:{function:async e=>{const c=e.eventPayload.config;try {await OkHttp.newBuilder().readTimeout(100).build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body('{}','text').build().execute({});}catch(_){}return {text:'fake success'};}}});"#;
        let fixture = Fixture::new(source).await;
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        fixture.configure(
            format!(
                "http://{}/v1/chat/completions",
                listener.local_addr().unwrap()
            ),
            false,
        );
        let server = std::thread::spawn(move || {
            let (mut socket, _, _) = read(&listener);
            if timeout {
                socket
                    .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n")
                    .unwrap();
                let mut bytes = [0; 1];
                assert_eq!(socket.read(&mut bytes).unwrap(), 0);
            } else {
                socket.write_all(b"HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").unwrap();
            }
        });
        let outcome = events(
            &fixture
                .runtime
                .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
                .unwrap(),
        )
        .await;
        assert!(
            !outcome
                .iter()
                .any(|e| matches!(e, ChatEvent::Completed { .. })),
            "{outcome:?}"
        );
        assert!(outcome.iter().any(|e|matches!(e,ChatEvent::Failed(f) if f.kind==if timeout{ChatFailureKind::Timeout}else{ChatFailureKind::Protocol})),"{outcome:?}");
        server.join().unwrap();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn extension_pool_and_xml_continuation_share_chat_owner_and_release_for_next_key() {
    let source = r#"exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'夹具',description:'',
listModels:{function:()=>['fixture-model']},testConnection:{function:async e=>{const c=e.eventPayload.config;
 const r=await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({messages:[],connection:true},'json').build().execute({});
 return {success:r.json().answer==='ok'};}},calculateInputTokens:{function:()=>1},
sendMessage:{function:async e=>{const p=e.eventPayload,c=p.config;
 const result=await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({messages:p.chatHistory},'json').build().execute({});
 return {text:result.json().answer};}}});"#;
    let fixture = Fixture::new(source).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    fixture.configure(
        format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        ),
        false,
    );
    let server = std::thread::spawn(move || {
        for index in 0..3 {
            let (mut socket, _, body) = read(&listener);
            let answer = if index == 0 {
                assert_eq!(body["connection"], true);
                "ok".to_owned()
            } else if index == 1 {
                "<tool name=\"echo\"><param name=\"text\">ping</param></tool>".into()
            } else {
                let history = body["messages"].as_array().unwrap();
                let last = history.last().unwrap()["content"].as_str().unwrap();
                assert!(
                    history
                        .iter()
                        .any(|m| m["content"].as_str().unwrap().contains("<tool name"))
                );
                last.strip_prefix("<tool_result name=\"echo\" status=\"success\">")
                    .unwrap()
                    .strip_suffix("</tool_result>")
                    .unwrap()
                    .to_owned()
            };
            respond(&mut socket, &json!({"answer":answer}).to_string());
        }
    });
    let runtime = &fixture.runtime;
    let draft = runtime.model_catalog().unwrap().configs.remove(0).draft;
    let pool = runtime
        .start_pool_test(
            draft,
            vec![chat::pool::PoolKey {
                id: "key-1".into(),
                key: "synthetic-fixture-key".into(),
                enabled: true,
                availability: "UNTESTED".into(),
            }],
            vec![],
            1,
        )
        .unwrap();
    let outcome = events(&pool).await;
    assert!(
        outcome
            .iter()
            .any(|e| matches!(e,ChatEvent::PoolResult{id,available:true} if id=="key-1")),
        "{outcome:?}"
    );
    assert!(
        outcome
            .iter()
            .any(|e| matches!(e,ChatEvent::Completed{reason,..} if reason=="pool")),
        "{outcome:?}"
    );
    let xml = runtime
        .start_configured_probe("default".into(), 2, CREDENTIALS.into(), "xml_tool".into())
        .unwrap();
    let outcome = events(&xml).await;
    assert!(
        outcome.iter().any(|e| matches!(
            e,
            ChatEvent::Completed {
                verified: Some(true),
                ..
            }
        )),
        "{outcome:?}"
    );
    server.join().unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn pool_uses_connection_handler_without_chat_or_count_and_rejects_false_results() {
    for (result, accepted) in [
        ("true", true),
        ("'ready'", true),
        ("{success:true,message:'ready'}", true),
        ("false", false),
        ("{success:false}", false),
        ("{success:'true'}", false),
        ("{success:true,error:'failed'}", false),
        ("null", false),
    ] {
        let source = format!(
            "exports.registerToolPkg=()=>ToolPkg.registerAiProvider({{id:'fixture',displayName:'夹具',description:'',listModels:{{function:()=>[]}},calculateInputTokens:{{function:()=>{{throw Error('count must not run')}}}},sendMessage:{{function:()=>{{throw Error('chat must not run')}}}},testConnection:{{function:e=>{{if(e.eventPayload.chatHistory)throw Error('history');return {result};}}}}}});"
        );
        let fixture = Fixture::new(&source).await;
        fixture.configure("http://127.0.0.1:1/v1/chat/completions".into(), false);
        let draft = fixture
            .runtime
            .model_catalog()
            .unwrap()
            .configs
            .remove(0)
            .draft;
        let run = fixture
            .runtime
            .start_pool_test(
                draft,
                vec![chat::pool::PoolKey {
                    id: "key".into(),
                    key: "synthetic-fixture-key".into(),
                    enabled: true,
                    availability: "UNTESTED".into(),
                }],
                vec![],
                1,
            )
            .unwrap();
        let outcome = events(&run).await;
        assert!(
            outcome
                .iter()
                .any(|e| matches!(e,ChatEvent::PoolResult{available,..} if *available==accepted)),
            "{result}: {outcome:?}"
        );
        assert!(
            !outcome.iter().any(|e| matches!(
                e,
                ChatEvent::Text(_) | ChatEvent::Usage { .. } | ChatEvent::Failed(_)
            )),
            "{outcome:?}"
        );
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn count_and_send_use_same_final_history_and_one_concurrency_permit() {
    let source = r#"exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'夹具',description:'',listModels:{function:()=>[]},testConnection:{function:()=>true},
calculateInputTokens:{function:async e=>{const p=e.eventPayload,c=p.config;
 const r=await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({phase:'count',history:p.chatHistory,tools:p.availableTools},'json').build().execute({});return r.json();}},
sendMessage:{function:async e=>{const p=e.eventPayload,c=p.config;const r=await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({phase:'send',history:p.chatHistory},'json').build().execute({});return r.json();}}});"#;
    let fixture = Fixture::new(source).await;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    fixture.configure(
        format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        ),
        false,
    );
    let server = std::thread::spawn(move || {
        let (mut socket, _, count) = read(&listener);
        assert_eq!(count["phase"], "count");
        assert_eq!(
            count["history"].as_array().unwrap().last().unwrap()["content"],
            "final input 😀"
        );
        assert_eq!(count["tools"], Value::Null);
        respond(&mut socket, r#"{"inputTokens":"123.99"}"#);
        let (mut socket, _, send) = read(&listener);
        assert_eq!(send["phase"], "send");
        assert_eq!(send["history"], count["history"]);
        respond(
            &mut socket,
            r#"{"text":"answer","usage":{"input":4,"output":2}}"#,
        );
    });
    let id = fixture.runtime.create_conversation().unwrap();
    let run = fixture
        .runtime
        .start_conversation(
            fixture.runtime.prepare_conversation(id.clone()).unwrap(),
            "final input 😀".into(),
            CREDENTIALS.into(),
        )
        .unwrap();
    let outcome = events(&run).await;
    assert!(
        outcome
            .iter()
            .any(|e| matches!(e, ChatEvent::Completed { .. })),
        "{outcome:?}"
    );
    assert!(
        !outcome.iter().any(|e| matches!(e, ChatEvent::Failed(_))),
        "{outcome:?}"
    );
    let stats = fixture.runtime.conversation_statistics(id).unwrap();
    assert_eq!(stats.context_tokens, Some(123));
    assert_eq!(stats.recent_input_tokens, Some(4));
    server.join().unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn invalid_or_over_budget_count_never_sends_or_claims_usage() {
    for (count, expected) in [
        ("'invalid'", ChatFailureKind::Protocol),
        ("{error:'failure',tokens:2}", ChatFailureKind::Protocol),
        ("2147483647", ChatFailureKind::InvalidInput),
    ] {
        let source = format!(
            "exports.registerToolPkg=()=>ToolPkg.registerAiProvider({{id:'fixture',displayName:'夹具',description:'',listModels:{{function:()=>[]}},testConnection:{{function:()=>true}},calculateInputTokens:{{function:()=>({count})}},sendMessage:{{function:()=>({{text:'MUST NOT SEND',usage:{{input:2,output:1}}}})}}}});"
        );
        let fixture = Fixture::new(&source).await;
        fixture.configure("http://127.0.0.1:1/v1/chat/completions".into(), false);
        let id = fixture.runtime.create_conversation().unwrap();
        let run = fixture
            .runtime
            .start_conversation(
                fixture.runtime.prepare_conversation(id.clone()).unwrap(),
                "keep original".into(),
                CREDENTIALS.into(),
            )
            .unwrap();
        let outcome = events(&run).await;
        assert!(
            outcome
                .iter()
                .any(|e| matches!(e,ChatEvent::Failed(f) if f.kind==expected)),
            "{outcome:?}"
        );
        assert!(
            !outcome.iter().any(|e| matches!(
                e,
                ChatEvent::Text(_) | ChatEvent::Usage { .. } | ChatEvent::Completed { .. }
            )),
            "{outcome:?}"
        );
        let snapshot = fixture.runtime.conversation(id).unwrap();
        assert_eq!(snapshot.messages[0].content, "keep original");
        assert!(snapshot.messages[1].content.is_empty());
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn revocation_during_count_or_connection_waits_for_http_and_never_marks_key_unavailable() {
    use std::sync::atomic::{AtomicBool, Ordering};
    for handler in ["calculateInputTokens", "testConnection"] {
        let work = "async e=>{const c=e.eventPayload.config;const r=await OkHttp.newBuilder().build().newRequest().url(c.apiEndpoint).method('POST').headers({Authorization:'Bearer '+c.apiKey}).body({},'json').build().execute({});return r.json();}";
        let source = format!(
            "exports.registerToolPkg=()=>ToolPkg.registerAiProvider({{id:'fixture',displayName:'夹具',description:'',listModels:{{function:()=>[]}},sendMessage:{{function:()=>{{throw Error('send must not run')}}}},calculateInputTokens:{{function:{}}},testConnection:{{function:{}}}}});",
            if handler == "calculateInputTokens" {
                work
            } else {
                "()=>1"
            },
            if handler == "testConnection" {
                work
            } else {
                "()=>true"
            }
        );
        let fixture = Fixture::new(&source).await;
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        fixture.configure(
            format!(
                "http://{}/v1/chat/completions",
                listener.local_addr().unwrap()
            ),
            false,
        );
        let connected = Arc::new(AtomicBool::new(false));
        let signal = connected.clone();
        let server = std::thread::spawn(move || {
            let (mut socket, _, _) = read(&listener);
            socket
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\n")
                .unwrap();
            signal.store(true, Ordering::Release);
            assert_eq!(socket.read(&mut [0; 16]).unwrap(), 0);
            assert!(listener.accept().is_err());
        });
        let r = &fixture.runtime;
        let run = if handler == "testConnection" {
            r.start_pool_test(
                r.model_catalog().unwrap().configs.remove(0).draft,
                vec![chat::pool::PoolKey {
                    id: "key".into(),
                    key: "synthetic-fixture-key".into(),
                    enabled: true,
                    availability: "UNTESTED".into(),
                }],
                vec![],
                1,
            )
            .unwrap()
        } else {
            r.start_configured_probe("default".into(), 2, CREDENTIALS.into(), "chat".into())
                .unwrap()
        };
        tokio::time::timeout(Duration::from_secs(5), async {
            while !connected.load(Ordering::Acquire) {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
        })
        .await
        .unwrap();
        tokio::time::timeout(
            Duration::from_secs(5),
            r.change_extension("fixture".into(), 1, Some(false)),
        )
        .await
        .unwrap()
        .unwrap();
        let outcome = events(&run).await;
        assert!(
            outcome
                .iter()
                .any(|e| matches!(e,ChatEvent::Failed(f) if f.kind==ChatFailureKind::Interrupted)),
            "{handler}: {outcome:?}"
        );
        assert!(
            !outcome.iter().any(|e| matches!(
                e,
                ChatEvent::PoolResult { .. } | ChatEvent::Completed { .. } | ChatEvent::Text(_)
            )),
            "{outcome:?}"
        );
        server.join().unwrap();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
#[ignore = "Requires explicit authorization and credentials in process environment"]
async fn authorized_live_provider_uses_actual_http_without_exposing_credentials() {
    let endpoint = std::env::var("KIYORI_LIVE_ENDPOINT").unwrap();
    let model = std::env::var("KIYORI_LIVE_MODEL").unwrap();
    let key = std::env::var("KIYORI_LIVE_KEY").unwrap();
    // 移除合成服务用量；真实响应只投影实际prompt/completion报告。
    let fixture = Fixture::new(&SOURCE.replace(",cachedInput:1", "")).await;
    let mut draft = fixture
        .runtime
        .model_catalog()
        .unwrap()
        .configs
        .remove(0)
        .draft;
    draft.provider = "TOOLPKG:fixture:fixture".into();
    draft.protocol = "native".into();
    draft.endpoint = endpoint;
    draft.models = vec![model.clone()];
    let mut records = vec![];
    for streaming in [true, false] {
        let mut input = chat::probe::prepare(draft.clone(), key.clone(), vec![], "chat").unwrap();
        input.messages = vec![chat::ChatMessage {
            role: "user".into(),
            content: "What is 2+3? Reply with exactly the digit 5 and nothing else.".into(),
        }];
        input.timeout_ms = 90_000;
        input.stream = streaming;
        let run = fixture.runtime.start_chat(input).unwrap();
        let outcome = tokio::time::timeout(Duration::from_secs(100), async {
            let mut result = vec![];
            while let Some(e) = run.next_event().await.unwrap() {
                result.push(e);
            }
            result
        })
        .await
        .unwrap();
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
        let passed = text.trim() == "5"
            && outcome
                .iter()
                .any(|e| matches!(e,ChatEvent::Completed{reason,..} if reason=="stop"))
            && !outcome.iter().any(|e| matches!(e, ChatEvent::Failed(_)));
        let failure = outcome.iter().find_map(|e| {
            if let ChatEvent::Failed(f) = e {
                Some(format!("{:?}", f.kind))
            } else {
                None
            }
        });
        records.push(json!({"stream":streaming,"passed":passed,"answerVerified":text.trim()=="5","failure":failure,
            "usageReported":outcome.iter().any(|e|matches!(e,ChatEvent::Usage{..}))}));
        run.cancel_and_wait().await;
    }
    let report = json!({"scope":"Actual extension provider HTTP, synthetic input, no device acceptance","model":model,"records":records});
    if let Ok(path) = std::env::var("KIYORI_LIVE_REPORT") {
        std::fs::write(path, serde_json::to_vec_pretty(&report).unwrap()).unwrap();
    }
    assert!(records.iter().all(|v| v["passed"] == true), "{report}");
}
