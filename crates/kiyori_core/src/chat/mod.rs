pub mod directory;
pub mod extension;
pub(crate) mod gemini;
pub mod limits;
mod media;
pub(crate) mod messages;
pub mod native;
pub mod observation;
pub mod pool;
pub mod probe;
mod responses;
mod sse;
#[cfg(test)]
mod tests;
mod tool_probe;
#[cfg(test)]
mod tool_probe_tests;
mod usage;

use crate::runtime::{CoreError, ErrorCode};
use reqwest::{
    Client, Url,
    header::{HeaderMap, HeaderName, HeaderValue},
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{sync::Arc, time::Duration};
use tokio::sync::{Mutex, mpsc};
use tokio_util::sync::CancellationToken;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChatFailureKind {
    InvalidInput,
    Unsupported,
    Transport,
    Timeout,
    Http,
    Protocol,
    Interrupted,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChatFailure {
    pub kind: ChatFailureKind,
    pub message: String,
    pub http_status: Option<u16>,
}
impl ChatFailure {
    pub(crate) fn new(kind: ChatFailureKind, message: &str) -> Self {
        Self {
            kind,
            message: message.into(),
            http_status: None,
        }
    }
    fn protocol() -> Self {
        Self::new(ChatFailureKind::Protocol, "模型返回了无效的流式数据")
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

// 凭据输入不实现Debug，错误也不附带请求、URL或供应商响应正文。
pub struct ChatRequest {
    pub extension: Option<extension::ExtensionInput>,
    pub local: Option<native::LocalInput>,
    pub prelude: Option<Box<Prelude>>,
    pub provider: String,
    pub continuation_credentials: Option<CredentialSource>,
    pub google_search: bool,
    pub claude_cache: bool,
    pub admission: Option<Arc<limits::Gate>>,
    pub stream: bool,
    pub probe: Option<probe::Probe>,
    pub protocol: String,
    pub endpoint: String,
    pub model: String,
    pub api_key: String,
    pub headers: Vec<(String, String)>,
    pub messages: Vec<ChatMessage>,
    pub parameters: String,
    pub timeout_ms: u32,
}
pub struct Prelude {
    pub(crate) request: ChatRequest,
    pub(crate) finish: Box<dyn FnOnce(String) -> Result<Vec<ChatMessage>, CoreError> + Send>,
    pub(crate) usage: Box<dyn FnMut(ChatEvent) -> Result<(), CoreError> + Send>,
}
pub type CredentialSource =
    Box<dyn FnMut() -> Result<(String, Vec<(String, String)>), CoreError> + Send>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChatEvent {
    Models(Vec<directory::ModelEntry>),
    PoolResult {
        id: String,
        available: bool,
    },
    Started,
    Text(String),
    Usage {
        input: u64,
        output: u64,
        output_reported: bool,
        total: u64,
        cache_read: Option<u64>,
        cache_write: Option<u64>,
        reasoning: Option<u64>,
    },
    Completed {
        reason: String,
        verified: Option<bool>,
    },
    Failed(ChatFailure),
    Cancelled,
}
struct RunState {
    receiver: mpsc::Receiver<ChatEvent>,
    terminal: bool,
}
pub struct ChatRun {
    cancellation: CancellationToken,
    finished: CancellationToken,
    state: Mutex<RunState>,
}
impl ChatRun {
    pub fn cancel(&self) {
        self.cancellation.cancel();
    }
    pub async fn cancel_and_wait(&self) {
        self.cancel();
        self.finished.cancelled().await;
    }
    pub async fn next_event(&self) -> Result<Option<ChatEvent>, CoreError> {
        let mut state = self.state.try_lock().map_err(|_| CoreError {
            code: ErrorCode::ConcurrentRead,
            message: "A chat supports only one pending event reader.".into(),
        })?;
        if state.terminal {
            return Ok(None);
        }
        let event = tokio::select! {
            biased;
            _ = self.cancellation.cancelled() => {
                self.finished.cancelled().await;
                ChatEvent::Cancelled
            },
            event = state.receiver.recv() => event.unwrap_or_else(|| ChatEvent::Failed(
                ChatFailure::new(ChatFailureKind::Interrupted, "请求任务意外结束"))),
        };
        state.terminal = matches!(
            event,
            ChatEvent::Completed { .. } | ChatEvent::Failed(_) | ChatEvent::Cancelled
        );
        if state.terminal {
            state.receiver.close();
        }
        Ok(Some(event))
    }
}
impl Drop for ChatRun {
    fn drop(&mut self) {
        self.cancel();
    }
}

/// 持久化先于投影；即使UI退订/队列背压，取消也会写入唯一终态并释放执行锁。
pub(crate) fn persist(
    upstream: ChatRun,
    cancellation: CancellationToken,
    mut save: impl FnMut(ChatEvent) -> Result<ChatEvent, CoreError> + Send + 'static,
) -> ChatRun {
    let (sender, receiver) = mpsc::channel(8);
    let worker_cancel = cancellation.clone();
    let finished = CancellationToken::new();
    let guard = finished.clone().drop_guard();
    tokio::spawn(async move {
        let _guard = guard;
        loop {
            let event = tokio::select! {
                biased;
                _ = worker_cancel.cancelled() => {
                    upstream.cancel_and_wait().await;
                    ChatEvent::Cancelled
                },
                event = upstream.next_event() => match event {
                    Ok(Some(event)) => event,
                    _ => ChatEvent::Failed(ChatFailure::new(ChatFailureKind::Interrupted, "请求意外中断，未自动重试")),
                },
            };
            let event = match save(event) {
                Ok(event) => event,
                Err(_) => {
                    upstream.cancel_and_wait().await;
                    // DB失效时不能声称已保存；仍保留running账本供下次锁恢复。
                    let failure = ChatEvent::Failed(ChatFailure::new(
                        ChatFailureKind::Interrupted,
                        "聊天保存失败，请重新打开会话核对；未自动重试",
                    ));
                    tokio::select! { _ = worker_cancel.cancelled() => {}, _ = sender.send(failure) => {} }
                    break;
                }
            };
            let terminal = matches!(
                event,
                ChatEvent::Completed { .. } | ChatEvent::Failed(_) | ChatEvent::Cancelled
            );
            let delivered = tokio::select! {
                biased;
                _ = worker_cancel.cancelled(), if !terminal => false,
                result = sender.send(event) => result.is_ok(),
                _ = worker_cancel.cancelled(), if terminal => false,
            };
            if terminal {
                break;
            }
            if !delivered {
                upstream.cancel_and_wait().await;
                let _ = save(ChatEvent::Cancelled);
                break;
            }
        }
        upstream.cancel_and_wait().await;
    });
    ChatRun {
        cancellation,
        finished,
        state: Mutex::new(RunState {
            receiver,
            terminal: false,
        }),
    }
}

pub(crate) fn client() -> Result<Client, CoreError> {
    // 固定Mozilla根使Android不依赖尚未初始化的JNI verifier；不关闭证书/主机校验。
    let roots = webpki_root_certs::TLS_SERVER_ROOT_CERTS
        .iter()
        .map(|der| reqwest::Certificate::from_der(der.as_ref()))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| client_error())?;
    let _ = rustls::crypto::ring::default_provider().install_default();
    Client::builder()
        .tls_certs_only(roots)
        .redirect(reqwest::redirect::Policy::none())
        .retry(reqwest::retry::never())
        .no_proxy()
        .connect_timeout(Duration::from_secs(15))
        .read_timeout(Duration::from_secs(60))
        .pool_max_idle_per_host(2)
        .build()
        .map_err(|_| client_error())
}
fn client_error() -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: "模型网络客户端初始化失败".into(),
    }
}

pub(crate) fn start(
    client: Arc<Client>,
    input: ChatRequest,
    cancellation: CancellationToken,
) -> ChatRun {
    start_observed(client, input, cancellation, None)
}

// 在有界队列和SQLite写入前记录到达时间；UI/存储背压不能延长输出计时。
pub(crate) struct EventSender {
    sender: mpsc::Sender<ChatEvent>,
    observation: Option<Arc<std::sync::Mutex<observation::Tracker>>>,
    cancellation: CancellationToken,
    workers: Arc<std::sync::Mutex<Vec<tokio::task::JoinHandle<()>>>>,
}
impl EventSender {
    fn observe(&self, event: &ChatEvent) {
        if let Some(tracker) = &self.observation {
            tracker
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .observe(event);
        }
    }
    async fn send(&self, event: ChatEvent) -> Result<(), mpsc::error::SendError<ChatEvent>> {
        self.observe(&event);
        tokio::select! {
            biased;
            _ = self.cancellation.cancelled() => Err(mpsc::error::SendError(event)),
            permit = self.sender.reserve() => match permit {
                Ok(permit) => { permit.send(event); Ok(()) },
                Err(_) => Err(mpsc::error::SendError(event)),
            }
        }
    }
}

pub(crate) fn start_observed(
    client: Arc<Client>,
    input: ChatRequest,
    cancellation: CancellationToken,
    observation: Option<Arc<std::sync::Mutex<observation::Tracker>>>,
) -> ChatRun {
    let (sender, receiver) = mpsc::channel(8);
    let workers = Arc::new(std::sync::Mutex::new(Vec::new()));
    let sender = EventSender {
        sender,
        observation,
        cancellation: cancellation.clone(),
        workers: workers.clone(),
    };
    let worker_cancel = cancellation.clone();
    let finished = CancellationToken::new();
    let guard = finished.clone().drop_guard();
    tokio::spawn(async move {
        let _guard = guard;
        let result = tokio::select! {
            biased;
            _ = worker_cancel.cancelled() => { sender.observe(&ChatEvent::Cancelled); None },
            result = execute(&client, input, &sender) => Some(result),
        };
        // future 被取消不等于 C++ 已停止。finished 和持久化锁都要等 RAII 析构结束。
        let pending = std::mem::take(
            &mut *workers
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner),
        );
        for worker in pending {
            let _ = worker.await;
        }
        if let Some(Err(error)) = result {
            let _ = sender.send(ChatEvent::Failed(error)).await;
        }
    });
    ChatRun {
        cancellation,
        finished,
        state: Mutex::new(RunState {
            receiver,
            terminal: false,
        }),
    }
}

