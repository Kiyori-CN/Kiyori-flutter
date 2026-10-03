pub mod pool;
pub mod probe;
mod responses;
mod sse;
#[cfg(test)]
mod tests;

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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChatEvent {
    PoolResult {
        id: String,
        available: bool,
    },
    Started,
    Text(String),
    Usage {
        input: u64,
        output: u64,
        total: u64,
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
    let (sender, receiver) = mpsc::channel(8);
    let worker_cancel = cancellation.clone();
    let finished = CancellationToken::new();
    let guard = finished.clone().drop_guard();
    tokio::spawn(async move {
        let _guard = guard;
        let work = async {
            let result = execute(&client, input, &sender).await;
            if let Err(error) = result {
                let _ = sender.send(ChatEvent::Failed(error)).await;
            }
        };
        tokio::select! { biased; _ = worker_cancel.cancelled() => {}, _ = work => {} }
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

fn endpoint(value: &str, protocol: &str) -> Result<Url, ChatFailure> {
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
    if !exact {
        let suffix = if protocol == "responses" {
            "responses"
        } else {
            "chat/completions"
        };
        let path = url.path().trim_end_matches('/');
        if path.is_empty() {
            url.set_path(&format!("/v1/{suffix}"));
        } else if path.to_ascii_lowercase().ends_with("/v1") {
            url.set_path(&format!("{path}/{suffix}"));
        }
    }
    Ok(url)
}

async fn execute(
    client: &Client,
    mut input: ChatRequest,
    sender: &mpsc::Sender<ChatEvent>,
) -> Result<(), ChatFailure> {
    if !matches!(input.protocol.as_str(), "chat" | "responses") {
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
    let url = endpoint(&input.endpoint, &input.protocol)?;
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
    if is_responses {
        responses::prepare(object, &input.messages)?;
    } else {
        object.insert("messages".into(), json!(input.messages));
        object.insert("n".into(), json!(1));
    }
    object.insert("stream".into(), json!(true));
    let bytes = serde_json::to_vec(&body).map_err(|_| ChatFailure::protocol())?;
    if bytes.len() > 8 * 1024 * 1024 {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "请求正文超过8 MiB限制",
        ));
    }
    let mut headers = HeaderMap::new();
    if !input.api_key.trim().is_empty() {
        let mut value = HeaderValue::from_str(&format!("Bearer {}", input.api_key.trim()))
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "认证信息格式无效"))?;
        value.set_sensitive(true);
        headers.insert(reqwest::header::AUTHORIZATION, value);
    }
    if input.headers.len() > 100 {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "请求头数量过多",
        ));
    }
    for (name, value) in input.headers {
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
        let mut value = HeaderValue::from_str(&value)
            .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "请求头内容无效"))?;
        value.set_sensitive(true);
        headers.insert(name, value);
    }
    let operation = async {
        let _ = sender.send(ChatEvent::Started).await;
        let mut response = client
            .post(url)
            .headers(headers)
            .header("Content-Type", "application/json")
            .header("Accept", "text/event-stream")
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
        while let Some(chunk) = response.chunk().await.map_err(transport)? {
            for byte in chunk {
                if let Some(data) = sse.push(byte)? {
                    if is_responses {
                        if let Some(reason) =
                            responses.decode(&data, &mut input.probe, sender).await?
                        {
                            let verified =
                                input.probe.as_ref().map(|probe| probe.verified(&reason));
                            let _ = sender.send(ChatEvent::Completed { reason, verified }).await;
                            return Ok(());
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
                        let verified = input.probe.as_ref().map(|probe| probe.verified(&reason));
                        let _ = sender.send(ChatEvent::Completed { reason, verified }).await;
                        return Ok(());
                    }
                    decode(&data, &mut finish, &mut input.probe, sender).await?;
                }
            }
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
    sender: &mpsc::Sender<ChatEvent>,
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
        if delta.get("tool_calls").is_some_and(|v| !v.is_null())
            || delta.get("function_call").is_some_and(|v| !v.is_null())
        {
            return Err(ChatFailure::new(
                ChatFailureKind::Unsupported,
                "此请求入口尚未接入工具调用执行",
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
            if !matches!(reason, "stop" | "length") {
                return Err(ChatFailure::new(
                    ChatFailureKind::Unsupported,
                    "模型以工具调用、过滤或未知原因结束",
                ));
            }
            *finish = Some(reason.into());
        }
    }
    if let Some(usage) = value.get("usage").filter(|v| !v.is_null()) {
        let field = |name| {
            usage
                .get(name)
                .and_then(Value::as_u64)
                .ok_or_else(ChatFailure::protocol)
        };
        let _ = sender
            .send(ChatEvent::Usage {
                input: field("prompt_tokens")?,
                output: field("completion_tokens")?,
                total: field("total_tokens")?,
            })
            .await;
    }
    Ok(())
}
