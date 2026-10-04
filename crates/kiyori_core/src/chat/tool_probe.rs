//! 无外部副作用的两步echo能力探测；只在精确schema匹配后生成不可预知的本地结果。
use super::*;

// 旧提取器接受格式化XML和解释文字；只验证这一无副作用schema，不扩展成任意工具执行器。
fn xml_call(text: &str) -> bool {
    fn name(tag: &str, element: &str, expected: &str) -> bool {
        let Some(rest) = tag.strip_prefix(element).and_then(|v| v.strip_suffix('>')) else {
            return false;
        };
        if !rest.starts_with(char::is_whitespace) {
            return false;
        }
        let Some(rest) = rest.trim().strip_prefix("name") else {
            return false;
        };
        let Some(rest) = rest.trim_start().strip_prefix('=') else {
            return false;
        };
        let value = rest.trim();
        value == format!("\"{expected}\"") || value == format!("'{expected}'")
    }
    if text.matches("<tool").count() != 1 || text.matches("</tool>").count() != 1 {
        return false;
    }
    let Some(start) = text.find("<tool") else {
        return false;
    };
    let Some((tag, body)) = text[start..].split_once('>') else {
        return false;
    };
    if !name(&format!("{tag}>"), "<tool", "echo") {
        return false;
    }
    let Some((body, _)) = body.split_once("</tool>") else {
        return false;
    };
    let body = body.trim();
    let Some((tag, value)) = body.split_once('>') else {
        return false;
    };
    if !name(&format!("{tag}>"), "<param", "text") {
        return false;
    }
    value
        .strip_suffix("</param>")
        .is_some_and(|value| value.trim() == "ping")
}

