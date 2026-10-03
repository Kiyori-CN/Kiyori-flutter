//! 聊天功能模型的上下文选项与全局历史媒体偏好，复用同一SQLite事务。
use crate::{
    models::{self, ModelConfig},
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, TransactionBehavior, params};

#[derive(Clone, Debug, PartialEq)]
pub struct ContextOptions {
    pub context_length: f64,
    pub max_context_length: f64,
    pub summary_enabled: bool,
    pub summary_threshold: f64,
    pub summary_by_count: bool,
    pub summary_count: u32,
    pub summary_rules: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct HistoryRetention {
    pub revision: u32,
    pub image_turns: u32,
    pub media_turns: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ContextSettings {
    pub config: ModelConfig,
    pub history: HistoryRetention,
}

fn storage(_: rusqlite::Error) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: "Context storage operation failed.".into(),
    }
}
fn conflict() -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: "Context settings changed; reload before saving.".into(),
    }
}
fn read(tx: &Connection) -> Result<ContextSettings, CoreError> {
    let id: String = tx
        .query_row(
            "SELECT config_id FROM function_models WHERE function='chat'",
            [],
            |r| r.get(0),
        )
        .map_err(storage)?;
    let history = tx
        .query_row(
            "SELECT revision,image_turns,media_turns FROM history_retention WHERE id=1",
            [],
            |r| {
                Ok(HistoryRetention {
                    revision: r.get(0)?,
                    image_turns: r.get(1)?,
                    media_turns: r.get(2)?,
                })
            },
        )
        .map_err(storage)?;
    Ok(ContextSettings {
        config: models::read_config(tx, &id)?,
        history,
    })
}

impl AppStore {
    pub fn context_settings(&self) -> Result<ContextSettings, CoreError> {
        let mut connection = self.connection.lock().map_err(|_| conflict())?;
        let tx = connection.transaction().map_err(storage)?;
        read(&tx)
    }
    pub fn save_context_settings(
        &self,
        id: String,
        revision: u32,
        options: ContextOptions,
        history: HistoryRetention,
    ) -> Result<ContextSettings, CoreError> {
        let mut connection = self.connection.lock().map_err(|_| conflict())?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let mut current = read(&tx)?;
        // 绑定切换和并发编辑必须拒绝旧草稿；媒体是全局事实，不能跟随模型复制。
        if current.config.id != id
            || current.config.revision != revision
            || current.history.revision != history.revision
        {
            return Err(conflict());
        }
        let old = current.config.draft.options.clone();
        let next = &mut current.config.draft.options;
        next.context_length = options.context_length;
        next.max_context_length = options.max_context_length;
        next.summary_enabled = options.summary_enabled;
        next.summary_threshold = options.summary_threshold;
        next.summary_by_count = options.summary_by_count;
        next.summary_count = options.summary_count;
        next.summary_rules = options.summary_rules;
        models::validate(&mut current.config.draft)?;
        if old != current.config.draft.options {
            current.config.revision = revision.checked_add(1).ok_or_else(conflict)?;
            tx.execute(
                "UPDATE model_configs SET options=?1, revision=?2 WHERE id=?3",
                params![
                    models::options_json(&current.config.draft.options)?,
                    current.config.revision,
                    id
                ],
            )
            .map_err(storage)?;
        }
        if current.history.image_turns != history.image_turns
            || current.history.media_turns != history.media_turns
        {
            current.history = HistoryRetention {
                revision: history.revision.checked_add(1).ok_or_else(conflict)?,
                ..history
            };
            tx.execute(
                "UPDATE history_retention SET revision=?1,image_turns=?2,media_turns=?3 WHERE id=1",
                params![
                    current.history.revision,
                    current.history.image_turns,
                    current.history.media_turns
                ],
            )
            .map_err(storage)?;
        }
        tx.commit().map_err(storage)?;
        Ok(current)
    }
}
impl Runtime {
    pub fn context_settings(&self) -> Result<ContextSettings, CoreError> {
        self.with_store(AppStore::context_settings)
    }
    pub fn save_context_settings(
        &self,
        id: String,
        revision: u32,
        options: ContextOptions,
        history: HistoryRetention,
    ) -> Result<ContextSettings, CoreError> {
        self.with_store(|store| store.save_context_settings(id, revision, options, history))
    }
}
