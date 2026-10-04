use super::*;
use crate::{
    models::{ModelConfigDraft, ModelOptions},
    runtime::Runtime,
};
use std::{
    io::{Read, Write},
    net::TcpListener,
};

fn document(protocol: &str, text: &str, tool: bool) -> Value {
    match protocol {
        "chat" => {
            json!({"choices":[{"index":0,"message":if tool {json!({"content":"","reasoning_content":"private thought","tool_calls":[{"id":"call-fixture","type":"function","function":{"name":"echo","arguments":"{\"text\":\"ping\"}"}}]})}else{json!({"content":text})},"finish_reason":if tool {"tool_calls"}else{"stop"}}]})
        }
        "responses" => {
            json!({"status":"completed","output":if tool {json!([{"type":"reasoning","id":"thinking","encrypted_content":"opaque-fixture"},{"type":"function_call","id":"item-fixture","call_id":"call-fixture","name":"echo","arguments":"{\"text\":\"ping\"}"}])}else{json!([{"type":"message","id":"item-answer","role":"assistant","content":[{"type":"output_text","text":text}]}])}})
        }
        "messages" => {
            json!({"type":"message","role":"assistant","stop_reason":if tool {"tool_use"}else{"end_turn"},"content":if tool {json!([{"type":"thinking","thinking":"private thought","signature":"signature-fixture"},{"type":"tool_use","id":"call-fixture","name":"echo","input":{"text":"ping"}}])}else{json!([{"type":"text","text":text}])}})
        }
        _ => {
            json!({"candidates":[{"content":{"parts":if tool {json!([{"text":"private thought","thought":true},{"functionCall":{"name":"echo","args":{"text":"ping"}},"thoughtSignature":"signature-fixture"}])}else{json!([{"text":text}])}},"finishReason":"STOP"}]})
        }
    }
}
fn response(protocol: &str, stream: bool, text: &str, tool: bool) -> String {
    if !stream {
        return document(protocol, text, tool).to_string();
    }
    let frames = match protocol {
        "chat" if tool => vec![
            json!({"choices":[{"index":0,"delta":{"reasoning_content":"private "},"finish_reason":null}]}),
            json!({"choices":[{"index":0,"delta":{"reasoning_content":"thought"},"finish_reason":null}]}),
            json!({"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call-fixture","function":{"name":"e","arguments":"{\"text\":"}}]},"finish_reason":null}]}),
            json!({"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"name":"cho","arguments":"\"ping\"}"}}]},"finish_reason":"tool_calls"}]}),
        ],
        "chat" => {
            vec![json!({"choices":[{"index":0,"delta":{"content":text},"finish_reason":"stop"}]})]
        }
        "responses" if tool => vec![
            json!({"type":"response.output_item.added","output_index":1,"item":{"type":"function_call","id":"item-fixture","call_id":"call-fixture","name":"echo","arguments":""}}),
            json!({"type":"response.function_call_arguments.delta","output_index":1,"item_id":"item-fixture","delta":"{\"text\":"}),
            json!({"type":"response.function_call_arguments.delta","output_index":1,"item_id":"item-fixture","delta":"\"ping\"}"}),
            json!({"type":"response.function_call_arguments.done","output_index":1,"item_id":"item-fixture","arguments":"{\"text\":\"ping\"}"}),
            json!({"type":"response.output_item.done","output_index":1,"item":document(protocol,text,true)["output"][1]}),
            json!({"type":"response.completed","response":document(protocol,text,true)}),
        ],
        "responses" => vec![
            json!({"type":"response.output_text.delta","output_index":0,"content_index":0,"item_id":"item-answer","delta":text}),
            json!({"type":"response.completed","response":document(protocol,text,false)}),
        ],
        "messages" if tool => vec![
            json!({"type":"message_start"}),
            json!({"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}),
            json!({"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"private thought"}}),
            json!({"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"signature-fixture"}}),
            json!({"type":"content_block_stop","index":0}),
            json!({"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-fixture","name":"echo","input":{}}}),
            json!({"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}),
            json!({"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"ping\"}"}}),
            json!({"type":"content_block_stop","index":1}),
            json!({"type":"message_delta","delta":{"stop_reason":"tool_use"}}),
            json!({"type":"message_stop"}),
        ],
        "messages" => vec![
            json!({"type":"message_start"}),
            json!({"type":"content_block_start","index":0,"content_block":{"type":"text","text":text}}),
            json!({"type":"content_block_stop","index":0}),
            json!({"type":"message_delta","delta":{"stop_reason":"end_turn"}}),
            json!({"type":"message_stop"}),
        ],
        _ => vec![document(protocol, text, tool)],
    };
    let mut response: String = frames.iter().map(|v| format!("data: {v}\n\n")).collect();
    if protocol == "chat" {
        response.push_str("data: [DONE]\n\n");
    }
    response
}

#[tokio::test]
async fn real_two_round_native_and_xml_probes_require_call_and_nonce_result_replay() {
    for protocol in ["chat", "responses", "messages", "native"] {
        for stream in [true, false] {
            for native in [true, false] {
                let listener = TcpListener::bind("127.0.0.1:0").unwrap();
                let endpoint = format!("http://{}", listener.local_addr().unwrap());
                let worker = std::thread::spawn(move || {
                    let mut requests: Vec<Value> = Vec::new();
                    for round in 0..2 {
                        let (mut socket, _) = listener.accept().unwrap();
                        socket
                            .set_read_timeout(Some(Duration::from_secs(3)))
                            .unwrap();
                        let mut bytes = Vec::new();
                        loop {
                            let mut block = [0; 4096];
                            let count = socket.read(&mut block).unwrap();
                            assert!(count > 0);
                            bytes.extend_from_slice(&block[..count]);
                            if let Some(offset) = bytes.windows(4).position(|v| v == b"\r\n\r\n") {
                                let headers =
                                    String::from_utf8_lossy(&bytes[..offset]).to_ascii_lowercase();
                                let length = headers
                                    .lines()
                                    .find_map(|v| v.strip_prefix("content-length: "))
                                    .unwrap()
                                    .parse::<usize>()
                                    .unwrap();
                                if bytes.len() >= offset + 4 + length {
                                    break;
                                }
                            }
                        }
                        let offset = bytes.windows(4).position(|v| v == b"\r\n\r\n").unwrap() + 4;
                        let body: Value = serde_json::from_slice(&bytes[offset..]).unwrap();
                        let text = if round == 0 {
                            if native {
                                String::new()
                            } else {
                                "<tool name=\"echo\"><param name=\"text\">ping</param></tool>"
                                    .into()
                            }
                        } else {
                            let field = match protocol {
                                "responses" => "input",
                                "native" => "contents",
                                _ => "messages",
                            };
                            let last = body[field].as_array().unwrap().last().unwrap();
                            let code = if native {
                                let path = match protocol {
                                    "chat" => "/content",
                                    "responses" => "/output",
                                    "messages" => "/content/0/content",
                                    _ => "/parts/0/functionResponse/response/result",
                                };
                                last.pointer(path).unwrap().as_str().unwrap().to_owned()
                            } else {
                                let path = match protocol {
                                    "messages" => "/content/0/text",
                                    "native" => "/parts/0/text",
                                    _ => "/content",
                                };
                                let text = last.pointer(path).unwrap().as_str().unwrap();
                                text.split('>')
                                    .nth(1)
                                    .unwrap()
                                    .split('<')
                                    .next()
                                    .unwrap()
                                    .into()
                            };
                            assert!(code.starts_with("probe_") && code.len() == 38);
                            assert!(!requests[0].to_string().contains(&code));
                            code
                        };
                        requests.push(body);
                        let response = response(protocol, stream, &text, native && round == 0);
                        write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{response}",if stream {"text/event-stream"}else{"application/json"},response.len()).unwrap();
                    }
                    requests
                });
                let draft = ModelConfigDraft {
                    name: "fixture".into(),
                    provider: if protocol == "native" {
                        "GOOGLE".into()
                    } else {
                        "OPENAI_GENERIC".into()
                    },
                    protocol: protocol.into(),
                    endpoint,
                    models: vec!["fixture".into()],
                    options: ModelOptions::default(),
                };
                let mut input = probe::prepare(
                    draft,
                    String::new(),
                    vec![],
                    if native { "tool" } else { "xml_tool" },
                )
                .unwrap();
                input.stream = stream;
                let runtime = Runtime::new();
                let run = runtime.start_chat(input).unwrap();
                let mut events = Vec::new();
                while let Some(event) = run.next_event().await.unwrap() {
                    events.push(event);
                }
                assert!(
                    matches!(
                        events.last(),
                        Some(ChatEvent::Completed {
                            verified: Some(true),
                            ..
                        })
                    ),
                    "{protocol}/{stream}/{native}: {events:?}"
                );
                assert_eq!(
                    events
                        .iter()
                        .filter(|e| matches!(e, ChatEvent::Completed { .. }))
                        .count(),
                    1
                );
                assert!(!format!("{events:?}").contains("private thought"));
                let requests = worker.join().unwrap();
                if native {
                    match protocol {
                        "chat" => {
                            assert_eq!(
                                requests[1]["messages"][2]["reasoning_content"],
                                "private thought"
                            );
                            assert_eq!(requests[1]["messages"][3]["tool_call_id"], "call-fixture")
                        }
                        "responses" => assert_eq!(
                            requests[1]["input"][2]["encrypted_content"],
                            "opaque-fixture"
                        ),
                        "messages" => assert_eq!(
                            requests[1]["messages"][1]["content"][0]["signature"],
                            "signature-fixture"
                        ),
                        _ => assert_eq!(
                            requests[1]["contents"][1]["parts"][1]["thoughtSignature"],
                            "signature-fixture"
                        ),
                    }
                }
            }
        }
    }
}

#[test]
fn tool_probe_never_dispatches_unknown_extra_or_unidentified_calls_or_guess_answers() {
    for text in [
        "<tool name=\"echo\">\n  <param name=\"text\">ping</param>\n</tool>",
        "```xml\n<tool name = 'echo'><param name = 'text'>ping</param></tool>\n```",
        "I will call the tool.\n<tool name=\"echo\"><param name=\"text\">ping</param></tool>",
    ] {
        assert!(
            tool_probe::ToolProbe::new(false)
                .advance("chat", text, "stop")
                .unwrap()
        );
    }
    for text in [
        "<tool name=\"echo\"><param name=\"text\">pi ng</param></tool>",
        "<tool name=\"echo\"><param name=\"text\">ping</param><param name=\"extra\">x</param></tool>",
        "<tool name=\"echo\"><param name=\"text\">ping</param></tool><tool name=\"shell\"></tool>",
        "<tool name=\"echo\" command=\"x\"><param name=\"text\">ping</param></tool>",
    ] {
        assert!(
            !tool_probe::ToolProbe::new(false)
                .advance("chat", text, "stop")
                .unwrap()
        );
    }
    for (id, name, args) in [
        ("", "echo", json!({"text":"ping"})),
        ("call", "shell", json!({"text":"ping"})),
        ("call", "echo", json!({"text":"ping","extra":true})),
        ("call", "echo", json!({"text":"wrong"})),
    ] {
        let mut tool = tool_probe::ToolProbe::new(true);
        tool.capture(id, name, args).unwrap();
        assert!(!tool.advance("chat", "guessed response", "tool").unwrap());
        assert!(tool.code.is_empty());
    }
    let mut tool = tool_probe::ToolProbe::new(true);
    tool.capture("call", "echo", json!({"text":"ping"}))
        .unwrap();
    tool.capture("call2", "echo", json!({"text":"ping"}))
        .unwrap();
    assert!(!tool.advance("messages", "", "tool").unwrap());
    let mut tool = tool_probe::ToolProbe::new(false);
    assert!(
        !tool
            .advance(
                "chat",
                "<tool name=\"shell\"><param name=\"text\">ping</param></tool>",
                "stop"
            )
            .unwrap()
    );
}
