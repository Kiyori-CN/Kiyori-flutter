//! 内置能力探测只上传这三份固定素材；不打开用户路径或扩大附件授权。
use super::*;
use base64::{Engine, engine::general_purpose::STANDARD};

pub(super) struct Input {
    kind: String,
    mime: &'static str,
    bytes: &'static [u8],
}
impl Input {
    pub fn prepare(
        draft: &crate::models::ModelConfigDraft,
        kind: &str,
    ) -> Result<(Self, String, String), CoreError> {
        let unsupported = || CoreError {
            code: ErrorCode::InvalidInput,
            message: "当前媒体开关或API协议不支持此直接输入；未发送素材".into(),
        };
        let official = endpoint(&draft.endpoint, &draft.protocol)
            .ok()
            .is_some_and(|u| {
                u.scheme() == "https"
                    && u.host_str() == Some("api.openai.com")
                    && u.port_or_known_default() == Some(443)
            });
        let (mime, bytes, code, prompt) = match kind {
            "image" if draft.options.image => (
                "image/jpeg",
                include_bytes!("../../assets/model-probe/image.jpg").as_slice(),
                "7K2Q",
                "A short code is shown in this image. Reply with only that code. Do not describe the image.",
            ),
            "audio"
                if draft.options.audio
                    && draft.protocol != "messages"
                    && !(draft.protocol == "responses" && official) =>
            {
                (
                    "audio/mpeg",
                    include_bytes!("../../assets/model-probe/audio.mp3").as_slice(),
                    "375",
                    "This audio says three digits in English, one after another. Reply with only those three digits and nothing else.",
                )
            }
            "video"
                if draft.options.video
                    && !matches!(draft.protocol.as_str(), "messages" | "responses")
                    && !official =>
            {
                (
                    "video/mp4",
                    include_bytes!("../../assets/model-probe/video.mp4").as_slice(),
                    "M4XP",
                    "A short code is shown on screen throughout this video. Reply with only that code. Do not describe the video.",
                )
            }
            _ => return Err(unsupported()),
        };
        Ok((
            Self {
                kind: kind.into(),
                mime,
                bytes,
            },
            code.into(),
            prompt.into(),
        ))
    }
    pub fn apply(
        &self,
        protocol: &str,
        object: &mut serde_json::Map<String, Value>,
    ) -> Result<(), ChatFailure> {
        let data = STANDARD.encode(self.bytes);
        let uri = format!("data:{};base64,{data}", self.mime);
        match protocol {
            "native" => {
                let parts = object
                    .get_mut("contents")
                    .and_then(|v| v.pointer_mut("/0/parts"))
                    .and_then(Value::as_array_mut)
                    .ok_or_else(ChatFailure::protocol)?;
                parts.insert(0, json!({"inlineData":{"mimeType":self.mime,"data":data}}));
            }
            "messages" => {
                let parts = object
                    .get_mut("messages")
                    .and_then(|v| v.pointer_mut("/0/content"))
                    .and_then(Value::as_array_mut)
                    .ok_or_else(ChatFailure::protocol)?;
                parts.insert(0,json!({"type":"image","source":{"type":"base64","media_type":self.mime,"data":data}}));
            }
            "chat" | "responses" => {
                let field = if protocol == "responses" {
                    "input"
                } else {
                    "messages"
                };
                let message = object
                    .get_mut(field)
                    .and_then(|v| v.pointer_mut("/0"))
                    .and_then(Value::as_object_mut)
                    .ok_or_else(ChatFailure::protocol)?;
                let text = message
                    .remove("content")
                    .ok_or_else(ChatFailure::protocol)?;
                let part = match (protocol, self.kind.as_str()) {
                    ("responses", "image") => json!({"type":"input_image","image_url":uri}),
                    (_, "image") => json!({"type":"image_url","image_url":{"url":uri}}),
                    (_, "audio") => {
                        json!({"type":"input_audio","input_audio":{"data":data,"format":"mp3"}})
                    }
                    (_, "video") => json!({"type":"video_url","video_url":{"url":uri}}),
                    _ => return Err(ChatFailure::protocol()),
                };
                message.insert("content".into(),json!([part,{"type":if protocol=="responses" {"input_text"} else {"text"},"text":text}]));
            }
            _ => return Err(ChatFailure::protocol()),
        }
        Ok(())
    }
    pub fn matches(&self, text: &str, expected: &str) -> bool {
        let normalized: String = text
            .chars()
            .filter(|c| c.is_alphanumeric())
            .flat_map(char::to_uppercase)
            .collect();
        if normalized == expected {
            return true;
        }
        if self.kind != "audio" {
            return false;
        }
        let mut digits = String::new();
        for word in text
            .to_ascii_lowercase()
            .split(|c: char| !c.is_ascii_alphanumeric())
            .filter(|v| !v.is_empty())
        {
            if word.bytes().all(|c| c.is_ascii_digit()) {
                digits.push_str(word);
                continue;
            }
            let Some(index) = [
                "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            ]
            .iter()
            .position(|w| *w == word) else {
                return false;
            };
            digits.push(char::from(b'0' + index as u8));
        }
        digits == expected
    }
}
