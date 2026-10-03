use super::*;
use crate::runtime::Runtime;
use std::io::{Read, Write};
use std::net::TcpListener;

fn request(endpoint: String) -> ChatRequest {
    ChatRequest {
        probe: None,
        protocol: "chat".into(),
        endpoint,
        model: "local-model".into(),
        api_key: "loopback-fixture".into(),
        headers: vec![("X-Test".into(), "fixture".into())],
        messages: vec![ChatMessage {
            role: "user".into(),
            content: "Hi".into(),
        }],
        parameters: "{\"temperature\":0}".into(),
        timeout_ms: 3000,
    }
}

fn serve(
    status: &str,
    body: String,
    content_type: &str,
) -> (String, std::thread::JoinHandle<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!("http://{}", listener.local_addr().unwrap());
    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\nLocation: {endpoint}/redirect\r\n\r\n{body}",
        body.len()
    );
    let worker = std::thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        socket
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        let mut bytes = vec![];
        let mut buffer = [0; 1024];
        loop {
            let n = socket.read(&mut buffer).unwrap();
            assert!(n > 0);
            bytes.extend_from_slice(&buffer[..n]);
            if let Some(end) = bytes.windows(4).position(|w| w == b"\r\n\r\n") {
                let header = String::from_utf8_lossy(&bytes[..end]);
                let length: usize = header
                    .lines()
                    .find_map(|line| {
                        line.to_ascii_lowercase()
                            .strip_prefix("content-length: ")
                            .map(|s| s.parse().unwrap())
                    })
                    .unwrap();
                if bytes.len() >= end + 4 + length {
                    break;
                }
            }
        }
        // 包含中文的响应故意按单字节写，不能假定一次read就是一个事件或UTF-8字符。
        for byte in response.as_bytes() {
            if socket.write_all(&[*byte]).is_err() {
                break;
            }
        }
        String::from_utf8(bytes).unwrap()
    });
    (endpoint, worker)
}
fn body() -> String {
    concat!("data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"你好\"},\"finish_reason\":null}]}\r\n\r\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n",
        "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":1,\"total_tokens\":3}}\n\n",
        "data: [DONE]\n\n").into()
}
async fn collect(run: &ChatRun) -> Vec<ChatEvent> {
    let mut events = vec![];
    while let Some(event) = tokio::time::timeout(Duration::from_secs(5), run.next_event())
        .await
        .unwrap()
        .unwrap()
    {
        events.push(event);
    }
    events
}

#[tokio::test]
async fn real_post_stream_usage_and_terminal_once() {
    let (endpoint, worker) = serve("200 OK", body(), "text/event-stream; charset=utf-8");
    let runtime = Runtime::new();
    let run = runtime.start_chat(request(endpoint)).unwrap();
    assert_eq!(
        collect(&run).await,
        [
            ChatEvent::Started,
            ChatEvent::Text("你好".into()),
            ChatEvent::Usage {
                input: 2,
                output: 1,
                total: 3
            },
            ChatEvent::Completed {
                reason: "stop".into(),
                verified: None,
            }
        ]
    );
    run.cancel();
    assert_eq!(run.next_event().await.unwrap(), None);
    let received = worker.join().unwrap();
    assert!(received.starts_with("POST /v1/chat/completions HTTP/1.1"));
    assert!(
        received
            .to_lowercase()
            .contains("authorization: bearer loopback-fixture")
    );
    assert!(received.to_lowercase().contains("x-test: fixture"));
    let posted: Value = serde_json::from_str(received.split("\r\n\r\n").nth(1).unwrap()).unwrap();
    assert_eq!(posted["stream"], true);
    assert_eq!(posted["model"], "local-model");
    assert_eq!(posted["messages"][0]["content"], "Hi");
    assert_eq!(posted["temperature"], 0);
}

#[tokio::test]
async fn redirect_and_http_errors_are_not_retried_or_exposed() {
    for status in [
        "307 Temporary Redirect",
        "401 Unauthorized",
        "429 Too Many Requests",
        "503 Unavailable",
    ] {
        let (endpoint, worker) = serve(
            status,
            "private-response-fixture".into(),
            "application/json",
        );
        let runtime = Runtime::new();
        let run = runtime.start_chat(request(endpoint)).unwrap();
        let events = collect(&run).await;
        assert!(
            matches!(events.last(), Some(ChatEvent::Failed(f)) if f.kind == ChatFailureKind::Http && f.http_status == Some(status[..3].parse().unwrap()))
        );
        assert!(!format!("{events:?}").contains("private-response-fixture"));
        worker.join().unwrap();
    }
}

#[test]
fn endpoint_completion_and_credentials_boundaries() {
    assert_eq!(
        endpoint("https://example.test").unwrap().path(),
        "/v1/chat/completions"
    );
    assert_eq!(
        endpoint("https://example.test/v1/").unwrap().path(),
        "/v1/chat/completions"
    );
    assert_eq!(
        endpoint("https://example.test/custom#").unwrap().path(),
        "/custom"
    );
    for raw in [
        "http://example.test",
        "https://u:p@example.test",
        "https://example.test/?key=private",
        "https://example.test/#fragment",
        "file:///tmp/a",
    ] {
        assert!(endpoint(raw).is_err());
    }
    assert!(endpoint("http://[::1]:8080").is_ok());
}

#[tokio::test]
async fn missing_done_and_invalid_stream_fail() {
    for (body, content_type, kind) in [
        (
            body().replace("data: [DONE]\n\n", ""),
            "text/event-stream",
            ChatFailureKind::Interrupted,
        ),
        (
            "data: [DONE]\n\n".into(),
            "text/event-stream",
            ChatFailureKind::Interrupted,
        ),
        (
            "data: invalid\n\n".into(),
            "text/event-stream",
            ChatFailureKind::Protocol,
        ),
        (body(), "application/json", ChatFailureKind::Protocol),
        (
            "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[]}}]}\n\n".into(),
            "text/event-stream",
            ChatFailureKind::Unsupported,
        ),
    ] {
        let (endpoint, worker) = serve("200 OK", body, content_type);
        let runtime = Runtime::new();
        let run = runtime.start_chat(request(endpoint)).unwrap();
        let events = collect(&run).await;
        assert!(matches!(events.last(), Some(ChatEvent::Failed(f)) if f.kind == kind));
        worker.join().unwrap();
    }
}

#[tokio::test]
async fn runtime_close_and_drop_cancel_unconsumed_requests() {
    let runtime = Runtime::new();
    let run = runtime
        .start_chat(request("http://127.0.0.1:1".into()))
        .unwrap();
    runtime.close();
    assert_eq!(collect(&run).await, [ChatEvent::Cancelled]);
    assert!(
        runtime
            .start_chat(request("http://127.0.0.1:1".into()))
            .is_err()
    );
}
