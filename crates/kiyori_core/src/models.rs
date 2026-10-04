//! 模型配置和引用属于核心；明文凭据只在native安全存储中。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, OptionalExtension, Transaction, TransactionBehavior, params};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::{
    fs::{File, OpenOptions},
    path::PathBuf,
    sync::Mutex,
};

/// 文件锁覆盖native写入窗口，进程退出由OS释放；不能通过年龄猜测pending已失去owner。
pub struct ModelSecretsLease {
    directory: PathBuf,
    file: Mutex<Option<File>>,
}
impl ModelSecretsLease {
    pub fn close(&self) {
        if let Ok(mut file) = self.file.lock() {
            file.take();
        }
    }
    pub(crate) fn with_store<T>(
        &self,
        store: &AppStore,
        operation: impl FnOnce() -> Result<T, CoreError>,
    ) -> Result<T, CoreError> {
        let file = self
            .file
            .lock()
            .map_err(|_| invalid("Secret lease lock failed."))?;
        if file.is_none() || self.directory != store.directory {
            return Err(invalid(
                "Secret lease is closed or belongs to another database.",
            ));
        }
        operation()
    }
}

pub const DEFAULT_MODEL_CONFIG: &str = "default";
#[cfg(test)]
#[path = "models_tests.rs"]
mod tests;

