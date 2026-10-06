//! 会话身份来自既有Run；请求快照先落盘再进入提供方，取消等待写入和执行资源释放。
use super::*;
use crate::{conversation_audit, storage::AppStore};
use std::{sync::Mutex as SyncMutex, time::Instant};

pub(crate) struct ProviderAudit {
    store: Arc<AppStore>,
    conversation: String,
    run: String,
    pub(super) phase: &'static str,
    state: SyncMutex<State>,
}
#[derive(Default)]
struct State {
    ordinal: u32,
    active: Option<Attempt>,
}
struct Attempt {
    ordinal: u32,
    started: Instant,
    phase: &'static str,
    provider: String,
    model: String,
    transport: &'static str,
}
impl ProviderAudit {
    pub fn new(
        store: Arc<AppStore>,
        conversation: String,
        run: String,
        phase: &'static str,
    ) -> Self {
        Self {
            store,
            conversation,
            run,
            phase,
            state: Default::default(),
        }
    }
    fn failure() -> ChatFailure {
        ChatFailure::new(ChatFailureKind::Interrupted, "请求审计保存失败；执行已停止")
    }
    fn write(&self, kind: &str, summary: &str, payload: Value) -> Result<(), ChatFailure> {
        self.write_all(&[(kind, summary, payload)])
    }
    fn write_all(&self, events: &[(&str, &str, Value)]) -> Result<(), ChatFailure> {
        let mut connection = self.store.connection.lock().map_err(|_| Self::failure())?;
        let tx = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(|_| Self::failure())?;
        let running: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE id=?1 AND conversation_id=?2 AND state='running' UNION ALL SELECT 1 FROM conversation_title_requests WHERE id=?1 AND conversation_id=?2 AND state='running')",rusqlite::params![self.run,self.conversation],|r|r.get(0)).map_err(|_| Self::failure())?;
        if !running {
            return Err(Self::failure());
        }
        for (kind, summary, payload) in events {
            conversation_audit::append(
                &tx,
                &self.conversation,
                "PROVIDER",
                kind,
                summary,
                payload.clone(),
            )
            .map_err(|_| Self::failure())?;
        }
        tx.commit().map_err(|_| Self::failure())
    }
    pub fn begin(
        &self,
        input: &ChatRequest,
        phase: &'static str,
        transport: &'static str,
        body: Option<&Value>,
    ) -> Result<(), ChatFailure> {
        let mut state = self.state.lock().map_err(|_| Self::failure())?;
        if state.active.is_some() {
            return Err(Self::failure());
        }
        let ordinal = state.ordinal + 1;
        let mut snapshot = json!({"runId":self.run,"hopOrdinal":ordinal-1,"phase":phase,"providerModel":format!("{}:{}",input.provider,input.model),"provider":input.provider,"model":input.model,"protocol":input.protocol,"endpoint":input.endpoint,"stream":input.stream,"apiKeyConfigured":!input.api_key.is_empty(),"customHeaderNames":input.headers.iter().map(|(name,_)|name).collect::<Vec<_>>(),"requestHistory":input.messages,"modelParameters":serde_json::from_str::<Value>(&input.parameters).unwrap_or(Value::Null),"requestBody":body,"availableTools":Value::Null,"transport":transport});
        let secrets: Vec<&str> = std::iter::once(input.api_key.as_str())
            .chain(input.headers.iter().map(|(_, value)| value.as_str()))
            .filter(|value| !value.is_empty())
            .collect();
        scrub(&mut snapshot, &secrets);
        // 不保留认证头/Key原文；短期已解析凭据仅用于清除正文中意外重复的同一秘密。
        self.write_all(&[(
            "FINAL_PROVIDER_SEMANTIC_REQUEST",
            "已固化最终 Provider 语义请求",
            snapshot,
        ),("PROVIDER_ATTEMPT_STARTED","开始 Provider 执行",json!({"runId":self.run,"hopOrdinal":ordinal-1,"attemptNumber":1,"phase":phase,"provider":input.provider,"model":input.model,"transport":transport,"stream":input.stream,"retrySafety":"NO_AUTOMATIC_RETRY"}))])?;
        state.ordinal = ordinal;
        state.active = Some(Attempt {
            ordinal,
            started: Instant::now(),
            phase,
            provider: input.provider.clone(),
            model: input.model.clone(),
            transport,
        });
        Ok(())
    }
    pub fn response(&self, status: u16, version: String) -> Result<(), ChatFailure> {
        let state = self.state.lock().map_err(|_| Self::failure())?;
        let Some(attempt) = &state.active else {
            return Ok(());
        };
        self.write("PROVIDER_RESPONSE_HEADERS","已收到 Provider 响应头",json!({"runId":self.run,"hopOrdinal":attempt.ordinal-1,"responseStatusCode":status,"protocol":version,"responseHeadersReceived":true,"elapsedMs":attempt.started.elapsed().as_millis().min(u64::MAX as u128) as u64}))
    }
    pub fn finish(&self, result: Option<&Result<String, ChatFailure>>) -> Result<(), ChatFailure> {
        let mut state = self.state.lock().map_err(|_| Self::failure())?;
        let Some(attempt) = state.active.as_ref() else {
            return Ok(());
        };
        let (terminal, reason, status) = match result {
            Some(Ok(reason)) => ("COMPLETED", reason.clone(), None),
            Some(Err(error)) => ("FAILED", format!("{:?}", error.kind), error.http_status),
            None => ("CANCELLED", "请求已取消".into(), None),
        };
        self.write("PROVIDER_ATTEMPT_FINISHED","Provider 执行已结束",json!({"runId":self.run,"hopOrdinal":attempt.ordinal-1,"attemptNumber":1,"phase":attempt.phase,"provider":attempt.provider,"model":attempt.model,"transport":attempt.transport,"terminalState":terminal,"finishReason":reason,"httpStatus":status,"elapsedMs":attempt.started.elapsed().as_millis().min(u64::MAX as u128) as u64,"retrySafety":"NO_AUTOMATIC_RETRY"}))?;
        state.active = None;
        Ok(())
    }
}
fn credential(name: &str) -> bool {
    let normalized = name.to_ascii_lowercase().replace(['_', '-'], "");
    [
        "authorization",
        "cookie",
        "password",
        "passwd",
        "apikey",
        "accesstoken",
        "refreshtoken",
        "authtoken",
        "clientsecret",
        "privatekey",
        "signature",
        "secret",
    ]
    .iter()
    .any(|word| normalized.contains(word))
}
fn scrub(value: &mut Value, secrets: &[&str]) {
    match value {
        Value::Object(map) => {
            for (name, value) in map {
                if credential(name)
                    && !matches!(name.as_str(), "apiKeyConfigured" | "customHeaderNames")
                {
                    *value = json!("[REDACTED:credential]");
                } else {
                    scrub(value, secrets);
                }
            }
        }
        Value::Array(values) => {
            for value in values {
                scrub(value, secrets)
            }
        }
        Value::String(text) => {
            for secret in secrets {
                *text = text.replace(secret, "[REDACTED:credential]");
            }
            *text = conversation_audit::redact(text);
        }
        _ => {}
    }
}

