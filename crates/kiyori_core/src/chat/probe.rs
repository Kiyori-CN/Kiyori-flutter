use super::*;
use crate::models::ModelConfigDraft;

pub struct Probe {
    expected: Option<String>,
    text: String,
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
        reason == "stop"
            && match &self.expected {
                Some(expected) => self.text.trim() == expected,
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
    let invalid = || CoreError {
        code: ErrorCode::InvalidInput,
        message: "模型探测参数无效".into(),
    };
    let model = draft.models.first().ok_or_else(invalid)?.clone();
    let expected = match kind {
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
        _ => return Err(invalid()),
    };
    let messages = match &expected {
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
        protocol: draft.protocol,
        endpoint: draft.endpoint,
        model,
        api_key,
        headers,
        messages,
        parameters: Value::Object(parameters).to_string(),
        timeout_ms: 90_000,
        probe: Some(Probe {
            expected,
            text: String::new(),
            units: 0,
        }),
    })
}
