use super::*;

#[tokio::test]
async fn media_probes_send_original_asset_not_the_expected_answer_and_validate_response() {
    use base64::{Engine, engine::general_purpose::STANDARD};
    for (protocol, kind, code, asset) in [
        (
            "chat",
            "image",
            "7K2Q",
            include_bytes!("../../assets/model-probe/image.jpg").as_slice(),
        ),
        (
            "responses",
            "image",
            "7K2Q",
            include_bytes!("../../assets/model-probe/image.jpg").as_slice(),
        ),
        (
            "messages",
            "image",
            "7K2Q",
            include_bytes!("../../assets/model-probe/image.jpg").as_slice(),
        ),
        (
            "native",
            "image",
            "7K2Q",
            include_bytes!("../../assets/model-probe/image.jpg").as_slice(),
        ),
        (
            "chat",
            "audio",
            "three seven five",
            include_bytes!("../../assets/model-probe/audio.mp3").as_slice(),
        ),
        (
            "responses",
            "audio",
            "375",
            include_bytes!("../../assets/model-probe/audio.mp3").as_slice(),
        ),
        (
            "native",
            "audio",
            "375",
            include_bytes!("../../assets/model-probe/audio.mp3").as_slice(),
        ),
        (
            "chat",
            "video",
            "M4XP",
            include_bytes!("../../assets/model-probe/video.mp4").as_slice(),
        ),
        (
            "native",
            "video",
            "M4XP",
            include_bytes!("../../assets/model-probe/video.mp4").as_slice(),
        ),
    ] {
        let output = match protocol {
            "chat" => {
                json!({"choices":[{"index":0,"message":{"content":code},"finish_reason":"stop"}]})
            }
            "responses" => {
                json!({"status":"completed","output":[{"type":"message","id":"fixture","role":"assistant","content":[{"type":"output_text","text":code}]}]})
            }
            "messages" => {
                json!({"type":"message","role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":code}]})
            }
            _ => {
                json!({"candidates":[{"content":{"parts":[{"text":code}]},"finishReason":"STOP"}]})
            }
        };
        let (endpoint, worker) = serve("200 OK", output.to_string(), "application/json");
        let draft = crate::models::ModelConfigDraft {
            name: "fixture".into(),
            provider: if protocol == "native" {
                "GOOGLE".into()
            } else {
                "OPENAI_GENERIC".into()
            },
            protocol: protocol.into(),
            endpoint,
            models: vec!["fixture".into()],
            options: crate::models::ModelOptions {
                image: true,
                audio: true,
                video: true,
                ..Default::default()
            },
        };
        let mut input = probe::prepare(draft, String::new(), vec![], kind).unwrap();
        input.stream = false;
        assert!(!input.messages[0].content.contains(code));
        let received = collect(&Runtime::new().start_chat(input).unwrap()).await;
        assert!(
            matches!(
                received.last(),
                Some(ChatEvent::Completed {
                    verified: Some(true),
                    ..
                })
            ),
            "{protocol}/{kind}: {received:?}"
        );
        let captured = worker.join().unwrap();
        let body: Value = serde_json::from_str(captured.split_once("\r\n\r\n").unwrap().1).unwrap();
        let path = match protocol {
            "native" => "/contents/0/parts/0/inlineData/data",
            "messages" => "/messages/0/content/0/source/data",
            "responses" => {
                if kind == "image" {
                    "/input/0/content/0/image_url"
                } else {
                    "/input/0/content/0/input_audio/data"
                }
            }
            _ => match kind {
                "image" => "/messages/0/content/0/image_url/url",
                "audio" => "/messages/0/content/0/input_audio/data",
                _ => "/messages/0/content/0/video_url/url",
            },
        };
        let encoded = body.pointer(path).unwrap().as_str().unwrap();
        let encoded = encoded
            .split_once(";base64,")
            .map(|(_, data)| data)
            .unwrap_or(encoded);
        assert_eq!(STANDARD.decode(encoded).unwrap(), asset);
    }
}

