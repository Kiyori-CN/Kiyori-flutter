//! Gemini原生协议；认证仅放请求头，完整finishReason与HTTP流结束共同证明终态。
use super::*;

pub(super) fn url(endpoint_value: &str, model: &str, stream: bool) -> Result<Url, ChatFailure> {
    let mut url = endpoint(endpoint_value, "native")?;
    let model = model.strip_prefix("models/").unwrap_or(model);
    if model.is_empty()
        || !model
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "Gemini模型标识无效",
        ));
    }
    let path = url
        .path()
        .trim_end_matches('/')
        .split("/models/")
        .next()
        .unwrap_or("");
    let path = path.strip_suffix("/models").unwrap_or(path);
    let base = if ["/v1", "/v1beta", "/v1alpha"]
        .iter()
        .any(|v| path.ends_with(v))
    {
        path.to_owned()
    } else {
        format!("{path}/v1beta")
    };
    url.set_path(&base);
    url.path_segments_mut()
        .map_err(|_| ChatFailure::protocol())?
        .push("models")
        .push(&format!(
            "{model}:{}",
            if stream {
                "streamGenerateContent"
            } else {
                "generateContent"
            }
        ));
    if stream {
        url.query_pairs_mut().append_pair("alt", "sse");
    }
    Ok(url)
}

pub(super) fn prepare(
    object: &mut serde_json::Map<String, Value>,
    input: &[ChatMessage],
    search: bool,
) -> Result<(), ChatFailure> {
    object.remove("model");
    let mut config = serde_json::Map::new();
    for (name, value) in std::mem::take(object) {
        let target = match name.as_str() {
            "top_p" => "topP",
            "top_k" => "topK",
            "max_tokens" => "maxOutputTokens",
            _ => &name,
        };
        if config.insert(target.to_owned(), value).is_some() {
            return Err(ChatFailure::new(
                ChatFailureKind::InvalidInput,
                "Gemini参数映射后重复",
            ));
        }
    }
    if config
        .get("candidateCount")
        .is_some_and(|v| v.as_u64() != Some(1))
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "当前请求入口只接受一个Gemini候选",
        ));
    }
    let systems: Vec<_> = input
        .iter()
        .filter(|m| m.role == "system")
        .map(|m| json!({"text":m.content}))
        .collect();
    if !systems.is_empty() {
        object.insert("systemInstruction".into(), json!({"parts":systems}));
    }
    let contents: Vec<_> = input.iter().filter(|m| m.role != "system").map(|m| {
        json!({"role":if m.role == "assistant" {"model"} else {"user"},"parts":[{"text":m.content}]})
    }).collect();
    if contents.is_empty() {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "Gemini至少需要一条对话消息",
        ));
    }
    object.insert("contents".into(), json!(contents));
    object.insert("generationConfig".into(), json!(config));
    if search {
        object.insert("tools".into(), json!([{"googleSearch":{}}]));
    }
    Ok(())
}

pub(crate) fn thinking(
    config: &mut serde_json::Map<String, Value>,
    model: &str,
    enabled: bool,
    quality: u32,
) -> Result<(), CoreError> {
    let invalid = |message: &str| CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    };
    let name = model.trim().to_ascii_lowercase();
    let name = name.strip_prefix("models/").unwrap_or(&name);
    let is25 = ["gemini-2.5-pro", "gemini-2.5-flash"]
        .iter()
        .any(|p| name == *p || name.starts_with(&format!("{p}-")));
    let is3 = [
        "gemini-3-",
        "gemini-3.1-",
        "gemini-3.5-",
        "gemini-3.6-",
        "gemini-3.7-",
        "gemini-3.8-",
    ]
    .iter()
    .any(|p| {
        name.starts_with(p) && name[p.len()..].starts_with("pro")
            || name.starts_with(p) && name[p.len()..].starts_with("flash")
    });
    let custom = config.remove("thinkingConfig");
    let mut thinking = match custom {
        Some(Value::Object(v)) => v,
        Some(_) => return Err(invalid("Gemini thinkingConfig必须为对象")),
        None => serde_json::Map::new(),
    };
    if !is25 && !is3 {
        if !thinking.is_empty() {
            config.insert("thinkingConfig".into(), json!(thinking));
        }
        return Ok(());
    }
    if !enabled && !(is25 && name.contains("flash")) {
        return Err(invalid(
            "当前Gemini模型不支持关闭思考，请开启思考或更换模型",
        ));
    }
    if thinking.contains_key("thinkingLevel") && thinking.contains_key("thinkingBudget") {
        return Err(invalid("Gemini thinkingLevel与thinkingBudget不能同时设置"));
    }
    let level = quality.saturating_sub(1).min(4) as usize;
    if !enabled {
        if thinking.contains_key("thinkingLevel")
            || thinking
                .get("thinkingBudget")
                .is_some_and(|v| v.as_i64() != Some(0))
        {
            return Err(invalid("Gemini显式思考参数与关闭思考冲突"));
        }
        thinking.insert("thinkingBudget".into(), json!(0));
    } else if is25 {
        if thinking.contains_key("thinkingLevel") {
            return Err(invalid("Gemini 2.5使用thinkingBudget"));
        }
        let maximum = if name.contains("pro") { 32768 } else { 24576 };
        let minimum = if name.contains("flash-lite") {
            512
        } else if name.contains("pro") {
            128
        } else {
            1
        };
        let budget = thinking
            .entry("thinkingBudget")
            .or_insert_with(|| json!([1024, 4096, 8192, 16384, maximum][level]))
            .as_i64()
            .ok_or_else(|| invalid("Gemini思考预算必须为整数"))?;
        if budget != -1 && !(minimum..=maximum).contains(&budget) {
            return Err(invalid("Gemini思考预算超出模型范围"));
        }
    } else {
        let levels = if name.starts_with("gemini-3.1-flash-lite-image") {
            ["minimal", "minimal", "high", "high", "high"]
        } else if name.starts_with("gemini-3-pro") {
            ["low", "low", "high", "high", "high"]
        } else {
            ["low", "medium", "high", "high", "high"]
        };
        if !thinking.contains_key("thinkingBudget") && !thinking.contains_key("thinkingLevel") {
            thinking.insert("thinkingLevel".into(), json!(levels[level]));
        }
        if let Some(value) = thinking.get("thinkingLevel") {
            let value = value
                .as_str()
                .ok_or_else(|| invalid("Gemini思考档位必须为文本"))?
                .to_ascii_lowercase();
            let minimal = name.contains("flash-lite")
                || ["gemini-3-flash", "gemini-3.5-flash", "gemini-3.6-flash"]
                    .iter()
                    .any(|p| name.starts_with(p));
            if !levels.contains(&value.as_str()) && !(minimal && value == "minimal") {
                return Err(invalid("Gemini思考档位不适用于当前模型"));
            }
        }
        if thinking
            .get("thinkingBudget")
            .is_some_and(|v| v.as_i64().is_none_or(|v| v != -1 && v <= 0))
        {
            return Err(invalid("Gemini 3不能用零预算关闭思考"));
        }
    }
    thinking.insert("includeThoughts".into(), json!(enabled));
    config.insert("thinkingConfig".into(), json!(thinking));
    Ok(())
}

