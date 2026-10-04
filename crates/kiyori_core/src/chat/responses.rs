//! Responses文本协议适配；网络、超时、取消和背压仍归共享请求核心。
use super::*;
use std::collections::BTreeMap;
use std::hash::{DefaultHasher, Hasher};

pub(super) fn prepare(
    object: &mut serde_json::Map<String, Value>,
    messages: &[ChatMessage],
) -> Result<(), ChatFailure> {
    // 沿用编辑页的通用token参数；不同时发送两个互斥的协议字段。
    if let Some(limit) = object.remove("max_tokens") {
        if object.contains_key("max_output_tokens") {
            return Err(ChatFailure::new(
                ChatFailureKind::InvalidInput,
                "输出token限制重复",
            ));
        }
        object.insert("max_output_tokens".into(), limit);
    }
    object.insert("input".into(), json!(messages));
    object.insert("store".into(), json!(false));
    object.insert("background".into(), json!(false));
    Ok(())
}

#[derive(Default)]
pub(super) struct Decoder {
    document: bool,
    functions: BTreeMap<u64, (String, String, String, String)>,
    sequence: Option<u64>,
    // 不累计正文；增量指纹用于检查最终快照没有缺段、重复或替换。
    parts: BTreeMap<(u64, u64), (String, usize, DefaultHasher)>,
}

fn unsupported() -> ChatFailure {
    ChatFailure::new(
        ChatFailureKind::Unsupported,
        "此请求入口尚未接入该输出类型或工具执行",
    )
}

fn validate_item(item: &Value, tools: bool) -> Result<(), ChatFailure> {
    match item.get("type").and_then(Value::as_str) {
        Some("message") => {
            if item.get("role").and_then(Value::as_str) != Some("assistant") {
                return Err(ChatFailure::protocol());
            }
            for part in item
                .get("content")
                .and_then(Value::as_array)
                .ok_or_else(ChatFailure::protocol)?
            {
                if part.get("type").and_then(Value::as_str) != Some("output_text") {
                    return Err(unsupported());
                }
            }
            Ok(())
        }
        Some("reasoning") => Ok(()),
        Some("function_call") if tools => {
            for key in ["id", "call_id", "name", "arguments"] {
                let value = item
                    .get(key)
                    .and_then(Value::as_str)
                    .ok_or_else(ChatFailure::protocol)?;
                if value.len() > 64000 {
                    return Err(ChatFailure::protocol());
                }
            }
            Ok(())
        }
        _ => Err(unsupported()),
    }
}

