use flutter_rust_bridge::frb;
use kiyori_core::runtime;
use std::{fmt, sync::Arc};

#[derive(Debug, Clone, Copy)]
pub enum ErrorCode {
    InvalidInput,
    RuntimeClosed,
    ConcurrentRead,
}

#[derive(Debug, Clone)]
pub struct BridgeError {
    pub code: ErrorCode,
    pub message: String,
}

impl fmt::Display for BridgeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for BridgeError {}

impl From<runtime::CoreError> for BridgeError {
    fn from(error: runtime::CoreError) -> Self {
        Self {
            code: match error.code {
                runtime::ErrorCode::InvalidInput => ErrorCode::InvalidInput,
                runtime::ErrorCode::RuntimeClosed => ErrorCode::RuntimeClosed,
                runtime::ErrorCode::ConcurrentRead => ErrorCode::ConcurrentRead,
            },
            message: error.message,
        }
    }
}

pub struct RuntimeInfo {
    pub core_version: String,
    pub host_platform: String,
    pub capabilities: Vec<Capability>,
}

pub struct Capability {
    pub id: String,
    pub available: bool,
    pub reason: String,
}

#[derive(Debug, Clone, Copy)]
pub enum TaskPhase {
    Started,
    Running,
    Completed,
    Cancelled,
}

pub struct TaskEvent {
    pub revision: u32,
    pub phase: TaskPhase,
    pub completed_steps: u32,
    pub total_steps: u32,
}

#[frb(opaque)]
pub struct RuntimeHandle {
    inner: Arc<runtime::Runtime>,
}

#[frb(opaque)]
pub struct TaskHandle {
    inner: runtime::DiagnosticTask,
}

pub fn create_runtime() -> RuntimeHandle {
    RuntimeHandle {
        inner: Arc::new(runtime::Runtime::new()),
    }
}

impl RuntimeHandle {
    pub fn info(&self) -> Result<RuntimeInfo, BridgeError> {
        let host_platform = self.inner.host_platform()?.to_owned();
        Ok(RuntimeInfo {
            core_version: env!("CARGO_PKG_VERSION").into(),
            host_platform,
            capabilities: vec![
                Capability {
                    id: "kiyori.runtime.diagnostics".into(),
                    available: true,
                    reason: "".into(),
                },
                Capability {
                    id: "kiyori.assistant".into(),
                    available: false,
                    reason: "not_implemented".into(),
                },
                Capability {
                    id: "kiyori.browser".into(),
                    available: false,
                    reason: "not_implemented".into(),
                },
                Capability {
                    id: "kiyori.files".into(),
                    available: false,
                    reason: "not_implemented".into(),
                },
            ],
        })
    }

    pub fn start_diagnostic(
        &self,
        steps: u32,
        interval_ms: u32,
    ) -> Result<TaskHandle, BridgeError> {
        Ok(TaskHandle {
            inner: self.inner.start_diagnostic(steps, interval_ms)?,
        })
    }

    pub fn close(&self) {
        self.inner.close();
    }
}

impl TaskHandle {
    pub fn cancel(&self) {
        self.inner.cancel();
    }

    pub async fn next_event(&self) -> Result<Option<TaskEvent>, BridgeError> {
        Ok(self.inner.next_event().await?.map(|event| TaskEvent {
            revision: event.revision,
            phase: match event.phase {
                runtime::TaskPhase::Started => TaskPhase::Started,
                runtime::TaskPhase::Running => TaskPhase::Running,
                runtime::TaskPhase::Completed => TaskPhase::Completed,
                runtime::TaskPhase::Cancelled => TaskPhase::Cancelled,
            },
            completed_steps: event.completed_steps,
            total_steps: event.total_steps,
        }))
    }
}
