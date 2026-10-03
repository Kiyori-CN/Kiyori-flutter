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

pub struct ModelParameter {
    pub name: String,
    pub enabled: bool,
    pub value_type: String,
    pub value: String,
    pub category: String,
}
impl From<kiyori_core::models::ModelParameter> for ModelParameter {
    fn from(v: kiyori_core::models::ModelParameter) -> Self {
        Self {
            name: v.name,
            enabled: v.enabled,
            value_type: v.value_type,
            value: v.value,
            category: v.category,
        }
    }
}
impl From<ModelParameter> for kiyori_core::models::ModelParameter {
    fn from(v: ModelParameter) -> Self {
        Self {
            name: v.name,
            enabled: v.enabled,
            value_type: v.value_type,
            value: v.value,
            category: v.category,
        }
    }
}
pub struct ModelOptions {
    pub context_length: f64,
    pub max_context_length: f64,
    pub max_context_mode: bool,
    pub summary_enabled: bool,
    pub summary_threshold: f64,
    pub summary_by_count: bool,
    pub summary_count: u32,
    pub summary_rules: String,
    pub image: bool,
    pub audio: bool,
    pub video: bool,
    pub google_search: bool,
    pub claude_cache: bool,
    pub tool_call: bool,
    pub request_limit: u32,
    pub concurrent_limit: u32,
    pub mnn_forward: u32,
    pub mnn_threads: u32,
    pub llama_threads: u32,
    pub llama_context: u32,
    pub llama_batch: u32,
    pub llama_micro_batch: u32,
    pub llama_gpu_layers: i32,
    pub llama_mmap: bool,
    pub llama_flash_attention: bool,
    pub llama_kv_unified: bool,
    pub llama_offload_kqv: bool,
    pub parameters: Vec<ModelParameter>,
}
impl From<kiyori_core::models::ModelOptions> for ModelOptions {
    fn from(v: kiyori_core::models::ModelOptions) -> Self {
        Self {
            context_length: v.context_length,
            max_context_length: v.max_context_length,
            max_context_mode: v.max_context_mode,
            summary_enabled: v.summary_enabled,
            summary_threshold: v.summary_threshold,
            summary_by_count: v.summary_by_count,
            summary_count: v.summary_count,
            summary_rules: v.summary_rules,
            image: v.image,
            audio: v.audio,
            video: v.video,
            google_search: v.google_search,
            claude_cache: v.claude_cache,
            tool_call: v.tool_call,
            request_limit: v.request_limit,
            concurrent_limit: v.concurrent_limit,
            mnn_forward: v.mnn_forward,
            mnn_threads: v.mnn_threads,
            llama_threads: v.llama_threads,
            llama_context: v.llama_context,
            llama_batch: v.llama_batch,
            llama_micro_batch: v.llama_micro_batch,
            llama_gpu_layers: v.llama_gpu_layers,
            llama_mmap: v.llama_mmap,
            llama_flash_attention: v.llama_flash_attention,
            llama_kv_unified: v.llama_kv_unified,
            llama_offload_kqv: v.llama_offload_kqv,
            parameters: v.parameters.into_iter().map(Into::into).collect(),
        }
    }
}
impl From<ModelOptions> for kiyori_core::models::ModelOptions {
    fn from(v: ModelOptions) -> Self {
        Self {
            context_length: v.context_length,
            max_context_length: v.max_context_length,
            max_context_mode: v.max_context_mode,
            summary_enabled: v.summary_enabled,
            summary_threshold: v.summary_threshold,
            summary_by_count: v.summary_by_count,
            summary_count: v.summary_count,
            summary_rules: v.summary_rules,
            image: v.image,
            audio: v.audio,
            video: v.video,
            google_search: v.google_search,
            claude_cache: v.claude_cache,
            tool_call: v.tool_call,
            request_limit: v.request_limit,
            concurrent_limit: v.concurrent_limit,
            mnn_forward: v.mnn_forward,
            mnn_threads: v.mnn_threads,
            llama_threads: v.llama_threads,
            llama_context: v.llama_context,
            llama_batch: v.llama_batch,
            llama_micro_batch: v.llama_micro_batch,
            llama_gpu_layers: v.llama_gpu_layers,
            llama_mmap: v.llama_mmap,
            llama_flash_attention: v.llama_flash_attention,
            llama_kv_unified: v.llama_kv_unified,
            llama_offload_kqv: v.llama_offload_kqv,
            parameters: v.parameters.into_iter().map(Into::into).collect(),
        }
    }
}
pub struct ModelConfigDraft {
    pub name: String,
    pub provider: String,
    pub protocol: String,
    pub endpoint: String,
    pub models: Vec<String>,
    pub options: ModelOptions,
}
impl From<kiyori_core::models::ModelConfigDraft> for ModelConfigDraft {
    fn from(v: kiyori_core::models::ModelConfigDraft) -> Self {
        Self {
            name: v.name,
            provider: v.provider,
            protocol: v.protocol,
            endpoint: v.endpoint,
            models: v.models,
            options: v.options.into(),
        }
    }
}
impl From<ModelConfigDraft> for kiyori_core::models::ModelConfigDraft {
    fn from(v: ModelConfigDraft) -> Self {
        Self {
            name: v.name,
            provider: v.provider,
            protocol: v.protocol,
            endpoint: v.endpoint,
            models: v.models,
            options: v.options.into(),
        }
    }
}
pub struct ModelConfig {
    pub id: String,
    pub revision: u32,
    pub draft: ModelConfigDraft,
    pub secret_reference: Option<String>,
}
impl From<kiyori_core::models::ModelConfig> for ModelConfig {
    fn from(v: kiyori_core::models::ModelConfig) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            draft: v.draft.into(),
            secret_reference: v.secret_reference,
        }
    }
}
pub struct FunctionModel {
    pub function: String,
    pub config_id: String,
    pub model_name: String,
}
impl From<kiyori_core::models::FunctionModel> for FunctionModel {
    fn from(v: kiyori_core::models::FunctionModel) -> Self {
        Self {
            function: v.function,
            config_id: v.config_id,
            model_name: v.model_name,
        }
    }
}
pub struct ModelCatalog {
    pub configs: Vec<ModelConfig>,
    pub functions: Vec<FunctionModel>,
}