impl Decoder {
    pub async fn document(
        value: Value,
        probe: &mut Option<probe::Probe>,
        sender: &super::EventSender,
    ) -> Result<String, ChatFailure> {
        let kind = match value.get("status").and_then(Value::as_str) {
            Some("completed") => "response.completed",
            Some("incomplete") => "response.incomplete",
            _ => return Err(ChatFailure::protocol()),
        };
        let output = value
            .get("output")
            .and_then(Value::as_array)
            .ok_or_else(ChatFailure::protocol)?;
        // 先核对整个文档的输出类型，再投影文本；完整JSON复用相同终态与用量校验。
        for item in output {
            validate_item(item, tool_probe::native(probe).is_some())?;
        }
        let mut decoder = Self {
            document: true,
            ..Default::default()
        };
        for (index, item) in output.iter().enumerate() {
            if item["type"] != "message" {
                continue;
            }
            let id = item
                .get("id")
                .and_then(Value::as_str)
                .ok_or_else(ChatFailure::protocol)?;
            for (part, content) in item["content"]
                .as_array()
                .ok_or_else(ChatFailure::protocol)?
                .iter()
                .enumerate()
            {
                let text = content
                    .get("text")
                    .and_then(Value::as_str)
                    .ok_or_else(ChatFailure::protocol)?;
                decoder.decode(&serde_json::json!({"type":"response.output_text.delta","output_index":index,"content_index":part,"item_id":id,"delta":text}).to_string(),probe,sender).await?;
            }
        }
        decoder
            .decode(
                &serde_json::json!({"type":kind,"response":value}).to_string(),
                probe,
                sender,
            )
            .await?
            .ok_or_else(ChatFailure::protocol)
    }
    pub async fn decode(
        &mut self,
        data: &str,
        probe: &mut Option<probe::Probe>,
        sender: &super::EventSender,
    ) -> Result<Option<String>, ChatFailure> {
        let value: Value = serde_json::from_str(data).map_err(|_| ChatFailure::protocol())?;
        if let Some(sequence) = value.get("sequence_number") {
            let sequence = sequence.as_u64().ok_or_else(ChatFailure::protocol)?;
            if self.sequence.is_some_and(|old| sequence <= old) {
                return Err(ChatFailure::protocol());
            }
            self.sequence = Some(sequence);
        }
        let kind = value
            .get("type")
            .and_then(Value::as_str)
            .ok_or_else(ChatFailure::protocol)?;
        match kind {
            "response.output_text.delta" => {
                let index = value
                    .get("output_index")
                    .and_then(Value::as_u64)
                    .ok_or_else(ChatFailure::protocol)?;
                let part = value
                    .get("content_index")
                    .and_then(Value::as_u64)
                    .ok_or_else(ChatFailure::protocol)?;
                let id = value
                    .get("item_id")
                    .and_then(Value::as_str)
                    .ok_or_else(ChatFailure::protocol)?;
                let text = value
                    .get("delta")
                    .and_then(Value::as_str)
                    .ok_or_else(ChatFailure::protocol)?;
                if index > 4095
                    || part > 4095
                    || id.len() > 512
                    || self.parts.len() >= 4096 && !self.parts.contains_key(&(index, part))
                {
                    return Err(ChatFailure::protocol());
                }
                let tracked = self
                    .parts
                    .entry((index, part))
                    .or_insert_with(|| (id.into(), 0, DefaultHasher::new()));
                if tracked.0 != id {
                    return Err(ChatFailure::protocol());
                }
                tracked.1 = tracked
                    .1
                    .checked_add(text.len())
                    .ok_or_else(ChatFailure::protocol)?;
                tracked.2.write(text.as_bytes());
                if let Some(probe) = probe {
                    probe.append(text)?;
                } else if !text.is_empty() {
                    let _ = sender.send(ChatEvent::Text(text.into())).await;
                }
            }
            "response.output_item.added" | "response.output_item.done" => {
                let item = value.get("item").ok_or_else(ChatFailure::protocol)?;
                validate_item(item, tool_probe::native(probe).is_some())?;
                if item["type"] == "function_call" {
                    let index = value["output_index"]
                        .as_u64()
                        .filter(|v| *v < 4096)
                        .ok_or_else(ChatFailure::protocol)?;
                    let fields = (
                        item["id"].as_str().unwrap().to_owned(),
                        item["call_id"].as_str().unwrap().to_owned(),
                        item["name"].as_str().unwrap().to_owned(),
                        item["arguments"].as_str().unwrap().to_owned(),
                    );
                    if kind == "response.output_item.added" {
                        if self.functions.len() >= 16
                            || self.functions.insert(index, fields).is_some()
                        {
                            return Err(ChatFailure::protocol());
                        }
                    } else if self.functions.get(&index) != Some(&fields) {
                        return Err(ChatFailure::new(
                            ChatFailureKind::Interrupted,
                            "工具调用最终快照与增量不一致",
                        ));
                    }
                }
            }
            "response.function_call_arguments.delta" | "response.function_call_arguments.done" => {
                if tool_probe::native(probe).is_none() {
                    return Err(unsupported());
                }
                let index = value["output_index"]
                    .as_u64()
                    .ok_or_else(ChatFailure::protocol)?;
                let tracked = self
                    .functions
                    .get_mut(&index)
                    .ok_or_else(ChatFailure::protocol)?;
                if value["item_id"].as_str() != Some(tracked.0.as_str()) {
                    return Err(ChatFailure::protocol());
                }
                if kind.ends_with(".delta") {
                    let delta = value["delta"].as_str().ok_or_else(ChatFailure::protocol)?;
                    if tracked.3.len() + delta.len() > 64000 {
                        return Err(ChatFailure::protocol());
                    }
                    tracked.3.push_str(delta);
                } else if value["arguments"].as_str() != Some(tracked.3.as_str()) {
                    return Err(ChatFailure::new(
                        ChatFailureKind::Interrupted,
                        "工具参数最终快照与增量不一致",
                    ));
                }
            }
            "response.content_part.added" | "response.content_part.done" => {
                if value.pointer("/part/type").and_then(Value::as_str) != Some("output_text") {
                    return Err(unsupported());
                }
            }
            "response.completed" | "response.incomplete" => {
                let response = value.get("response").ok_or_else(ChatFailure::protocol)?;
                let expected = if kind == "response.completed" {
                    "completed"
                } else {
                    "incomplete"
                };
                if response.get("status").and_then(Value::as_str) != Some(expected)
                    || response.get("error").is_some_and(|v| !v.is_null())
                {
                    return Err(ChatFailure::protocol());
                }
                let reason = if expected == "completed" {
                    "stop"
                } else if response
                    .pointer("/incomplete_details/reason")
                    .and_then(Value::as_str)
                    == Some("max_output_tokens")
                {
                    "length"
                } else {
                    return Err(unsupported());
                };
                let output = response
                    .get("output")
                    .and_then(Value::as_array)
                    .ok_or_else(ChatFailure::protocol)?;
                let mut remaining = self.parts.clone();
                for (index, item) in output.iter().enumerate() {
                    validate_item(item, tool_probe::native(probe).is_some())?;
                    if item["type"] == "function_call" {
                        let id = item["id"].as_str().unwrap();
                        let call_id = item["call_id"].as_str().unwrap();
                        let name = item["name"].as_str().unwrap();
                        let arguments = item["arguments"].as_str().unwrap();
                        if !self.document
                            && self.functions.remove(&(index as u64))
                                != Some((id.into(), call_id.into(), name.into(), arguments.into()))
                        {
                            return Err(ChatFailure::new(
                                ChatFailureKind::Interrupted,
                                "工具调用缺少对应的完整增量",
                            ));
                        }
                        let parsed =
                            serde_json::from_str(arguments).map_err(|_| ChatFailure::protocol())?;
                        tool_probe::native(probe)
                            .ok_or_else(unsupported)?
                            .capture(call_id, name, parsed)?;
                    }
                    if let Some(tool) = tool_probe::native(probe)
                        && !tool.second
                    {
                        tool.block(item.clone())?;
                    }
                    if item["type"] == "message" {
                        let id = item
                            .get("id")
                            .and_then(Value::as_str)
                            .ok_or_else(ChatFailure::protocol)?;
                        let content = item
                            .get("content")
                            .and_then(Value::as_array)
                            .ok_or_else(ChatFailure::protocol)?;
                        for (part, content) in content.iter().enumerate() {
                            let text = content
                                .get("text")
                                .and_then(Value::as_str)
                                .ok_or_else(ChatFailure::protocol)?;
                            let tracked = remaining.remove(&(index as u64, part as u64));
                            let mut expected_hash = DefaultHasher::new();
                            expected_hash.write(text.as_bytes());
                            if tracked
                                .as_ref()
                                .map_or(!text.is_empty(), |(old_id, bytes, hash)| {
                                    old_id != id
                                        || *bytes != text.len()
                                        || hash.finish() != expected_hash.finish()
                                })
                            {
                                return Err(ChatFailure::new(
                                    ChatFailureKind::Interrupted,
                                    "最终响应与已接收文本流不一致",
                                ));
                            }
                        }
                    }
                }
                if !remaining.is_empty() || !self.functions.is_empty() {
                    return Err(ChatFailure::protocol());
                }
                if let Some(usage) = response.get("usage").and_then(usage::parse) {
                    let _ = sender.send(usage).await;
                }
                return Ok(Some(reason.into()));
            }
            "response.failed" | "error" => {
                return Err(ChatFailure::new(
                    ChatFailureKind::Protocol,
                    "模型服务在流中返回错误",
                ));
            }
            // reasoning不混入助手正文；尚未实现思考投影与多轮不透明reasoning回传。
            "response.created"
            | "response.in_progress"
            | "response.output_text.done"
            | "response.reasoning_text.delta"
            | "response.reasoning_text.done"
            | "response.reasoning_summary_text.delta"
            | "response.reasoning_summary_text.done"
            | "response.reasoning_summary_part.added"
            | "response.reasoning_summary_part.done" => {}
            _ => return Err(unsupported()),
        }
        Ok(None)
    }
}
