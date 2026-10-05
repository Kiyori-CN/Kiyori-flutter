#![cfg(any(target_os = "windows", target_os = "android"))]
use kiyori_core::{runtime::Runtime, scripts::*};
use kiyori_scripts::NativeScripts;
use serde_json::{Value, json};
use std::{sync::Arc, time::Duration};

fn source(body: &str) -> String {
    format!(
        r#"exports.registerToolPkg=()=>{{
      const handler=async event=>{{ {body} }};
      ToolPkg.registerAiProvider({{id:'fixture',displayName:'示例',description:'正式执行夹具',
        listModels:{{function:handler}},sendMessage:{{function:handler}},
        testConnection:{{function:handler}},calculateInputTokens:{{function:handler}}}});
    }};"#
    )
}
fn request(body: &str) -> ScriptRequest {
    ScriptRequest {
        source: source(body),
        operation: ScriptOperation::Invoke {
            provider_id: "fixture".into(),
            handler: ProviderHandler::SendMessage,
            payload: json!({"value":5}),
        },
        limits: ScriptLimits {
            timeout_ms: 250,
            ..Default::default()
        },
    }
}
async fn collect(
    runtime: &Runtime,
    request: ScriptRequest,
) -> (Vec<Value>, Result<Value, ScriptFailure>) {
    let run = runtime.start_script(request).await.unwrap();
    let mut events = Vec::new();
    loop {
        match run.next_event().await.unwrap().unwrap() {
            ScriptEvent::Intermediate(value) => events.push(value),
            ScriptEvent::Completed(value) => {
                assert!(run.next_event().await.unwrap().is_none());
                return (events, Ok(value));
            }
            ScriptEvent::Failed(error) => {
                assert!(run.next_event().await.unwrap().is_none());
                return (events, Err(error));
            }
        }
    }
}
fn runtime() -> Runtime {
    let runtime = Runtime::new();
    runtime.set_script_adapter(Arc::new(NativeScripts)).unwrap();
    runtime
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn real_commonjs_registration_four_handlers_promises_and_unicode() {
    let runtime = runtime();
    let body = "sendIntermediateResult({chunk:'中文'}); return Promise.resolve({value:event.eventPayload.value});";
    let mut registration = request(body);
    registration.operation = ScriptOperation::Register;
    let (_, registered) = collect(&runtime, registration).await;
    assert_eq!(
        registrations(registered.unwrap()).unwrap()[0].display_name,
        "示例"
    );
    for handler in [
        ProviderHandler::ListModels,
        ProviderHandler::SendMessage,
        ProviderHandler::TestConnection,
        ProviderHandler::CalculateInputTokens,
    ] {
        let mut input = request(body);
        if let ScriptOperation::Invoke {
            handler: operation, ..
        } = &mut input.operation
        {
            *operation = handler;
        }
        let (events, result) = collect(&runtime, input).await;
        assert_eq!(events, vec![json!({"chunk":"中文"})]);
        assert_eq!(result.unwrap(), json!({"value":5}));
    }
    runtime.close();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn real_runtime_rejects_host_access_rejections_and_unresolved_promises() {
    let runtime = runtime();
    let (_, globals) = collect(&runtime, request("return [typeof process,typeof require,typeof fetch,typeof std,typeof os,typeof OkHttp];")).await;
    assert_eq!(
        globals.unwrap(),
        json!([
            "undefined",
            "undefined",
            "undefined",
            "undefined",
            "undefined",
            "undefined"
        ])
    );
    for (body, expected) in [
        ("return import('os');", ScriptFailureKind::Execution),
        (
            "return Promise.reject('private credential fixture');",
            ScriptFailureKind::Execution,
        ),
        (
            "return new Promise(()=>{});",
            ScriptFailureKind::UnresolvedPromise,
        ),
        ("return undefined;", ScriptFailureKind::Protocol),
        ("return 5n;", ScriptFailureKind::Execution),
        ("const a={};a.a=a;return a;", ScriptFailureKind::Execution),
        (
            "let a=0;for(let i=0;i<200;i++)a=[a];return a;",
            ScriptFailureKind::Protocol,
        ),
    ] {
        let (_, result) = collect(&runtime, request(body)).await;
        let failure = result.unwrap_err();
        assert_eq!(failure.kind, expected, "{body}");
        assert!(!failure.to_string().contains("private"));
    }
    runtime.close();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
#[ignore = "Requires explicit path to the read-only legacy provider source"]
async fn original_legacy_provider_runs_on_the_formal_port() {
    let source =
        std::fs::read_to_string(std::env::var("KIYORI_LEGACY_PROVIDER_SOURCE").unwrap()).unwrap();
    let runtime = runtime();
    let (_, registered) = collect(
        &runtime,
        ScriptRequest {
            source: source.clone(),
            operation: ScriptOperation::Register,
            limits: Default::default(),
        },
    )
    .await;
    let providers = registrations(registered.unwrap()).unwrap();
    assert_eq!(providers[0].id, "example_openai_compatible_provider");
    for handler in [
        ProviderHandler::CalculateInputTokens,
        ProviderHandler::ListModels,
        ProviderHandler::SendMessage,
        ProviderHandler::TestConnection,
    ] {
        let (_, result) = collect(&runtime, ScriptRequest {
            source: source.clone(), operation: ScriptOperation::Invoke {
                provider_id: providers[0].id.clone(),handler,
                payload: json!({"chatHistory":[{"content":"abcdefgh"}],"config":{"apiEndpoint":"https://example.invalid/v1/chat/completions","modelName":"fixture","apiKey":""}}),
            }, limits: Default::default(),
        }).await;
        if handler == ProviderHandler::CalculateInputTokens {
            assert_eq!(result.unwrap(), json!({"tokens":2}));
        } else {
            assert_eq!(result.unwrap_err().kind, ScriptFailureKind::Execution);
        }
    }
    runtime.close();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn real_runtime_limits_caught_interrupt_memory_stack_jobs_and_output() {
    let runtime = runtime();
    for (body, expected) in [
        ("while(true){}", ScriptFailureKind::Timeout),
        (
            "while(true){try{while(true){}}catch(e){}}",
            ScriptFailureKind::Timeout,
        ),
        (
            "return new ArrayBuffer(256*1024*1024);",
            ScriptFailureKind::Execution,
        ),
        (
            "function recurse(){return recurse()} return recurse();",
            ScriptFailureKind::Execution,
        ),
        (
            "function loop(){return Promise.resolve().then(loop)};return loop();",
            ScriptFailureKind::JobLimit,
        ),
        (
            "sendIntermediateResult({chunk:'x'.repeat(1024*1024+1)});return true;",
            ScriptFailureKind::OutputLimit,
        ),
        (
            "try{sendIntermediateResult({chunk:'x'.repeat(1024*1024+1)});}catch(e){}return true;",
            ScriptFailureKind::OutputLimit,
        ),
        (
            "return 'x'.repeat(9*1024*1024);",
            ScriptFailureKind::OutputLimit,
        ),
    ] {
        let mut input = request(body);
        input.limits.max_jobs = 100;
        input.limits.memory_bytes = 64 * 1024 * 1024;
        let (_, result) = collect(&runtime, input).await;
        assert_eq!(result.unwrap_err().kind, expected, "{body}");
    }
    let (_, after) = collect(&runtime, request("return 5;")).await;
    assert_eq!(after.unwrap(), json!(5));
    runtime.close();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn real_runtime_cancel_backpressure_drop_and_close_release_instances() {
    let runtime = Arc::new(runtime());
    let mut input = request("while(true){}");
    input.limits.timeout_ms = 5000;
    let run = runtime.start_script(input).await.unwrap();
    tokio::time::sleep(Duration::from_millis(30)).await;
    run.cancel();
    assert!(matches!(
        run.next_event().await.unwrap(),
        Some(ScriptEvent::Failed(ScriptFailure {
            kind: ScriptFailureKind::Cancelled
        }))
    ));
    let mut stream =
        request("for(let i=0;i<10000;i++)sendIntermediateResult({chunk:'x'});return 5;");
    stream.limits.timeout_ms = 5000;
    let blocked = runtime.start_script(stream).await.unwrap();
    tokio::time::sleep(Duration::from_millis(30)).await;
    let closing = runtime.clone();
    tokio::time::timeout(
        Duration::from_secs(2),
        tokio::task::spawn_blocking(move || closing.close()),
    )
    .await
    .unwrap()
    .unwrap();
    assert!(matches!(
        blocked.next_event().await.unwrap(),
        Some(ScriptEvent::Failed(ScriptFailure {
            kind: ScriptFailureKind::Cancelled
        }))
    ));
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn malformed_registration_does_not_leave_stale_provider_or_vm_state() {
    let runtime = runtime();
    for source in [
        "exports.registerToolPkg=()=>ToolPkg.registerAiProvider({id:'x',displayName:'x'});",
        "exports.registerToolPkg=()=>{throw Error('private fixture')};",
        "exports.registerToolPkg=()=>new Promise(()=>{});",
    ] {
        let mut input = request("return 5;");
        input.source = source.into();
        input.operation = ScriptOperation::Register;
        assert!(collect(&runtime, input).await.1.is_err());
    }
    let (_, result) = collect(&runtime, request("return 5;")).await;
    assert_eq!(result.unwrap(), json!(5));
    runtime.close();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn registration_snapshot_ignores_prototype_forgery_and_rejects_late_registration() {
    let runtime = runtime();
    let mut input = request("return 5;");
    input.operation = ScriptOperation::Register;
    input.source.push_str("Object.prototype.toJSON=()=>({id:'forged'}); Array.prototype.map=()=>[];Array.prototype.find=()=>null;RegExp.prototype.test=()=>false;");
    let (_, result) = collect(&runtime, input).await;
    assert_eq!(registrations(result.unwrap()).unwrap()[0].id, "fixture");
    let (_, late) = collect(
        &runtime,
        request("ToolPkg.registerAiProvider({});return 5;"),
    )
    .await;
    assert_eq!(late.unwrap_err().kind, ScriptFailureKind::Execution);
    runtime.close();
}
