//! Anthropic Messages文本协议。内容块按索引校验，只有message_stop证明完整结束。
use super::*;
use std::collections::HashMap;

pub(super) fn prepare(
    object: &mut serde_json::Map<String, Value>,
    input: &[ChatMessage],
    cache: bool,
) -> Result<(), ChatFailure> {
    if object.get("max_tokens").is_none() {
        object.insert("max_tokens".into(), json!(4096));
    }
    if object
        .get("max_tokens")
        .and_then(Value::as_u64)
        .is_none_or(|v| v == 0)
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "Messages max_tokens必须为正整数",
        ));
    }
    let system: Vec<_> = input
        .iter()
        .filter(|m| m.role == "system")
        .map(|m| json!({"type":"text","text":m.content}))
        .collect();
    let mut messages: Vec<_> = input
        .iter()
        .filter(|m| m.role != "system")
        .map(|m| json!({"role":m.role,"content":[{"type":"text","text":m.content}]}))
        .collect();
    if messages.is_empty() {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "Messages至少需要一条对话消息",
        ));
    }
    let mut system = system;
    {
        let control = if cache {
            json!({"type":"ephemeral","ttl":"1h"})
        } else {
            json!({"type":"ephemeral"})
        };
        if let Some(block) = system.last_mut().and_then(Value::as_object_mut) {
            block.insert("cache_control".into(), control.clone());
        }
        if let Some(block) = messages
            .last_mut()
            .and_then(|m| m.pointer_mut("/content/0"))
            .and_then(Value::as_object_mut)
        {
            block.insert("cache_control".into(), control);
        }
    }
    if !system.is_empty() {
        object.insert("system".into(), Value::Array(system));
    }
    object.insert("messages".into(), Value::Array(messages));
    Ok(())
}

