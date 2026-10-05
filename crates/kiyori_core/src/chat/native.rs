//! 平台只拥有推理句柄；请求、取消、背压和资源租约仍属于共享核心。
use super::*;
use crate::{models::ModelOptions, runtime::Runtime, storage::AppStore};
use std::{fs::File, path::PathBuf, sync::Arc, time::Instant};
#[cfg(test)]
#[path = "native_tests.rs"]
mod tests;

pub struct ModelResource {
    pub root: PathBuf,
    pub model_path: PathBuf,
    pub cache: PathBuf,
    pub config: Value,
    pub(crate) _guard: File,
}
pub struct InferenceRequest {
    pub provider: String,
    pub resource: ModelResource,
    pub options: ModelOptions,
    pub parameters: Value,
    pub messages: Vec<ChatMessage>,
}
#[derive(Debug)]
pub struct InferenceResult {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub reason: String,
}
/// 同步接口仅在blocking worker调用；stop和emit返回false均要求尽快结束并析构。
pub trait InferenceAdapter: Send + Sync {
    fn generate(
        &self,
        input: &InferenceRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<InferenceResult, ChatFailure>;
}
type Resolver = Arc<dyn Fn(&str, &str) -> Result<ModelResource, CoreError> + Send + Sync>;
pub struct LocalInput {
    pub options: ModelOptions,
    pub thinking: bool,
    adapter: Option<Arc<dyn InferenceAdapter>>,
    resource: Option<Resolver>,
}
impl LocalInput {
    pub fn new(options: ModelOptions) -> Self {
        Self {
            options,
            thinking: false,
            adapter: None,
            resource: None,
        }
    }
}
impl Runtime {
    pub fn set_inference_adapter(
        &self,
        adapter: Arc<dyn InferenceAdapter>,
    ) -> Result<(), CoreError> {
        self.ensure_open()?;
        self.inference.set(adapter).map_err(|_| CoreError {
            code: ErrorCode::InvalidInput,
            message: "本地推理adapter已装配".into(),
        })
    }
    pub(crate) fn bind_inference(&self, request: &mut ChatRequest) {
        self.bind_extension(request);
        if let Some(local) = &mut request.local {
            local.adapter = self.inference.get().cloned();
            let state = self.store.clone();
            let closed = self.cancellation.clone();
            local.resource = Some(Arc::new(move |provider, model| {
                if closed.is_cancelled() {
                    return Err(CoreError {
                        code: ErrorCode::RuntimeClosed,
                        message: "Runtime已关闭".into(),
                    });
                }
                let store = state
                    .lock()
                    .map_err(|_| crate::files::error("资源存储锁不可用"))?
                    .as_ref()
                    .cloned()
                    .ok_or_else(|| crate::files::error("本地模型需要持久资源存储"))?;
                store.inference_resource(provider, model)
            }));
        }
        if let Some(prelude) = &mut request.prelude {
            self.bind_inference(&mut prelude.request);
        }
    }
}

pub(super) async fn execute(
    input: &mut ChatRequest,
    sender: &EventSender,
) -> Result<String, ChatFailure> {
    let local = input.local.as_ref().ok_or_else(ChatFailure::protocol)?;
    let adapter = local.adapter.clone().ok_or_else(|| {
        ChatFailure::new(ChatFailureKind::Unsupported, "当前平台未装配本地模型推理")
    })?;
    let resolver = local
        .resource
        .clone()
        .ok_or_else(|| ChatFailure::new(ChatFailureKind::InvalidInput, "本地模型资源未装配"))?;
    if input.messages.is_empty()
        || input.messages.len() > 1000
        || input
            .messages
            .iter()
            .try_fold(0usize, |total, m| total.checked_add(m.content.len()))
            .is_none_or(|total| total > 8 * 1024 * 1024)
        || input.messages.iter().any(|m| {
            !matches!(m.role.as_str(), "system" | "user" | "assistant") || m.content.contains('\0')
        })
        || !(100..=600_000).contains(&input.timeout_ms)
    {
        return Err(ChatFailure::new(
            ChatFailureKind::InvalidInput,
            "本地模型消息或超时无效",
        ));
    }
    if input
        .probe
        .as_ref()
        .is_some_and(|p| p.media.is_some() || p.tool.as_ref().is_some_and(|t| t.native))
    {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "本地模型媒体与原生工具模板尚未接入",
        ));
    }
    if input.provider == "MNN"
        && input
            .messages
            .iter()
            .any(|m| m.content.contains("<img>") || m.content.contains("<audio>"))
    {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "本地媒体标签需要受控资源，尚未接入",
        ));
    }
    let mut parameters: Value = serde_json::from_str(&input.parameters)
        .map_err(|_| ChatFailure::new(ChatFailureKind::InvalidInput, "本地参数不是JSON对象"))?;
    parameters
        .as_object_mut()
        .ok_or_else(ChatFailure::protocol)?
        .entry("enable_thinking")
        .or_insert(Value::Bool(local.thinking));
    let mut messages = input.messages.clone();
    if let Some(probe) = &input.probe
        && let Some(tool) = &probe.tool
        && tool.second
    {
        messages.extend([
            ChatMessage {
                role: "assistant".into(),
                content: tool.first_text.clone(),
            },
            ChatMessage {
                role: "user".into(),
                content: format!(
                    "<tool_result name=\"echo\" status=\"success\">{}</tool_result>",
                    tool.code
                ),
            },
        ]);
    }
    let provider = input.provider.clone();
    let model = input.model.clone();
    let options = local.options.clone();
    let permit = match &input.admission {
        Some(gate) => Some(gate.acquire().await),
        None => None,
    };
    let deadline = Instant::now() + Duration::from_millis(input.timeout_ms.into());
    let cancellation = sender.cancellation.child_token();
    let guard = cancellation.clone().drop_guard();
    let (queue, mut receive) = mpsc::channel::<Vec<u8>>(8);
    let (finish, result) = tokio::sync::oneshot::channel();
    let worker = tokio::task::spawn_blocking(move || {
        let _permit = permit;
        let stopped = || cancellation.is_cancelled() || Instant::now() >= deadline;
        let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let resource = resolver(&provider, &model)
                .map_err(|e| ChatFailure::new(ChatFailureKind::InvalidInput, &e.message))?;
            if stopped() {
                return Err(ChatFailure::new(
                    ChatFailureKind::Timeout,
                    "本地模型请求已停止",
                ));
            }
            let request = InferenceRequest {
                provider,
                resource,
                options,
                parameters,
                messages,
            };
            let mut total = 0usize;
            let mut output_limit = false;
            let mut emit = |bytes: &[u8]| {
                if bytes.len() > 1024 * 1024 || bytes.len() > 8 * 1024 * 1024 - total {
                    output_limit = true;
                    return false;
                }
                if stopped() {
                    return false;
                }
                total += bytes.len();
                let mut bytes = bytes.to_vec();
                loop {
                    if stopped() {
                        return false;
                    }
                    match queue.try_send(bytes) {
                        Ok(()) => return true,
                        Err(mpsc::error::TrySendError::Full(returned)) => {
                            bytes = returned;
                            std::thread::sleep(Duration::from_millis(1));
                        }
                        Err(_) => return false,
                    }
                }
            };
            let outcome = adapter.generate(&request, &stopped, &mut emit);
            if output_limit {
                Err(ChatFailure::new(
                    ChatFailureKind::Protocol,
                    "本地模型输出超过分片或总大小上限",
                ))
            } else {
                outcome
            }
        }))
        .unwrap_or_else(|_| {
            Err(ChatFailure::new(
                ChatFailureKind::Interrupted,
                "本地推理worker异常结束",
            ))
        });
        let outcome = if Instant::now() >= deadline {
            Err(ChatFailure::new(
                ChatFailureKind::Timeout,
                "本地模型推理超时；已等待资源释放",
            ))
        } else {
            outcome
        };
        drop(queue);
        let _ = finish.send(outcome);
    });
    sender
        .workers
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .push(worker);
    let _guard = guard;
    let _ = sender.send(ChatEvent::Started).await;
    let mut pending = Vec::new();
    let mut buffered = String::new();
    while let Some(bytes) = receive.recv().await {
        pending.extend(bytes);
        let (valid, incomplete) = match std::str::from_utf8(&pending) {
            Ok(_) => (pending.len(), false),
            Err(e) if e.error_len().is_none() => (e.valid_up_to(), true),
            Err(_) => {
                return Err(ChatFailure::new(
                    ChatFailureKind::Protocol,
                    "本地模型输出不是有效UTF-8",
                ));
            }
        };
        if valid > 0 {
            let text = std::str::from_utf8(&pending[..valid])
                .map_err(|_| ChatFailure::protocol())?
                .to_owned();
            if let Some(probe) = &mut input.probe {
                probe.append(&text)?;
            }
            if input.stream {
                send_text(sender, &text).await?;
            } else {
                buffered.push_str(&text);
            }
            pending.drain(..valid);
        }
        if !incomplete && !pending.is_empty() {
            return Err(ChatFailure::protocol());
        }
    }
    let result = result
        .await
        .map_err(|_| ChatFailure::new(ChatFailureKind::Interrupted, "本地推理结果丢失"))??;
    if !pending.is_empty() {
        return Err(ChatFailure::new(
            ChatFailureKind::Protocol,
            "本地模型结束于不完整UTF-8",
        ));
    }
    if !buffered.is_empty() {
        send_text(sender, &buffered).await?;
    }
    let _ = sender
        .send(ChatEvent::Usage {
            input: result.input_tokens,
            output: result.output_tokens,
            total: result.input_tokens.saturating_add(result.output_tokens),
            output_reported: true,
            cache_read: None,
            cache_write: None,
            reasoning: None,
        })
        .await;
    Ok(result.reason)
}