pub(crate) fn endpoint(value: &str, protocol: &str) -> Result<Url, ChatFailure> {
    let raw = value.trim();
    let exact = raw.ends_with('#');
    let raw = raw.strip_suffix('#').unwrap_or(raw);
    let mut url = Url::parse(raw)
        .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "模型端点无效"))?;
    let loopback = url.host_str().is_some_and(|host| {
        host == "localhost"
            || host
                .trim_matches(['[', ']'])
                .parse::<std::net::IpAddr>()
                .is_ok_and(|ip| ip.is_loopback())
    });
    if !url.username().is_empty()
        || url.password().is_some()
        || url.query().is_some()
        || url.fragment().is_some()
        || !(url.scheme() == "https" || url.scheme() == "http" && loopback)
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "端点需要HTTPS（本机回环可用HTTP），且不能含账号、查询或片段",
        ));
    }
    if !exact && protocol != "native" {
        let suffix = match protocol {
            "responses" => "responses",
            "messages" => "messages",
            _ => "chat/completions",
        };
        let path = url.path().trim_end_matches('/');
        if path.is_empty()
            || (protocol == "messages" && path.to_ascii_lowercase().ends_with("/anthropic"))
        {
            url.set_path(&format!("{path}/v1/{suffix}"));
        } else if path.to_ascii_lowercase().ends_with("/v1") {
            url.set_path(&format!("{path}/{suffix}"));
        }
    }
    Ok(url)
}