pub(crate) fn thinking(
    object: &mut serde_json::Map<String, Value>,
    model: &str,
    enabled: bool,
    quality: u32,
    deepseek: bool,
) -> Result<(), CoreError> {
    let invalid = |message: &str| CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    };
    let level = quality.saturating_sub(1).min(4) as usize;
    if deepseek {
        object.insert(
            "thinking".into(),
            json!({"type":if enabled {"enabled"} else {"disabled"}}),
        );
        let mut output = match object.remove("output_config") {
            Some(Value::Object(v)) => v,
            None => serde_json::Map::new(),
            _ => return Err(invalid("output_config必须为对象")),
        };
        if enabled {
            output.insert(
                "effort".into(),
                json!(["low", "high", "max", "max", "max"][level]),
            );
        } else {
            output.remove("effort");
        }
        if !output.is_empty() {
            object.insert("output_config".into(), json!(output));
        }
        object.remove("budget_tokens");
        return Ok(());
    }
    // 旧normalizeClaudeModelName同时支持4-6、4.6和Sonnet4命名；日期不参与版本判断。
    let mut normalized = String::new();
    let mut previous: Option<char> = None;
    for c in model.trim().to_ascii_lowercase().chars() {
        if !c.is_ascii_alphanumeric() {
            if !normalized.ends_with('-') {
                normalized.push('-');
            }
            previous = None;
            continue;
        }
        if previous.is_some_and(|p| p.is_ascii_digit() != c.is_ascii_digit())
            && !normalized.ends_with('-')
        {
            normalized.push('-');
        }
        normalized.push(c);
        previous = Some(c);
    }
    let parts: Vec<_> = normalized.split('-').filter(|p| !p.is_empty()).collect();
    let at_least = |family: &str, major: u32, minor: u32| {
        let Some(index) = parts.iter().position(|p| *p == family) else {
            return false;
        };
        let number = |p: &&str| p.len() < 8 && p.bytes().all(|b| b.is_ascii_digit());
        let mut before: Vec<_> = parts[..index]
            .iter()
            .rev()
            .take_while(|p| number(p))
            .take(2)
            .copied()
            .collect();
        before.reverse();
        let after: Vec<_> = parts[index + 1..]
            .iter()
            .take_while(|p| number(p))
            .take(2)
            .copied()
            .collect();
        let numbers = if before.is_empty() { after } else { before };
        let version = numbers
            .first()
            .and_then(|v| v.parse::<u32>().ok())
            .map(|major| {
                (
                    major,
                    numbers
                        .get(1)
                        .and_then(|v| v.parse::<u32>().ok())
                        .unwrap_or(0),
                )
            });
        version.is_some_and(|v| v >= (major, minor))
    };
    let always = normalized.contains("mythos-preview")
        || at_least("fable", 5, 0)
        || at_least("mythos", 5, 0);
    let modern = always || at_least("opus", 4, 7) || at_least("sonnet", 5, 0);
    let adaptive = always || at_least("opus", 4, 6) || at_least("sonnet", 4, 6);
    if !enabled && always {
        return Err(invalid("当前Claude模型不支持关闭思考"));
    }
    if enabled || modern {
        object.remove("temperature");
        object.remove("top_k");
        if modern || object.get("top_p").and_then(Value::as_f64).unwrap_or(1.0) < 0.95 {
            object.remove("top_p");
        }
    }
    if enabled && adaptive {
        object.remove("budget_tokens");
        object.insert(
            "thinking".into(),
            json!({"type":"adaptive","display":"summarized"}),
        );
        let mut output = match object.remove("output_config") {
            Some(Value::Object(v)) => v,
            None => serde_json::Map::new(),
            _ => return Err(invalid("output_config必须为对象")),
        };
        output.entry("effort").or_insert_with(|| {
            json!(
                [
                    "low",
                    "medium",
                    "high",
                    if modern { "xhigh" } else { "max" },
                    "max"
                ][level]
            )
        });
        object.insert("output_config".into(), json!(output));
    } else if enabled {
        let max = object
            .get("max_tokens")
            .map(Value::as_u64)
            .unwrap_or(Some(4096))
            .ok_or_else(|| invalid("Messages max_tokens必须为正整数"))?;
        let budget = object
            .remove("budget_tokens")
            .map(|v| v.as_u64())
            .unwrap_or_else(|| {
                Some([1024, 4096, 8192, 16384, 32768][level].min(max.saturating_sub(1)))
            })
            .ok_or_else(|| invalid("Claude思考预算必须为整数"))?;
        if budget < 1024 || budget >= max {
            return Err(invalid("Claude思考预算至少1024且必须低于max_tokens"));
        }
        object.insert(
            "thinking".into(),
            json!({"type":"enabled","budget_tokens":budget}),
        );
    } else {
        object.remove("budget_tokens");
        if adaptive {
            object.insert("thinking".into(), json!({"type":"disabled"}));
            if at_least("opus", 5, 0)
                && object
                    .get("output_config")
                    .and_then(|v| v.get("effort"))
                    .and_then(Value::as_str)
                    .is_some_and(|e| matches!(e, "xhigh" | "max"))
            {
                return Err(invalid("Claude Opus 5的xhigh/max档位要求开启思考"));
            }
        }
    }
    Ok(())
}

