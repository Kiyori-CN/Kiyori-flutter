#![cfg(any(target_os = "windows", target_os = "android"))]
use kiyori_core::{
    extensions::http::ModelHttpHost, models::ModelConfigDraft, runtime::Runtime, scripts::*,
};
use kiyori_scripts::NativeScripts;
use serde_json::json;
use std::{
    io::{Cursor, Read, Write},
    net::TcpListener,
    sync::Arc,
    time::{Duration, Instant},
};
use zip::{ZipWriter, write::SimpleFileOptions};
const SOURCE: &str = r#"
exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'fixture',displayName:'真实网络夹具',description:'',
listModels:{function:async event=>{const c=event.eventPayload.config;
 const response=await OkHttp.newBuilder().readTimeout(5000).build().newRequest()
 .url(c.apiEndpoint.replace('/chat/completions','/models')).method('GET')
 .headers({Authorization:'Bearer '+c.apiKey}).build().execute({});
 return {models:response.json().data};}},
testConnection:{function:async event=>{const c=event.eventPayload.config;
 const response=await OkHttp.newBuilder().readTimeout(5000).build().newRequest()
 .url(c.apiEndpoint.replace('/chat/completions','/models')).method('GET')
 .headers({Authorization:'Bearer '+c.apiKey}).build().execute({});return {success:response.isSuccessful()};}},
sendMessage:{function:async event=>{const c=event.eventPayload.config;let buffer='',text='';
 await OkHttp.newBuilder().readTimeout(5000).build().newRequest().url(c.apiEndpoint).method('POST')
 .headers({Authorization:'Bearer '+c.apiKey,'Content-Type':'application/json'})
 .body({model:c.modelName,messages:[],stream:true},'json').build().execute({onIntermediateResult:event=>{
   buffer+=event.chunk;let end;while((end=buffer.indexOf('\n\n'))>=0){const part=buffer.slice(0,end).slice(5).trim();buffer=buffer.slice(end+2);
   if(part==='[DONE]')continue;const value=JSON.parse(part);const content=value.choices?.[0]?.delta?.content;if(content){text+=content;sendIntermediateResult({chunk:content});}}
 }});return {text};}},calculateInputTokens:{function:()=>({tokens:7})}});