impl EventSender {
    pub(super) async fn wait_workers(&self) {
        loop {
            let pending = std::mem::take(
                &mut *self
                    .workers
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner),
            );
            if pending.is_empty() {
                break;
            }
            for worker in pending {
                let _ = worker.await;
            }
        }
    }
    pub(super) async fn audit_write(
        &self,
        work: impl FnOnce(Arc<ProviderAudit>) -> Result<(), ChatFailure> + Send + 'static,
    ) -> Result<(), ChatFailure> {
        let Some(audit) = self.audit.clone() else {
            return Ok(());
        };
        let (send, receive) = tokio::sync::oneshot::channel();
        let job = tokio::task::spawn_blocking(move || {
            let _ = send.send(work(audit));
        });
        self.workers
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .push(tokio::spawn(async move {
                let _ = job.await;
            }));
        receive.await.map_err(|_| ProviderAudit::failure())?
    }
    pub(super) fn audit_begin<'a>(
        &'a self,
        input: &ChatRequest,
        transport: &'static str,
        body: Option<&Value>,
    ) -> impl Future<Output = Result<(), ChatFailure>> + Send + 'a + use<'a> {
        // 请求含仅Send的执行回调；在future创建前冻结输入，避免跨await借用回调。
        let phase = self.audit_phase;
        let snapshot = self.audit.as_ref().map(|_| AuditInput::from(input, body));
        async move {
            let Some(snapshot) = snapshot else {
                return Ok(());
            };
            self.audit_write(move |audit| {
                audit.begin(&snapshot.request, phase, transport, snapshot.body.as_ref())
            })
            .await
        }
    }
    pub(super) async fn audit_finish(
        &self,
        result: &Result<String, ChatFailure>,
    ) -> Result<(), ChatFailure> {
        // 超时会丢弃begin的await，但blocking写入仍在运行；先等待才能记录准确终态。
        if self.audit.is_some() {
            self.wait_workers().await;
        }
        let result = result.clone();
        self.audit_write(move |audit| audit.finish(Some(&result)))
            .await
    }
}
struct AuditInput {
    request: ChatRequest,
    body: Option<Value>,
}
impl AuditInput {
    fn from(input: &ChatRequest, body: Option<&Value>) -> Self {
        Self {
            body: body.cloned(),
            request: ChatRequest {
                extension: None,
                local: None,
                prelude: None,
                provider: input.provider.clone(),
                continuation_credentials: None,
                google_search: input.google_search,
                claude_cache: input.claude_cache,
                admission: None,
                stream: input.stream,
                probe: None,
                protocol: input.protocol.clone(),
                endpoint: input.endpoint.clone(),
                model: input.model.clone(),
                api_key: input.api_key.clone(),
                headers: input.headers.clone(),
                messages: input.messages.clone(),
                parameters: input.parameters.clone(),
                timeout_ms: input.timeout_ms,
            },
        }
    }
}
