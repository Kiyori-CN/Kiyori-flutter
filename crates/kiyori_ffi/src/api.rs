use flutter_rust_bridge::frb;
use kiyori_core::runtime;
use std::{fmt, sync::Arc};

#[derive(Debug, Clone, Copy)]
pub enum ErrorCode {
    InvalidInput,
    RuntimeClosed,
    ConcurrentRead,
    Storage,
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
                runtime::ErrorCode::Storage => ErrorCode::Storage,
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

pub struct WorkflowRecord {
    pub id: String,
    pub name: String,
    pub description: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub enabled: bool,
}

pub struct KnowledgeSpace {
    pub id: String,
    pub name: String,
}
pub struct MemoryDraft {
    pub kind: String,
    pub title: String,
    pub content: String,
    pub category: String,
    pub source: String,
    pub folder: String,
    pub credibility: f64,
    pub importance: f64,
    pub tags: Vec<String>,
}
pub struct MemoryRecord {
    pub id: String,
    pub space_id: String,
    pub draft: MemoryDraft,
    pub archived: bool,
    pub created_at: i64,
    pub updated_at: i64,
}
pub struct KnowledgeSnapshot {
    pub spaces: Vec<KnowledgeSpace>,
    pub active_space: String,
    pub folders: Vec<String>,
    pub records: Vec<MemoryRecord>,
    pub has_more: bool,
    pub available_tags: Vec<String>,
}
pub struct MemoryQuery {
    pub kind: Option<String>,
    pub folder: String,
    pub text: String,
    pub category: Option<String>,
    pub tag: Option<String>,
    pub archived: bool,
    pub sort_title: bool,
    pub offset: u32,
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

pub fn create_runtime_with_data_dir(data_dir: String) -> Result<RuntimeHandle, BridgeError> {
    Ok(RuntimeHandle {
        inner: Arc::new(runtime::Runtime::with_data_dir(data_dir).map_err(BridgeError::from)?),
    })
}

impl RuntimeHandle {
    pub fn query_knowledge(&self, query: MemoryQuery) -> Result<KnowledgeSnapshot, BridgeError> {
        Ok(self
            .inner
            .query_knowledge(kiyori_core::knowledge::MemoryQuery {
                kind: query.kind,
                folder: query.folder,
                text: query.text,
                category: query.category,
                tag: query.tag,
                archived: query.archived,
                sort_title: query.sort_title,
                offset: query.offset,
            })?
            .into())
    }
    pub fn get_memory(
        &self,
        space: String,
        id: String,
    ) -> Result<Option<MemoryRecord>, BridgeError> {
        Ok(self.inner.get_memory(space, id)?.map(Into::into))
    }
    pub fn rename_knowledge_folder(
        &self,
        space: String,
        old: String,
        new: String,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.rename_knowledge_folder(space, old, new)?)
    }
    pub fn delete_knowledge_folder(&self, space: String, path: String) -> Result<(), BridgeError> {
        Ok(self.inner.delete_knowledge_folder(space, path)?)
    }
    pub fn knowledge_snapshot(&self) -> Result<KnowledgeSnapshot, BridgeError> {
        Ok(self.inner.knowledge_snapshot()?.into())
    }
    pub fn save_knowledge_space(
        &self,
        id: Option<String>,
        name: String,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_knowledge_space(id, name)?)
    }
    pub fn select_knowledge_space(&self, id: String) -> Result<(), BridgeError> {
        Ok(self.inner.select_knowledge_space(id)?)
    }
    pub fn delete_knowledge_space(&self, id: String) -> Result<bool, BridgeError> {
        Ok(self.inner.delete_knowledge_space(id)?)
    }
    pub fn create_knowledge_folder(&self, space: String, path: String) -> Result<(), BridgeError> {
        Ok(self.inner.create_knowledge_folder(space, path)?)
    }
    pub fn save_memory(
        &self,
        space: String,
        id: Option<String>,
        draft: MemoryDraft,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_memory(space, id, draft.into())?)
    }
    pub fn archive_memory(
        &self,
        space: String,
        id: String,
        archived: bool,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.archive_memory(space, id, archived)?)
    }
    pub fn delete_memory(&self, space: String, id: String) -> Result<bool, BridgeError> {
        Ok(self.inner.delete_memory(space, id)?)
    }
    pub fn list_workflows(&self) -> Result<Vec<WorkflowRecord>, BridgeError> {
        Ok(self
            .inner
            .list_workflows()?
            .into_iter()
            .map(Into::into)
            .collect())
    }

    pub fn create_workflow(
        &self,
        name: String,
        description: String,
    ) -> Result<WorkflowRecord, BridgeError> {
        Ok(self.inner.create_workflow(name, description)?.into())
    }

    pub fn delete_workflow(&self, id: String) -> Result<bool, BridgeError> {
        Ok(self.inner.delete_workflow(id)?)
    }

    pub fn delete_workflows(&self, ids: Vec<String>) -> Result<u32, BridgeError> {
        Ok(self.inner.delete_workflows(ids)?)
    }

    pub fn update_workflow(
        &self,
        id: String,
        name: String,
        description: String,
        enabled: bool,
    ) -> Result<WorkflowRecord, BridgeError> {
        Ok(self
            .inner
            .update_workflow(id, name, description, enabled)?
            .into())
    }
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

impl From<MemoryDraft> for kiyori_core::knowledge::MemoryDraft {
    fn from(v: MemoryDraft) -> Self {
        Self {
            kind: v.kind,
            title: v.title,
            content: v.content,
            category: v.category,
            source: v.source,
            folder: v.folder,
            credibility: v.credibility,
            importance: v.importance,
            tags: v.tags,
        }
    }
}
impl From<kiyori_core::knowledge::MemoryDraft> for MemoryDraft {
    fn from(v: kiyori_core::knowledge::MemoryDraft) -> Self {
        Self {
            kind: v.kind,
            title: v.title,
            content: v.content,
            category: v.category,
            source: v.source,
            folder: v.folder,
            credibility: v.credibility,
            importance: v.importance,
            tags: v.tags,
        }
    }
}
impl From<kiyori_core::knowledge::KnowledgeSnapshot> for KnowledgeSnapshot {
    fn from(v: kiyori_core::knowledge::KnowledgeSnapshot) -> Self {
        Self {
            spaces: v
                .spaces
                .into_iter()
                .map(|s| KnowledgeSpace {
                    id: s.id,
                    name: s.name,
                })
                .collect(),
            active_space: v.active_space,
            folders: v.folders,
            has_more: v.has_more,
            available_tags: v.available_tags,
            records: v
                .records
                .into_iter()
                .map(|r| MemoryRecord {
                    id: r.id,
                    space_id: r.space_id,
                    draft: r.draft.into(),
                    archived: r.archived,
                    created_at: r.created_at,
                    updated_at: r.updated_at,
                })
                .collect(),
        }
    }
}

impl From<kiyori_core::knowledge::MemoryRecord> for MemoryRecord {
    fn from(r: kiyori_core::knowledge::MemoryRecord) -> Self {
        Self {
            id: r.id,
            space_id: r.space_id,
            draft: r.draft.into(),
            archived: r.archived,
            created_at: r.created_at,
            updated_at: r.updated_at,
        }
    }
}

impl From<kiyori_core::workflows::WorkflowRecord> for WorkflowRecord {
    fn from(value: kiyori_core::workflows::WorkflowRecord) -> Self {
        Self {
            id: value.id,
            name: value.name,
            description: value.description,
            created_at: value.created_at,
            updated_at: value.updated_at,
            enabled: value.enabled,
        }
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