#[test]
fn media_disabled_unsupported_protocol_and_wrong_answers_do_not_pass() {
    let mut draft = crate::models::ModelConfigDraft {
        name: "fixture".into(),
        provider: "OPENAI_GENERIC".into(),
        protocol: "chat".into(),
        endpoint: "https://api.openai.com/v1/chat/completions".into(),
        models: vec!["fixture".into()],
        options: Default::default(),
    };
    assert!(probe::prepare(draft.clone(), String::new(), vec![], "image").is_err());
    draft.options.audio = true;
    draft.options.video = true;
    draft.options.image = true;
    assert!(probe::prepare(draft.clone(), String::new(), vec![], "video").is_err());
    draft.protocol = "responses".into();
    assert!(probe::prepare(draft.clone(), String::new(), vec![], "audio").is_err());
    draft.protocol = "messages".into();
    for kind in ["audio", "video"] {
        assert!(probe::prepare(draft.clone(), String::new(), vec![], kind).is_err());
    }
    let mut input = probe::prepare(draft, String::new(), vec![], "image").unwrap();
    let probe = input.probe.as_mut().unwrap();
    probe.append("The code might be 7K2Q or 1234").unwrap();
    assert!(!probe.verified("stop"));
}

#[test]
fn messages_thinking_compiles_budget_adaptive_sampling_and_deepseek_output_effort() {
    let initial = || {
        serde_json::Map::from_iter([
            ("temperature".into(), json!(0.7)),
            ("top_k".into(), json!(10)),
            ("top_p".into(), json!(0.5)),
        ])
    };
    let mut parameters = initial();
    messages::thinking(&mut parameters, "claude-3.7-sonnet", true, 3, false).unwrap();
    assert_eq!(
        parameters["thinking"],
        json!({"type":"enabled","budget_tokens":4095})
    );
    assert!(!parameters.contains_key("temperature"));
    for name in ["claude-opus-4-6", "claude-4.6-sonnet", "Claude-Sonnet4.6"] {
        let mut parameters = initial();
        messages::thinking(&mut parameters, name, true, 4, false).unwrap();
        assert_eq!(
            parameters["thinking"],
            json!({"type":"adaptive","display":"summarized"})
        );
        assert_eq!(parameters["output_config"]["effort"], "max");
    }
    let mut parameters = initial();
    messages::thinking(&mut parameters, "claude-opus-4.7", true, 4, false).unwrap();
    assert_eq!(parameters["output_config"]["effort"], "xhigh");
    assert!(!parameters.contains_key("top_p"));
    let mut parameters = initial();
    assert!(messages::thinking(&mut parameters, "claude-mythos-preview", false, 3, false).is_err());
    let mut parameters = initial();
    parameters.insert("budget_tokens".into(), json!(4096));
    assert!(messages::thinking(&mut parameters, "claude-3-7-sonnet", true, 3, false).is_err());
    let mut parameters = initial();
    messages::thinking(&mut parameters, "deepseek-chat", true, 3, true).unwrap();
    assert_eq!(parameters["thinking"], json!({"type":"enabled"}));
    assert_eq!(parameters["output_config"]["effort"], "max");
    messages::thinking(&mut parameters, "deepseek-chat", false, 3, true).unwrap();
    assert_eq!(parameters["thinking"], json!({"type":"disabled"}));
    assert!(!parameters.contains_key("output_config"));
}

