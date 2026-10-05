use crate::storage::AppStore;
use std::{fmt, time::Duration};
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    InvalidInput,
    RuntimeClosed,
    ConcurrentRead,
    Storage,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreError {
    pub code: ErrorCode,
    pub message: String,
}

impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for CoreError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskPhase {
    Started,
    Running,
    Completed,
    Cancelled,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskEvent {
    pub revision: u32,
    pub phase: TaskPhase,
    pub completed_steps: u32,
    pub total_steps: u32,
}

#[derive(Default)]
struct TaskState {
    started: bool,
    terminal: bool,
    revision: u32,
    completed: u32,
}

pub struct DiagnosticTask {
    cancellation: CancellationToken,
    state: Mutex<TaskState>,
    steps: u32,
    interval: Duration,
}

impl DiagnosticTask {
    pub fn cancel(&self) {
        self.cancellation.cancel();
    }

    /// 拉取提供背压：没有消费者就没有生产任务或累积队列。
    /// 持锁等待还保证终态只交付一次，并明确拒绝两个消费者争抢事件。
    pub async fn next_event(&self) -> Result<Option<TaskEvent>, CoreError> {
        let mut state = self.state.try_lock().map_err(|_| CoreError {
            code: ErrorCode::ConcurrentRead,
            message: "A task supports only one pending event reader.".into(),
        })?;
        if state.terminal {
            return Ok(None);
        }
        let phase = if self.cancellation.is_cancelled() {
            TaskPhase::Cancelled
        } else if !state.started {
            state.started = true;
            TaskPhase::Started
        } else {
            tokio::select! {
                biased;
                _ = self.cancellation.cancelled() => TaskPhase::Cancelled,
                _ = tokio::time::sleep(self.interval) => {
                    state.completed += 1;
                    if state.completed == self.steps {
                        TaskPhase::Completed
                    } else {
                        TaskPhase::Running
                    }
                }
            }
        };
        let event = TaskEvent {
            revision: state.revision,
            phase,
            completed_steps: state.completed,
            total_steps: self.steps,
        };
        state.revision += 1;
        state.terminal = matches!(phase, TaskPhase::Completed | TaskPhase::Cancelled);
        Ok(Some(event))
    }
}

pub struct Runtime {
    pub(crate) extensions: std::sync::Arc<crate::extensions::Registry>,
    pub(crate) scripts: std::sync::Arc<crate::scripts::Registry>,
    pub(crate) inference:
        std::sync::OnceLock<std::sync::Arc<dyn crate::chat::native::InferenceAdapter>>,
    pub(crate) chat_observations: std::sync::Mutex<
        std::collections::HashMap<
            String,
            std::sync::Arc<std::sync::Mutex<crate::chat::observation::Tracker>>,
        >,
    >,
    pub(crate) cancellation: CancellationToken,
    pub(crate) store: std::sync::Arc<std::sync::Mutex<Option<std::sync::Arc<AppStore>>>>,
    pub(crate) chat_client: std::sync::OnceLock<Result<std::sync::Arc<reqwest::Client>, CoreError>>,
    pub(crate) model_limits: crate::chat::limits::Registry,
}

impl Default for Runtime {
    fn default() -> Self {
        Self::new()
    }
}

impl Runtime {
    /// 产品装配在句柄发布前完成，不在新Runtime上制造重复注册的失败分支。
    pub fn new_with_adapters(
        inference: std::sync::Arc<dyn crate::chat::native::InferenceAdapter>,
        scripts: std::sync::Arc<dyn crate::scripts::ScriptAdapter>,
    ) -> Self {
        let mut runtime = Self::new_with_inference(inference);
        runtime.scripts = std::sync::Arc::new(crate::scripts::Registry::with_adapter(scripts));
        runtime
    }
    /// 在句柄发布前装配推理端口，构造过程没有重复注册的失败分支。
    pub fn new_with_inference(
        adapter: std::sync::Arc<dyn crate::chat::native::InferenceAdapter>,
    ) -> Self {
        let mut runtime = Self::new();
        runtime.inference = std::sync::OnceLock::from(adapter);
        runtime
    }

    pub fn new() -> Self {
        Self {
            extensions: Default::default(),
            scripts: Default::default(),
            inference: Default::default(),
            chat_observations: Default::default(),
            cancellation: CancellationToken::new(),
            store: std::sync::Arc::new(std::sync::Mutex::new(None)),
            chat_client: std::sync::OnceLock::new(),
            model_limits: Default::default(),
        }
    }

    pub fn with_data_dir(path: impl AsRef<std::path::Path>) -> Result<Self, CoreError> {
        Ok(Self {
            extensions: Default::default(),
            scripts: Default::default(),
            inference: Default::default(),
            chat_observations: Default::default(),
            cancellation: CancellationToken::new(),
            store: std::sync::Arc::new(std::sync::Mutex::new(Some(std::sync::Arc::new(
                AppStore::open(path)?,
            )))),
            chat_client: std::sync::OnceLock::new(),
            model_limits: Default::default(),
        })
    }

    pub(crate) fn with_store<T>(
        &self,
        operation: impl FnOnce(&AppStore) -> Result<T, CoreError>,
    ) -> Result<T, CoreError> {
        let store = self.store.lock().map_err(|_| CoreError {
            code: ErrorCode::Storage,
            message: "Application storage lock failed.".into(),
        })?;
        self.ensure_open()?;
        let store = store.as_ref().ok_or_else(|| CoreError {
            code: ErrorCode::Storage,
            message: "Persistent application storage is not configured.".into(),
        })?;
        operation(store)
    }

    // 执行worker持有同一存储，关闭入口后仍能提交取消终态；不重新打开第二个数据库。
    pub(crate) fn persistent_store(&self) -> Result<std::sync::Arc<AppStore>, CoreError> {
        let store = self.store.lock().map_err(|_| CoreError {
            code: ErrorCode::Storage,
            message: "Application storage lock failed.".into(),
        })?;
        self.ensure_open()?;
        store.clone().ok_or_else(|| CoreError {
            code: ErrorCode::Storage,
            message: "Persistent application storage is not configured.".into(),
        })
    }

    pub fn list_workflows(&self) -> Result<Vec<crate::workflows::WorkflowRecord>, CoreError> {
        self.with_store(|store| store.list())
    }
    pub fn create_workflow(
        &self,
        name: String,
        description: String,
    ) -> Result<crate::workflows::WorkflowRecord, CoreError> {
        self.with_store(|store| store.create(name, description))
    }
    pub fn delete_workflow(&self, id: String) -> Result<bool, CoreError> {
        self.with_store(|store| store.delete(id))
    }

    pub fn delete_workflows(&self, ids: Vec<String>) -> Result<u32, CoreError> {
        self.with_store(|store| store.delete_many(ids))
    }

    pub fn update_workflow(
        &self,
        id: String,
        name: String,
        description: String,
        enabled: bool,
    ) -> Result<crate::workflows::WorkflowRecord, CoreError> {
        self.with_store(|store| store.update(id, name, description, enabled))
    }

    pub fn ensure_open(&self) -> Result<(), CoreError> {
        if self.cancellation.is_cancelled() {
            Err(CoreError {
                code: ErrorCode::RuntimeClosed,
                message: "The runtime has been closed.".into(),
            })
        } else {
            Ok(())
        }
    }

    pub fn host_platform(&self) -> Result<&'static str, CoreError> {
        self.ensure_open()?;
        Ok(std::env::consts::OS)
    }

    pub fn start_diagnostic(
        &self,
        steps: u32,
        interval_ms: u32,
    ) -> Result<DiagnosticTask, CoreError> {
        self.ensure_open()?;
        if !(1..=100).contains(&steps) || !(10..=1000).contains(&interval_ms) {
            return Err(CoreError {
                code: ErrorCode::InvalidInput,
                message: "Expected 1..100 steps and a 10..1000 ms interval.".into(),
            });
        }
        Ok(DiagnosticTask {
            cancellation: self.cancellation.child_token(),
            state: Mutex::new(TaskState::default()),
            steps,
            interval: Duration::from_millis(interval_ms.into()),
        })
    }

    pub fn close(&self) {
        self.cancellation.cancel();
        // JS中断由blocking worker检查；等待其RAII析构，不能仅断开事件订阅。
        self.scripts.wait_idle();
        self.extensions.wait_idle();
        // 关闭等待当前短事务提交；后续操作在持锁后检查关闭状态，不能迟到写入。
        if let Ok(mut store) = self.store.lock() {
            store.take();
        }
        if let Ok(mut observations) = self.chat_observations.lock() {
            observations.clear();
        }
    }

    pub fn start_chat(
        &self,
        mut request: crate::chat::ChatRequest,
    ) -> Result<crate::chat::ChatRun, CoreError> {
        self.ensure_open()?;
        self.bind_inference(&mut request);
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(std::sync::Arc::new))
            .clone()?;
        Ok(crate::chat::start(
            client,
            request,
            self.cancellation.child_token(),
        ))
    }

    pub fn start_pool_test(
        &self,
        draft: crate::models::ModelConfigDraft,
        keys: Vec<crate::chat::pool::PoolKey>,
        headers: Vec<(String, String)>,
        concurrency: u32,
    ) -> Result<crate::chat::ChatRun, CoreError> {
        self.ensure_open()?;
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(std::sync::Arc::new))
            .clone()?;
        let extension = if draft.provider.starts_with("TOOLPKG:") {
            let mut request =
                crate::chat::probe::prepare(draft.clone(), String::new(), headers.clone(), "chat")?;
            self.bind_extension(&mut request);
            request.extension
        } else {
            None
        };
        crate::chat::pool::start_pool(
            client,
            crate::chat::pool::Configuration { draft, extension },
            keys,
            headers,
            concurrency,
            self.cancellation.child_token(),
        )
    }

    pub fn start_model_directory(
        &self,
        draft: crate::models::ModelConfigDraft,
        api_key: String,
        headers: Vec<(String, String)>,
    ) -> Result<crate::chat::ChatRun, CoreError> {
        self.ensure_open()?;
        if draft.provider.starts_with("TOOLPKG:") {
            return self.start_extension_directory(draft, api_key, headers);
        }
        if matches!(draft.provider.as_str(), "MNN" | "LLAMA_CPP") {
            let prefix = if draft.provider == "MNN" {
                "mnn:"
            } else {
                "llama:"
            };
            let models = self
                .transfers()?
                .into_iter()
                .filter(|t| t.phase == "completed" && t.owner.starts_with(prefix))
                .map(|t| {
                    let name = t.owner[prefix.len()..].to_owned();
                    crate::chat::directory::ModelEntry {
                        id: name.clone(),
                        name,
                    }
                })
                .collect();
            return Ok(crate::chat::directory::local(
                models,
                self.cancellation.child_token(),
            ));
        }
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(std::sync::Arc::new))
            .clone()?;
        Ok(crate::chat::directory::start(
            client,
            draft,
            api_key,
            headers,
            self.cancellation.child_token(),
        ))
    }
}