/// 非流式同样分事件交付完整正文；跨token残留的UTF-8字节也不能撑大单事件。
async fn send_text(sender: &EventSender, mut text: &str) -> Result<(), ChatFailure> {
    while !text.is_empty() {
        let mut end = text.len().min(1024 * 1024);
        while !text.is_char_boundary(end) {
            end -= 1;
        }
        sender
            .send(ChatEvent::Text(text[..end].to_owned()))
            .await
            .map_err(|_| ChatFailure::new(ChatFailureKind::Interrupted, "本地输出订阅已关闭"))?;
        text = &text[end..];
    }
    Ok(())
}

impl AppStore {
    fn inference_resource(&self, provider: &str, model: &str) -> Result<ModelResource, CoreError> {
        use rusqlite::OptionalExtension;
        let prefix = match provider {
            "MNN" => "mnn",
            "LLAMA_CPP" => "llama",
            _ => return Err(crate::files::error("本地提供方无效")),
        };
        let id: String = self
            .connection
            .lock()
            .map_err(|_| crate::files::error("资源存储锁不可用"))?
            .query_row(
                "SELECT id FROM transfers WHERE owner=?1 AND phase='completed'",
                [format!("{prefix}:{model}")],
                |r| r.get(0),
            )
            .optional()
            .map_err(|_| crate::files::error("模型资源读取失败"))?
            .ok_or_else(|| crate::files::error("本地模型尚未下载或导入完成"))?;
        let guard = self.transfer_lock(&id)?;
        let (spec, snapshot) = self.transfer(&id)?;
        if snapshot.phase != "completed" || !snapshot.current_file.is_empty() {
            return Err(crate::files::error("本地模型校验未完成"));
        }
        for file in &spec.files {
            if file.path.split('/').next() == Some(".inference-cache") {
                return Err(crate::files::error("模型包不得占用推理缓存目录"));
            }
            let path = self.managed_path(&id, &file.path)?;
            if !path.is_file()
                || path
                    .metadata()
                    .map_err(|_| crate::files::error("模型文件状态不可读"))?
                    .len()
                    != file.size
            {
                return Err(crate::files::error("模型资源文件已变化，请重新下载"));
            }
        }
        let root = self.managed_path(&id, "")?;
        let cache = self.managed_path(&id, ".inference-cache")?;
        std::fs::create_dir_all(&cache).map_err(|_| crate::files::error("模型缓存目录不可用"))?;
        let (model_path, config) = if provider == "MNN" {
            let mut config = self.read_model_config(&spec, &id, "config.json")?;
            validate_paths(&config, &spec)?;
            let info_path = config
                .get("llm_config")
                .and_then(Value::as_str)
                .unwrap_or("llm_config.json");
            let info = self.read_model_config(&spec, &id, info_path)?;
            validate_paths(&info, &spec)?;
            config
                .as_object_mut()
                .ok_or_else(|| crate::files::error("模型配置不是对象"))?
                .extend(
                    info.as_object()
                        .ok_or_else(|| crate::files::error("模型信息不是对象"))?
                        .clone(),
                );
            if config
                .get("speculative_type")
                .and_then(Value::as_str)
                .is_some_and(|v| !v.is_empty())
            {
                return Err(crate::files::error("本地推测解码附属模型尚未接入"));
            }
            // 上游load会额外读取context.json。先验证并合入内存，再让它只读宿主生成的空对象，
            // 防止包内context覆盖请求的thinking设置或插入未经验证的模板上下文。
            let context = config
                .get("context_file")
                .and_then(Value::as_str)
                .unwrap_or("context.json")
                .to_owned();
            if self.managed_path(&id, &context)?.exists() {
                let context = self.read_model_config(&spec, &id, &context)?;
                if !context.is_object() {
                    return Err(crate::files::error("模型模板上下文不是对象"));
                }
                if !config["jinja"].is_object() {
                    config["jinja"] = json!({});
                }
                if !config["jinja"]["context"].is_object() {
                    config["jinja"]["context"] = json!({});
                }
                config["jinja"]["context"]
                    .as_object_mut()
                    .ok_or_else(|| crate::files::error("模型模板上下文无效"))?
                    .extend(
                        context
                            .as_object()
                            .ok_or_else(|| crate::files::error("模型模板上下文无效"))?
                            .clone(),
                    );
            }
            let empty_context = self.managed_path(&id, ".inference-cache/context.json")?;
            std::fs::write(empty_context, b"{}")
                .map_err(|_| crate::files::error("模型模板缓存不可写"))?;
            config["context_file"] = json!(".inference-cache/context.json");
            // 固定引擎还会按约定名读取附属权重；存在的文件都必须来自已验证清单。
            for default in [
                "embeddings_bf16.bin",
                "visual.mnn",
                "visual.mnn.weight",
                "audio.mnn",
                "audio.mnn.weight",
                "ple_embeddings_bf16.bin",
                "talker.mnn",
                "talker.mnn.weight",
                "spk_dict.mnn",
                "predit.mnn",
                "dit.mnn",
                "bigvgan.mnn",
            ] {
                if self.managed_path(&id, default)?.exists()
                    && !spec.files.iter().any(|f| f.path == default)
                {
                    return Err(crate::files::error("模型包含未校验的附属文件"));
                }
            }
            let tokenizer = config
                .get("tokenizer_file")
                .and_then(Value::as_str)
                .unwrap_or("tokenizer.txt");
            let model_file = config
                .get("llm_model")
                .and_then(Value::as_str)
                .unwrap_or("llm.mnn");
            for path in [
                tokenizer,
                model_file,
                config
                    .get("llm_weight")
                    .and_then(Value::as_str)
                    .unwrap_or("llm.mnn.weight"),
            ] {
                if !spec.files.iter().any(|f| f.path == path)
                    || !self.managed_path(&id, path)?.is_file()
                {
                    return Err(crate::files::error("模型配置引用未校验文件"));
                }
            }
            (self.managed_path(&id, model_file)?, config)
        } else {
            let file = spec
                .files
                .iter()
                .find(|f| f.path == model)
                .or_else(|| {
                    let mut files = spec
                        .files
                        .iter()
                        .filter(|f| f.path.to_ascii_lowercase().ends_with(".gguf"));
                    let first = files.next();
                    if files.next().is_some() { None } else { first }
                })
                .ok_or_else(|| crate::files::error("GGUF模型文件不明确"))?;
            (self.managed_path(&id, &file.path)?, json!({}))
        };
        if !model_path.is_file() {
            return Err(crate::files::error("模型文件已不可用"));
        }
        Ok(ModelResource {
            root,
            model_path,
            cache,
            config,
            _guard: guard,
        })
    }
    fn read_model_config(
        &self,
        spec: &crate::downloads::TransferSpec,
        id: &str,
        relative: &str,
    ) -> Result<Value, CoreError> {
        use ring::digest::{SHA256, digest};
        let file = spec
            .files
            .iter()
            .find(|f| f.path == relative && f.size <= 2 * 1024 * 1024)
            .ok_or_else(|| crate::files::error("模型配置未校验或超过2 MiB"))?;
        let path = self.managed_path(id, relative)?;
        if path
            .metadata()
            .map_err(|_| crate::files::error("模型配置不可读"))?
            .len()
            != file.size
        {
            return Err(crate::files::error("模型配置大小已变化"));
        }
        let bytes = std::fs::read(path).map_err(|_| crate::files::error("模型配置不可读"))?;
        let hash = digest(&SHA256, &bytes)
            .as_ref()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>();
        if !hash.eq_ignore_ascii_case(&file.sha256) {
            return Err(crate::files::error("模型配置校验失败"));
        }
        serde_json::from_slice(&bytes).map_err(|_| crate::files::error("模型配置JSON无效"))
    }
}
fn validate_paths(value: &Value, spec: &crate::downloads::TransferSpec) -> Result<(), CoreError> {
    match value {
        Value::Object(object) => {
            for (key, value) in object {
                if matches!(
                    key.as_str(),
                    "base_dir" | "tmp_path" | "prefix_cache_path" | "npu_model_dir"
                ) {
                    return Err(crate::files::error("模型包不得指定宿主路径或缓存目录"));
                }
                if key.ends_with("_path")
                    || key.ends_with("_dir")
                    || matches!(key.as_str(), "lora" | "block_model")
                {
                    return Err(crate::files::error("模型包包含未授权路径参数"));
                }
                if (key.ends_with("_file")
                    || key.ends_with("_model")
                    || key.ends_with("_weight")
                    || matches!(
                        key.as_str(),
                        "llm_config"
                            | "spk_dict"
                            | "eagle_fc"
                            | "eagle_d2t"
                            | "dflash_fc"
                            | "dflash_lmhead"
                    ))
                    && !value.as_str().is_some_and(|s| {
                        crate::files::valid_relative(s) && spec.files.iter().any(|f| f.path == s)
                    })
                {
                    return Err(crate::files::error("模型配置引用未校验文件或无效相对路径"));
                }
                validate_paths(value, spec)?;
            }
        }
        Value::Array(values) => {
            for value in values {
                validate_paths(value, spec)?;
            }
        }
        _ => {}
    }
    Ok(())
}