pub struct ContextOptions {
    pub context_length: f64,
    pub max_context_length: f64,
    pub summary_enabled: bool,
    pub summary_threshold: f64,
    pub summary_by_count: bool,
    pub summary_count: u32,
    pub summary_rules: String,
}
impl From<ContextOptions> for kiyori_core::context::ContextOptions {
    fn from(v: ContextOptions) -> Self {
        Self {
            context_length: v.context_length,
            max_context_length: v.max_context_length,
            summary_enabled: v.summary_enabled,
            summary_threshold: v.summary_threshold,
            summary_by_count: v.summary_by_count,
            summary_count: v.summary_count,
            summary_rules: v.summary_rules,
        }
    }
}
pub struct HistoryRetention {
    pub revision: u32,
    pub image_turns: u32,
    pub media_turns: u32,
}
impl From<HistoryRetention> for kiyori_core::context::HistoryRetention {
    fn from(v: HistoryRetention) -> Self {
        Self {
            revision: v.revision,
            image_turns: v.image_turns,
            media_turns: v.media_turns,
        }
    }
}
pub struct ContextSettings {
    pub config: ModelConfig,
    pub history: HistoryRetention,
}
impl From<kiyori_core::context::ContextSettings> for ContextSettings {
    fn from(v: kiyori_core::context::ContextSettings) -> Self {
        Self {
            config: v.config.into(),
            history: HistoryRetention {
                revision: v.history.revision,
                image_turns: v.history.image_turns,
                media_turns: v.history.media_turns,
            },
        }
    }
}
impl From<kiyori_core::models::ModelCatalog> for ModelCatalog {
    fn from(v: kiyori_core::models::ModelCatalog) -> Self {
        Self {
            configs: v.configs.into_iter().map(Into::into).collect(),
            functions: v.functions.into_iter().map(Into::into).collect(),
        }
    }
}

pub struct PromptTool {
    pub kind: String,
    pub name: String,
}
impl From<kiyori_core::prompts::PromptTool> for PromptTool {
    fn from(v: kiyori_core::prompts::PromptTool) -> Self {
        Self {
            kind: v.kind,
            name: v.name,
        }
    }
}
impl From<PromptTool> for kiyori_core::prompts::PromptTool {
    fn from(v: PromptTool) -> Self {
        Self {
            kind: v.kind,
            name: v.name,
        }
    }
}

