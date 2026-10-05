//! 扩展供应商仍走同一ChatRun；包代次、配额、HTTP与VM释放由Rust拥有。
use super::*;
use crate::{
    extensions::{self, http::ModelHttpHost},
    models::ModelConfigDraft,
    runtime::Runtime,
    scripts::{self, ProviderHandler, ScriptEvent, ScriptFailure, ScriptFailureKind, ScriptLimits},
    storage::AppStore,
};
use std::collections::HashSet;

#[derive(Clone)]
pub struct ExtensionInput {
    pub thinking: bool,
    draft: ModelConfigDraft,
    binding: Option<Result<Binding, CoreError>>,
}
#[derive(Clone)]
struct Binding {
    store: Arc<AppStore>,
    extensions: Arc<extensions::Registry>,
    scripts: Arc<scripts::Registry>,
    revision: u32,
}
impl ExtensionInput {
    pub fn new(draft: ModelConfigDraft) -> Self {
        Self {
            thinking: false,
            draft,
            binding: None,
        }
    }
}
impl Runtime {
    pub(crate) fn bind_extension(&self, input: &mut ChatRequest) {
        if let Some(extension) = &mut input.extension {
            extension.binding = Some((|| {
                let provider = self
                    .extension_providers()?
                    .into_iter()
                    .find(|p| p.id == input.provider)
                    .ok_or_else(|| crate::files::error("扩展已停用、卸载或供应商不存在"))?;
                Ok(Binding {
                    store: self.persistent_store()?,
                    extensions: self.extensions.clone(),
                    scripts: self.scripts.clone(),
                    revision: provider.revision,
                })
            })());
        }
    }
    pub(crate) fn start_extension_directory(
        &self,
        draft: ModelConfigDraft,
        key: String,
        headers: Vec<(String, String)>,
    ) -> Result<ChatRun, CoreError> {
        let provider = self
            .extension_providers()?
            .into_iter()
            .find(|p| p.id == draft.provider)
            .ok_or_else(|| crate::files::error("扩展已停用、卸载或供应商不存在"))?;
        let binding = Binding {
            store: self.persistent_store()?,
            extensions: self.extensions.clone(),
            scripts: self.scripts.clone(),
            revision: provider.revision,
        };
        let client = self.chat_client.get_or_init(chat_client).clone()?;
        let cancellation = self.cancellation.child_token();
        let finished = CancellationToken::new();
        let guard = finished.clone().drop_guard();
        let (queue, receiver) = mpsc::channel(8);
        let sender = EventSender {
            sender: queue,
            observation: None,
            cancellation: cancellation.clone(),
            workers: Default::default(),
        };
        tokio::spawn(async move {
            let _guard = guard;
            let work = async {
                let token = sender.cancellation.child_token();
                let _call_guard = token.clone().drop_guard();
                let host = Arc::new(
                    ModelHttpHost::with_client(client, &draft, key, headers).map_err(failure)?,
                );
                let payload = json!({"config":host.config(&draft,""),"providerId":extensions::provider_parts(&draft.provider).map_err(core_failure)?.1});
                let call = invocation(
                    &binding,
                    &draft.provider,
                    ProviderHandler::ListModels,
                    payload,
                    60_000,
                    &token,
                )?;
                let run = binding
                    .scripts
                    .clone()
                    .start_owned(call.request, token, Some(call.lease), Some(host))
                    .await
                    .map_err(failure)?;
                let run = track(run, None, &sender);
                let _ = sender.send(ChatEvent::Started).await;
                match run.next_event().await.map_err(failure)? {
                    Some(ScriptEvent::Completed(value)) => {
                        let models = models(value)?;
                        sender
                            .send(ChatEvent::Models(models))
                            .await
                            .map_err(|_| interrupted())?;
                        sender
                            .send(ChatEvent::Completed {
                                reason: "models".into(),
                                verified: None,
                            })
                            .await
                            .map_err(|_| interrupted())?;
                        Ok(())
                    }
                    Some(ScriptEvent::Failed(error)) => Err(failure(error)),
                    _ => Err(protocol()),
                }
            };
            let result = tokio::select! { biased; _ = sender.cancellation.cancelled() => None,
            result = work => Some(result) };
            finish_workers(&sender).await;
            if let Some(Err(error)) = result {
                let _ = sender.send(ChatEvent::Failed(error)).await;
            }
        });
        Ok(ChatRun {
            cancellation,
            finished,
            state: Mutex::new(RunState {
                receiver,
                terminal: false,
            }),
        })
    }
}
fn chat_client() -> Result<Arc<Client>, CoreError> {
    super::client().map(Arc::new)
}
fn core_failure(_: CoreError) -> ChatFailure {
    ChatFailure::new(
        ChatFailureKind::InvalidInput,
        "扩展已停用、变更或资源不可用",
    )
}
fn protocol() -> ChatFailure {
    ChatFailure::new(
        ChatFailureKind::Protocol,
        "扩展供应商返回了无效或不一致的结果",
    )
}
fn interrupted() -> ChatFailure {
    ChatFailure::new(
        ChatFailureKind::Interrupted,
        "扩展请求已停止，已等待资源释放",
    )
}
fn failure(error: ScriptFailure) -> ChatFailure {
    let kind = match error.kind {
        ScriptFailureKind::Timeout => ChatFailureKind::Timeout,
        ScriptFailureKind::Cancelled
        | ScriptFailureKind::Interrupted
        | ScriptFailureKind::RuntimeClosed => ChatFailureKind::Interrupted,
        ScriptFailureKind::Unsupported => ChatFailureKind::Unsupported,
        ScriptFailureKind::InvalidInput => ChatFailureKind::InvalidInput,
        ScriptFailureKind::Protocol | ScriptFailureKind::OutputLimit => ChatFailureKind::Protocol,
        _ => ChatFailureKind::Protocol,
    };
    ChatFailure::new(kind, "扩展供应商执行失败；未自动重试")
}
fn invocation(
    binding: &Binding,
    provider: &str,
    handler: ProviderHandler,
    payload: Value,
    timeout_ms: u32,
    token: &CancellationToken,
) -> Result<extensions::Invocation, ChatFailure> {
    binding
        .extensions
        .prepare(
            &binding.store,
            provider,
            binding.revision,
            extensions::ProviderCall {
                handler,
                payload,
                limits: ScriptLimits {
                    timeout_ms,
                    ..Default::default()
                },
            },
            token.clone(),
        )
        .map_err(core_failure)
}
fn track(
    run: scripts::ScriptRun,
    permit: Option<limits::Permit>,
    sender: &EventSender,
) -> Arc<scripts::ScriptRun> {
    let run = Arc::new(run);
    let waiting = run.clone();
    let worker = tokio::spawn(async move {
        waiting.wait_finished().await;
        drop(permit);
    });
    sender
        .workers
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .push(worker);
    run
}
async fn finish_workers(sender: &EventSender) {
    let workers = std::mem::take(
        &mut *sender
            .workers
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner),
    );
    for worker in workers {
        let _ = worker.await;
    }
}
pub(super) async fn execute(
    client: Arc<Client>,
    input: &mut ChatRequest,
    sender: &EventSender,
) -> Result<String, ChatFailure> {
    let extension = input.extension.as_ref().ok_or_else(protocol)?;
    let binding = extension
        .binding
        .as_ref()
        .ok_or_else(protocol)?
        .as_ref()
        .map_err(|_| core_failure(crate::files::error("扩展不可用")))?
        .clone();
    let draft = extension.draft.clone();
    let thinking = extension.thinking;
    if !(100..=600_000).contains(&input.timeout_ms)
        || input.model.trim().is_empty()
        || input.model.len() > 512
        || input.messages.is_empty()
        || input.messages.len() > 1000
        || input.messages.iter().any(|m| {
            !matches!(m.role.as_str(), "system" | "user" | "assistant") || m.content.contains('\0')
        })
        || input
            .messages
            .iter()
            .map(|m| m.content.len())
            .sum::<usize>()
            > 8 * 1024 * 1024
    {
        return Err(protocol());
    }
    if input
        .probe
        .as_ref()
        .is_some_and(|p| p.media.is_some() || p.tool.as_ref().is_some_and(|t| t.native))
    {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "扩展媒体与原生工具探测合同尚未接入",
        ));
    }
    let parameters: Value = serde_json::from_str(&input.parameters).map_err(|_| protocol())?;
    let object = parameters.as_object().ok_or_else(protocol)?;
    let model_parameters: Vec<_> = object.iter().map(|(name,value)| json!({"id":name,"name":name,"value":value,
        "type":if value.is_string(){"STRING"}else if value.is_boolean(){"BOOLEAN"}else if value.is_i64()||value.is_u64(){"INT"}else{"FLOAT"},
            "category":"OTHER","enabled":true,"custom":true})).collect();
    let host = Arc::new(
        ModelHttpHost::with_client(client, &draft, input.api_key.clone(), input.headers.clone())
            .map_err(failure)?,
    );
    let mut history: Vec<_> = input.messages.iter().map(|m| json!({"kind":m.role.to_uppercase(),"content":m.content,"toolName":null,"metadata":{}})).collect();
    if let Some(tool) = input
        .probe
        .as_ref()
        .and_then(|p| p.tool.as_ref())
        .filter(|t| t.second)
    {
        history.extend([json!({"kind":"ASSISTANT","content":tool.first_text}),
            json!({"kind":"USER","content":format!("<tool_result name=\"echo\" status=\"success\">{}</tool_result>",tool.code)})]);
    }
    let token = sender.cancellation.child_token();
    let _guard = token.clone().drop_guard();
    let payload = json!({"config":host.config(&draft,&input.model),"providerId":extensions::provider_parts(&input.provider).map_err(core_failure)?.1,
        "chatHistory":history,"modelParameters":model_parameters,"enableThinking":thinking,
        "stream":input.stream,"availableTools":null,"preserveThinkInHistory":false,"enableRetry":false,"timeout":input.timeout_ms});
    // 先登记包租约再等配额，撤销也能停止排队中的请求；配额只获取一次。
    let call = invocation(
        &binding,
        &input.provider,
        ProviderHandler::SendMessage,
        payload,
        input.timeout_ms,
        &token,
    )?;
    let timeout_ms = input.timeout_ms;
    let operation = async {
        let permit = match &input.admission {
            Some(gate) => {
                tokio::select! { biased; _ = token.cancelled() => return Err(interrupted()), permit = gate.acquire() => Some(permit) }
            }
            None => None,
        };
        let run = binding
            .scripts
            .clone()
            .start_owned(call.request, token.clone(), Some(call.lease), Some(host))
            .await
            .map_err(failure)?;
        let run = track(run, permit, sender);
        let _ = sender.send(ChatEvent::Started).await;
        let mut accumulated = String::new();
        let mut latest_usage = None;
        let mut emitted = false;
        loop {
            match run.next_event().await.map_err(failure)? {
                Some(ScriptEvent::Intermediate(value)) => {
                    let chunk = text(&value)?;
                    if chunk.len() > 8 * 1024 * 1024 - accumulated.len() {
                        return Err(protocol());
                    }
                    accumulated.push_str(&chunk);
                    if input.stream && !chunk.is_empty() {
                        deliver(&chunk, input, sender).await?;
                        emitted = true;
                    }
                    if let Some(usage) = usage(&value)? {
                        let _ = sender.send(usage.clone()).await;
                        latest_usage = Some(usage);
                    }
                }
                Some(ScriptEvent::Completed(value)) => {
                    let final_text = text(&value)?;
                    if final_text.trim().is_empty() {
                        return Err(protocol());
                    }
                    if accumulated.is_empty() {
                        accumulated = final_text;
                    } else if final_text != accumulated {
                        return Err(protocol());
                    }
                    if accumulated.trim().is_empty() || accumulated.len() > 8 * 1024 * 1024 {
                        return Err(protocol());
                    }
                    if let Some(usage) = usage(&value)? {
                        latest_usage = Some(usage);
                    }
                    if !input.stream || !emitted {
                        deliver(&accumulated, input, sender).await?;
                    }
                    // 只有终态有正文的供应商也必须投影；中间只有usage不能吞掉全文。
                    if let Some(usage) = latest_usage {
                        let _ = sender.send(usage).await;
                    }
                    let reason = value
                        .get("finishReason")
                        .or_else(|| value.get("finish_reason"))
                        .and_then(Value::as_str)
                        .unwrap_or("stop");
                    if !matches!(reason, "stop" | "length" | "content_filter") {
                        return Err(protocol());
                    }
                    return Ok(reason.to_owned());
                }
                Some(ScriptEvent::Failed(error)) => return Err(failure(error)),
                None => return Err(protocol()),
            }
        }
    };
    tokio::time::timeout(Duration::from_millis(timeout_ms.into()), operation)
        .await
        .map_err(|_| ChatFailure::new(ChatFailureKind::Timeout, "扩展请求超时；已等待资源释放"))?
}
async fn deliver(
    text: &str,
    input: &mut ChatRequest,
    sender: &EventSender,
) -> Result<(), ChatFailure> {
    if let Some(probe) = &mut input.probe {
        probe.append(text)?;
    }
    let mut remaining = text;
    while !remaining.is_empty() {
        let mut end = remaining.len().min(1024 * 1024);
        while !remaining.is_char_boundary(end) {
            end -= 1;
        }
        sender
            .send(ChatEvent::Text(remaining[..end].to_owned()))
            .await
            .map_err(|_| interrupted())?;
        remaining = &remaining[end..];
    }
    Ok(())
}
fn text(value: &Value) -> Result<String, ChatFailure> {
    if let Some(text) = value.as_str() {
        return Ok(text.to_owned());
    }
    let object = value.as_object().ok_or_else(protocol)?;
    if object.contains_key("error") || object.get("success") == Some(&Value::Bool(false)) {
        return Err(protocol());
    }
    let mut result = String::new();
    for key in ["chunk", "chunks", "text", "content"] {
        if let Some(value) = object.get(key) {
            if key == "chunks" {
                for part in value.as_array().ok_or_else(protocol)? {
                    result.push_str(part.as_str().ok_or_else(protocol)?);
                }
            } else {
                result.push_str(value.as_str().ok_or_else(protocol)?);
            }
        }
    }
    Ok(result)
}
fn usage(value: &Value) -> Result<Option<ChatEvent>, ChatFailure> {
    let Some(value) = value.get("usage") else {
        return Ok(None);
    };
    let value = value.as_object().ok_or_else(protocol)?;
    let count = |aliases: &[&str]| -> Result<Option<u64>, ChatFailure> {
        let mut found = None;
        for key in aliases {
            if let Some(raw) = value.get(*key) {
                let n = raw
                    .as_u64()
                    .or_else(|| raw.as_str().and_then(|s| s.parse::<u64>().ok()))
                    .filter(|n| *n <= i32::MAX as u64)
                    .ok_or_else(protocol)?;
                if found.is_some_and(|previous| previous != n) {
                    return Err(protocol());
                }
                found = Some(n);
            }
        }
        Ok(found)
    };
    let input = count(&["input", "inputTokens"])?;
    let output = count(&["output", "outputTokens"])?;
    let cache_read = count(&["cachedInput", "cachedInputTokens"])?;
    let cache_write = count(&["cacheWrite", "cacheWriteTokens", "cacheCreationInputTokens"])?;
    let reasoning = count(&["reasoning", "reasoningTokens"])?;
    if [input, output, cache_read, cache_write, reasoning]
        .iter()
        .all(Option::is_none)
    {
        return Err(protocol());
    }
    Ok(Some(ChatEvent::Usage {
        input: input.unwrap_or(0),
        output: output.unwrap_or(0),
        output_reported: output.is_some(),
        total: input.unwrap_or(0) + output.unwrap_or(0),
        cache_read,
        cache_write,
        reasoning,
    }))
}
fn models(value: Value) -> Result<Vec<directory::ModelEntry>, ChatFailure> {
    let items = value.get("models").unwrap_or(&value);
    let values = items
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_else(|| std::slice::from_ref(items));
    if values.len() > 20_000 {
        return Err(protocol());
    }
    let mut ids = HashSet::new();
    let mut models = Vec::new();
    for value in values {
        let id = value
            .as_str()
            .or_else(|| {
                ["id", "name", "model"].iter().find_map(|key| {
                    value
                        .get(*key)
                        .and_then(Value::as_str)
                        .filter(|s| !s.trim().is_empty())
                })
            })
            .ok_or_else(protocol)?;
        let id = id.trim();
        let name = ["name", "displayName", "title"]
            .iter()
            .find_map(|key| {
                value
                    .get(*key)
                    .and_then(Value::as_str)
                    .filter(|s| !s.trim().is_empty())
            })
            .unwrap_or(id)
            .trim();
        if id.trim().is_empty()
            || id.len() > 512
            || name.trim().is_empty()
            || name.len() > 1024
            || id.chars().any(char::is_control)
            || name.chars().any(char::is_control)
            || !ids.insert(id)
        {
            return Err(protocol());
        }
        models.push(directory::ModelEntry {
            id: id.into(),
            name: name.into(),
        });
    }
    Ok(models)
}