#[tokio::test]
async fn gemini_stream_document_prefix_search_parameters_and_usage_share_execution() {
    for stream in [true, false] {
        let value = json!({"candidates":[{"index":0,"content":{"role":"model","parts":[{"text":"private thought","thought":true},{"text":"你好"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":10,"cachedContentTokenCount":4,"candidatesTokenCount":2,"thoughtsTokenCount":3}});
        let body = if stream {
            format!("data: {value}\n\n")
        } else {
            value.to_string()
        };
        let (root, worker) = serve(
            "200 OK",
            body,
            if stream {
                "text/event-stream"
            } else {
                "application/json"
            },
        );
        let runtime = Runtime::new();
        let mut input = request(format!(
            "{root}/proxy/v1beta/models/previous:generateContent#"
        ));
        input.protocol = "native".into();
        input.model = "models/gemini-2.5-flash".into();
        input.stream = stream;
        input.google_search = true;
        input.parameters = r#"{"top_p":0.5,"top_k":3,"max_tokens":4096,"temperature":0}"#.into();
        input.messages.insert(
            0,
            ChatMessage {
                role: "system".into(),
                content: "system fixture".into(),
            },
        );
        let received = collect(&runtime.start_chat(input).unwrap()).await;
        assert!(received.contains(&ChatEvent::Text("你好".into())));
        assert!(
            matches!(received.last(), Some(ChatEvent::Completed{reason,..}) if reason == "stop")
        );
        assert!(!format!("{received:?}").contains("private thought"));
        assert!(received.contains(&ChatEvent::Usage {
            input: 10,
            output: 5,
            output_reported: true,
            total: 15,
            cache_read: Some(4),
            cache_write: None,
            reasoning: Some(3)
        }));
        let captured = worker.join().unwrap();
        let (headers, body) = captured.split_once("\r\n\r\n").unwrap();
        assert!(headers.starts_with(&format!(
            "POST /proxy/v1beta/models/gemini-2.5-flash:{}{} HTTP",
            if stream {
                "streamGenerateContent"
            } else {
                "generateContent"
            },
            if stream { "?alt=sse" } else { "" }
        )));
        assert!(
            headers
                .to_ascii_lowercase()
                .contains("x-goog-api-key: loopback-fixture")
        );
        assert!(!headers.to_ascii_lowercase().contains("authorization:"));
        let body: Value = serde_json::from_str(body).unwrap();
        assert_eq!(
            body["systemInstruction"]["parts"][0]["text"],
            "system fixture"
        );
        assert_eq!(body["generationConfig"]["topP"], 0.5);
        assert_eq!(body["generationConfig"]["maxOutputTokens"], 4096);
        assert_eq!(body["tools"], json!([{"googleSearch":{}}]));
        for field in ["model", "messages", "stream", "n"] {
            assert!(body.get(field).is_none());
        }
    }
}

#[tokio::test]
async fn gemini_rejects_missing_finish_filter_tools_and_partial_tail() {
    let stop =
        json!({"candidates":[{"content":{"parts":[{"text":"partial"}]},"finishReason":"STOP"}]});
    for body in [
        format!(
            "data: {}\n\n",
            json!({"candidates":[{"content":{"parts":[{"text":"partial"}]}}]})
        ),
        format!(
            "data: {}\n\n",
            json!({"candidates":[{"finishReason":"SAFETY"}]})
        ),
        format!(
            "data: {}\n\n",
            json!({"candidates":[{"content":{"parts":[{"functionCall":{"name":"untrusted"}}]},"finishReason":"STOP"}]})
        ),
        format!("data: {stop}\n\ndata: {{\"private-tail\":"),
        format!("data: {stop}\n\ndata: {stop}\n\n"),
        format!(
            "data: {stop}\n\ndata: {}\n\n",
            json!({"error":{"message":"private-upstream-message"}})
        ),
    ] {
        let (endpoint, worker) = serve("200 OK", body, "text/event-stream");
        let runtime = Runtime::new();
        let mut input = request(endpoint);
        input.protocol = "native".into();
        let received = collect(&runtime.start_chat(input).unwrap()).await;
        assert!(matches!(received.last(), Some(ChatEvent::Failed(_))));
        assert!(
            !received
                .iter()
                .any(|e| matches!(e, ChatEvent::Completed { .. }))
        );
        assert!(!format!("{received:?}").contains("private-upstream-message"));
        worker.join().unwrap();
    }
}

#[test]
fn gemini_url_and_thinking_follow_old_contract_without_path_injection() {
    for endpoint in [
        "https://generativelanguage.googleapis.com/v1beta/models",
        "https://generativelanguage.googleapis.com/v1beta/models/",
        "https://generativelanguage.googleapis.com/v1beta",
    ] {
        for stream in [false, true] {
            let result = gemini::url(endpoint, "gemini-2.5-flash", stream).unwrap();
            assert_eq!(
                result.path(),
                if stream {
                    "/v1beta/models/gemini-2.5-flash:streamGenerateContent"
                } else {
                    "/v1beta/models/gemini-2.5-flash:generateContent"
                }
            );
            assert_eq!(result.query(), if stream { Some("alt=sse") } else { None });
        }
    }
    for model in ["../private", "models/a/b", "a:operation", "a?key=value"] {
        assert!(gemini::url("http://127.0.0.1", model, true).is_err());
    }
    let mut parameters = serde_json::Map::new();
    gemini::thinking(&mut parameters, "gemini-2.5-flash", false, 3).unwrap();
    assert_eq!(
        parameters["thinkingConfig"],
        json!({"thinkingBudget":0,"includeThoughts":false})
    );
    for (model, field, expected) in [
        ("gemini-2.5-pro", "thinkingBudget", json!(8192)),
        ("gemini-3-pro", "thinkingLevel", json!("high")),
        (
            "gemini-3.1-flash-lite-image",
            "thinkingLevel",
            json!("high"),
        ),
    ] {
        let mut parameters = serde_json::Map::new();
        assert!(gemini::thinking(&mut parameters, model, false, 3).is_err());
        gemini::thinking(&mut parameters, model, true, 3).unwrap();
        assert_eq!(parameters["thinkingConfig"][field], expected);
    }
    for value in [
        json!(false),
        json!({"thinkingBudget":0}),
        json!({"thinkingBudget":2,"thinkingLevel":"high"}),
        json!({"thinkingLevel":"unknown"}),
    ] {
        let mut parameters = serde_json::Map::from_iter([("thinkingConfig".into(), value)]);
        assert!(gemini::thinking(&mut parameters, "gemini-3.8-flash", true, 3).is_err());
    }
}

#[tokio::test]
async fn messages_authentication_uses_the_selected_provider_and_custom_header_override() {
    for provider in [
        "ZHIPU",
        "MIMO",
        "INFINIAI",
        "LMSTUDIO",
        "OLLAMA",
        "DEEPSEEK",
        "NOVITA",
        "ANTHROPIC_GENERIC",
    ] {
        let body = json!({"type":"message","role":"assistant","content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn"}).to_string();
        let (endpoint, worker) = serve("200 OK", body, "application/json");
        let mut input = request(endpoint);
        input.protocol = "messages".into();
        input.provider = provider.into();
        input.stream = false;
        let received = collect(&Runtime::new().start_chat(input).unwrap()).await;
        assert!(matches!(received.last(), Some(ChatEvent::Completed { .. })));
        let captured = worker.join().unwrap().to_lowercase();
        let bearer = matches!(
            provider,
            "ZHIPU" | "MIMO" | "INFINIAI" | "LMSTUDIO" | "OLLAMA"
        );
        assert!(captured.contains(if bearer {
            "authorization: bearer loopback-fixture"
        } else {
            "x-api-key: loopback-fixture"
        }));
        assert_eq!(captured.contains("\r\nx-api-key:"), !bearer);
        if provider == "MIMO" {
            assert!(captured.contains("\r\napi-key: loopback-fixture"));
        }
    }
}

#[test]
fn saved_text_and_json_parameters_keep_their_declared_types() {
    let mut draft = crate::models::ModelConfigDraft {
        name: "test".into(),
        provider: "OPENAI_GENERIC".into(),
        protocol: "chat".into(),
        endpoint: "http://127.0.0.1".into(),
        models: vec!["fixture".into()],
        options: crate::models::ModelOptions::default(),
    };
    draft.options.parameters = vec![
        crate::models::ModelParameter {
            name: "user".into(),
            enabled: true,
            value_type: "text".into(),
            value: "synthetic user".into(),
            category: "custom".into(),
        },
        crate::models::ModelParameter {
            name: "reasoning".into(),
            enabled: true,
            value_type: "json".into(),
            value: r#"{"effort":"none"}"#.into(),
            category: "custom".into(),
        },
    ];
    let prepared = super::probe::prepare(draft, String::new(), vec![], "chat").unwrap();
    let value: serde_json::Value = serde_json::from_str(&prepared.parameters).unwrap();
    assert_eq!(value["user"], "synthetic user");
    assert_eq!(value["reasoning"]["effort"], "none");
}

#[tokio::test]
async fn messages_stream_and_document_use_system_auth_cache_and_complete_usage() {
    for stream in [true, false] {
        let events = [
            json!({"type":"message_start","message":{"usage":{"input_tokens":2,"cache_read_input_tokens":8,"cache_creation_input_tokens":1,"output_tokens":0}}}),
            json!({"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}),
            json!({"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"private thought"}}),
            json!({"type":"content_block_stop","index":0}),
            json!({"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}),
            json!({"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"你好"}}),
            json!({"type":"content_block_stop","index":1}),
            json!({"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}),
            json!({"type":"message_stop"}),
        ];
        let body = if stream {
            events.iter().map(|e| format!("data: {e}\n\n")).collect()
        } else {
            json!({"type":"message","role":"assistant","content":[{"type":"thinking","thinking":"private thought"},{"type":"text","text":"你好"}],"stop_reason":"end_turn","usage":{"input_tokens":2,"cache_read_input_tokens":8,"cache_creation_input_tokens":1,"output_tokens":3}}).to_string()
        };
        let (endpoint, worker) = serve(
            "200 OK",
            body,
            if stream {
                "text/event-stream"
            } else {
                "application/json"
            },
        );
        let runtime = Runtime::new();
        let mut input = request(endpoint);
        input.protocol = "messages".into();
        input.stream = stream;
        input.claude_cache = true;
        input.messages.insert(
            0,
            ChatMessage {
                role: "system".into(),
                content: "system fixture".into(),
            },
        );
        let run = runtime.start_chat(input).unwrap();
        let received = collect(&run).await;
        assert!(received.contains(&ChatEvent::Text("你好".into())));
        assert!(!format!("{received:?}").contains("private thought"));
        assert!(matches!(received.last(),Some(ChatEvent::Completed{reason,..}) if reason=="stop"));
        assert!(received.contains(&ChatEvent::Usage {
            input: 11,
            output: 3,
            output_reported: true,
            total: 14,
            cache_read: Some(8),
            cache_write: Some(1),
            reasoning: None
        }));
        let request = worker.join().unwrap();
        let (headers, body) = request.split_once("\r\n\r\n").unwrap();
        assert!(headers.starts_with("POST /v1/messages"));
        assert!(
            headers
                .to_lowercase()
                .contains("x-api-key: loopback-fixture")
        );
        assert!(
            headers
                .to_lowercase()
                .contains("anthropic-version: 2023-06-01")
        );
        assert!(!headers.to_lowercase().contains("authorization:"));
        let body: Value = serde_json::from_str(body).unwrap();
        assert_eq!(body["system"][0]["text"], "system fixture");
        assert_eq!(body["system"][0]["cache_control"]["ttl"], "1h");
        assert_eq!(body["messages"][0]["role"], "user");
        assert_eq!(body["max_tokens"], 4096);
        assert!(body.get("n").is_none());
    }
}

#[tokio::test]
async fn messages_rejects_open_blocks_tools_and_missing_terminal_without_false_success() {
    for sequence in [
        vec![
            json!({"type":"message_start"}),
            json!({"type":"message_stop"}),
        ],
        vec![
            json!({"type":"message_start"}),
            json!({"type":"content_block_start","index":0,"content_block":{"type":"text","text":"partial"}}),
            json!({"type":"message_delta","delta":{"stop_reason":"end_turn"}}),
        ],
        vec![
            json!({"type":"message_start"}),
            json!({"type":"content_block_start","index":0,"content_block":{"type":"tool_use","name":"unknown"}}),
        ],
        vec![json!({"type":"error","error":{"message":"private upstream error"}})],
    ] {
        let (endpoint, worker) = serve(
            "200 OK",
            sequence.iter().map(|e| format!("data: {e}\n\n")).collect(),
            "text/event-stream",
        );
        let runtime = Runtime::new();
        let mut input = request(endpoint);
        input.protocol = "messages".into();
        let run = runtime.start_chat(input).unwrap();
        let received = collect(&run).await;
        assert!(matches!(received.last(), Some(ChatEvent::Failed(_))));
        assert!(
            !received
                .iter()
                .any(|e| matches!(e, ChatEvent::Completed { .. }))
        );
        assert!(!format!("{received:?}").contains("private upstream error"));
        worker.join().unwrap();
    }
}
use crate::runtime::Runtime;
use std::io::{Read, Write};
use std::net::TcpListener;

fn request(endpoint: String) -> ChatRequest {
    ChatRequest {
        prelude: None,
        provider: String::new(),
        continuation_credentials: None,
        google_search: false,
        claude_cache: false,
        admission: None,
        stream: true,
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

#[tokio::test]
async fn optional_usage_never_invalidates_valid_chat_or_responses() {
    for protocol in ["chat", "responses"] {
        for stream in [true, false] {
            for usage in [
                json!({}),
                json!({"input_tokens":12}),
                json!({"input_tokens":-1,"output_tokens":2}),
                json!({"input_tokens":12,"output_tokens":"bad"}),
                json!({"input_tokens":12,"output_tokens":2}),
            ] {
                let document = if protocol == "chat" {
                    json!({"choices":[{"index":0,"message":{"role":"assistant","content":"完整回复"},"delta":{"content":"完整回复"},"finish_reason":"stop"}],"usage":usage})
                } else {
                    json!({"status":"completed","output":[{"type":"message","role":"assistant","id":"message","content":[{"type":"output_text","text":"完整回复"}]}],"usage":usage})
                };
                let body = if !stream {
                    document.to_string()
                } else if protocol == "chat" {
                    format!("data: {document}\n\ndata: [DONE]\n\n")
                } else {
                    format!(
                        "data: {}\n\ndata: {}\n\n",
                        json!({"type":"response.output_text.delta","item_id":"message","output_index":0,"content_index":0,"delta":"完整回复"}),
                        json!({"type":"response.completed","response":document})
                    )
                };
                let (endpoint, worker) = serve(
                    "200 OK",
                    body,
                    if stream {
                        "text/event-stream"
                    } else {
                        "application/json"
                    },
                );
                let runtime = Runtime::new();
                let mut input = request(endpoint);
                input.protocol = protocol.into();
                input.stream = stream;
                let run = runtime.start_chat(input).unwrap();
                let mut events = vec![];
                while let Some(event) = run.next_event().await.unwrap() {
                    events.push(event);
                }
                assert!(
                    matches!(events.last(), Some(ChatEvent::Completed { .. })),
                    "{protocol} {stream} {usage}: {events:?}"
                );
                if usage.get("output_tokens").is_none()
                    && usage.get("input_tokens") == Some(&json!(12))
                {
                    assert!(events.iter().any(|e| matches!(
                        e,
                        ChatEvent::Usage {
                            input: 12,
                            output_reported: false,
                            ..
                        }
                    )));
                }
                worker.join().unwrap();
                runtime.close();
            }
        }
    }
}

#[tokio::test]
async fn nonstream_chat_and_responses_use_json_and_preserve_usage() {
    for (protocol, body) in [
        (
            "chat",
            json!({"choices":[{"index":0,"message":{"role":"assistant","content":"完整回复"},"finish_reason":"stop"}],"usage":{"prompt_tokens":2,"completion_tokens":3,"total_tokens":5}}),
        ),
        (
            "responses",
            json!({"status":"completed","output":[{"type":"message","role":"assistant","id":"message","content":[{"type":"output_text","text":"完整回复"}]}],"usage":{"input_tokens":2,"output_tokens":3,"total_tokens":5}}),
        ),
    ] {
        let (endpoint, worker) = serve("200 OK", body.to_string(), "application/json");
        let runtime = Runtime::new();
        let mut input = request(endpoint);
        input.stream = false;
        input.protocol = protocol.into();
        let run = runtime.start_chat(input).unwrap();
        let mut events = vec![];
        while let Some(event) = run.next_event().await.unwrap() {
            events.push(event);
        }
        assert!(
            events
                .iter()
                .any(|e| matches!(e,ChatEvent::Text(text) if text=="完整回复"))
        );
        assert!(events.iter().any(|e| matches!(
            e,
            ChatEvent::Usage {
                input: 2,
                output: 3,
                total: 5,
                ..
            }
        )));
        assert!(matches!(events.last(),Some(ChatEvent::Completed {reason,..}) if reason=="stop"));
        let request = worker.join().unwrap();
        assert!(request.contains("\"stream\":false"));
        assert!(
            request
                .to_ascii_lowercase()
                .contains("accept: application/json")
        );
        runtime.close();
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

fn responses_body(status: &str, reason: Option<&str>, text: &str) -> String {
    let mut events = vec![
        json!({"type":"response.created"}),
        json!({"type":"response.output_item.added","item":{"type":"reasoning","id":"r"}}),
        json!({"type":"response.reasoning_text.delta","delta":"private-reasoning-fixture"}),
        json!({"type":"response.output_item.added","item":{"type":"message","role":"assistant","id":"m","content":[]}}),
    ];
    for delta in ["你", "好"] {
        events.push(json!({"type":"response.output_text.delta","item_id":"m","output_index":1,"content_index":0,"delta":delta}));
    }
    events.push(json!({"type":"response.output_text.done","text":"你好"}));
    events.push(json!({"type":format!("response.{status}"),"response":{
        "status":status,"error":null,"incomplete_details":reason.map(|r| json!({"reason":r})),
        "output":[{"type":"reasoning","id":"r"},{"type":"message","role":"assistant","id":"m","content":[{"type":"output_text","text":text}]}],
        "usage":{"input_tokens":2,"output_tokens":3,"total_tokens":5}}}));
    events
        .into_iter()
        .enumerate()
        .map(|(sequence, mut value)| {
            value["sequence_number"] = json!(sequence);
            format!(
                "event: {}\ndata: {value}\n\n",
                value["type"].as_str().unwrap()
            )
        })
        .collect()
}

#[tokio::test]
async fn responses_request_stream_and_usage_do_not_require_chat_done() {
    let (endpoint, worker) = serve(
        "200 OK",
        responses_body("completed", None, "你好"),
        "text/event-stream",
    );
    let runtime = Runtime::new();
    let mut input = request(endpoint);
    input.protocol = "responses".into();
    input.parameters = r#"{"max_tokens":64,"reasoning":{"effort":"none"}}"#.into();
    input.messages.insert(
        0,
        ChatMessage {
            role: "system".into(),
            content: "Be concise".into(),
        },
    );
    let events = collect(&runtime.start_chat(input).unwrap()).await;
    assert_eq!(
        events,
        [
            ChatEvent::Started,
            ChatEvent::Text("你".into()),
            ChatEvent::Text("好".into()),
            ChatEvent::Usage {
                input: 2,
                output: 3,
                total: 5,
                cache_read: None,
                cache_write: None,
                reasoning: None,
                output_reported: true,
            },
            ChatEvent::Completed {
                reason: "stop".into(),
                verified: None
            }
        ]
    );
    assert!(!format!("{events:?}").contains("private-reasoning-fixture"));
    let received = worker.join().unwrap();
    assert!(received.starts_with("POST /v1/responses HTTP/1.1"));
    let posted: Value = serde_json::from_str(received.split("\r\n\r\n").nth(1).unwrap()).unwrap();
    assert_eq!(posted["input"][0]["role"], "system");
    assert_eq!(posted["max_output_tokens"], 64);
    assert_eq!(posted["reasoning"]["effort"], "none");
    assert_eq!(posted["store"], false);
    assert_eq!(posted["background"], false);
    assert!(
        posted.get("messages").is_none()
            && posted.get("n").is_none()
            && posted.get("max_tokens").is_none()
    );
}

#[test]
fn responses_endpoint_completes_base_and_preserves_exact_paths() {
    for base in ["https://example.test", "https://example.test/v1/"] {
        assert_eq!(endpoint(base, "responses").unwrap().path(), "/v1/responses");
    }
    assert_eq!(
        endpoint("https://example.test/custom#", "responses")
            .unwrap()
            .path(),
        "/custom"
    );
}

#[tokio::test]
async fn responses_incomplete_errors_tools_and_missing_terminal_are_explicit() {
    for (body, expected) in [
        (responses_body("incomplete", Some("max_output_tokens"), "你好"), None),
        (responses_body("completed", None, "替换"), Some(ChatFailureKind::Interrupted)),
        (responses_body("completed", None, ""), Some(ChatFailureKind::Interrupted)),
        ("data: {\"type\":\"response.failed\",\"error\":\"private-error\"}\n\n".into(), Some(ChatFailureKind::Protocol)),
        ("data: {\"type\":\"response.output_item.added\",\"item\":{\"type\":\"function_call\"}}\n\n".into(), Some(ChatFailureKind::Unsupported)),
        ("data: {\"type\":\"response.created\"}\n\n".into(), Some(ChatFailureKind::Interrupted)),
        ("data: [DONE]\n\n".into(), Some(ChatFailureKind::Protocol)),
    ] {
        let (endpoint, worker) = serve("200 OK", body, "text/event-stream");
        let runtime = Runtime::new();
        let mut input = request(endpoint);
        input.protocol = "responses".into();
        let events = collect(&runtime.start_chat(input).unwrap()).await;
        match expected {
            None => assert!(matches!(events.last(), Some(ChatEvent::Completed {reason,..}) if reason=="length")),
            Some(expected) => assert!(matches!(events.last(), Some(ChatEvent::Failed(f)) if f.kind==expected), "{events:?}"),
        }
        assert!(!format!("{events:?}").contains("private-error"));
        worker.join().unwrap();
    }
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
                total: 3,
                cache_read: None,
                cache_write: None,
                reasoning: None,
                output_reported: true,
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
        endpoint("https://example.test", "chat").unwrap().path(),
        "/v1/chat/completions"
    );
    assert_eq!(
        endpoint("https://example.test/v1/", "chat").unwrap().path(),
        "/v1/chat/completions"
    );
    assert_eq!(
        endpoint("https://example.test/custom#", "chat")
            .unwrap()
            .path(),
        "/custom"
    );
    for raw in [
        "http://example.test",
        "https://u:p@example.test",
        "https://example.test/?key=private",
        "https://example.test/#fragment",
        "file:///tmp/a",
    ] {
        assert!(endpoint(raw, "chat").is_err());
    }
    assert!(endpoint("http://[::1]:8080", "chat").is_ok());
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