pub struct CharacterDraft {
    pub name: String,
    pub description: String,
    pub setting: String,
    pub opening: String,
    pub chat: String,
    pub voice: String,
    pub custom: String,
    pub marks: String,
    pub tag_ids: Vec<String>,
    pub model_config: Option<String>,
    pub model_name: Option<String>,
    pub memory_space: Option<String>,
    pub tools_enabled: bool,
    pub tools: Vec<PromptTool>,
}
impl From<kiyori_core::prompts::CharacterDraft> for CharacterDraft {
    fn from(v: kiyori_core::prompts::CharacterDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            setting: v.setting,
            opening: v.opening,
            chat: v.chat,
            voice: v.voice,
            custom: v.custom,
            marks: v.marks,
            tag_ids: v.tag_ids,
            model_config: v.model_config,
            model_name: v.model_name,
            memory_space: v.memory_space,
            tools_enabled: v.tools_enabled,
            tools: v.tools.into_iter().map(Into::into).collect(),
        }
    }
}
impl From<CharacterDraft> for kiyori_core::prompts::CharacterDraft {
    fn from(v: CharacterDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            setting: v.setting,
            opening: v.opening,
            chat: v.chat,
            voice: v.voice,
            custom: v.custom,
            marks: v.marks,
            tag_ids: v.tag_ids,
            model_config: v.model_config,
            model_name: v.model_name,
            memory_space: v.memory_space,
            tools_enabled: v.tools_enabled,
            tools: v.tools.into_iter().map(Into::into).collect(),
        }
    }
}

pub struct PromptCharacter {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: CharacterDraft,
}
impl From<kiyori_core::prompts::PromptCharacter> for PromptCharacter {
    fn from(v: kiyori_core::prompts::PromptCharacter) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}
impl From<PromptCharacter> for kiyori_core::prompts::PromptCharacter {
    fn from(v: PromptCharacter) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}

pub struct TagDraft {
    pub name: String,
    pub description: String,
    pub content: String,
}
impl From<kiyori_core::prompts::TagDraft> for TagDraft {
    fn from(v: kiyori_core::prompts::TagDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            content: v.content,
        }
    }
}
impl From<TagDraft> for kiyori_core::prompts::TagDraft {
    fn from(v: TagDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            content: v.content,
        }
    }
}

pub struct PromptTag {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: TagDraft,
}
impl From<kiyori_core::prompts::PromptTag> for PromptTag {
    fn from(v: kiyori_core::prompts::PromptTag) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}
impl From<PromptTag> for kiyori_core::prompts::PromptTag {
    fn from(v: PromptTag) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}

pub struct GroupDraft {
    pub name: String,
    pub description: String,
    pub members: Vec<String>,
}
impl From<kiyori_core::prompts::GroupDraft> for GroupDraft {
    fn from(v: kiyori_core::prompts::GroupDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            members: v.members,
        }
    }
}
impl From<GroupDraft> for kiyori_core::prompts::GroupDraft {
    fn from(v: GroupDraft) -> Self {
        Self {
            name: v.name,
            description: v.description,
            members: v.members,
        }
    }
}

pub struct PromptGroup {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: GroupDraft,
}
impl From<kiyori_core::prompts::PromptGroup> for PromptGroup {
    fn from(v: kiyori_core::prompts::PromptGroup) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}
impl From<PromptGroup> for kiyori_core::prompts::PromptGroup {
    fn from(v: PromptGroup) -> Self {
        Self {
            id: v.id,
            revision: v.revision,
            updated_at: v.updated_at,
            draft: v.draft.into(),
        }
    }
}