#[derive(Default)]
pub(super) struct Decoder {
    started: bool,
    blocks: HashMap<u64, String>,
    next: u64,
    reason: Option<String>,
    usage: serde_json::Map<String, Value>,
}
impl Decoder {
    async fn text(
        text: &str,
        probe: &mut Option<probe::Probe>,
        sender: &EventSender,
    ) -> Result<(), ChatFailure> {
        if let Some(probe) = probe {
            probe.append(text)?;
        }
        if !text.is_empty() {
            let _ = sender.send(ChatEvent::Text(text.into())).await;
        }
        Ok(())
    }
    fn reason(reason: &str, tools: bool) -> Result<String, ChatFailure> {
        match reason {
            "end_turn" | "stop_sequence" => Ok("stop".into()),
            "max_tokens" => Ok("length".into()),
            "tool_use" if tools => Ok("tool".into()),
            "tool_use" => Err(ChatFailure::new(
                ChatFailureKind::Unsupported,
                "模型返回工具调用，当前文本入口尚未接入工具执行",
            )),
            "refusal" => Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "模型拒绝了本次请求",
            )),
            _ => Err(ChatFailure::new(
                ChatFailureKind::Interrupted,
                "Messages未完整结束",
            )),
        }
    }
    async fn usage(&mut self, value: &Value, sender: &EventSender) {
        if let Some(value) = value.as_object() {
            for (key, value) in value {
                self.usage.insert(key.clone(), value.clone());
            }
        }
        // Anthropic input_tokens排除缓存；归一化到共享统计的完整输入分母。
        let input = self.usage.get("input_tokens").and_then(Value::as_u64);
        let read_value = self.usage.get("cache_read_input_tokens");
        let write_value = self.usage.get("cache_creation_input_tokens");
        let read = read_value.map(Value::as_u64).unwrap_or(Some(0));
        let write = write_value.map(Value::as_u64).unwrap_or(Some(0));
        let Some((read, write)) = read.zip(write) else {
            return;
        };
        if let Some(total) = input
            .and_then(|i| i.checked_add(read))
            .and_then(|i| i.checked_add(write))
        {
            let normalized = json!({"input_tokens":total,"output_tokens":self.usage.get("output_tokens"),
                "input_tokens_details":{"cached_tokens":read_value.map(|_| read),"cache_write_tokens":write_value.map(|_| write)}});
            if let Some(event) = super::usage::parse(&normalized) {
                let _ = sender.send(event).await;
            }
        }
    }
    pub(super) async fn decode(
        &mut self,
        data: &str,
        probe: &mut Option<probe::Probe>,
        sender: &EventSender,
    ) -> Result<Option<String>, ChatFailure> {
        let value: Value = serde_json::from_str(data).map_err(|_| ChatFailure::protocol())?;
        let kind = value
            .get("type")
            .and_then(Value::as_str)
            .ok_or_else(ChatFailure::protocol)?;
        match kind {
            "ping" => {}
            "error" => {
                return Err(ChatFailure::new(
                    ChatFailureKind::Protocol,
                    "Messages服务报告请求失败",
                ));
            }
            "message_start" if !self.started => {
                self.started = true;
                self.usage(&value["message"]["usage"], sender).await;
            }
            "content_block_start" if self.started && self.reason.is_none() => {
                let index = value["index"].as_u64().ok_or_else(ChatFailure::protocol)?;
                if index != self.next || index >= 1024 {
                    return Err(ChatFailure::protocol());
                }
                self.next += 1;
                let block = &value["content_block"];
                let kind = block["type"].as_str().ok_or_else(ChatFailure::protocol)?;
                if let Some(tool) = tool_probe::native(probe) {
                    if !tool.second {
                        tool.block(block.clone())?;
                    }
                    if kind == "tool_use" {
                        tool.capture(
                            block["id"].as_str().ok_or_else(ChatFailure::protocol)?,
                            block["name"].as_str().ok_or_else(ChatFailure::protocol)?,
                            block["input"].clone(),
                        )?;
                        if block["input"] == json!({}) {
                            tool.calls
                                .last_mut()
                                .ok_or_else(ChatFailure::protocol)?
                                .arguments
                                .clear();
                        }
                    }
                }
                if !matches!(kind, "text" | "thinking" | "redacted_thinking")
                    && !(kind == "tool_use" && tool_probe::native(probe).is_some())
                {
                    return Err(ChatFailure::new(
                        ChatFailureKind::Unsupported,
                        "Messages返回了尚未接入的内容类型",
                    ));
                }
                self.blocks.insert(index, kind.into());
                if kind == "text" {
                    Self::text(
                        block["text"].as_str().ok_or_else(ChatFailure::protocol)?,
                        probe,
                        sender,
                    )
                    .await?;
                }
            }
            "content_block_delta" if self.started && self.reason.is_none() => {
                let index = value["index"].as_u64().ok_or_else(ChatFailure::protocol)?;
                let block = self.blocks.get(&index).ok_or_else(ChatFailure::protocol)?;
                let delta = &value["delta"];
                match delta["type"].as_str() {
                    Some("text_delta") if block == "text" => {
                        if let Some(tool) = tool_probe::native(probe) {
                            tool.append_block(
                                index as usize,
                                "text",
                                delta["text"].as_str().ok_or_else(ChatFailure::protocol)?,
                            )?;
                        }
                        Self::text(
                            delta["text"].as_str().ok_or_else(ChatFailure::protocol)?,
                            probe,
                            sender,
                        )
                        .await?
                    }
                    Some("thinking_delta" | "signature_delta") if block == "thinking" => {
                        let field = if delta["type"] == "thinking_delta" {
                            "thinking"
                        } else {
                            "signature"
                        };
                        if let Some(tool) = tool_probe::native(probe) {
                            tool.append_block(
                                index as usize,
                                field,
                                delta[field].as_str().ok_or_else(ChatFailure::protocol)?,
                            )?;
                        }
                    }
                    Some("input_json_delta") if block == "tool_use" => {
                        let partial = delta["partial_json"]
                            .as_str()
                            .ok_or_else(ChatFailure::protocol)?;
                        let call = tool_probe::native(probe)
                            .and_then(|t| t.calls.last_mut())
                            .ok_or_else(ChatFailure::protocol)?;
                        if call.arguments.len() + partial.len() > 64000 {
                            return Err(ChatFailure::protocol());
                        }
                        call.arguments.push_str(partial);
                    }
                    _ => return Err(ChatFailure::protocol()),
                }
            }
            "content_block_stop" if self.started && self.reason.is_none() => {
                let index = value["index"].as_u64().ok_or_else(ChatFailure::protocol)?;
                if self.blocks.remove(&index).is_none() {
                    return Err(ChatFailure::protocol());
                }
            }
            "message_delta" if self.started && self.blocks.is_empty() && self.reason.is_none() => {
                let reason = value["delta"]["stop_reason"]
                    .as_str()
                    .ok_or_else(ChatFailure::protocol)?;
                self.reason = Some(Self::reason(reason, tool_probe::native(probe).is_some())?);
                self.usage(&value["usage"], sender).await;
            }
            "message_stop" if self.started && self.blocks.is_empty() => {
                return self
                    .reason
                    .take()
                    .map(Some)
                    .ok_or_else(ChatFailure::protocol);
            }
            _ => return Err(ChatFailure::protocol()),
        }
        Ok(None)
    }
    pub(super) async fn document(
        value: Value,
        probe: &mut Option<probe::Probe>,
        sender: &EventSender,
    ) -> Result<String, ChatFailure> {
        if value["type"] != "message" || value["role"] != "assistant" {
            return Err(ChatFailure::protocol());
        }
        let reason = Self::reason(
            value["stop_reason"]
                .as_str()
                .ok_or_else(ChatFailure::protocol)?,
            tool_probe::native(probe).is_some(),
        )?;
        let blocks = value["content"]
            .as_array()
            .ok_or_else(ChatFailure::protocol)?;
        for block in blocks {
            if let Some(tool) = tool_probe::native(probe)
                && !tool.second
            {
                tool.block(block.clone())?;
            }
            match block["type"].as_str() {
                Some("text") => {
                    Self::text(
                        block["text"].as_str().ok_or_else(ChatFailure::protocol)?,
                        probe,
                        sender,
                    )
                    .await?
                }
                Some("thinking" | "redacted_thinking") => {}
                Some("tool_use") if tool_probe::native(probe).is_some() => {
                    tool_probe::native(probe)
                        .ok_or_else(ChatFailure::protocol)?
                        .capture(
                            block["id"].as_str().ok_or_else(ChatFailure::protocol)?,
                            block["name"].as_str().ok_or_else(ChatFailure::protocol)?,
                            block["input"].clone(),
                        )?;
                }
                _ => {
                    return Err(ChatFailure::new(
                        ChatFailureKind::Unsupported,
                        "Messages返回了尚未接入的内容类型",
                    ));
                }
            }
        }
        Self::default().usage(&value["usage"], sender).await;
        Ok(reason)
    }
}
