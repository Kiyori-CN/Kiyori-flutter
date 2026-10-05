//! 受限脚本执行端口。核心拥有预算和生命周期，平台仅持有单次执行器句柄。
use crate::runtime::Runtime;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    fmt,
    sync::{Arc, Condvar, Mutex},
    time::{Duration, Instant},
};
use tokio::sync::{Semaphore, mpsc, oneshot};
use tokio_util::sync::CancellationToken;

const MAX_SOURCE: usize = 2 * 1024 * 1024;
const MAX_EVENT: usize = 1024 * 1024;
const MAX_OUTPUT: usize = 8 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScriptFailureKind {
    InvalidInput,
    Unsupported,
    RuntimeClosed,
    ConcurrentRead,
    Cancelled,
    Timeout,
    OutputLimit,
    JobLimit,
    UnresolvedPromise,
    Execution,
    Interrupted,
    Protocol,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScriptFailure {
    pub kind: ScriptFailureKind,
}
impl From<ScriptFailureKind> for ScriptFailure {
    fn from(kind: ScriptFailureKind) -> Self {
        Self { kind }
    }
}
impl fmt::Display for ScriptFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // 执行器异常可能含源码、输入和凭据；只交付稳定原因，不转发JS异常正文。
        write!(f, "Script execution failed: {:?}", self.kind)
    }
}
impl std::error::Error for ScriptFailure {}

#[derive(Debug, Clone, Copy)]
pub struct ScriptLimits {
    pub timeout_ms: u32,
    pub memory_bytes: usize,
    pub stack_bytes: usize,
    pub max_jobs: u32,
}
impl Default for ScriptLimits {
    fn default() -> Self {
        Self {
            timeout_ms: 30_000,
            memory_bytes: 32 * 1024 * 1024,
            stack_bytes: 512 * 1024,
            max_jobs: 100_000,
        }
    }
}
impl ScriptLimits {
    fn valid(self) -> bool {
        (10..=600_000).contains(&self.timeout_ms)
            && (1024 * 1024..=128 * 1024 * 1024).contains(&self.memory_bytes)
            && (64 * 1024..=1024 * 1024).contains(&self.stack_bytes)
            && (1..=100_000).contains(&self.max_jobs)
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ProviderHandler {
    ListModels,
    SendMessage,
    TestConnection,
    CalculateInputTokens,
}
#[derive(Debug, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum ScriptOperation {
    Register,
    Invoke {
        provider_id: String,
        handler: ProviderHandler,
        payload: Value,
    },
}
pub struct ScriptRequest {
    pub source: String,
    pub operation: ScriptOperation,
    pub limits: ScriptLimits,
}
impl ScriptRequest {
    fn valid(&self) -> bool {
        self.limits.valid()
            && !self.source.is_empty()
            && self.source.len() <= MAX_SOURCE
            && !self.source.contains('\0')
            && match &self.operation {
                ScriptOperation::Register => true,
                ScriptOperation::Invoke {
                    provider_id,
                    payload,
                    ..
                } => valid_id(provider_id) && payload.to_string().len() <= MAX_EVENT,
            }
    }
}
pub fn valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 128
        && id
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'-' | b'.'))
}
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProviderRegistration {
    pub id: String,
    pub display_name: String,
    pub description: String,
}
pub fn registrations(value: Value) -> Result<Vec<ProviderRegistration>, ScriptFailure> {
    let values: Vec<ProviderRegistration> =
        serde_json::from_value(value).map_err(|_| ScriptFailureKind::Protocol)?;
    let mut ids = std::collections::HashSet::new();
    if values.len() > 32
        || values.iter().any(|p| {
            !valid_id(&p.id)
                || p.display_name.trim().is_empty()
                || p.display_name.len() > 1024
                || p.description.len() > 4096
                || p.display_name.chars().any(char::is_control)
                || p.description.contains('\0')
                || !ids.insert(&p.id)
        })
    {
        return Err(ScriptFailureKind::Protocol.into());
    }
    Ok(values)
}