pub struct PromptCatalog {
    pub characters: Vec<PromptCharacter>,
    pub tags: Vec<PromptTag>,
    pub groups: Vec<PromptGroup>,
    pub active_character: Option<String>,
    pub active_group: Option<String>,
}
impl From<kiyori_core::prompts::PromptCatalog> for PromptCatalog {
    fn from(v: kiyori_core::prompts::PromptCatalog) -> Self {
        Self {
            characters: v.characters.into_iter().map(Into::into).collect(),
            tags: v.tags.into_iter().map(Into::into).collect(),
            groups: v.groups.into_iter().map(Into::into).collect(),
            active_character: v.active_character,
            active_group: v.active_group,
        }
    }
}
impl From<PromptCatalog> for kiyori_core::prompts::PromptCatalog {
    fn from(v: PromptCatalog) -> Self {
        Self {
            characters: v.characters.into_iter().map(Into::into).collect(),
            tags: v.tags.into_iter().map(Into::into).collect(),
            groups: v.groups.into_iter().map(Into::into).collect(),
            active_character: v.active_character,
            active_group: v.active_group,
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
    pub diary: Option<DiarySummary>,
}
pub struct DiarySummary {
    pub closed: bool,
    pub entry_count: u32,
    pub first_day: Option<String>,
    pub last_phase: Option<String>,
    pub last_raw_phase: Option<String>,
}
pub struct DiaryEntry {
    pub date: String,
    pub time: String,
    pub phase: String,
    pub raw_phase: Option<String>,
    pub body: String,
}
pub struct DiaryDocument {
    pub preface: String,
    pub entries: Vec<DiaryEntry>,
}
pub fn parse_diary(content: String) -> DiaryDocument {
    let value = kiyori_core::diary::parse(&content);
    DiaryDocument {
        preface: value.preface,
        entries: value
            .entries
            .into_iter()
            .map(|entry| DiaryEntry {
                date: entry.date,
                time: entry.time,
                phase: entry.phase,
                raw_phase: entry.raw_phase,
                body: entry.body,
            })
            .collect(),
    }
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
    pub diary_closed: Option<bool>,
}

pub struct MemoryLinkDraft {
    pub source_id: String,
    pub target_id: String,
    pub relation: String,
    pub weight: f64,
    pub description: String,
}
pub struct MemoryLink {
    pub id: String,
    pub draft: MemoryLinkDraft,
    pub cross_folder: bool,
}
pub struct GraphNode {
    pub id: String,
    pub title: String,
    pub node_type: String,
}
pub struct MemoryGraph {
    pub space_id: String,
    pub nodes: Vec<GraphNode>,
    pub edges: Vec<MemoryLink>,
    pub has_more: bool,
}

impl From<MemoryQuery> for kiyori_core::knowledge::MemoryQuery {
    fn from(query: MemoryQuery) -> Self {
        Self {
            kind: query.kind,
            folder: query.folder,
            text: query.text,
            category: query.category,
            tag: query.tag,
            archived: query.archived,
            sort_title: query.sort_title,
            offset: query.offset,
            diary_closed: query.diary_closed,
        }
    }
}
impl From<MemoryLinkDraft> for kiyori_core::graph::MemoryLinkDraft {
    fn from(draft: MemoryLinkDraft) -> Self {
        Self {
            source_id: draft.source_id,
            target_id: draft.target_id,
            relation: draft.relation,
            weight: draft.weight,
            description: draft.description,
        }
    }
}
impl From<kiyori_core::graph::MemoryGraph> for MemoryGraph {
    fn from(graph: kiyori_core::graph::MemoryGraph) -> Self {
        Self {
            space_id: graph.space_id,
            has_more: graph.has_more,
            nodes: graph
                .nodes
                .into_iter()
                .map(|n| GraphNode {
                    id: n.id,
                    title: n.title,
                    node_type: n.node_type,
                })
                .collect(),
            edges: graph
                .edges
                .into_iter()
                .map(|e| MemoryLink {
                    id: e.id,
                    cross_folder: e.cross_folder,
                    draft: MemoryLinkDraft {
                        source_id: e.draft.source_id,
                        target_id: e.draft.target_id,
                        relation: e.draft.relation,
                        weight: e.draft.weight,
                        description: e.draft.description,
                    },
                })
                .collect(),
        }
    }
}

pub struct MemorySearchSettings {
    pub graph_visible: bool,
    pub score_mode: String,
    pub keyword_weight: f64,
    pub tag_weight: f64,
    pub vector_weight: f64,
    pub edge_weight: f64,
    pub auto_interval: u32,
    pub extraction_rules: String,
}
impl From<kiyori_core::memory_search::MemorySearchSettings> for MemorySearchSettings {
    fn from(v: kiyori_core::memory_search::MemorySearchSettings) -> Self {
        Self {
            graph_visible: v.graph_visible,
            score_mode: v.score_mode,
            keyword_weight: v.keyword_weight,
            tag_weight: v.tag_weight,
            vector_weight: v.vector_weight,
            edge_weight: v.edge_weight,
            auto_interval: v.auto_interval,
            extraction_rules: v.extraction_rules,
        }
    }
}
impl From<MemorySearchSettings> for kiyori_core::memory_search::MemorySearchSettings {
    fn from(v: MemorySearchSettings) -> Self {
        Self {
            graph_visible: v.graph_visible,
            score_mode: v.score_mode,
            keyword_weight: v.keyword_weight,
            tag_weight: v.tag_weight,
            vector_weight: v.vector_weight,
            edge_weight: v.edge_weight,
            auto_interval: v.auto_interval,
            extraction_rules: v.extraction_rules,
        }
    }
}
pub struct MemorySearchCandidate {
    pub id: String,
    pub title: String,
    pub folder: String,
    pub matched_tokens: u32,
    pub keyword_score: f64,
    pub tag_score: f64,
    pub reverse_score: f64,
    pub edge_score: f64,
    pub total_score: f64,
    pub passed: bool,
}
impl From<kiyori_core::memory_search::MemorySearchCandidate> for MemorySearchCandidate {
    fn from(v: kiyori_core::memory_search::MemorySearchCandidate) -> Self {
        Self {
            id: v.id,
            title: v.title,
            folder: v.folder,
            matched_tokens: v.matched_tokens,
            keyword_score: v.keyword_score,
            tag_score: v.tag_score,
            reverse_score: v.reverse_score,
            edge_score: v.edge_score,
            total_score: v.total_score,
            passed: v.passed,
        }
    }
}
pub struct MemorySearchReport {
    pub space_id: String,
    pub tokens: Vec<String>,
    pub scope_count: u32,
    pub keyword_matches: u32,
    pub tag_matches: u32,
    pub reverse_matches: u32,
    pub edges_traversed: u32,
    pub passed_count: u32,
    pub keyword_weight: f64,
    pub tag_weight: f64,
    pub edge_weight: f64,
    pub vector_unavailable: bool,
    pub has_more: bool,
    pub candidates: Vec<MemorySearchCandidate>,
}
impl From<kiyori_core::memory_search::MemorySearchReport> for MemorySearchReport {
    fn from(v: kiyori_core::memory_search::MemorySearchReport) -> Self {
        Self {
            space_id: v.space_id,
            tokens: v.tokens,
            scope_count: v.scope_count,
            keyword_matches: v.keyword_matches,
            tag_matches: v.tag_matches,
            reverse_matches: v.reverse_matches,
            edges_traversed: v.edges_traversed,
            passed_count: v.passed_count,
            keyword_weight: v.keyword_weight,
            tag_weight: v.tag_weight,
            edge_weight: v.edge_weight,
            vector_unavailable: v.vector_unavailable,
            has_more: v.has_more,
            candidates: v.candidates.into_iter().map(Into::into).collect(),
        }
    }
}

#[frb(opaque)]
pub struct RuntimeHandle {
    inner: Arc<runtime::Runtime>,
}

#[frb(opaque)]
pub struct ModelSecretsHandle {
    lease: kiyori_core::models::ModelSecretsLease,
    runtime: Arc<runtime::Runtime>,
}
impl ModelSecretsHandle {
    pub fn reserve(&self, id: String, revision: u32) -> Result<String, BridgeError> {
        Ok(self
            .runtime
            .reserve_model_secret(id, revision, &self.lease)?)
    }
    pub fn close(&self) {
        self.lease.close();
    }
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
    pub fn begin_model_secrets(&self) -> Result<ModelSecretsHandle, BridgeError> {
        Ok(ModelSecretsHandle {
            lease: self.inner.begin_model_secrets()?,
            runtime: self.inner.clone(),
        })
    }
    pub fn reset_function_models(&self) -> Result<(), BridgeError> {
        Ok(self.inner.reset_function_models()?)
    }
    pub fn model_catalog(&self) -> Result<ModelCatalog, BridgeError> {
        Ok(self.inner.model_catalog()?.into())
    }
    pub fn context_settings(&self) -> Result<ContextSettings, BridgeError> {
        Ok(self.inner.context_settings()?.into())
    }
    pub fn save_context_settings(
        &self,
        id: String,
        revision: u32,
        options: ContextOptions,
        history: HistoryRetention,
    ) -> Result<ContextSettings, BridgeError> {
        Ok(self
            .inner
            .save_context_settings(id, revision, options.into(), history.into())?
            .into())
    }
    pub fn create_model_config(&self, name: String) -> Result<String, BridgeError> {
        Ok(self.inner.create_model_config(name)?)
    }
    pub fn save_model_config(
        &self,
        id: String,
        revision: u32,
        draft: ModelConfigDraft,
        secret_reference: Option<String>,
        replacement: Option<String>,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.save_model_config(
            id,
            revision,
            draft.into(),
            secret_reference,
            replacement,
        )?)
    }
    pub fn retire_model_secret(&self, reference: String) -> Result<(), BridgeError> {
        Ok(self.inner.retire_model_secret(reference)?)
    }
    pub fn retired_model_secrets(&self) -> Result<Vec<String>, BridgeError> {
        Ok(self.inner.retired_model_secrets()?)
    }
    pub fn forget_retired_model_secret(&self, reference: String) -> Result<(), BridgeError> {
        Ok(self.inner.forget_retired_model_secret(reference)?)
    }
    pub fn select_function_model(
        &self,
        function: String,
        config: String,
        model: String,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.select_function_model(function, config, model)?)
    }
    pub fn delete_model_config(
        &self,
        id: String,
        revision: u32,
        replacement_config: Option<String>,
        replacement_model: Option<String>,
    ) -> Result<(), BridgeError> {
        Ok(self
            .inner
            .delete_model_config(id, revision, replacement_config, replacement_model)?)
    }
    pub fn prompt_catalog(&self) -> Result<PromptCatalog, BridgeError> {
        Ok(self.inner.prompt_catalog()?.into())
    }
    pub fn save_character(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: CharacterDraft,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_character(id, revision, draft.into())?)
    }
    pub fn save_prompt_tag(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: TagDraft,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_prompt_tag(id, revision, draft.into())?)
    }
    pub fn save_prompt_group(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: GroupDraft,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_prompt_group(id, revision, draft.into())?)
    }
    pub fn activate_prompt(&self, kind: String, id: String) -> Result<(), BridgeError> {
        Ok(self.inner.activate_prompt(kind, id)?)
    }
    pub fn delete_prompt(
        &self,
        kind: String,
        id: String,
        revision: u32,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.delete_prompt(kind, id, revision)?)
    }
    pub fn duplicate_prompt(
        &self,
        kind: String,
        id: String,
        revision: u32,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.duplicate_prompt(kind, id, revision)?)
    }
    pub fn reset_default_character(&self, revision: u32) -> Result<(), BridgeError> {
        Ok(self.inner.reset_default_character(revision)?)
    }
    pub fn compose_character_prompt(&self, id: String, voice: bool) -> Result<String, BridgeError> {
        Ok(self.inner.compose_character_prompt(id, voice)?)
    }
    pub fn memory_search_settings(
        &self,
        space: String,
    ) -> Result<MemorySearchSettings, BridgeError> {
        Ok(self.inner.memory_search_settings(space)?.into())
    }
    pub fn save_memory_search_settings(
        &self,
        space: String,
        value: MemorySearchSettings,
    ) -> Result<(), BridgeError> {
        Ok(self
            .inner
            .save_memory_search_settings(space, value.into())?)
    }
    pub fn set_memory_graph_visible(
        &self,
        space: String,
        visible: bool,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.set_memory_graph_visible(space, visible)?)
    }
    pub fn simulate_memory_search(
        &self,
        space: String,
        query: MemoryQuery,
    ) -> Result<MemorySearchReport, BridgeError> {
        Ok(self
            .inner
            .simulate_memory_search(space, query.into())?
            .into())
    }

    pub fn memory_graph(&self, query: MemoryQuery) -> Result<MemoryGraph, BridgeError> {
        Ok(self.inner.memory_graph(query.into())?.into())
    }
    pub fn save_memory_link(
        &self,
        space: String,
        id: Option<String>,
        draft: MemoryLinkDraft,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.save_memory_link(space, id, draft.into())?)
    }
    pub fn delete_memory_link(&self, space: String, id: String) -> Result<bool, BridgeError> {
        Ok(self.inner.delete_memory_link(space, id)?)
    }
    pub fn delete_memories(&self, space: String, ids: Vec<String>) -> Result<u32, BridgeError> {
        Ok(self.inner.delete_memories(space, ids)?)
    }
    pub fn create_diary(
        &self,
        space: String,
        draft: MemoryDraft,
        phase: String,
        stamp: String,
    ) -> Result<String, BridgeError> {
        Ok(self.inner.create_diary(space, draft.into(), phase, stamp)?)
    }
    pub fn append_diary(
        &self,
        space: String,
        id: String,
        body: String,
        phase: String,
        stamp: String,
    ) -> Result<(), BridgeError> {
        Ok(self.inner.append_diary(space, id, body, phase, stamp)?)
    }
    pub fn query_knowledge(&self, query: MemoryQuery) -> Result<KnowledgeSnapshot, BridgeError> {
        Ok(self.inner.query_knowledge(query.into())?.into())
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
            records: v.records.into_iter().map(Into::into).collect(),
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
            diary: r.diary.map(|value| DiarySummary {
                closed: value.closed,
                entry_count: value.entry_count,
                first_day: value.first_day,
                last_phase: value.last_phase,
                last_raw_phase: value.last_raw_phase,
            }),
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
