//! 单次模型配置的HTTP能力；同client、限定操作URL，凭据不进入JS。
use crate::{
    chat,
    models::ModelConfigDraft,
    runtime::Runtime,
    scripts::{ScriptFailure, ScriptFailureKind, ScriptHttpHost},
};
use reqwest::{
    Client, Url,
    header::{HeaderMap, HeaderName, HeaderValue},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    sync::{
        Arc,
        atomic::{AtomicU32, Ordering},
    },
    time::Duration,
};

const KEY_REFERENCE: &str = "__kiyori_credential_reference__";
const MAX_BODY: usize = 8 * 1024 * 1024;
#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct Request {
    url: String,
    method: String,
    #[serde(default)]
    headers: BTreeMap<String, String>,
    body: Option<String>,
    stream: bool,
    timeout_ms: u32,
}
pub struct ModelHttpHost {
    client: Arc<Client>,
    executor: tokio::runtime::Handle,
    generation: Url,
    directory: Url,
    actual: HeaderMap,
    references: BTreeMap<String, String>,
    secrets: Vec<Vec<u8>>,
    calls: AtomicU32,
}
fn failure() -> ScriptFailure {
    ScriptFailureKind::Protocol.into()
}
impl ModelHttpHost {
    /// 只能从模型owner已选择的短期凭据构造；注册/普通脚本没有此能力。
    pub fn new(
        runtime: &Runtime,
        draft: &ModelConfigDraft,
        key: String,
        headers: Vec<(String, String)>,
    ) -> Result<Self, ScriptFailure> {
        runtime
            .ensure_open()
            .map_err(|_| ScriptFailureKind::RuntimeClosed)?;
        let client = runtime
            .chat_client
            .get_or_init(|| chat::client().map(Arc::new))
            .clone()
            .map_err(|_| ScriptFailureKind::Unsupported)?;
        Self::with_client(client, draft, key, headers)
    }
    pub(crate) fn with_client(
        client: Arc<Client>,
        draft: &ModelConfigDraft,
        key: String,
        headers: Vec<(String, String)>,
    ) -> Result<Self, ScriptFailure> {
        let generation = chat::endpoint(&draft.endpoint, &draft.protocol).map_err(|_| failure())?;
        let mut directory = generation.clone();
        let path = generation.path().trim_end_matches('/');
        let root = path
            .strip_suffix("/chat/completions")
            .or_else(|| path.strip_suffix("/responses"))
            .unwrap_or(path);
        directory.set_path(&format!("{root}/models"));
        let mut actual = HeaderMap::new();
        let mut references = BTreeMap::new();
        let mut secrets = Vec::new();
        if key.len() > 8192 || headers.len() > 100 {
            return Err(failure());
        }
        if !key.is_empty() {
            actual.insert(
                "authorization",
                HeaderValue::from_str(&format!("Bearer {key}")).map_err(|_| failure())?,
            );
            secrets.push(key.into_bytes());
        }
        for (index, (name, value)) in headers.into_iter().enumerate() {
            let name = HeaderName::from_bytes(name.as_bytes()).map_err(|_| failure())?;
            if value.len() > 8192
                || matches!(
                    name.as_str(),
                    "host"
                        | "content-length"
                        | "transfer-encoding"
                        | "connection"
                        | "proxy-authorization"
                        | "proxy-connection"
                )
            {
                return Err(failure());
            }
            let parsed = HeaderValue::from_str(&value).map_err(|_| failure())?;
            references.insert(
                name.to_string(),
                format!("__kiyori_header_reference_{index}__"),
            );
            if !value.is_empty()
                && !matches!(name.as_str(), "content-type" | "accept" | "user-agent")
            {
                secrets.push(value.into_bytes());
            }
            actual.insert(name, parsed);
        }
        Ok(Self {
            client,
            executor: tokio::runtime::Handle::try_current()
                .map_err(|_| ScriptFailureKind::Unsupported)?,
            generation,
            directory,
            actual,
            references,
            secrets,
            calls: AtomicU32::new(0),
        })
    }
    pub fn config(&self, draft: &ModelConfigDraft, model: &str) -> Value {
        let options = &draft.options;
        let parameters: Vec<_> = options.parameters.iter().map(|p| json!({
            "id":p.name,"name":p.name,"value":if p.value_type=="text" {Value::String(p.value.clone())} else {serde_json::from_str(&p.value).unwrap_or(Value::Null)},
            "type":match p.value_type.as_str(){"text"=>"STRING","boolean"=>"BOOLEAN","integer"=>"INT",_=>"FLOAT"},
            "category":match p.category.as_str(){"generation"=>"GENERATION","creativity"=>"CREATIVITY","repetition"=>"REPETITION",_=>"OTHER"},"enabled":p.enabled,"custom":p.category=="custom"})).collect();
        json!({"name":draft.name,"apiProviderType":draft.provider,"apiProviderTypeId":draft.provider,
            "apiEndpoint":self.generation.as_str(),"modelName":model,
            "apiKey":KEY_REFERENCE,"customHeaders":self.references,"customParameters":parameters,
            "enableDirectImageProcessing":options.image,"enableDirectAudioProcessing":options.audio,
            "enableDirectVideoProcessing":options.video,"enableGoogleSearch":options.google_search,
            "enableClaude1hPromptCache":options.claude_cache,"enableToolCall":options.tool_call,
            "requestLimitPerMinute":options.request_limit,"maxConcurrentRequests":options.concurrent_limit})
    }
    fn checked(&self, value: Value) -> Result<(Request, Url, HeaderMap), ScriptFailure> {
        let request: Request = serde_json::from_value(value).map_err(|_| failure())?;
        if !(1..=600_000).contains(&request.timeout_ms)
            || request.headers.len() > 100
            || request.body.as_ref().is_some_and(|v| v.len() > 1024 * 1024)
        {
            return Err(failure());
        }
        let url = Url::parse(&request.url).map_err(|_| failure())?;
        if request.body.as_ref().is_some_and(|body| {
            body.contains(KEY_REFERENCE)
                || self
                    .references
                    .values()
                    .any(|reference| body.contains(reference))
        }) {
            return Err(failure());
        }
        if !(request.method == "GET"
            && url == self.directory
            && request.body.is_none()
            && !request.stream
            || request.method == "POST" && url == self.generation && request.body.is_some())
        {
            return Err(failure());
        }
        let mut headers = HeaderMap::new();
        for (raw, value) in &request.headers {
            let name = HeaderName::from_bytes(raw.as_bytes()).map_err(|_| failure())?;
            if self
                .references
                .get(name.as_str())
                .is_some_and(|reference| reference == value)
                || name == "authorization" && value == &format!("Bearer {KEY_REFERENCE}")
            {
                continue;
            }
            if !matches!(name.as_str(), "content-type" | "accept")
                || name == "content-type" && value != "application/json"
                || name == "accept"
                    && !matches!(
                        value.as_str(),
                        "application/json" | "text/event-stream" | "*/*"
                    )
            {
                return Err(failure());
            }
            headers.insert(name, HeaderValue::from_str(value).map_err(|_| failure())?);
        }
        for (name, value) in &self.actual {
            headers.insert(name, value.clone());
        }
        Ok((request, url, headers))
    }
}
// 保留最长凭据长度的尾部，跨HTTP分片的凭据回显也不能在发现前流入JS。
struct TextGuard<'a> {
    bytes: Vec<u8>,
    secrets: &'a [Vec<u8>],
    held: usize,
}
impl<'a> TextGuard<'a> {
    fn new(secrets: &'a [Vec<u8>]) -> Self {
        Self {
            bytes: vec![],
            held: secrets.iter().map(Vec::len).max().unwrap_or(1) - 1,
            secrets,
        }
    }
    fn push(&mut self, bytes: &[u8], final_part: bool) -> Result<String, ScriptFailure> {
        self.bytes.extend_from_slice(bytes);
        if self
            .secrets
            .iter()
            .any(|secret| self.bytes.windows(secret.len()).any(|v| v == secret))
        {
            return Err(failure());
        }
        let mut end = if final_part {
            self.bytes.len()
        } else {
            self.bytes.len().saturating_sub(self.held)
        };
        // HTTP允许UTF-8码点跨片段；只交付完整前缀，非法序列明确失败。
        match std::str::from_utf8(&self.bytes) {
            Ok(text) => {
                while !text.is_char_boundary(end) {
                    end -= 1;
                }
            }
            Err(error) if error.error_len().is_none() && !final_part => {
                end = end.min(error.valid_up_to());
                while end > 0 && std::str::from_utf8(&self.bytes[..end]).is_err() {
                    end -= 1;
                }
            }
            Err(_) => return Err(failure()),
        }
        let text = std::str::from_utf8(&self.bytes[..end])
            .map_err(|_| failure())?
            .to_owned();
        self.bytes.drain(..end);
        Ok(text)
    }
}
impl ScriptHttpHost for ModelHttpHost {
    fn request(
        &self,
        input: Value,
        stopped: &dyn Fn() -> bool,
        chunk: &mut dyn FnMut(&str) -> bool,
    ) -> Result<Value, ScriptFailure> {
        let (request, url, headers) = self.checked(input)?;
        if self.calls.fetch_add(1, Ordering::Relaxed) >= 16 {
            return Err(ScriptFailureKind::OutputLimit.into());
        }
        if stopped() {
            return Err(ScriptFailureKind::Cancelled.into());
        }
        self.executor.block_on(async {
            let work=async {
                let mut builder=self.client.request(if request.method=="GET"{reqwest::Method::GET}else{reqwest::Method::POST},url).headers(headers);
                if let Some(body)=request.body {builder=builder.body(body);}
                let mut response=builder.send().await.map_err(|_|ScriptFailureKind::Execution)?;
                let status=response.status().as_u16();
                if !(200..300).contains(&status){return Err(ScriptFailureKind::Execution.into());}
                if response.content_length().is_some_and(|n|n>MAX_BODY as u64){return Err(ScriptFailureKind::OutputLimit.into());}
                let mut guard=TextGuard::new(&self.secrets);
                let mut total=0usize;
                let mut content=String::new();
                while let Some(bytes)=response.chunk().await.map_err(|_|ScriptFailureKind::Execution)? {
                    if bytes.len()>MAX_BODY-total {return Err(ScriptFailureKind::OutputLimit.into());}
                    total+=bytes.len();
                    let text=guard.push(&bytes,false)?;
                    if request.stream {
                        deliver(&text, chunk)?;
                    } else {content.push_str(&text);}
                }
                let tail=guard.push(&[],true)?;
                if request.stream {deliver(&tail,chunk)?;} else {content.push_str(&tail);}
                Ok(json!({"statusCode":status,"ok":true,"content":content}))
            };
            let cancelled=async {loop {if stopped(){break;}tokio::time::sleep(Duration::from_millis(2)).await;}};
            tokio::select!{biased;_=cancelled=>Err(ScriptFailureKind::Cancelled.into()),result=tokio::time::timeout(Duration::from_millis(request.timeout_ms.into()),work)=>result.map_err(|_|ScriptFailureKind::Timeout)?}
        })
    }
}
fn deliver(mut text: &str, chunk: &mut dyn FnMut(&str) -> bool) -> Result<(), ScriptFailure> {
    while !text.is_empty() {
        let mut end = text.len().min(64 * 1024);
        while !text.is_char_boundary(end) {
            end -= 1;
        }
        if !chunk(&text[..end]) {
            return Err(ScriptFailureKind::Interrupted.into());
        }
        text = &text[end..];
    }
    Ok(())
}

#[cfg(test)]
#[path = "http_tests.rs"]
mod tests;