impl Drop for Runtime {
    fn drop(&mut self) {
        self.close();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    #[tokio::test]
    async fn events_are_ordered_and_completion_is_delivered_once() {
        let runtime = Runtime::new();
        let task = runtime.start_diagnostic(2, 10).unwrap();
        let mut events = vec![];
        while let Some(event) = task.next_event().await.unwrap() {
            events.push(event);
        }
        assert_eq!(
            events.iter().map(|e| e.revision).collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
        assert_eq!(
            events.iter().map(|e| e.phase).collect::<Vec<_>>(),
            vec![TaskPhase::Started, TaskPhase::Running, TaskPhase::Completed]
        );
        assert_eq!(events.last().unwrap().completed_steps, 2);
        task.cancel();
        assert_eq!(task.next_event().await.unwrap(), None);
    }

    #[tokio::test]
    async fn cancellation_before_first_read_has_one_terminal_event() {
        let runtime = Runtime::new();
        let task = runtime.start_diagnostic(2, 1000).unwrap();
        task.cancel();
        assert_eq!(
            task.next_event().await.unwrap().unwrap().phase,
            TaskPhase::Cancelled
        );
        assert_eq!(task.next_event().await.unwrap(), None);
    }

    #[tokio::test]
    async fn close_wakes_pending_read_and_rejects_new_work() {
        let runtime = Runtime::new();
        let task = runtime.start_diagnostic(2, 1000).unwrap();
        task.next_event().await.unwrap();
        let read = task.next_event();
        tokio::pin!(read);
        tokio::select! {
            result = &mut read => panic!("unexpected early result: {result:?}"),
            _ = tokio::time::sleep(Duration::from_millis(10)) => {}
        }
        runtime.close();
        let event = tokio::time::timeout(Duration::from_millis(200), read)
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        assert_eq!(event.phase, TaskPhase::Cancelled);
        assert_eq!(
            runtime.ensure_open().unwrap_err().code,
            ErrorCode::RuntimeClosed
        );
        assert!(runtime.start_diagnostic(1, 10).is_err());
        runtime.close();
    }

    #[tokio::test]
    async fn concurrent_reader_is_rejected_without_consuming_events() {
        let runtime = Runtime::new();
        let task = Arc::new(runtime.start_diagnostic(2, 1000).unwrap());
        task.next_event().await.unwrap();
        let read = task.next_event();
        tokio::pin!(read);
        tokio::select! {
            _ = &mut read => panic!("unexpected early completion"),
            _ = tokio::time::sleep(Duration::from_millis(10)) => {}
        }
        assert_eq!(
            task.next_event().await.unwrap_err().code,
            ErrorCode::ConcurrentRead
        );
        task.cancel();
        assert_eq!(read.await.unwrap().unwrap().phase, TaskPhase::Cancelled);
    }

    #[test]
    fn invalid_input_is_structured() {
        let runtime = Runtime::new();
        for (steps, interval) in [(0, 10), (101, 10), (1, 9), (1, 1001)] {
            let error = runtime.start_diagnostic(steps, interval).err().unwrap();
            assert_eq!(error.code, ErrorCode::InvalidInput);
        }
        assert!(runtime.start_diagnostic(100, 1000).is_ok());
    }

    #[tokio::test]
    async fn dropping_runtime_cancels_children_but_sessions_are_isolated() {
        let first = Runtime::new();
        let second = Runtime::new();
        let task = first.start_diagnostic(1, 10).unwrap();
        drop(first);
        assert_eq!(
            task.next_event().await.unwrap().unwrap().phase,
            TaskPhase::Cancelled
        );
        assert!(second.ensure_open().is_ok());
    }
}