#[cfg(test)]
pub(crate) fn remove_schema_six_for_fixture(connection: &Connection) {
    crate::conversations::remove_schema_for_fixture(connection);
    connection.execute_batch("DROP TABLE function_models; DROP TABLE model_names; DROP TABLE model_secrets; DROP TABLE model_configs;").unwrap();
}
pub const FUNCTIONS: [&str; 11] = [
    "chat",
    "summary",
    "titleGeneration",
    "memory",
    "ui",
    "translation",
    "grep",
    "planner",
    "image",
    "audio",
    "video",
];

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ModelParameter {
    pub name: String,
    pub enabled: bool,
    pub value_type: String,
    pub value: String,
    pub category: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
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

impl Default for ModelOptions {
    fn default() -> Self {
        Self {
            context_length: 64.,
            max_context_length: 200.,
            max_context_mode: false,
            summary_enabled: true,
            summary_threshold: 0.7,
            summary_by_count: true,
            summary_count: 16,
            summary_rules: String::new(),
            image: false,
            audio: false,
            video: false,
            google_search: false,
            claude_cache: false,
            tool_call: true,
            request_limit: 0,
            concurrent_limit: 0,
            mnn_forward: 0,
            mnn_threads: 4,
            llama_threads: 4,
            llama_context: 2048,
            llama_batch: 512,
            llama_micro_batch: 512,
            llama_gpu_layers: 0,
            llama_mmap: false,
            llama_flash_attention: false,
            llama_kv_unified: true,
            llama_offload_kqv: false,
            parameters: [
                ("max_tokens", "integer", "4096", "generation"),
                ("temperature", "decimal", "1.0", "creativity"),
                ("top_p", "decimal", "1.0", "creativity"),
                ("top_k", "integer", "0", "creativity"),
                ("presence_penalty", "decimal", "0.0", "repetition"),
                ("frequency_penalty", "decimal", "0.0", "repetition"),
                ("repetition_penalty", "decimal", "1.0", "repetition"),
            ]
            .into_iter()
            .map(|(name, value_type, value, category)| ModelParameter {
                name: name.into(),
                enabled: false,
                value_type: value_type.into(),
                value: value.into(),
                category: category.into(),
            })
            .collect(),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct ModelConfigDraft {
    pub name: String,
    pub provider: String,
    pub protocol: String,
    pub endpoint: String,
    pub models: Vec<String>,
    pub options: ModelOptions,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ModelConfig {
    pub id: String,
    pub revision: u32,
    pub draft: ModelConfigDraft,
    pub secret_reference: Option<String>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct FunctionModel {
    pub function: String,
    pub config_id: String,
    pub model_name: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ModelCatalog {
    pub configs: Vec<ModelConfig>,
    pub functions: Vec<FunctionModel>,
}

/// 只存在于当前操作句柄；不含凭据，撤销必须核对配置与受影响角色的提交代次。
pub struct ModelNamesUndo {
    id: String,
    revision: u32,
    previous: Vec<String>,
    replacement: Option<String>,
    functions: Vec<(String, String)>,
    characters: Vec<(String, String, u32)>,
}

fn invalid(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    }
}
fn storage(_: rusqlite::Error) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: "Model storage operation failed.".into(),
    }
}
pub(crate) fn options_json(value: &ModelOptions) -> Result<String, CoreError> {
    serde_json::to_string(value).map_err(|_| invalid("Invalid model options."))
}
fn parse_options(value: &str) -> Result<ModelOptions, CoreError> {
    serde_json::from_str(value).map_err(|_| CoreError {
        code: ErrorCode::Storage,
        message: "Stored model options are invalid.".into(),
    })
}
pub(crate) fn initialize(tx: &Transaction<'_>) -> Result<(), CoreError> {
    tx.execute("INSERT INTO model_configs VALUES('default',1,'默认配置','DEEPSEEK','chat','https://api.deepseek.com/v1/chat/completions',?1,NULL)",
        [options_json(&ModelOptions::default())?]).map_err(storage)?;
    tx.execute(
        "INSERT INTO model_names VALUES('default','deepseek-v4-flash',0)",
        [],
    )
    .map_err(storage)?;
    for function in FUNCTIONS {
        tx.execute(
            "INSERT INTO function_models VALUES(?1,'default','deepseek-v4-flash')",
            [function],
        )
        .map_err(storage)?;
    }
    Ok(())
}

pub(crate) fn validate(draft: &mut ModelConfigDraft) -> Result<(), CoreError> {
    draft.name = draft.name.trim().into();
    if draft.name.is_empty()
        || draft.provider.trim().is_empty()
        || !matches!(
            draft.protocol.as_str(),
            "chat" | "responses" | "messages" | "native"
        )
    {
        return Err(invalid("Invalid model configuration identity."));
    }
    draft.endpoint = draft.endpoint.trim().into();
    if !draft.endpoint.is_empty() {
        // 旧EndpointCompleter用末尾#表示地址已完整；它不是URL fragment正文。
        let endpoint = draft.endpoint.strip_suffix('#').unwrap_or(&draft.endpoint);
        let rest = endpoint
            .strip_prefix("https://")
            .or_else(|| endpoint.strip_prefix("http://"));
        let authority = rest.map(|r| r.split('/').next().unwrap_or_default());
        if draft
            .endpoint
            .chars()
            .any(|c| c.is_control() || c.is_whitespace())
            || endpoint.contains(['?', '#', '@', '\\'])
            || !authority.is_some_and(|a| {
                !a.is_empty()
                    && a.chars()
                        .all(|c| c.is_ascii_alphanumeric() || ".-:[]".contains(c))
            })
        {
            return Err(invalid(
                "Endpoint must be HTTP(S) without user information, query or fragment; use secure headers for credentials.",
            ));
        }
    }
    // 保存限制排除URL凭据常见载体；执行前仍须解析URL并检查TLS和重定向边界。
    let mut seen = HashSet::new();
    draft.models = draft
        .models
        .iter()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty() && seen.insert(s.clone()))
        .collect();
    let o = &draft.options;
    if !o.context_length.is_finite()
        || o.context_length <= 0.
        || !o.max_context_length.is_finite()
        || o.max_context_length <= 0.
        || !o.summary_threshold.is_finite()
        || !(0. ..1.).contains(&o.summary_threshold)
        || o.summary_threshold == 0.
        || o.summary_count == 0
        || o.mnn_threads == 0
        || o.llama_threads == 0
        || o.llama_context == 0
        || o.llama_batch == 0
        || o.llama_micro_batch == 0
        || o.mnn_forward > 4
    {
        return Err(invalid("Invalid model numeric option."));
    }
    let mut names = HashSet::new();
    for p in &o.parameters {
        if p.name.trim().is_empty() || !names.insert(&p.name) {
            return Err(invalid("Duplicate or blank parameter."));
        }
        let valid = match p.value_type.as_str() {
            "integer" => p.value.parse::<i64>().is_ok(),
            "decimal" => p.value.parse::<f64>().is_ok_and(f64::is_finite),
            "boolean" => matches!(p.value.as_str(), "true" | "false"),
            "text" => true,
            "json" => serde_json::from_str::<serde_json::Value>(&p.value).is_ok(),
            _ => false,
        };
        if !valid {
            return Err(invalid("Invalid parameter value."));
        }
    }
    Ok(())
}
fn require_revision(tx: &Connection, id: &str, revision: u32) -> Result<u32, CoreError> {
    let current: Option<u32> = tx
        .query_row(
            "SELECT revision FROM model_configs WHERE id=?1",
            [id],
            |r| r.get(0),
        )
        .optional()
        .map_err(storage)?;
    if current != Some(revision) {
        return Err(invalid(
            "Model changed or was deleted; reload before saving.",
        ));
    }
    revision
        .checked_add(1)
        .ok_or_else(|| invalid("Model revision exhausted."))
}
pub(crate) fn require_model(tx: &Connection, config: &str, name: &str) -> Result<(), CoreError> {
    let exists: bool = tx
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM model_names WHERE config_id=?1 AND name=?2)",
            params![config, name],
            |r| r.get(0),
        )
        .map_err(storage)?;
    if !exists {
        return Err(invalid("Model reference no longer exists."));
    }
    Ok(())
}
pub(crate) fn read_config(tx: &Connection, id: &str) -> Result<ModelConfig, CoreError> {
    let row = tx.query_row("SELECT revision,name,provider,protocol,endpoint,options,secret_reference FROM model_configs WHERE id=?1",[id],|r|Ok((
        r.get::<_,u32>(0)?, r.get::<_,String>(1)?, r.get::<_,String>(2)?,r.get::<_,String>(3)?,
        r.get::<_,String>(4)?,r.get::<_,String>(5)?,r.get::<_,Option<String>>(6)?,
    ))).map_err(storage)?;
    let models = tx
        .prepare("SELECT name FROM model_names WHERE config_id=?1 ORDER BY position")
        .map_err(storage)?
        .query_map([id], |r| r.get(0))
        .map_err(storage)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(storage)?;
    Ok(ModelConfig {
        id: id.into(),
        revision: row.0,
        secret_reference: row.6,
        draft: ModelConfigDraft {
            name: row.1,
            provider: row.2,
            protocol: row.3,
            endpoint: row.4,
            options: parse_options(&row.5)?,
            models,
        },
    })
}

impl AppStore {
    pub fn begin_model_secrets(&self) -> Result<ModelSecretsLease, CoreError> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(self.directory.join("model-secrets.lock"))
            .map_err(|_| invalid("Cannot open model secret lock."))?;
        file.try_lock().map_err(|error| match error {
            std::fs::TryLockError::WouldBlock => invalid("Model secret storage is busy."),
            std::fs::TryLockError::Error(_) => invalid("Model secret locking is unavailable."),
        })?;
        let lease = ModelSecretsLease {
            directory: self.directory.clone(),
            file: Mutex::new(Some(file)),
        };
        // 已取得独占锁，所有前任writer已退出。只改账本，native删除仍按retired可重试执行。
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        connection.execute("UPDATE model_secrets SET state='retired' WHERE state='pending' AND reference NOT IN (SELECT secret_reference FROM model_configs WHERE secret_reference IS NOT NULL)", []).map_err(storage)?;
        Ok(lease)
    }
    pub fn model_catalog(&self) -> Result<ModelCatalog, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection.transaction().map_err(storage)?;
        let ids = tx
            .prepare("SELECT id FROM model_configs ORDER BY rowid")
            .map_err(storage)?
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let configs = ids
            .iter()
            .map(|id| read_config(&tx, id))
            .collect::<Result<Vec<_>, _>>()?;
        let functions = tx
            .prepare("SELECT function,config_id,model_name FROM function_models ORDER BY function")
            .map_err(storage)?
            .query_map([], |r| {
                Ok(FunctionModel {
                    function: r.get(0)?,
                    config_id: r.get(1)?,
                    model_name: r.get(2)?,
                })
            })
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(ModelCatalog { configs, functions })
    }
    pub fn create_model_config(&self, name: String) -> Result<String, CoreError> {
        if name.trim().is_empty() {
            return Err(invalid("Model name cannot be blank."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let id: String = tx
            .query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
            .map_err(storage)?;
        tx.execute(
            "INSERT INTO model_configs VALUES(?1,1,?2,'OPENAI_GENERIC','chat','',?3,NULL)",
            params![id, name.trim(), options_json(&ModelOptions::default())?],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn save_model_config(
        &self,
        id: String,
        revision: u32,
        mut draft: ModelConfigDraft,
        secret_reference: Option<String>,
        replacement: Option<String>,
    ) -> Result<(), CoreError> {
        validate(&mut draft)?;
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        Self::save_config(&tx, id, revision, draft, secret_reference, replacement)?;
        tx.commit().map_err(storage)
    }

    fn save_config(
        tx: &Connection,
        id: String,
        revision: u32,
        draft: ModelConfigDraft,
        secret_reference: Option<String>,
        replacement: Option<String>,
    ) -> Result<(), CoreError> {
        let next = require_revision(tx, &id, revision)?;
        let old = read_config(tx, &id)?;
        let removed: Vec<_> = old
            .draft
            .models
            .iter()
            .filter(|name| !draft.models.contains(name))
            .collect();
        let replacement_valid = replacement
            .as_ref()
            .is_some_and(|r| draft.models.contains(r));
        for name in removed {
            let bindings: i64 = tx.query_row("SELECT (SELECT count(*) FROM function_models WHERE config_id=?1 AND model_name=?2)+(SELECT count(*) FROM prompt_characters WHERE model_config=?1 AND model_name=?2)",params![id,name],|r|r.get(0)).map_err(storage)?;
            if bindings > 0 {
                if !replacement_valid {
                    return Err(invalid(
                        "Bound models require an explicit valid replacement.",
                    ));
                }
                tx.execute(
                    "UPDATE function_models SET model_name=?1 WHERE config_id=?2 AND model_name=?3",
                    params![replacement, id, name],
                )
                .map_err(storage)?;
                tx.execute("UPDATE prompt_characters SET model_name=?1,revision=revision+1,updated_at=updated_at+1 WHERE model_config=?2 AND model_name=?3",params![replacement,id,name]).map_err(storage)?;
            }
        }
        if secret_reference != old.secret_reference {
            if let Some(reference) = &secret_reference {
                let valid:bool=tx.query_row("SELECT EXISTS(SELECT 1 FROM model_secrets WHERE reference=?1 AND config_id=?2 AND state='pending')",params![reference,id],|r|r.get(0)).map_err(storage)?;
                if !valid {
                    return Err(invalid(
                        "Secret reference is not reserved for this configuration.",
                    ));
                }
                tx.execute(
                    "UPDATE model_secrets SET state='active' WHERE reference=?1",
                    [reference],
                )
                .map_err(storage)?;
            }
            if let Some(reference) = old.secret_reference {
                tx.execute(
                    "UPDATE model_secrets SET state='retired' WHERE reference=?1",
                    [reference],
                )
                .map_err(storage)?;
            }
        }
        tx.execute("UPDATE model_configs SET revision=?1,name=?2,provider=?3,protocol=?4,endpoint=?5,options=?6,secret_reference=?7 WHERE id=?8",
            params![next,draft.name,draft.provider,draft.protocol,draft.endpoint,options_json(&draft.options)?,secret_reference,id]).map_err(storage)?;
        tx.execute("DELETE FROM model_names WHERE config_id=?1", [&id])
            .map_err(storage)?;
        for (position, name) in draft.models.iter().enumerate() {
            tx.execute(
                "INSERT INTO model_names VALUES(?1,?2,?3)",
                params![id, name, position as i64],
            )
            .map_err(storage)?;
        }
        Ok(())
    }

    fn change_model_names(
        &self,
        id: String,
        revision: u32,
        names: Vec<String>,
        replacement: Option<String>,
    ) -> Result<ModelNamesUndo, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let next = require_revision(&tx, &id, revision)?;
        let config = read_config(&tx, &id)?;
        let mut draft = config.draft;
        let previous = draft.models.clone();
        draft.models = names;
        validate(&mut draft)?;
        let removed: Vec<_> = previous
            .iter()
            .filter(|m| !draft.models.contains(m))
            .collect();
        let mut functions = Vec::new();
        let mut characters = Vec::new();
        for name in removed {
            let mut statement = tx.prepare("SELECT function,model_name FROM function_models WHERE config_id=?1 AND model_name=?2").map_err(storage)?;
            functions.extend(
                statement
                    .query_map(params![id, name], |r| Ok((r.get(0)?, r.get(1)?)))
                    .map_err(storage)?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(storage)?,
            );
            let mut statement = tx.prepare("SELECT id,model_name,revision FROM prompt_characters WHERE model_config=?1 AND model_name=?2").map_err(storage)?;
            characters.extend(
                statement
                    .query_map(params![id, name], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
                    .map_err(storage)?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(storage)?,
            );
        }
        Self::save_config(
            &tx,
            id.clone(),
            revision,
            draft,
            config.secret_reference,
            replacement.clone(),
        )?;
        tx.commit().map_err(storage)?;
        Ok(ModelNamesUndo {
            id,
            revision: next,
            previous,
            replacement,
            functions,
            characters,
        })
    }

    fn undo_model_names(&self, undo: ModelNamesUndo) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_revision(&tx, &undo.id, undo.revision)?;
        // 一项冲突即拒绝整次撤销，避免部分恢复与覆盖随后编辑的角色/功能。
        for (function, _) in &undo.functions {
            let current: (String, String) = tx
                .query_row(
                    "SELECT config_id,model_name FROM function_models WHERE function=?1",
                    [function],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .map_err(storage)?;
            if current.0 != undo.id || Some(&current.1) != undo.replacement.as_ref() {
                return Err(invalid("Model bindings changed after deletion."));
            }
        }
        for (id, _, revision) in &undo.characters {
            let current: (Option<String>, Option<String>, u32) = tx
                .query_row(
                    "SELECT model_config,model_name,revision FROM prompt_characters WHERE id=?1",
                    [id],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )
                .map_err(storage)?;
            if current.0.as_ref() != Some(&undo.id)
                || current.1 != undo.replacement
                || current.2
                    != revision
                        .checked_add(1)
                        .ok_or_else(|| invalid("Character revision overflow."))?
            {
                return Err(invalid("Model bindings changed after deletion."));
            }
        }
        let config = read_config(&tx, &undo.id)?;
        let mut draft = config.draft;
        draft.models = undo.previous;
        Self::save_config(
            &tx,
            undo.id.clone(),
            undo.revision,
            draft,
            config.secret_reference,
            None,
        )?;
        for (function, model) in undo.functions {
            tx.execute(
                "UPDATE function_models SET model_name=?1 WHERE function=?2",
                params![model, function],
            )
            .map_err(storage)?;
        }
        for (id, model, _) in undo.characters {
            tx.execute("UPDATE prompt_characters SET model_name=?1,revision=revision+1,updated_at=updated_at+1 WHERE id=?2", params![model,id]).map_err(storage)?;
        }
        tx.commit().map_err(storage)
    }

    pub fn reserve_model_secret(
        &self,
        id: String,
        revision: u32,
        lease: &ModelSecretsLease,
    ) -> Result<String, CoreError> {
        lease.with_store(self, || self.reserve_model_secret_locked(id, revision))
    }
    fn reserve_model_secret_locked(&self, id: String, revision: u32) -> Result<String, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_revision(&tx, &id, revision)?;
        let reference: String = tx
            .query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
            .map_err(storage)?;
        tx.execute(
            "INSERT INTO model_secrets VALUES(?1,?2,'pending')",
            params![reference, id],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(reference)
    }
    pub fn retire_model_secret(&self, reference: String) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let active: bool = tx
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM model_configs WHERE secret_reference=?1)",
                [&reference],
                |r| r.get(0),
            )
            .map_err(storage)?;
        if active {
            return Err(invalid("Active secret cannot be retired."));
        }
        tx.execute(
            "UPDATE model_secrets SET state='retired' WHERE reference=?1 AND state='pending'",
            [reference],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn retired_model_secrets(&self) -> Result<Vec<String>, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        connection
            .prepare("SELECT reference FROM model_secrets WHERE state='retired'")
            .map_err(storage)?
            .query_map([], |r| r.get(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)
    }
    pub fn forget_retired_model_secret(&self, reference: String) -> Result<(), CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        connection
            .execute(
                "DELETE FROM model_secrets WHERE reference=?1 AND state='retired'",
                [reference],
            )
            .map_err(storage)?;
        Ok(())
    }
    pub fn select_function_model(
        &self,
        function: String,
        config: String,
        model: String,
    ) -> Result<(), CoreError> {
        if !FUNCTIONS.contains(&function.as_str()) {
            return Err(invalid("Unknown model function."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_model(&tx, &config, &model)?;
        tx.execute("INSERT INTO function_models VALUES(?1,?2,?3) ON CONFLICT(function) DO UPDATE SET config_id=excluded.config_id,model_name=excluded.model_name",params![function,config,model]).map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn reset_function_models(&self) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let default = read_config(&tx, DEFAULT_MODEL_CONFIG)?;
        let model = default
            .draft
            .models
            .first()
            .ok_or_else(|| invalid("Default configuration has no model."))?;
        tx.execute(
            "UPDATE function_models SET config_id='default', model_name=?1",
            [model],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn delete_model_config(
        &self,
        id: String,
        revision: u32,
        replacement_config: Option<String>,
        replacement_model: Option<String>,
    ) -> Result<(), CoreError> {
        if id == DEFAULT_MODEL_CONFIG {
            return Err(invalid("Default model configuration cannot be deleted."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_revision(&tx, &id, revision)?;
        let bindings:i64=tx.query_row("SELECT (SELECT count(*) FROM function_models WHERE config_id=?1)+(SELECT count(*) FROM prompt_characters WHERE model_config=?1)",[&id],|r|r.get(0)).map_err(storage)?;
        if bindings > 0 {
            let (Some(config), Some(model)) = (replacement_config, replacement_model) else {
                return Err(invalid(
                    "Bound configuration requires an explicit replacement.",
                ));
            };
            if config == id {
                return Err(invalid(
                    "Cannot replace a deleted configuration with itself.",
                ));
            }
            require_model(&tx, &config, &model)?;
            tx.execute(
                "UPDATE function_models SET config_id=?1,model_name=?2 WHERE config_id=?3",
                params![config, model, id],
            )
            .map_err(storage)?;
            tx.execute("UPDATE prompt_characters SET model_config=?1,model_name=?2,revision=revision+1,updated_at=updated_at+1 WHERE model_config=?3",params![config,model,id]).map_err(storage)?;
        }
        tx.execute(
            "UPDATE model_secrets SET state='retired' WHERE config_id=?1 AND state='active'",
            [&id],
        )
        .map_err(storage)?;
        tx.execute("DELETE FROM model_configs WHERE id=?1", [&id])
            .map_err(storage)?;
        tx.commit().map_err(storage)
    }
}
impl Runtime {
    pub fn change_model_names(
        &self,
        id: String,
        revision: u32,
        names: Vec<String>,
        replacement: Option<String>,
    ) -> Result<ModelNamesUndo, CoreError> {
        self.with_store(|s| s.change_model_names(id, revision, names, replacement))
    }
    pub fn undo_model_names(&self, undo: ModelNamesUndo) -> Result<(), CoreError> {
        self.with_store(|s| s.undo_model_names(undo))
    }
    pub fn begin_model_secrets(&self) -> Result<ModelSecretsLease, CoreError> {
        self.with_store(AppStore::begin_model_secrets)
    }
    pub fn reset_function_models(&self) -> Result<(), CoreError> {
        self.with_store(AppStore::reset_function_models)
    }
    pub fn model_catalog(&self) -> Result<ModelCatalog, CoreError> {
        self.with_store(AppStore::model_catalog)
    }
    pub fn create_model_config(&self, name: String) -> Result<String, CoreError> {
        self.with_store(|s| s.create_model_config(name))
    }
    pub fn save_model_config(
        &self,
        id: String,
        revision: u32,
        draft: ModelConfigDraft,
        secret_reference: Option<String>,
        replacement: Option<String>,
    ) -> Result<(), CoreError> {
        let next_revision = revision
            .checked_add(1)
            .ok_or_else(|| invalid("Model revision exhausted."))?;
        let request_limit = draft.options.request_limit;
        let concurrent_limit = draft.options.concurrent_limit;
        self.with_store(|s| {
            s.save_model_config(id.clone(), revision, draft, secret_reference, replacement)?;
            // 提交已成功就必须返回成功；更新进程内门控无需再次读取可能失败的存储。
            // configure 按 revision 丢弃迟到更新，不能覆盖并发保存的新限制。
            self.model_limits
                .configure(&id, next_revision, request_limit, concurrent_limit);
            Ok(())
        })
    }
    pub fn reserve_model_secret(
        &self,
        id: String,
        revision: u32,
        lease: &ModelSecretsLease,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.reserve_model_secret(id, revision, lease))
    }
    pub fn retire_model_secret(&self, reference: String) -> Result<(), CoreError> {
        self.with_store(|s| s.retire_model_secret(reference))
    }
    pub fn retired_model_secrets(&self) -> Result<Vec<String>, CoreError> {
        self.with_store(AppStore::retired_model_secrets)
    }
    pub fn forget_retired_model_secret(&self, reference: String) -> Result<(), CoreError> {
        self.with_store(|s| s.forget_retired_model_secret(reference))
    }
    pub fn select_function_model(
        &self,
        function: String,
        config: String,
        model: String,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.select_function_model(function, config, model))
    }
    pub fn delete_model_config(
        &self,
        id: String,
        revision: u32,
        replacement_config: Option<String>,
        replacement_model: Option<String>,
    ) -> Result<(), CoreError> {
        self.with_store(|s| {
            s.delete_model_config(id.clone(), revision, replacement_config, replacement_model)
        })?;
        self.model_limits.remove(&id);
        Ok(())
    }
}