#[derive(Default)]
pub(super) struct Decoder {
    pub reason: Option<String>,
}
impl Decoder {
    pub async fn decode(
        &mut self,
        data: &str,
        probe: &mut Option<probe::Probe>,
        sender: &EventSender,
    ) -> Result<(), ChatFailure> {
        let value: Value = serde_json::from_str(data).map_err(|_| ChatFailure::protocol())?;
        if value.get("error").is_some() || value.pointer("/promptFeedback/blockReason").is_some() {
            return Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "Gemini服务拒绝或未能完成请求",
            ));
        }
        let candidates = match value.get("candidates") {
            Some(v) => Some(v.as_array().ok_or_else(ChatFailure::protocol)?),
            None => None,
        }
        .filter(|v| !v.is_empty());
        if let Some(candidates) = candidates {
            if candidates.len() != 1 || self.reason.is_some() {
                return Err(ChatFailure::protocol());
            }
            let candidate = &candidates[0];
            if candidate
                .get("index")
                .is_some_and(|v| v.as_u64() != Some(0))
            {
                return Err(ChatFailure::protocol());
            }
            if let Some(parts) = candidate.pointer("/content/parts") {
                for part in parts.as_array().ok_or_else(ChatFailure::protocol)? {
                    if let Some(tool) = tool_probe::native(probe)
                        && !tool.second
                    {
                        tool.block(part.clone())?;
                    }
                    if let Some(call) = part.get("functionCall") {
                        let Some(tool) = tool_probe::native(probe) else {
                            return Err(ChatFailure::new(
                                ChatFailureKind::Unsupported,
                                "当前入口不接受Gemini工具输出",
                            ));
                        };
                        tool.capture(
                            call.get("id").and_then(Value::as_str).unwrap_or(""),
                            call.get("name")
                                .and_then(Value::as_str)
                                .ok_or_else(ChatFailure::protocol)?,
                            call.get("args").ok_or_else(ChatFailure::protocol)?.clone(),
                        )?;
                        continue;
                    }
                    if part.get("inlineData").is_some() || part.get("fileData").is_some() {
                        return Err(ChatFailure::new(
                            ChatFailureKind::Unsupported,
                            "当前文本入口不接受Gemini工具或媒体输出",
                        ));
                    }
                    if part.get("thought").and_then(Value::as_bool) == Some(true) {
                        continue;
                    }
                    if let Some(text) = part.get("text") {
                        let text = text.as_str().ok_or_else(ChatFailure::protocol)?;
                        if let Some(probe) = probe {
                            probe.append(text)?;
                        }
                        if !text.is_empty() {
                            let _ = sender.send(ChatEvent::Text(text.into())).await;
                        }
                    }
                }
            }
            if let Some(reason) = candidate.get("finishReason") {
                self.reason = Some(match reason.as_str() {
                    Some("STOP") => "stop".into(),
                    Some("MAX_TOKENS") => "length".into(),
                    _ => {
                        return Err(ChatFailure::new(
                            ChatFailureKind::Interrupted,
                            "Gemini以过滤、错误或未知原因结束",
                        ));
                    }
                });
            }
        } else if value.get("usageMetadata").is_none() {
            return Err(ChatFailure::protocol());
        }
        if let Some(usage) = value.get("usageMetadata") {
            let count = |key: &str| usage.get(key).filter(|v| !v.is_null());
            let output = count("candidatesTokenCount");
            let thinking = count("thoughtsTokenCount");
            let total = output
                .map(Value::as_u64)
                .unwrap_or(Some(0))
                .zip(thinking.map(Value::as_u64).unwrap_or(Some(0)))
                .and_then(|(a, b)| a.checked_add(b));
            if let Some(total) = total {
                let normalized = json!({"input_tokens":count("promptTokenCount"),"output_tokens":if output.is_some() || thinking.is_some() {Some(total)} else {None},"cached_tokens":count("cachedContentTokenCount"),"output_tokens_details":{"reasoning_tokens":thinking}});
                if let Some(event) = super::usage::parse(&normalized) {
                    let _ = sender.send(event).await;
                }
            }
        }
        Ok(())
    }
}
