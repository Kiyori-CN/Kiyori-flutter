use super::*;
use crate::runtime::Runtime;
use std::io::{Read, Write};
use std::net::TcpListener;

fn draft(endpoint: String, protocol: &str) -> ModelConfigDraft {
    ModelConfigDraft {
        name: "fixture".into(),
        provider: if protocol == "native" {
            "GOOGLE"
        } else {
            "OPENAI_GENERIC"
        }
        .into(),
        protocol: protocol.into(),
        endpoint,
        models: vec![],
        options: Default::default(),
    }
}
fn serve(pages: Vec<(&'static str, String)>) -> (String, std::thread::JoinHandle<Vec<String>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!(
        "http://{}/proxy/v1/chat/completions#",
        listener.local_addr().unwrap()
    );
    let worker = std::thread::spawn(move || {
        let mut requests = Vec::new();
        for (status, body) in pages {
            let (mut socket, _) = listener.accept().unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut request = Vec::new();
            let mut byte = [0; 1];
            while !request.ends_with(b"\r\n\r\n") {
                socket.read_exact(&mut byte).unwrap();
                request.push(byte[0]);
            }
            requests.push(String::from_utf8(request).unwrap());
            let response = format!(
                "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            socket.write_all(response.as_bytes()).unwrap();
        }
        requests
    });
    (endpoint, worker)
}
async fn events(runtime: &Runtime, input: ModelConfigDraft) -> Vec<ChatEvent> {
    let run = runtime
        .start_model_directory(
            input,
            "synthetic-key".into(),
            vec![("X-Fixture".into(), "yes".into())],
        )
        .unwrap();
    let mut events = Vec::new();
    while let Some(event) = run.next_event().await.unwrap() {
        events.push(event);
    }
    events
}

#[tokio::test]
async fn directory_paginates_and_deduplicates_without_losing_proxy_or_auth() {
    for protocol in ["chat", "responses", "messages", "native"] {
        let google = protocol == "native";
        let first = if google {
            json!({"models":[{"name":"models/a","displayName":"甲"}],"nextPageToken":"page + /"})
        } else {
            json!({"data":[{"id":"a","display_name":"甲"}],"has_more":true,"last_id":"a + /"})
        };
        let last = if google {
            json!({"models":[{"name":"models/a"},{"name":"models/b"}]})
        } else {
            json!({"data":[{"id":"a"},{"id":"b"}]})
        };
        let (endpoint, worker) = serve(vec![
            ("200 OK", first.to_string()),
            ("200 OK", last.to_string()),
        ]);
        let output = events(&Runtime::new(), draft(endpoint, protocol)).await;
        assert_eq!(output.len(), 3);
        assert_eq!(
            output[1],
            ChatEvent::Models(vec![
                ModelEntry {
                    id: "a".into(),
                    name: "甲".into()
                },
                ModelEntry {
                    id: "b".into(),
                    name: "b".into()
                }
            ])
        );
        assert!(matches!(&output[2],ChatEvent::Completed{reason,..} if reason == "models"));
        let requests = worker.join().unwrap();
        assert!(requests[0].starts_with("GET /proxy/v1/models HTTP/1.1"));
        let request = requests[0].to_lowercase();
        assert!(request.contains("x-fixture: yes"));
        assert!(request.contains(if google {
            "x-goog-api-key: synthetic-key"
        } else if protocol == "messages" {
            "x-api-key: synthetic-key"
        } else {
            "authorization: bearer synthetic-key"
        }));
        if protocol == "messages" {
            assert!(request.contains("anthropic-version: 2023-06-01"));
        }
        assert!(requests[1].contains(if google {
            "pageToken=page+%2B+%2F"
        } else {
            "after_id=a+%2B+%2F"
        }));
    }
}

#[tokio::test]
async fn directory_rejects_partial_invalid_and_repeating_pages_without_publishing_entries() {
    for document in [
        json!({"data":[{"id":"good"},{"id":1}]}),
        json!({"data":[{"id":"bad\nname"}]}),
        json!({"data":[] ,"has_more":true}),
        json!({"models":[]}),
    ] {
        let (endpoint, worker) = serve(vec![("200 OK", document.to_string())]);
        let output = events(&Runtime::new(), draft(endpoint, "chat")).await;
        assert!(!output.iter().any(|e| matches!(e, ChatEvent::Models(_))));
        assert!(matches!(output.last(), Some(ChatEvent::Failed(_))));
        worker.join().unwrap();
    }
    let document = json!({"data":[{"id":"a"}],"has_more":true,"last_id":"same"}).to_string();
    let (endpoint, worker) = serve(vec![("200 OK", document.clone()), ("200 OK", document)]);
    assert!(matches!(
        events(&Runtime::new(), draft(endpoint, "chat"))
            .await
            .last(),
        Some(ChatEvent::Failed(_))
    ));
    worker.join().unwrap();
}

#[tokio::test]
async fn directory_does_not_echo_server_errors_or_follow_redirects() {
    for status in ["401 Unauthorized", "302 Found", "500 Internal Server Error"] {
        let (endpoint, worker) = serve(vec![(
            status,
            "private provider response and synthetic-key".into(),
        )]);
        let output = events(&Runtime::new(), draft(endpoint, "chat")).await;
        let Some(ChatEvent::Failed(error)) = output.last() else {
            panic!("missing terminal failure")
        };
        assert_eq!(error.kind, ChatFailureKind::Http);
        assert!(!error.message.contains("private"));
        assert!(!error.message.contains("synthetic-key"));
        worker.join().unwrap();
    }
}

#[tokio::test]
async fn runtime_close_cancels_directory_and_rejects_new_requests() {
    let runtime = Runtime::new();
    let run = runtime
        .start_model_directory(
            draft("http://127.0.0.1:1".into(), "chat"),
            String::new(),
            vec![],
        )
        .unwrap();
    runtime.close();
    assert_eq!(run.next_event().await.unwrap(), Some(ChatEvent::Cancelled));
    assert_eq!(run.next_event().await.unwrap(), None);
    assert!(
        runtime
            .start_model_directory(
                draft("https://example.com".into(), "chat"),
                String::new(),
                vec![]
            )
            .is_err()
    );
}

#[test]
fn directory_routes_versions_exact_marker_and_local_errors() {
    for (endpoint, expected) in [
        (
            "https://example.com/api/paas/v4/chat/completions#",
            "/api/paas/v4/models",
        ),
        (
            "https://example.com/proxy/v1beta/models/model:generateContent",
            "/proxy/v1beta/models",
        ),
        (
            "https://example.com/proxy/chat/completions",
            "/proxy/v1/models",
        ),
    ] {
        assert_eq!(
            url(&draft(endpoint.into(), "chat")).unwrap().path(),
            expected
        );
    }
    for endpoint in [
        "http://example.com",
        "https://user:password@example.com",
        "https://example.com?key=secret",
    ] {
        assert!(url(&draft(endpoint.into(), "chat")).is_err());
    }
    let mut local = draft(String::new(), "native");
    local.provider = "LLAMA_CPP".into();
    assert_eq!(url(&local).unwrap_err().kind, ChatFailureKind::Unsupported);
}

#[test]
fn directory_preserves_protocol_and_official_provider_routes_without_cross_host_fallback() {
    for (provider, protocol, endpoint, expected) in [
        (
            "GOOGLE",
            "chat",
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            "/v1beta/openai/models",
        ),
        (
            "DEEPSEEK",
            "messages",
            "https://api.deepseek.com/anthropic/v1/messages",
            "/v1/models",
        ),
        (
            "ZHIPU",
            "messages",
            "https://open.bigmodel.cn/api/anthropic/v1/messages",
            "/api/paas/v4/models",
        ),
        (
            "MIMO",
            "messages",
            "https://api.xiaomimimo.com/anthropic/v1/messages",
            "/v1/models",
        ),
        (
            "NOVITA",
            "messages",
            "https://api.novita.ai/anthropic/v1/messages",
            "/openai/v1/models",
        ),
        (
            "DEEPSEEK",
            "messages",
            "https://example.com/proxy/anthropic/v1/messages#",
            "/proxy/anthropic/v1/models",
        ),
        (
            "NOVITA",
            "messages",
            "https://api.novita.ai:8443/anthropic/v1/messages",
            "/anthropic/v1/models",
        ),
    ] {
        let mut input = draft(endpoint.into(), protocol);
        input.provider = provider.into();
        let source = Url::parse(endpoint.trim_end_matches('#')).unwrap();
        let target = url(&input).unwrap();
        assert_eq!(target.path(), expected);
        assert_eq!(target.host_str(), source.host_str());
        assert_eq!(target.port(), source.port());
    }
}

#[tokio::test]
async fn directory_uses_vendor_auth_with_selected_messages_protocol() {
    for provider in ["DEEPSEEK", "ZHIPU", "MIMO", "NOVITA", "ANTHROPIC_GENERIC"] {
        let (endpoint, worker) = serve(vec![("200 OK", json!({"data":[]}).to_string())]);
        let mut input = draft(endpoint, "messages");
        input.provider = provider.into();
        assert!(matches!(
            events(&Runtime::new(), input).await.last(),
            Some(ChatEvent::Completed { .. })
        ));
        let request = worker.join().unwrap().remove(0).to_lowercase();
        assert!(request.contains(if provider == "ANTHROPIC_GENERIC" {
            "x-api-key: synthetic-key"
        } else {
            "authorization: bearer synthetic-key"
        }));
        if provider == "MIMO" {
            assert!(request.contains("api-key: synthetic-key"));
        }
    }
}