async fn execute(
    client: &Arc<Client>,
    mut input: ChatRequest,
    sender: &EventSender,
) -> Result<(), ChatFailure> {
    if let Some(mut prelude) = input.prelude.take() {
        let (queue, mut receiver) = mpsc::channel(8);
        let summary_sender = EventSender {
            sender: queue,
            observation: None,
            cancellation: sender.cancellation.clone(),
            workers: sender.workers.clone(),
        };
        // 同一worker内并行收集有界事件与执行；取消丢弃两个future，结束前无孤儿请求。
        let generate = async {
            let reason = execute_once(client, &mut prelude.request, &summary_sender).await;
            drop(summary_sender);
            reason
        };
        let collect = async {
            let mut content = String::new();
            while let Some(event) = receiver.recv().await {
                match event {
                    ChatEvent::Text(text) => {
                        if content.len() + text.len() > 8 * 1024 * 1024 {
                            return Err(ChatFailure::new(
                                ChatFailureKind::Protocol,
                                "总结超过8 MiB限制；原文保留",
                            ));
                        }
                        content.push_str(&text);
                    }
                    usage @ ChatEvent::Usage { .. } => (prelude.usage)(usage).map_err(|_| {
                        ChatFailure::new(ChatFailureKind::Interrupted, "总结用量保存失败；原文保留")
                    })?,
                    _ => {}
                }
            }
            Ok(content)
        };
        let (reason, content) = tokio::try_join!(generate, collect)?;
        if reason != "stop" || content.trim().is_empty() {
            return Err(ChatFailure::new(
                ChatFailureKind::Interrupted,
                "总结未完整结束；原文保留，未继续聊天请求",
            ));
        }
        input.messages = (prelude.finish)(content)
            .map_err(|e| ChatFailure::new(ChatFailureKind::InvalidInput, &e.message))?;
        if let Some(tracker) = &sender.observation {
            let mut tracker = tracker
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            tracker.rebase_context(&input.messages);
        }
    }
    let timeout = input.timeout_ms;
    let probing = input.probe.is_some();
    let local = input.local.is_some();
    let operation = async {
        let mut reason = execute_once(client, &mut input, sender).await?;
        if let Some(probe) = &mut input.probe
            && let Some(tool) = &mut probe.tool
            && tool.advance(&input.protocol, &probe.text, &reason)?
        {
            probe.expected = Some(tool.code.clone());
            probe.text.clear();
            if let Some(source) = input.continuation_credentials.as_mut() {
                let (key, headers) = source().map_err(|_| {
                    ChatFailure::new(
                        ChatFailureKind::InvalidInput,
                        "工具续答前配置或安全凭据已失效",
                    )
                })?;
                input.api_key = key;
                input.headers = headers;
            }
            reason = execute_once(client, &mut input, sender).await?;
        }
        let verified = input.probe.as_ref().map(|p| p.verified(&reason));
        let _ = sender.send(ChatEvent::Completed { reason, verified }).await;
        Ok(())
    };
    if probing && !local {
        tokio::time::timeout(Duration::from_millis(timeout.into()), operation)
            .await
            .map_err(|_| {
                ChatFailure::new(ChatFailureKind::Timeout, "模型能力探测超时；未自动重试")
            })?
    } else {
        operation.await
    }
}

