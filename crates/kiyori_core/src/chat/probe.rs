use super::*;
use crate::models::ModelConfigDraft;

pub struct Probe {
    pub(super) tool: Option<tool_probe::ToolProbe>,
    pub(super) media: Option<media::Input>,
    pub(super) expected: Option<String>,
    pub(super) text: String,
    units: usize,
}
impl Probe {
    pub(super) fn append(&mut self, text: &str) -> Result<(), ChatFailure> {
        self.units += text.encode_utf16().count();
        if self.units > 64_000 {
            return Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "测试响应超过64000字符限制",
            ));
        }
        self.text.push_str(text);
        Ok(())
    }
    pub(super) fn verified(&self, reason: &str) -> bool {
        if self.tool.as_ref().is_some_and(|p| !p.second) {
            return false;
        }
        reason == "stop"
            && match &self.expected {
                Some(expected) => self
                    .media
                    .as_ref()
                    .map(|m| m.matches(&self.text, expected))
                    .unwrap_or_else(|| self.text.trim() == expected),
                None => !self.text.trim().is_empty(),
            }
    }
}

pub fn prepare(
    mut draft: ModelConfigDraft,
    api_key: String,
    headers: Vec<(String, String)>,
    kind: &str,
) -> Result<ChatRequest, CoreError> {
    crate::models::validate(&mut draft)?;
    if draft.protocol == "native" && draft.provider != "GOOGLE" {
        return Err(CoreError {
            code: ErrorCode::InvalidInput,
            message: "本地或扩展提供方的原生适配尚未接入".into(),
        });
    }
    let invalid = || CoreError {
        code: ErrorCode::InvalidInput,
        message: "模型探测参数无效".into(),
    };
    let model = draft.models.first().ok_or_else(invalid)?.clone();
    let mut media = None;
    let tool = match kind {
        "tool" => Some(tool_probe::ToolProbe::new(true)),
        "xml_tool" => Some(tool_probe::ToolProbe::new(false)),
        _ => None,
    };
    let mut media_prompt = String::new();
    let expected = match kind {
        "tool" | "xml_tool" => None,
        "chat" => None,
        "system" => {
            let mut bytes = [0; 16];
            rustls::crypto::ring::default_provider()
                .secure_random
                .fill(&mut bytes)
                .map_err(|_| invalid())?;
            Some(format!(
                "instruction_{}",
                bytes.iter().map(|b| format!("{b:02x}")).collect::<String>()
            ))
        }
        "image" | "audio" | "video" => {
            let (input, code, prompt) = media::Input::prepare(&draft, kind)?;
            media = Some(input);
            media_prompt = prompt;
            Some(code)
        }
        _ => return Err(invalid()),
    };
    let messages = if tool.is_some() {
        vec![
            ChatMessage {
                role: "system".into(),
                content: format!(
                    "Call echo exactly once with text ping. After receiving the tool result, reply only with its verification code. Do not call any other tool.{}",
                    if kind == "xml_tool" {
                        " Use this XML tool syntax: <tool name=\"echo\"><param name=\"text\">ping</param></tool>."
                    } else {
                        ""
                    }
                ),
            },
            ChatMessage {
                role: "user".into(),
                content: "Please run the verification now.".into(),
            },
        ]
    } else if media.is_some() {
        vec![ChatMessage {
            role: "user".into(),
            content: media_prompt,
        }]
    } else {
        match &expected {
            Some(code) => vec![
                ChatMessage {
                    role: "system".into(),
                    content: format!("Reply with exactly {code} and nothing else."),
                },
                ChatMessage {
                    role: "user".into(),
                    content: "Follow the response-format instruction.".into(),
                },
            ],
            None => vec![ChatMessage {
                role: "user".into(),
                content: "Hi".into(),
            }],
        }
    };
    let mut parameters = serde_json::Map::new();
    for parameter in draft.options.parameters.iter().filter(|p| p.enabled) {
        parameters.insert(
            parameter.name.clone(),
            if parameter.value_type == "text" {
                Value::String(parameter.value.clone())
            } else {
                serde_json::from_str(&parameter.value).map_err(|_| invalid())?
            },
        );
    }
    Ok(ChatRequest {
        provider: draft.provider,
        continuation_credentials: None,
        google_search: draft.options.google_search,
        claude_cache: draft.options.claude_cache,
        admission: None,
        stream: true,
        protocol: draft.protocol,
        endpoint: draft.endpoint,
        model,
        api_key,
        headers,
        messages,
        parameters: Value::Object(parameters).to_string(),
        timeout_ms: 90_000,
        probe: Some(Probe {
            tool,
            media,
            expected,
            text: String::new(),
            units: 0,
        }),
    })
}