pub(super) struct ToolProbe {
    pub native: bool,
    pub second: bool,
    pub replay: Vec<Value>,
    pub calls: Vec<Call>,
    pub first_text: String,
    reasoning: String,
    pub code: String,
    bytes: usize,
}
#[derive(Default)]
pub(super) struct Call {
    pub id: String,
    pub name: String,
    pub arguments: String,
}
impl ToolProbe {
    pub fn new(native: bool) -> Self {
        Self {
            native,
            second: false,
            replay: Vec::new(),
            calls: Vec::new(),
            first_text: String::new(),
            reasoning: String::new(),
            code: String::new(),
            bytes: 0,
        }
    }
    pub fn chat_reasoning(&mut self, text: &str) -> Result<(), ChatFailure> {
        if self.second {
            return Ok(());
        }
        if self.bytes + text.len() > 256_000 {
            return Err(ChatFailure::protocol());
        }
        self.bytes += text.len();
        self.reasoning.push_str(text);
        Ok(())
    }
    pub fn capture(&mut self, id: &str, name: &str, arguments: Value) -> Result<(), ChatFailure> {
        if self.second
            || self.calls.len() >= 16
            || id.len() > 512
            || name.len() > 512
            || arguments.to_string().len() > 64000
        {
            return Err(ChatFailure::protocol());
        }
        self.calls.push(Call {
            id: id.into(),
            name: name.into(),
            arguments: arguments.to_string(),
        });
        Ok(())
    }
    pub fn block(&mut self, value: Value) -> Result<(), ChatFailure> {
        let bytes = value.to_string().len();
        if self.replay.len() >= 1024 || self.bytes + bytes > 256_000 {
            return Err(ChatFailure::protocol());
        }
        self.bytes += bytes;
        self.replay.push(value);
        Ok(())
    }
    pub fn append_block(
        &mut self,
        index: usize,
        field: &str,
        text: &str,
    ) -> Result<(), ChatFailure> {
        if self.second {
            return Ok(());
        }
        let block = self
            .replay
            .get_mut(index)
            .and_then(Value::as_object_mut)
            .ok_or_else(ChatFailure::protocol)?;
        let value = block.entry(field).or_insert_with(|| json!(""));
        let mut current = value.as_str().ok_or_else(ChatFailure::protocol)?.to_owned();
        if current.len() + text.len() > 64000 || self.bytes + text.len() > 256_000 {
            return Err(ChatFailure::protocol());
        }
        current.push_str(text);
        self.bytes += text.len();
        *value = json!(current);
        Ok(())
    }
    pub fn chat_delta(&mut self, value: &Value) -> Result<(), ChatFailure> {
        if self.second {
            return Err(ChatFailure::protocol());
        }
        for delta in value.as_array().ok_or_else(ChatFailure::protocol)? {
            let index = delta.get("index").and_then(Value::as_u64).unwrap_or(0) as usize;
            if index >= 16 || index > self.calls.len() {
                return Err(ChatFailure::protocol());
            }
            if index == self.calls.len() {
                self.calls.push(Call::default());
            }
            let call = &mut self.calls[index];
            for (field, target) in [
                (delta.get("id"), &mut call.id),
                (delta.pointer("/function/name"), &mut call.name),
                (delta.pointer("/function/arguments"), &mut call.arguments),
            ] {
                if let Some(value) = field {
                    target.push_str(value.as_str().ok_or_else(ChatFailure::protocol)?);
                }
                if target.len() > 64000 {
                    return Err(ChatFailure::protocol());
                }
            }
        }
        Ok(())
    }
    pub fn advance(
        &mut self,
        protocol: &str,
        text: &str,
        reason: &str,
    ) -> Result<bool, ChatFailure> {
        if self.second {
            return Ok(false);
        }
        if self.native {
            if self.calls.len() != 1
                || (matches!(protocol, "chat" | "messages") && reason != "tool")
            {
                return Ok(false);
            }
            let call = &self.calls[0];
            if call.name != "echo"
                || call.id.len() > 512
                || call.name.len() > 512
                || (protocol != "native"
                    && (call.id.trim().is_empty() || call.id.chars().any(char::is_control)))
                || serde_json::from_str::<Value>(&call.arguments).ok()
                    != Some(json!({"text":"ping"}))
            {
                return Ok(false);
            }
        } else {
            // 严格接受一个schema一致的XML调用，不把普通文字、多个调用或未知工具当作执行。
            if !xml_call(text) || reason != "stop" {
                return Ok(false);
            }
        }
        let mut bytes = [0u8; 16];
        rustls::crypto::ring::default_provider()
            .secure_random
            .fill(&mut bytes)
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "无法生成工具验证结果"))?;
        self.code = format!(
            "probe_{}",
            bytes.iter().map(|b| format!("{b:02x}")).collect::<String>()
        );
        self.first_text = text.into();
        self.second = true;
        Ok(true)
    }
    pub fn apply(
        &self,
        protocol: &str,
        object: &mut serde_json::Map<String, Value>,
    ) -> Result<(), ChatFailure> {
        let schema = json!({"type":"object","properties":{"text":{"type":"string","description":"Text to verify."}},"required":["text"],"additionalProperties":false});
        if self.native {
            let tool = match protocol {
                "chat" => {
                    json!({"type":"function","function":{"name":"echo","description":"Returns a verification code for the supplied text.","parameters":schema}})
                }
                "responses" => {
                    json!({"type":"function","name":"echo","description":"Returns a verification code for the supplied text.","parameters":schema})
                }
                "messages" => {
                    json!({"name":"echo","description":"Returns a verification code for the supplied text.","input_schema":schema})
                }
                "native" => {
                    json!({"functionDeclarations":[{"name":"echo","description":"Returns a verification code for the supplied text.","parameters":schema}]})
                }
                _ => return Err(ChatFailure::protocol()),
            };
            let tools = object
                .entry("tools")
                .or_insert_with(|| json!([]))
                .as_array_mut()
                .ok_or_else(ChatFailure::protocol)?;
            tools.push(tool);
        }
        if !self.second {
            return Ok(());
        }
        let field = match protocol {
            "responses" => "input",
            "native" => "contents",
            _ => "messages",
        };
        let messages = object
            .get_mut(field)
            .and_then(Value::as_array_mut)
            .ok_or_else(ChatFailure::protocol)?;
        if !self.native {
            let result = format!(
                "<tool_result name=\"echo\" status=\"success\">{}</tool_result>",
                self.code
            );
            match protocol {
                "native" => messages.extend([
                    json!({"role":"model","parts":[{"text":self.first_text}]}),
                    json!({"role":"user","parts":[{"text":result}]}),
                ]),
                "messages" => messages.extend([
                    json!({"role":"assistant","content":[{"type":"text","text":self.first_text}]}),
                    json!({"role":"user","content":[{"type":"text","text":result}]}),
                ]),
                _ => messages.extend([
                    json!({"role":"assistant","content":self.first_text}),
                    json!({"role":"user","content":result}),
                ]),
            }
        } else {
            let call = &self.calls[0];
            let args: Value =
                serde_json::from_str(&call.arguments).map_err(|_| ChatFailure::protocol())?;
            match protocol {
                "chat"=>{
                    let mut assistant=json!({"role":"assistant","content":self.first_text,"tool_calls":[{"id":call.id,"type":"function","function":{"name":call.name,"arguments":call.arguments}}]});
                    // 思考只用于本次供应商工具续答，不能投影到正文或落入会话/日志。
                    if !self.reasoning.is_empty() { assistant["reasoning_content"]=json!(self.reasoning); }
                    messages.extend([assistant,json!({"role":"tool","tool_call_id":call.id,"content":self.code})]);
                },
                "responses"=>{messages.extend(self.replay.clone()); messages.push(json!({"type":"function_call_output","call_id":call.id,"output":self.code}));},
                "messages"=>{
                    let mut replay=self.replay.clone();
                    for block in &mut replay {if block["type"]=="tool_use" {block["input"]=args.clone();}}
                    messages.extend([json!({"role":"assistant","content":replay}),json!({"role":"user","content":[{"type":"tool_result","tool_use_id":call.id,"content":self.code}]})]);
                },
                "native"=>messages.extend([json!({"role":"model","parts":self.replay}),json!({"role":"user","parts":[{"functionResponse":{"name":call.name,"response":{"result":self.code}}}]})]),
                _=>return Err(ChatFailure::protocol()),
            }
        }
        Ok(())
    }
}

pub(super) fn native(probe: &mut Option<probe::Probe>) -> Option<&mut ToolProbe> {
    probe
        .as_mut()
        .and_then(|p| p.tool.as_mut())
        .filter(|p| p.native)
}