async fn execute_once(
    client: &Arc<Client>,
    input: &mut ChatRequest,
    sender: &EventSender,
) -> Result<String, ChatFailure> {
    if input.extension.is_some() {
        return extension::execute(client.clone(), input, sender).await;
    }
    if input.local.is_some() {
        return native::execute(input, sender).await;
    }
    if !matches!(
        input.protocol.as_str(),
        "chat" | "responses" | "messages" | "native"
    ) {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "该模型协议的请求执行尚未接入",
        ));
    }
    if !(100..=600_000).contains(&input.timeout_ms)
        || input.model.trim().is_empty()
        || input.model.len() > 512
        || input.messages.is_empty()
        || input.messages.len() > 1000
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "模型、消息或超时参数无效",
        ));
    }
    let is_responses = input.protocol == "responses";
    let is_messages = input.protocol == "messages";
    let is_gemini = input.protocol == "native";
    let url = if is_gemini {
        gemini::url(&input.endpoint, &input.model, input.stream)?
    } else {
        endpoint(&input.endpoint, &input.protocol)?
    };
    let mut body: Value = serde_json::from_str(&input.parameters)
        .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "请求参数必须为JSON对象"))?;
    let object = body
        .as_object_mut()
        .ok_or_else(|| ChatFailure::new(ChatFailureKind::InvalidInput, "请求参数必须为JSON对象"))?;
    for message in &input.messages {
        if !matches!(message.role.as_str(), "system" | "user" | "assistant") {
            return Err(ChatFailure::new(
                ChatFailureKind::Unsupported,
                "此请求入口暂不支持工具消息",
            ));
        }
    }
    for reserved in [
        "model",
        "messages",
        "stream",
        "n",
        "tools",
        "tool_choice",
        "functions",
        "function_call",
        "input",
        "instructions",
        "system",
        "contents",
        "systemInstruction",
        "generationConfig",
        "toolConfig",
        "previous_response_id",
        "conversation",
        "store",
        "background",
    ] {
        if object.contains_key(reserved) {
            return Err(ChatFailure::new(
                ChatFailureKind::InvalidInput,
                "自定义参数不能覆盖请求核心字段",
            ));
        }
    }
    object.insert("model".into(), json!(input.model));
    if is_gemini {
        gemini::prepare(object, &input.messages, input.google_search)?;
    } else if is_responses {
        responses::prepare(object, &input.messages)?;
    } else if is_messages {
        messages::prepare(object, &input.messages, input.claude_cache)?;
    } else {
        object.insert("messages".into(), json!(input.messages));
        object.insert("n".into(), json!(1));
    }
    if !is_gemini {
        object.insert("stream".into(), json!(input.stream));
    }
    if let Some(media) = input.probe.as_ref().and_then(|p| p.media.as_ref()) {
        media.apply(&input.protocol, object)?;
    }
    if let Some(tool) = input.probe.as_ref().and_then(|p| p.tool.as_ref()) {
        tool.apply(&input.protocol, object)?;
    }
    let bytes = serde_json::to_vec(&body).map_err(|_| ChatFailure::protocol())?;
    if bytes.len() > 8 * 1024 * 1024 {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "请求正文超过8 MiB限制",
        ));
    }
    let mut headers = HeaderMap::new();
    if !input.api_key.trim().is_empty() {
        let bearer = !is_gemini
            && (!is_messages
                || matches!(
                    input.provider.as_str(),
                    "ZHIPU" | "MIMO" | "INFINIAI" | "LMSTUDIO" | "OLLAMA"
                ));
        let auth = if !bearer {
            input.api_key.trim().to_owned()
        } else {
            format!("Bearer {}", input.api_key.trim())
        };
        let mut value = HeaderValue::from_str(&auth)
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "认证信息格式无效"))?;
        value.set_sensitive(true);
        headers.insert(
            if is_gemini {
                HeaderName::from_static("x-goog-api-key")
            } else if !bearer {
                HeaderName::from_static("x-api-key")
            } else {
                reqwest::header::AUTHORIZATION
            },
            value,
        );
        if input.provider == "MIMO" {
            let mut value = HeaderValue::from_str(input.api_key.trim())
                .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "认证信息格式无效"))?;
            value.set_sensitive(true);
            headers.insert("api-key", value);
        }
    }
    if is_messages {
        headers.insert("anthropic-version", HeaderValue::from_static("2023-06-01"));
    }
    if input.headers.len() > 100 {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "请求头数量过多",
        ));
    }
    for (name, value) in &input.headers {
        let name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "请求头名称无效"))?;
        if matches!(
            name.as_str(),
            "host"
                | "content-length"
                | "transfer-encoding"
                | "connection"
                | "content-type"
                | "accept"
                | "upgrade"
                | "proxy-authorization"
                | "cookie"
        ) {
            return Err(ChatFailure::new(
                ChatFailureKind::InvalidInput,
                "自定义请求头不能覆盖传输控制字段",
            ));
        }
        let mut value = HeaderValue::from_str(value)
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "请求头内容无效"))?;
        value.set_sensitive(true);
        headers.insert(name, value);
    }
    let _permit = match &input.admission {
        Some(gate) => Some(gate.acquire().await),
        None => None,
    };
    let operation = async {
        let _ = sender.send(ChatEvent::Started).await;
        let mut response = client
            .post(url)
            .headers(headers)
            .header("Content-Type", "application/json")
            .header(
                "Accept",
                if input.stream {
                    "text/event-stream"
                } else {
                    "application/json"
                },
            )
            .body(bytes)
            .send()
            .await
            .map_err(transport)?;
        if !response.status().is_success() {
            let status = response.status().as_u16();
            return Err(ChatFailure {
                kind: ChatFailureKind::Http,
                message: format!("模型服务返回HTTP {status}"),
                http_status: Some(status),
            });
        }
        if !input.stream {
            let mut body = Vec::new();
            while let Some(chunk) = response.chunk().await.map_err(transport)? {
                if body.len() + chunk.len() > 8 * 1024 * 1024 {
                    return Err(ChatFailure::new(
                        ChatFailureKind::Protocol,
                        "模型回复超过8 MiB限制",
                    ));
                }
                body.extend_from_slice(&chunk);
            }
            let mut value: Value =
                serde_json::from_slice(&body).map_err(|_| ChatFailure::protocol())?;
            let reason = if is_gemini {
                let mut decoder = gemini::Decoder::default();
                decoder
                    .decode(&value.to_string(), &mut input.probe, sender)
                    .await?;
                decoder.reason.ok_or_else(ChatFailure::protocol)?
            } else if is_responses {
                responses::Decoder::document(value, &mut input.probe, sender).await?
            } else if is_messages {
                messages::Decoder::document(value, &mut input.probe, sender).await?
            } else {
                let choices = value
                    .get_mut("choices")
                    .and_then(Value::as_array_mut)
                    .ok_or_else(ChatFailure::protocol)?;
                for choice in choices {
                    let object = choice.as_object_mut().ok_or_else(ChatFailure::protocol)?;
                    let message = object.remove("message").ok_or_else(ChatFailure::protocol)?;
                    object.insert("delta".into(), message);
                }
                let mut finish = None;
                decode(&value.to_string(), &mut finish, &mut input.probe, sender).await?;
                finish.ok_or_else(ChatFailure::protocol)?
            };
            return Ok(reason);
        }
        if response
            .headers()
            .get("content-type")
            .and_then(|v| v.to_str().ok())
            .is_none_or(|v| {
                !v.split(';')
                    .next()
                    .unwrap_or("")
                    .trim()
                    .eq_ignore_ascii_case("text/event-stream")
            })
        {
            return Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "模型服务未返回SSE流",
            ));
        }
        let mut sse = sse::Sse::new();
        let mut finish: Option<String> = None;
        let mut responses = responses::Decoder::default();
        let mut messages = messages::Decoder::default();
        let mut gemini = gemini::Decoder::default();
        while let Some(chunk) = response.chunk().await.map_err(transport)? {
            for byte in chunk {
                if let Some(data) = sse.push(byte)? {
                    if is_gemini {
                        if data == "[DONE]" {
                            return Err(ChatFailure::protocol());
                        }
                        gemini.decode(&data, &mut input.probe, sender).await?;
                        continue;
                    }
                    if is_messages {
                        if let Some(reason) =
                            messages.decode(&data, &mut input.probe, sender).await?
                        {
                            return Ok(reason);
                        }
                        continue;
                    }
                    if is_responses {
                        if let Some(reason) =
                            responses.decode(&data, &mut input.probe, sender).await?
                        {
                            return Ok(reason);
                        }
                        continue;
                    }
                    if data == "[DONE]" {
                        let reason = finish.ok_or_else(|| {
                            ChatFailure::new(
                                ChatFailureKind::Interrupted,
                                "流已结束但缺少模型结束原因",
                            )
                        })?;
                        return Ok(reason);
                    }
                    decode(&data, &mut finish, &mut input.probe, sender).await?;
                }
            }
        }
        if is_gemini {
            if !sse.at_boundary() {
                return Err(ChatFailure::new(
                    ChatFailureKind::Interrupted,
                    "Gemini末尾事件不完整",
                ));
            }
            let reason = gemini.reason.ok_or_else(|| {
                ChatFailure::new(ChatFailureKind::Interrupted, "Gemini流缺少结束原因")
            })?;
            return Ok(reason);
        }
        Err(ChatFailure::new(
            ChatFailureKind::Interrupted,
            "模型流在完成标记前中断",
        ))
    };
    tokio::time::timeout(Duration::from_millis(input.timeout_ms.into()), operation)
        .await
        .map_err(|_| ChatFailure::new(ChatFailureKind::Timeout, "模型请求超时；未自动重试"))?
}
fn transport(error: reqwest::Error) -> ChatFailure {
    if error.is_timeout() {
        ChatFailure::new(ChatFailureKind::Timeout, "模型连接或读取超时；未自动重试")
    } else {
        ChatFailure::new(
            ChatFailureKind::Transport,
            "模型网络请求失败；提交状态可能未知，未自动重试",
        )
    }
}