"#;
struct ObservedHost {
    inner: ModelHttpHost,
    outcomes: std::sync::Mutex<Vec<Result<(), ScriptFailureKind>>>,
}
impl ScriptHttpHost for ObservedHost {
    fn request(
        &self,
        input: serde_json::Value,
        stopped: &dyn Fn() -> bool,
        chunk: &mut dyn FnMut(&str) -> bool,
    ) -> Result<serde_json::Value, ScriptFailure> {
        let result = self.inner.request(input, stopped, chunk);
        self.outcomes
            .lock()
            .unwrap()
            .push(result.as_ref().map(|_| ()).map_err(|e| e.kind));
        result
    }
}
fn zip_source(source: &str) -> Vec<u8> {
    let mut writer = ZipWriter::new(Cursor::new(vec![]));
    writer
        .start_file("manifest.json", SimpleFileOptions::default())
        .unwrap();
    writer.write_all(br#"{"schema_version":1,"toolpkg_id":"fixture","version":"1.0.0","main":"main.js","enabled_by_default":true}"#).unwrap();
    writer
        .start_file("main.js", SimpleFileOptions::default())
        .unwrap();
    writer.write_all(source.as_bytes()).unwrap();
    writer.finish().unwrap().into_inner()
}
async fn scenario(source: String, provider: &str) {
    let root = std::env::temp_dir().join(format!(
        "kiyori-http-js-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let runtime = Arc::new(Runtime::with_data_dir(&root).unwrap());
    runtime.set_script_adapter(Arc::new(NativeScripts)).unwrap();
    let importer = runtime.begin_extension_import().unwrap();
    importer.append(zip_source(&source)).unwrap();
    let package = importer.finish().await.unwrap();
    drop(importer);
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    let server = std::thread::spawn(move || {
        for index in 0..3 {
            let start = Instant::now();
            let mut socket = loop {
                match listener.accept() {
                    Ok((socket, _)) => break socket,
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
            let mut bytes = Vec::new();
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
                    .contains("authorization: bearer synthetic-fixture-key")
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
            if index < 2 {
                assert!(headers.starts_with("GET /v1/models "));
                let body = br#"{"data":[{"id":"fixture","name":"fixture-model"}]}"#;
                socket
                    .write_all(
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            body.len()
                        )
                        .as_bytes(),
                    )
                    .unwrap();
                socket.write_all(body).unwrap();
            } else {
                assert!(headers.starts_with("POST /v1/chat/completions "));
                let body = std::str::from_utf8(&bytes[end..]).unwrap();
                assert!(!body.contains("__kiyori_") && !body.contains("synthetic-fixture-key"));
                let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}\n\ndata: {\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":2},\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n";
                socket
                    .write_all(
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            sse.len()
                        )
                        .as_bytes(),
                    )
                    .unwrap();
                for part in sse.as_bytes().chunks(7) {
                    socket.write_all(part).unwrap();
                    socket.flush().unwrap();
                    std::thread::sleep(Duration::from_millis(1));
                }
            }
        }
    });
    let draft = ModelConfigDraft {
        name: "fixture".into(),
        provider: format!("TOOLPKG:fixture:{provider}"),
        protocol: "chat".into(),
        endpoint,
        models: vec!["fixture".into()],
        options: Default::default(),
    };
    let host = Arc::new(ObservedHost {
        inner: ModelHttpHost::new(&runtime, &draft, "synthetic-fixture-key".into(), vec![])
            .unwrap(),
        outcomes: Default::default(),
    });
    let payload = json!({"config":host.inner.config(&draft,"fixture"),"chatHistory":[{"kind":"USER","content":"你好"}]});
    for handler in [
        ProviderHandler::ListModels,
        ProviderHandler::TestConnection,
        ProviderHandler::SendMessage,
        ProviderHandler::CalculateInputTokens,
    ] {
        let run = runtime
            .start_extension_with_http(
                draft.provider.clone(),
                package.revision,
                handler,
                payload.clone(),
                ScriptLimits {
                    timeout_ms: 10_000,
                    ..Default::default()
                },
                Some(host.clone()),
            )
            .await
            .unwrap();
        let mut chunks = String::new();
        let final_value = loop {
            match run.next_event().await.unwrap().unwrap() {
                ScriptEvent::Intermediate(v) => {
                    if let Some(text) = v["chunk"].as_str() {
                        chunks.push_str(text);
                    }
                }
                ScriptEvent::Completed(v) => break v,
                ScriptEvent::Failed(e) => panic!(
                    "{handler:?} {e}; host outcomes {:?}",
                    host.outcomes.lock().unwrap()
                ),
            }
        };
        match handler {
            ProviderHandler::ListModels => assert_eq!(final_value["models"][0]["id"], "fixture"),
            ProviderHandler::TestConnection => assert_eq!(final_value["success"], true),
            ProviderHandler::SendMessage => {
                assert_eq!(final_value["text"], "你好");
                assert_eq!(chunks, "你好");
            }
            ProviderHandler::CalculateInputTokens => {
                assert!(final_value["tokens"].as_u64().unwrap() > 0)
            }
        }
        assert!(run.next_event().await.unwrap().is_none());
    }
    server.join().unwrap();
    runtime.close();
    drop(runtime);
    std::fs::remove_dir_all(root).unwrap();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn installed_provider_uses_real_shared_http_and_stream_callbacks() {
    scenario(SOURCE.into(), "fixture").await;
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
#[ignore = "Requires explicit path to the read-only original provider"]
async fn original_provider_runs_four_handlers_with_controlled_http() {
    let source =
        std::fs::read_to_string(std::env::var("KIYORI_LEGACY_PROVIDER_SOURCE").unwrap()).unwrap();
    scenario(source, "example_openai_compatible_provider").await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn streamed_nested_hjson_provider_executes_real_vm_and_reopens() {
    let root = std::env::temp_dir().join(format!(
        "kiyori-hjson-vm-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let runtime = Arc::new(Runtime::with_data_dir(&root).unwrap());
    runtime.set_script_adapter(Arc::new(NativeScripts)).unwrap();
    let mut writer = ZipWriter::new_stream(Vec::new());
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    writer
        .start_file("package/manifest.hjson", options)
        .unwrap();
    writer.write_all("toolpkg_id: fixture\nmain: dist/main.js\ndisplay_name: 测试供应商😀\napi_version: 1.0.1\n".as_bytes()).unwrap();
    writer.start_file("package/dist/main.js", options).unwrap();
    writer.write_all(SOURCE.as_bytes()).unwrap();
    let importer = runtime.begin_extension_import().unwrap();
    importer
        .append(writer.finish().unwrap().into_inner())
        .unwrap();
    let package = importer.finish().await.unwrap();
    assert_eq!(package.name, "测试供应商😀");
    let provider = runtime.extension_providers().unwrap().remove(0);
    let run = runtime
        .start_extension(
            provider.id,
            provider.revision,
            ProviderHandler::CalculateInputTokens,
            json!({"chatHistory":[{"content":"你好😀"}]}),
            Default::default(),
        )
        .await
        .unwrap();
    assert!(
        matches!(run.next_event().await.unwrap(),Some(ScriptEvent::Completed(value)) if value==json!({"tokens":7}))
    );
    run.cancel_and_wait().await.unwrap();
    drop(importer);
    runtime.close();
    let reopened = Runtime::with_data_dir(&root).unwrap();
    assert_eq!(
        reopened
            .extension_details(package.id, package.revision)
            .await
            .unwrap()
            .api_version,
        "1.0.1"
    );
    reopened.close();
    std::fs::remove_dir_all(root).unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn package_revocation_stops_http_and_releases_vm_before_returning() {
    let root = std::env::temp_dir().join(format!(
        "kiyori-http-revoke-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let runtime = Arc::new(Runtime::with_data_dir(&root).unwrap());
    runtime.set_script_adapter(Arc::new(NativeScripts)).unwrap();
    let importer = runtime.begin_extension_import().unwrap();
    importer.append(zip_source(SOURCE)).unwrap();
    let package = importer.finish().await.unwrap();
    drop(importer);
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    let connected = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let signalled = connected.clone();
    let server = std::thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
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
        signalled.store(true, std::sync::atomic::Ordering::Release);
        socket
            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\n")
            .unwrap();
        // 在途POST正文可能还没读完；最终EOF才证明客户端已停止。
        while socket.read(&mut part).unwrap() != 0 {}
    });
    let draft = ModelConfigDraft {
        name: "fixture".into(),
        provider: "TOOLPKG:fixture:fixture".into(),
        protocol: "chat".into(),
        endpoint,
        models: vec!["fixture".into()],
        options: Default::default(),
    };
    let host = Arc::new(ModelHttpHost::new(&runtime, &draft, String::new(), vec![]).unwrap());
    let payload = json!({"config":host.config(&draft,"fixture")});
    let run = runtime
        .start_extension_with_http(
            draft.provider.clone(),
            1,
            ProviderHandler::SendMessage,
            payload,
            ScriptLimits {
                timeout_ms: 10_000,
                ..Default::default()
            },
            Some(host),
        )
        .await
        .unwrap();
    tokio::time::timeout(Duration::from_secs(5), async {
        while !connected.load(std::sync::atomic::Ordering::Acquire) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    tokio::time::timeout(
        Duration::from_secs(5),
        runtime.change_extension(package.id, 1, Some(false)),
    )
    .await
    .unwrap()
    .unwrap();
    assert!(matches!(
        run.next_event().await.unwrap(),
        Some(ScriptEvent::Failed(ScriptFailure {
            kind: ScriptFailureKind::Cancelled
        }))
    ));
    assert!(runtime.extension_providers().unwrap().is_empty());
    server.join().unwrap();
    runtime.close();
    drop(runtime);
    std::fs::remove_dir_all(root).unwrap();
}