/// 只在blocking worker调用。emit=false或stopped=true必须结束并释放所有句柄。
pub trait ScriptAdapter: Send + Sync {
    fn execute(
        &self,
        request: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure>;
}

pub(crate) struct Registry {
    adapter: std::sync::OnceLock<Arc<dyn ScriptAdapter>>,
    slots: Arc<Semaphore>,
    active: Arc<(Mutex<usize>, Condvar)>,
}
impl Default for Registry {
    fn default() -> Self {
        Self {
            adapter: Default::default(),
            slots: Arc::new(Semaphore::new(4)),
            active: Arc::new((Mutex::new(0), Condvar::new())),
        }
    }
}
struct WorkerGuard(Arc<(Mutex<usize>, Condvar)>);
impl Drop for WorkerGuard {
    fn drop(&mut self) {
        let (lock, wake) = &*self.0;
        let mut count = lock
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        *count -= 1;
        wake.notify_all();
    }
}
impl Registry {
    pub(crate) fn with_adapter(adapter: Arc<dyn ScriptAdapter>) -> Self {
        Self {
            adapter: std::sync::OnceLock::from(adapter),
            ..Default::default()
        }
    }
    fn reserve(&self, cancelled: &CancellationToken) -> Result<WorkerGuard, ScriptFailure> {
        let mut count = self
            .active
            .0
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if cancelled.is_cancelled() {
            return Err(ScriptFailureKind::RuntimeClosed.into());
        }
        *count += 1;
        Ok(WorkerGuard(self.active.clone()))
    }
    pub(crate) fn wait_idle(&self) {
        let (lock, wake) = &*self.active;
        let mut count = lock
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        while *count != 0 {
            count = wake
                .wait(count)
                .unwrap_or_else(std::sync::PoisonError::into_inner);
        }
    }
}

#[derive(Debug)]
pub enum ScriptEvent {
    Intermediate(Value),
    Completed(Value),
    Failed(ScriptFailure),
}
struct ReadState {
    queue: mpsc::Receiver<Value>,
    outcome: Option<oneshot::Receiver<Result<Value, ScriptFailure>>>,
    terminal: bool,
}
pub struct ScriptRun {
    cancellation: CancellationToken,
    finished: CancellationToken,
    state: tokio::sync::Mutex<ReadState>,
}
impl Drop for ScriptRun {
    fn drop(&mut self) {
        self.cancellation.cancel();
    }
}
impl ScriptRun {
    pub fn cancel(&self) {
        self.cancellation.cancel();
    }
    pub async fn next_event(&self) -> Result<Option<ScriptEvent>, ScriptFailure> {
        let mut state = self
            .state
            .try_lock()
            .map_err(|_| ScriptFailureKind::ConcurrentRead)?;
        if state.terminal {
            return Ok(None);
        }
        if !self.cancellation.is_cancelled() {
            tokio::select! {
                biased;
                _ = self.cancellation.cancelled() => {},
                value = state.queue.recv() => {
                    if let Some(value) = value {
                        return Ok(Some(ScriptEvent::Intermediate(value)));
                    }
                }
            }
        }
        state.queue.close();
        // 超时/取消也必须等待RAII析构；最后结果不走有界队列，关闭不依赖消费者。
        let outcome = state.outcome.as_mut().ok_or(ScriptFailureKind::Protocol)?;
        let result = outcome
            .await
            .unwrap_or_else(|_| Err(ScriptFailureKind::Interrupted.into()));
        state.outcome.take();
        state.terminal = true;
        let result = if self.cancellation.is_cancelled() {
            Err(ScriptFailureKind::Cancelled.into())
        } else {
            result
        };
        Ok(Some(match result {
            Ok(value) => ScriptEvent::Completed(value),
            Err(error) => ScriptEvent::Failed(error),
        }))
    }
    pub async fn cancel_and_wait(&self) -> Result<(), ScriptFailure> {
        self.cancel();
        // 停止无需抢占事件读取者；页面可在订阅next_event的同时等待析构。
        self.finished.cancelled().await;
        Ok(())
    }
}
impl Runtime {
    pub fn set_script_adapter(&self, adapter: Arc<dyn ScriptAdapter>) -> Result<(), ScriptFailure> {
        if self.cancellation.is_cancelled() {
            return Err(ScriptFailureKind::RuntimeClosed.into());
        }
        self.scripts
            .adapter
            .set(adapter)
            .map_err(|_| ScriptFailureKind::InvalidInput.into())
    }
    pub async fn start_script(&self, request: ScriptRequest) -> Result<ScriptRun, ScriptFailure> {
        if self.cancellation.is_cancelled() {
            return Err(ScriptFailureKind::RuntimeClosed.into());
        }
        if !request.valid() {
            return Err(ScriptFailureKind::InvalidInput.into());
        }
        let adapter = self
            .scripts
            .adapter
            .get()
            .cloned()
            .ok_or(ScriptFailureKind::Unsupported)?;
        let deadline = Instant::now() + Duration::from_millis(request.limits.timeout_ms.into());
        let cancellation = self.cancellation.child_token();
        let drop_guard = cancellation.clone().drop_guard();
        let permit = tokio::select! {
            biased;
            _ = cancellation.cancelled() => return Err(ScriptFailureKind::RuntimeClosed.into()),
            _ = tokio::time::sleep_until(deadline.into()) => return Err(ScriptFailureKind::Timeout.into()),
            permit = self.scripts.slots.clone().acquire_owned() => permit.map_err(|_| ScriptFailureKind::Interrupted)?,
        };
        let active = self.scripts.reserve(&self.cancellation)?;
        let (queue, receive) = mpsc::channel(8);
        let (finish, result) = oneshot::channel();
        let finished = CancellationToken::new();
        let finish_guard = finished.clone().drop_guard();
        let stopped_token = cancellation.clone();
        tokio::task::spawn_blocking(move || {
            let _finish_guard = finish_guard;
            let stopped = || stopped_token.is_cancelled() || Instant::now() >= deadline;
            let mut total = 0usize;
            let mut events = 0u32;
            let mut emission_error = None;
            let mut emit = |bytes: &[u8]| {
                if bytes.len() > MAX_EVENT || bytes.len() > MAX_OUTPUT - total || events >= 65_536 {
                    emission_error = Some(ScriptFailureKind::OutputLimit);
                    return false;
                }
                if stopped() {
                    return false;
                }
                let Ok(mut value) = serde_json::from_slice::<Value>(bytes) else {
                    emission_error = Some(ScriptFailureKind::Protocol);
                    return false;
                };
                total += bytes.len();
                events += 1;
                loop {
                    if stopped() {
                        return false;
                    }
                    match queue.try_send(value) {
                        Ok(()) => return true,
                        Err(mpsc::error::TrySendError::Full(returned)) => {
                            value = returned;
                            std::thread::sleep(Duration::from_millis(1));
                        }
                        Err(_) => return false,
                    }
                }
            };
            let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                if stopped() {
                    return Err(ScriptFailureKind::Cancelled.into());
                }
                adapter.execute(&request, &stopped, &mut emit)
            }))
            .unwrap_or_else(|_| Err(ScriptFailureKind::Interrupted.into()));
            let outcome = if stopped_token.is_cancelled() {
                Err(ScriptFailureKind::Cancelled.into())
            } else if Instant::now() >= deadline {
                Err(ScriptFailureKind::Timeout.into())
            } else if let Some(kind) = emission_error {
                Err(kind.into())
            } else {
                outcome.and_then(|value| {
                    if value.to_string().len() > MAX_OUTPUT - total {
                        Err(ScriptFailureKind::OutputLimit.into())
                    } else {
                        Ok(value)
                    }
                })
            };
            // adapter已返回才释放并发与活跃标记，随后发布终态。
            drop(permit);
            drop(active);
            drop(queue);
            let _ = finish.send(outcome);
        });
        drop_guard.disarm();
        Ok(ScriptRun {
            cancellation,
            finished,
            state: tokio::sync::Mutex::new(ReadState {
                queue: receive,
                outcome: Some(result),
                terminal: false,
            }),
        })
    }
}

#[cfg(test)]
#[path = "scripts_tests.rs"]
mod tests;