async fn decode(
    data: &str,
    finish: &mut Option<String>,
    probe: &mut Option<probe::Probe>,
    sender: &EventSender,
) -> Result<(), ChatFailure> {
    let value: Value = serde_json::from_str(data).map_err(|_| ChatFailure::protocol())?;
    if value.get("error").is_some() {
        return Err(ChatFailure::new(
            ChatFailureKind::Protocol,
            "模型服务在流中返回错误",
        ));
    }
    let choices = value
        .get("choices")
        .and_then(Value::as_array)
        .ok_or_else(ChatFailure::protocol)?;
    if choices.len() > 1 {
        return Err(ChatFailure::protocol());
    }
    for choice in choices {
        if choice.get("index").and_then(Value::as_u64) != Some(0) || finish.is_some() {
            return Err(ChatFailure::protocol());
        }
        let delta = choice
            .get("delta")
            .and_then(Value::as_object)
            .ok_or_else(ChatFailure::protocol)?;
        if let Some(reasoning) = delta.get("reasoning_content").filter(|v| !v.is_null())
            && let Some(tool) = tool_probe::native(probe)
        {
            tool.chat_reasoning(reasoning.as_str().ok_or_else(ChatFailure::protocol)?)?;
        }
        if let Some(calls) = delta.get("tool_calls").filter(|v| !v.is_null()) {
            if let Some(tool) = tool_probe::native(probe) {
                tool.chat_delta(calls)?;
            } else {
                return Err(ChatFailure::new(
                    ChatFailureKind::Unsupported,
                    "此请求入口尚未接入工具调用执行",
                ));
            }
        }
        if delta.get("function_call").is_some_and(|v| !v.is_null()) {
            return Err(ChatFailure::new(
                ChatFailureKind::Unsupported,
                "当前入口不支持旧版function_call",
            ));
        }
        if let Some(content) = delta.get("content").filter(|v| !v.is_null()) {
            let content = content.as_str().ok_or_else(ChatFailure::protocol)?;
            if !content.is_empty() {
                if let Some(probe) = probe {
                    probe.append(content)?;
                } else {
                    let _ = sender.send(ChatEvent::Text(content.into())).await;
                }
            }
        }
        if let Some(reason) = choice.get("finish_reason").filter(|v| !v.is_null()) {
            let reason = reason.as_str().ok_or_else(ChatFailure::protocol)?;
            if reason == "tool_calls" && tool_probe::native(probe).is_some() {
                *finish = Some("tool".into());
            } else if !matches!(reason, "stop" | "length") {
                return Err(ChatFailure::new(
                    ChatFailureKind::Unsupported,
                    "模型以工具调用、过滤或未知原因结束",
                ));
            } else {
                *finish = Some(reason.into());
            }
        }
    }
    if let Some(usage) = value.get("usage").and_then(usage::parse) {
        let _ = sender.send(usage).await;
    }
    Ok(())
}
