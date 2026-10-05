//! 正式文字会话：SQLite为唯一事实，凭据短租约与每会话OS执行锁分别保护不同生命周期。
use crate::{
    chat, model_execution, models,
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, TransactionBehavior, params};
use std::{
    fs::{File, OpenOptions},
    sync::Arc,
};

pub(crate) const SCHEMA: &str = "
CREATE TABLE conversations (
 id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, character_id TEXT NOT NULL,
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, revision INTEGER NOT NULL DEFAULT 1);
CREATE TABLE conversation_state (id INTEGER PRIMARY KEY CHECK(id=1), active_id TEXT REFERENCES conversations(id) ON DELETE SET NULL);
INSERT INTO conversation_state VALUES(1,NULL);
CREATE TABLE conversation_runs (
 id TEXT PRIMARY KEY NOT NULL, conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 state TEXT NOT NULL, config_id TEXT NOT NULL, config_revision INTEGER NOT NULL, model TEXT NOT NULL,
 error TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, finished_at INTEGER,
 input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0);
CREATE UNIQUE INDEX conversation_active_run ON conversation_runs(conversation_id) WHERE state='running';
CREATE TABLE conversation_messages (
 id TEXT PRIMARY KEY NOT NULL, conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 run_id TEXT REFERENCES conversation_runs(id) ON DELETE CASCADE, position INTEGER NOT NULL,
 role TEXT NOT NULL, content TEXT NOT NULL, state TEXT NOT NULL, UNIQUE(conversation_id,position));
CREATE INDEX conversation_recent ON conversations(updated_at DESC,id);
PRAGMA user_version=9;";

#[cfg(test)]
#[path = "conversations_tests.rs"]
mod tests;

#[path = "conversations_summary.rs"]
mod summary;

#[path = "conversations_manual_summary.rs"]
mod manual_summary;
pub use manual_summary::PreparedSummary;

#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(connection: &Connection) {
    crate::downloads::remove_schema_for_fixture(connection);
    connection.execute_batch("DROP TABLE conversation_summary_usage; DROP TABLE conversation_summaries; DROP TABLE conversation_variants; DROP TABLE conversation_messages; DROP TABLE conversation_runs; DROP TABLE conversation_state; DROP TABLE conversations; DROP TABLE conversation_folders; DROP TABLE chat_preferences;").unwrap();
}

#[derive(Clone, Debug, PartialEq)]
pub struct Conversation {
    pub id: String,
    pub title: String,
    pub character_id: String,
    pub character_name: String,
    pub revision: u32,
    pub updated_at: i64,
    pub message_count: u32,
    pub folder: String,
    pub pinned: bool,
    pub locked: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Message {
    pub variant: u32,
    pub variant_count: u32,
    pub id: String,
    pub run_id: String,
    pub role: String,
    pub content: String,
    pub state: String,
    pub error: String,
    pub model: String,
    pub role_name: Option<String>,
    pub sent_at: Option<i64>,
    pub first_output_ms: Option<i64>,
    pub duration_ms: Option<i64>,
    pub input_tokens: Option<i64>,
    pub output_tokens: Option<i64>,
    pub cache_read_tokens: Option<i64>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConversationSnapshot {
    pub conversation: Conversation,
    pub messages: Vec<Message>,
    pub summary: Option<ConversationSummary>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConversationSummary {
    pub through_position: i64,
    pub content: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConversationCatalog {
    pub active_id: Option<String>,
    pub conversations: Vec<Conversation>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Statistics {
    pub context_tokens: Option<i64>,
    pub context_limit: Option<i64>,
    pub tokens_per_second: Option<f64>,
    pub speed_estimated: bool,
    pub requests: u32,
    pub reported_requests: u32,
    pub input_tokens: Option<i64>,
    pub output_tokens: Option<i64>,
    pub recent_input_tokens: Option<i64>,
    pub recent_output_tokens: Option<i64>,
    pub recent_model: String,
    pub first_output_ms: Option<i64>,
    pub duration_ms: Option<i64>,
    pub cache_reported_requests: u32,
    pub cache_read_tokens: Option<i64>,
    pub cache_write_tokens: Option<i64>,
    pub reasoning_tokens: Option<i64>,
    pub cache_input_tokens: Option<i64>,
    pub uncached_input_tokens: Option<i64>,
    pub recent_cache_read_tokens: Option<i64>,
    pub recent_cache_write_tokens: Option<i64>,
    pub recent_reasoning_tokens: Option<i64>,
}

#[derive(Clone, PartialEq)]
struct Selection {
    config: models::ModelConfig,
    model: String,
    character: String,
    role_name: String,
    system: String,
    preferences: crate::chat_preferences::Preferences,
    summary: Option<summary::Model>,
}
pub struct PreparedSend {
    lease: models::ModelSecretsLease,
    store: Arc<AppStore>,
    conversation: String,
    selection: Selection,
    target: Option<String>,
}
impl PreparedSend {
    pub fn secret_reference(&self) -> Option<String> {
        self.selection.config.secret_reference.clone()
    }
    pub fn summary_secret_reference(&self) -> Option<String> {
        self.selection
            .summary
            .as_ref()
            .and_then(|s| s.config.secret_reference.clone())
    }
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
        message: "聊天存储失败，请保留数据并重试".into(),
    }
}
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
fn identity(tx: &Connection) -> Result<String, CoreError> {
    tx.query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
        .map_err(storage)
}
fn exists(tx: &Connection, id: &str) -> Result<(), CoreError> {
    if tx
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM conversations WHERE id=?1)",
            [id],
            |r| r.get::<_, bool>(0),
        )
        .map_err(storage)?
    {
        Ok(())
    } else {
        Err(invalid("会话已不存在"))
    }
}
fn touch(tx: &Connection, id: &str) -> Result<(), CoreError> {
    tx.execute(
        "UPDATE conversations SET revision=revision+1,updated_at=max(updated_at+1,?2) WHERE id=?1",
        params![id, now()],
    )
    .map_err(storage)?;
    Ok(())
}
fn record(row: &rusqlite::Row<'_>) -> rusqlite::Result<Conversation> {
    Ok(Conversation {
        id: row.get(0)?,
        title: row.get(1)?,
        character_id: row.get(2)?,
        character_name: row.get(3)?,
        revision: row.get(4)?,
        updated_at: row.get(5)?,
        message_count: row.get(6)?,
        folder: row.get(7)?,
        pinned: row.get(8)?,
        locked: row.get(9)?,
    })
}
const SELECT_CONVERSATIONS: &str = "SELECT c.id,c.title,c.character_id,coalesce(p.name,c.character_id),c.revision,c.updated_at,(SELECT count(*) FROM conversation_messages m WHERE m.conversation_id=c.id),c.folder,c.pinned,c.locked FROM conversations c LEFT JOIN prompt_characters p ON p.id=c.character_id";

fn selection(tx: &Connection, id: &str, target: Option<&str>) -> Result<Selection, CoreError> {
    exists(tx, id)?;
    let active: Option<String> = tx
        .query_row(
            "SELECT character_id FROM prompt_active WHERE id=1",
            [],
            |r| r.get(0),
        )
        .map_err(storage)?;
    let character = if let Some(target) = target {
        tx.query_row("SELECT r.role_id FROM conversation_messages m JOIN conversation_runs r ON r.id=m.run_id WHERE m.id=?1 AND m.conversation_id=?2 AND m.role='assistant'",params![target,id],|r|r.get::<_,Option<String>>(0)).map_err(|_|invalid("回复目标已不存在"))?
            .ok_or_else(||invalid("旧回复没有角色身份快照，无法准确重新生成；可编辑原提问重发"))?
    } else {
        active.ok_or_else(|| invalid("群组自动对话尚未接入，请先选择单个角色"))?
    };
    let card = crate::prompts::read_character(tx, &character)
        .map_err(|_| invalid("此会话的角色已删除，请选择角色或新建会话"))?;
    let (config_id, model) = match (&card.draft.model_config, &card.draft.model_name) {
        (Some(config), Some(model)) => (config.clone(), model.clone()),
        (None, None) => tx
            .query_row(
                "SELECT config_id,model_name FROM function_models WHERE function='chat'",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(storage)?,
        _ => return Err(invalid("角色模型绑定不完整，请重新选择")),
    };
    let config = models::read_config(tx, &config_id)?;
    if !config.draft.models.contains(&model) {
        return Err(invalid("聊天模型已不存在，请重新选择"));
    }
    let system = crate::prompts::compose_prompt(tx, &character, false)?;
    let summary = if config.draft.options.summary_enabled {
        Some(summary::model(tx)?)
    } else {
        None
    };
    Ok(Selection {
        config,
        model,
        character,
        role_name: card.draft.name,
        system,
        preferences: crate::chat_preferences::read(tx)?.value,
        summary,
    })
}

impl AppStore {
    fn conversation_statistics(&self, id: &str) -> Result<Statistics, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection.transaction().map_err(storage)?;
        exists(&tx, id)?;
        // 逐请求饱和相加，避免SQLite SUM溢出导致整张统计抽屉不可读。
        let mut requests = 0u32;
        let mut reported_requests = 0u32;
        let mut cache_reported_requests = 0u32;
        let (mut input_tokens, mut output_tokens) = (0i64, 0i64);
        let (mut cache_read_tokens, mut cache_write_tokens, mut reasoning_tokens) =
            (0i64, 0i64, 0i64);
        let (mut cache_input_tokens, mut uncached_input_tokens) = (0i64, 0i64);
        {
            let mut statement = tx.prepare("SELECT usage_reported,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,reasoning_tokens FROM conversation_runs WHERE conversation_id=?1 AND state<>'running' UNION ALL SELECT s.usage_reported,s.input_tokens,s.output_tokens,s.cache_read_tokens,s.cache_write_tokens,s.reasoning_tokens FROM conversation_summary_usage s JOIN conversation_runs r ON r.id=s.run_id WHERE r.conversation_id=?1 AND r.state<>'running'").map_err(storage)?;
            let rows = statement
                .query_map([id], |r| {
                    Ok((
                        r.get::<_, bool>(0)?,
                        r.get::<_, i64>(1)?,
                        r.get::<_, i64>(2)?,
                        r.get::<_, Option<i64>>(3)?,
                        r.get::<_, Option<i64>>(4)?,
                        r.get::<_, Option<i64>>(5)?,
                    ))
                })
                .map_err(storage)?;
            for row in rows {
                let (reported, input, output, read, write, reasoning) = row.map_err(storage)?;
                requests = requests.saturating_add(1);
                if !reported {
                    continue;
                }
                reported_requests = reported_requests.saturating_add(1);
                input_tokens = input_tokens.saturating_add(input);
                output_tokens = output_tokens.saturating_add(output);
                reasoning_tokens = reasoning_tokens.saturating_add(reasoning.unwrap_or(0));
                if let Some(read) = read {
                    cache_reported_requests = cache_reported_requests.saturating_add(1);
                    cache_read_tokens = cache_read_tokens.saturating_add(read);
                    cache_write_tokens = cache_write_tokens.saturating_add(write.unwrap_or(0));
                    cache_input_tokens = cache_input_tokens.saturating_add(input);
                    uncached_input_tokens =
                        uncached_input_tokens.saturating_add(input - read - write.unwrap_or(0));
                } else {
                    uncached_input_tokens = uncached_input_tokens.saturating_add(input);
                }
            }
        }
        use rusqlite::OptionalExtension;
        let recent = tx.query_row(
            "SELECT CASE WHEN usage_reported=1 THEN input_tokens END,CASE WHEN usage_reported=1 THEN output_tokens END,model,first_output_at-created_at,finished_at-created_at,cache_read_tokens,cache_write_tokens,reasoning_tokens FROM conversation_runs WHERE conversation_id=?1 AND kind='chat' ORDER BY created_at DESC,rowid DESC LIMIT 1",
            [id], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?,r.get(6)?,r.get(7)?))
        ).optional().map_err(storage)?.unwrap_or((None,None,String::new(),None,None,None,None,None));
        tx.commit().map_err(storage)?;
        Ok(Statistics {
            context_tokens: None,
            context_limit: None,
            tokens_per_second: None,
            speed_estimated: true,
            requests,
            reported_requests,
            input_tokens: (reported_requests > 0).then_some(input_tokens),
            output_tokens: (reported_requests > 0).then_some(output_tokens),
            recent_input_tokens: recent.0,
            recent_output_tokens: recent.1,
            recent_model: recent.2,
            first_output_ms: recent.3,
            duration_ms: recent.4,
            cache_reported_requests,
            cache_read_tokens: (cache_reported_requests > 0).then_some(cache_read_tokens),
            cache_write_tokens: (cache_write_tokens > 0).then_some(cache_write_tokens),
            reasoning_tokens: (reasoning_tokens > 0).then_some(reasoning_tokens),
            cache_input_tokens: (cache_reported_requests > 0).then_some(cache_input_tokens),
            uncached_input_tokens: (reported_requests > 0).then_some(uncached_input_tokens),
            recent_cache_read_tokens: recent.5,
            recent_cache_write_tokens: recent.6,
            recent_reasoning_tokens: recent.7,
        })
    }
    fn run_lock(&self, id: &str) -> Result<File, CoreError> {
        if id.len() != 32 || !id.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(invalid("会话标识无效"));
        }
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(self.directory.join(format!("chat-{id}.lock")))
            .map_err(|_| invalid("无法打开会话执行锁"))?;
        file.try_lock()
            .map_err(|_| invalid("此会话正在生成，请先停止"))?;
        Ok(file)
    }
    fn recover(&self, tx: &Connection) -> Result<(), CoreError> {
        let ids = tx
            .prepare("SELECT DISTINCT conversation_id FROM conversation_runs WHERE state='running'")
            .map_err(storage)?
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        for id in ids {
            // 活跃进程持有锁时保持running；只有OS确认旧owner已退出才标中断，绝不重发。
            if let Ok(_guard) = self.run_lock(&id) {
                tx.execute("UPDATE conversation_messages SET state='interrupted' WHERE conversation_id=?1 AND state='running'",[&id]).map_err(storage)?;
                tx.execute("UPDATE conversation_runs SET state='interrupted',error='上次生成已中断，未自动重试',finished_at=?2 WHERE conversation_id=?1 AND state='running'",params![id,now()]).map_err(storage)?;
                touch(tx, &id)?;
            }
        }
        Ok(())
    }
    pub fn conversation_catalog(&self) -> Result<ConversationCatalog, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        self.recover(&tx)?;
        let conversations = tx
            .prepare(&format!(
                "{SELECT_CONVERSATIONS} ORDER BY c.pinned DESC,c.sort_order DESC,c.updated_at DESC,c.id"
            ))
            .map_err(storage)?
            .query_map([], record)
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let active_id = tx
            .query_row(
                "SELECT active_id FROM conversation_state WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(ConversationCatalog {
            active_id,
            conversations,
        })
    }
    pub fn search_conversations(&self, query: &str) -> Result<Vec<String>, CoreError> {
        let query = query.trim();
        if query.len() > 4096 {
            return Err(invalid("搜索内容过长"));
        }
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        // 标题和完整正文使用同一查询快照；百分号/下划线是文字，不能成为SQL通配符。
        connection.prepare("SELECT c.id FROM conversations c WHERE ?1='' OR instr(lower(c.title),lower(?1))>0 OR EXISTS(SELECT 1 FROM conversation_messages m WHERE m.conversation_id=c.id AND instr(lower(m.content),lower(?1))>0) ORDER BY c.updated_at DESC,c.id")
            .map_err(storage)?.query_map([query], |row| row.get(0)).map_err(storage)?
            .collect::<Result<Vec<_>, _>>().map_err(storage)
    }

    pub fn conversation(&self, id: &str) -> Result<ConversationSnapshot, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        self.recover(&tx)?;
        exists(&tx, id)?;
        let conversation = tx
            .query_row(
                &format!("{SELECT_CONVERSATIONS} WHERE c.id=?1"),
                [id],
                record,
            )
            .map_err(storage)?;
        let messages = tx.prepare("SELECT m.id,coalesce(m.run_id,''),m.role,m.content,m.state,coalesce(r.error,''),coalesce(r.model,''),r.role_name,r.created_at,r.first_output_at-r.created_at,r.finished_at-r.first_output_at,CASE WHEN r.usage_reported=1 THEN r.input_tokens END,CASE WHEN r.usage_reported=1 THEN r.output_tokens END,m.variant,max(m.variant,coalesce((SELECT max(v.variant) FROM conversation_variants v WHERE v.message_id=m.id),0))+1,r.cache_read_tokens FROM conversation_messages m LEFT JOIN conversation_runs r ON r.id=m.run_id WHERE m.conversation_id=?1 ORDER BY m.position").map_err(storage)?
            .query_map([id],|r|Ok(Message {id:r.get(0)?,run_id:r.get(1)?,role:r.get(2)?,content:r.get(3)?,state:r.get(4)?,error:r.get(5)?,model:r.get(6)?,role_name:r.get(7)?,sent_at:r.get(8)?,first_output_ms:r.get(9)?,duration_ms:r.get(10)?,input_tokens:r.get(11)?,output_tokens:r.get(12)?,variant:r.get(13)?,variant_count:r.get(14)?,cache_read_tokens:r.get(15)?})).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
        let summary =
            summary::cached(&tx, id)?.map(|(through_position, content)| ConversationSummary {
                through_position,
                content,
            });
        tx.commit().map_err(storage)?;
        Ok(ConversationSnapshot {
            conversation,
            messages,
            summary,
        })
    }
    pub fn create_conversation(&self) -> Result<String, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let character: Option<String> = tx
            .query_row(
                "SELECT character_id FROM prompt_active WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(storage)?;
        let character =
            character.ok_or_else(|| invalid("群组自动对话尚未接入，请先选择单个角色"))?;
        let id = identity(&tx)?;
        tx.execute(
            "INSERT INTO conversations(id,title,character_id,created_at,updated_at,revision) VALUES(?1,'新对话',?2,?3,?3,1)",
            params![id, character, now()],
        )
        .map_err(storage)?;
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [&id],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn select_conversation(&self, id: &str) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        exists(&tx, id)?;
        if crate::chat_preferences::read(&tx)?.value.auto_character {
            let character: String = tx
                .query_row(
                    "SELECT character_id FROM conversations WHERE id=?1",
                    [id],
                    |r| r.get(0),
                )
                .map_err(storage)?;
            crate::prompts::read_character(&tx, &character)?;
            tx.execute(
                "UPDATE prompt_active SET character_id=?1,group_id=NULL WHERE id=1",
                [character],
            )
            .map_err(storage)?;
        }
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [id],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)
    }
    fn select_chat_character(&self, id: &str) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        crate::prompts::read_character(&tx, id)?;
        tx.execute(
            "UPDATE prompt_active SET character_id=?1,group_id=NULL WHERE id=1",
            [id],
        )
        .map_err(storage)?;
        if crate::chat_preferences::read(&tx)?.value.auto_chat {
            use rusqlite::OptionalExtension;
            let recent: Option<String> = tx.query_row("SELECT id FROM conversations WHERE character_id=?1 ORDER BY updated_at DESC,id DESC LIMIT 1", [id], |r| r.get(0)).optional().map_err(storage)?;
            let selected = match recent {
                Some(recent) => recent,
                None => {
                    let created = identity(&tx)?;
                    tx.execute("INSERT INTO conversations(id,title,character_id,created_at,updated_at,revision) VALUES(?1,'新对话',?2,?3,?3,1)", params![created,id,now()]).map_err(storage)?;
                    created
                }
            };
            tx.execute(
                "UPDATE conversation_state SET active_id=?1 WHERE id=1",
                [selected],
            )
            .map_err(storage)?;
        }
        tx.commit().map_err(storage)
    }
    pub fn change_conversation(
        &self,
        id: &str,
        revision: u32,
        action: &str,
        value: &str,
    ) -> Result<(), CoreError> {
        let _guard = self.run_lock(id)?;
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let current: u32 = tx
            .query_row(
                "SELECT revision FROM conversations WHERE id=?1",
                [id],
                |r| r.get(0),
            )
            .map_err(storage)?;
        if current != revision {
            return Err(invalid("会话已变化，请重新载入"));
        }
        match action {
            "metadata" => {
                #[derive(serde::Deserialize)]
                #[serde(deny_unknown_fields)]
                struct Metadata {
                    title: String,
                    folder: String,
                    #[serde(default)]
                    character: Option<String>,
                }
                let value: Metadata =
                    serde_json::from_str(value).map_err(|_| invalid("对话信息无效"))?;
                if value.title.trim().is_empty() || value.title.len() > 4096 {
                    return Err(invalid("标题为空或过长"));
                }
                if let Some(character) = &value.character
                    && !tx
                        .query_row(
                            "SELECT EXISTS(SELECT 1 FROM prompt_characters WHERE id=?1)",
                            [character],
                            |r| r.get::<_, bool>(0),
                        )
                        .map_err(storage)?
                {
                    return Err(invalid("角色已不存在"));
                }
                if !value.folder.is_empty()
                    && !tx
                        .query_row(
                            "SELECT EXISTS(SELECT 1 FROM conversation_folders WHERE name=?1)",
                            [&value.folder],
                            |r| r.get::<_, bool>(0),
                        )
                        .map_err(storage)?
                {
                    return Err(invalid("文件夹已不存在"));
                }
                tx.execute(
                    "UPDATE conversations SET title=?2,folder=?3,character_id=coalesce(?4,character_id) WHERE id=?1",
                    params![id, value.title.trim(), value.folder, value.character],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            "rename" => {
                if value.trim().is_empty() {
                    return Err(invalid("名称不能为空"));
                }
                tx.execute(
                    "UPDATE conversations SET title=?2 WHERE id=?1",
                    params![id, value.trim()],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            "delete" => {
                let locked: bool = tx
                    .query_row("SELECT locked FROM conversations WHERE id=?1", [id], |r| {
                        r.get(0)
                    })
                    .map_err(storage)?;
                if locked {
                    return Err(invalid("已锁定的对话不能删除，请先解锁"));
                }
                tx.execute("DELETE FROM conversations WHERE id=?1", [id])
                    .map_err(storage)?;
            }
            "character" => {
                crate::prompts::read_character(&tx, value)?;
                tx.execute(
                    "UPDATE conversations SET character_id=?2 WHERE id=?1",
                    params![id, value],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            "locked" | "pinned" => {
                if !matches!(value, "true" | "false") {
                    return Err(invalid("会话标记无效"));
                }
                tx.execute(
                    &format!("UPDATE conversations SET {action}=?2 WHERE id=?1"),
                    params![id, value == "true"],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            "folder" => {
                if !value.is_empty()
                    && !tx
                        .query_row(
                            "SELECT EXISTS(SELECT 1 FROM conversation_folders WHERE name=?1)",
                            [value],
                            |r| r.get::<_, bool>(0),
                        )
                        .map_err(storage)?
                {
                    return Err(invalid("文件夹已不存在"));
                }
                tx.execute(
                    "UPDATE conversations SET folder=?2 WHERE id=?1",
                    params![id, value],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            "up" | "down" | "bottom" | "before" => {
                let (folder, pinned, character): (String, bool, String) = tx
                    .query_row(
                        "SELECT folder,pinned,character_id FROM conversations WHERE id=?1",
                        [id],
                        |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                    )
                    .map_err(storage)?;
                // 排序范围必须与历史投影一致；角色模式不能改动其它角色的序号或revision。
                let scoped = crate::chat_preferences::read(&tx)?.value.history_mode != "folder";
                let mut ids=tx.prepare("SELECT id FROM conversations WHERE folder=?1 AND pinned=?2 AND (?3=0 OR character_id=?4) ORDER BY sort_order DESC,updated_at DESC,id").map_err(storage)?.query_map(params![folder,pinned,scoped,character],|r|r.get::<_,String>(0)).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
                let position = ids
                    .iter()
                    .position(|entry| entry == id)
                    .ok_or_else(|| invalid("会话已不存在"))?;
                let target = match action {
                    "up" => position.saturating_sub(1),
                    "down" => (position + 1).min(ids.len() - 1),
                    "before" => {
                        let target = ids
                            .iter()
                            .position(|entry| entry == value)
                            .ok_or_else(|| invalid("只能在同一分组和置顶状态内排序"))?;
                        if target > position {
                            target - 1
                        } else {
                            target
                        }
                    }
                    _ => ids.len() - 1,
                };
                let moved = ids.remove(position);
                ids.insert(target, moved);
                for (index, entry) in ids.iter().enumerate() {
                    tx.execute(
                        "UPDATE conversations SET sort_order=?2,revision=revision+1 WHERE id=?1",
                        params![entry, (ids.len() - index) as i64],
                    )
                    .map_err(storage)?;
                }
            }
            "clear" => {
                tx.execute(
                    "DELETE FROM conversation_summaries WHERE conversation_id=?1",
                    [id],
                )
                .map_err(storage)?;
                tx.execute(
                    "DELETE FROM conversation_messages WHERE conversation_id=?1",
                    [id],
                )
                .map_err(storage)?;
                tx.execute(
                    "DELETE FROM conversation_runs WHERE conversation_id=?1",
                    [id],
                )
                .map_err(storage)?;
                touch(&tx, id)?;
            }
            _ => return Err(invalid("未知会话操作")),
        }
        tx.commit().map_err(storage)
    }
    pub fn change_message(
        &self,
        id: &str,
        revision: u32,
        message: &str,
        action: &str,
        text: &str,
    ) -> Result<(), CoreError> {
        let _guard = self.run_lock(id)?;
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let current: u32 = tx
            .query_row(
                "SELECT revision FROM conversations WHERE id=?1",
                [id],
                |r| r.get(0),
            )
            .map_err(storage)?;
        if current != revision {
            return Err(invalid("会话已变化，请重新载入"));
        }
        let position: i64 = tx
            .query_row(
                "SELECT position FROM conversation_messages WHERE id=?1 AND conversation_id=?2",
                params![message, id],
                |r| r.get(0),
            )
            .map_err(storage)?;
        if action != "branch" {
            // 修改/删除/切换版本后不能把旧摘要作为新历史事实继续使用。
            tx.execute(
                "DELETE FROM conversation_summaries WHERE conversation_id=?1",
                [id],
            )
            .map_err(storage)?;
            // 原文或较早摘要变化会使后续检查点过期；仍保留可见全文供用户核对。
            tx.execute("UPDATE conversation_messages SET state='invalidated' WHERE conversation_id=?1 AND role='summary' AND position>?2",params![id,position]).map_err(storage)?;
        }
        match action {
            "delete_selected" => {
                let ids: Vec<String> =
                    serde_json::from_str(text).map_err(|_| invalid("消息选择无效"))?;
                if ids.is_empty() || ids.len() > 10000 {
                    return Err(invalid("消息选择无效"));
                }
                for selected in ids {
                    tx.execute("UPDATE conversation_messages SET state='invalidated' WHERE conversation_id=?1 AND role='summary' AND position>(SELECT position FROM conversation_messages WHERE id=?2 AND conversation_id=?1)",params![id,selected]).map_err(storage)?;
                    let affected = tx
                        .execute(
                            "DELETE FROM conversation_messages WHERE id=?1 AND conversation_id=?2",
                            params![selected, id],
                        )
                        .map_err(storage)?;
                    if affected != 1 {
                        return Err(invalid("选中消息已变化，请重新选择"));
                    }
                }
            }
            "variant" => {
                let target: u32 = text.parse().map_err(|_| invalid("回复版本无效"))?;
                tx.execute("INSERT OR REPLACE INTO conversation_variants SELECT id,variant,run_id,content,state FROM conversation_messages WHERE id=?1 AND role='assistant'",[message]).map_err(storage)?;
                let (run,content,state):(Option<String>,String,String)=tx.query_row("SELECT run_id,content,state FROM conversation_variants WHERE message_id=?1 AND variant=?2",params![message,target],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(|_| invalid("回复版本已不存在"))?;
                tx.execute("UPDATE conversation_messages SET variant=?2,run_id=?3,content=?4,state=?5 WHERE id=?1",params![message,target,run,content,state]).map_err(storage)?;
            }
            "delete_variant" => {
                tx.execute("INSERT OR REPLACE INTO conversation_variants SELECT id,variant,run_id,content,state FROM conversation_messages WHERE id=?1 AND role='assistant'",[message]).map_err(storage)?;
                let selected: u32 = tx
                    .query_row(
                        "SELECT variant FROM conversation_messages WHERE id=?1",
                        [message],
                        |r| r.get(0),
                    )
                    .map_err(storage)?;
                let mut versions=tx.prepare("SELECT variant,run_id,content,state FROM conversation_variants WHERE message_id=?1 AND variant<>?2 ORDER BY variant").map_err(storage)?
                    .query_map(params![message,selected],|r|Ok((r.get::<_,u32>(0)?,r.get::<_,Option<String>>(1)?,r.get::<_,String>(2)?,r.get::<_,String>(3)?))).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
                if versions.is_empty() {
                    return Err(invalid("最后一个回复版本不能单独删除"));
                }
                tx.execute(
                    "DELETE FROM conversation_variants WHERE message_id=?1",
                    [message],
                )
                .map_err(storage)?;
                for (index, version) in versions.iter_mut().enumerate() {
                    version.0 = index as u32;
                    tx.execute(
                        "INSERT INTO conversation_variants VALUES(?1,?2,?3,?4,?5)",
                        params![message, index as i64, version.1, version.2, version.3],
                    )
                    .map_err(storage)?;
                }
                let index = (selected as usize).min(versions.len() - 1);
                let version = &versions[index];
                tx.execute("UPDATE conversation_messages SET variant=?2,run_id=?3,content=?4,state=?5 WHERE id=?1",params![message,index as i64,version.1,version.2,version.3]).map_err(storage)?;
            }
            "branch" => {
                let branch = identity(&tx)?;
                tx.execute("INSERT INTO conversations(id,title,character_id,created_at,updated_at,revision,folder) SELECT ?2,title||' (分支)',character_id,?3,?3,1,folder FROM conversations WHERE id=?1", params![id,branch,now()]).map_err(storage)?;
                // 分支复制独立运行快照与完整消息；源对话删除/编辑不会级联影响分支。
                tx.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,error,created_at,finished_at,input_tokens,output_tokens,usage_reported,first_output_at,role_name,role_id,cache_read_tokens,cache_write_tokens,reasoning_tokens,kind) SELECT ?3||'/'||r.id,?3,r.state,r.config_id,r.config_revision,r.model,r.error,r.created_at,r.finished_at,r.input_tokens,r.output_tokens,r.usage_reported,r.first_output_at,r.role_name,r.role_id,r.cache_read_tokens,r.cache_write_tokens,r.reasoning_tokens,r.kind FROM conversation_runs r WHERE r.conversation_id=?1 AND EXISTS(SELECT 1 FROM conversation_messages m WHERE m.position<=?2 AND (m.run_id=r.id OR EXISTS(SELECT 1 FROM conversation_variants v WHERE v.message_id=m.id AND v.run_id=r.id)))",params![id,position,branch]).map_err(storage)?;
                tx.execute("INSERT INTO conversation_messages(id,conversation_id,run_id,position,role,content,state,variant) SELECT ?3||'/'||id,?3,CASE WHEN run_id IS NULL THEN NULL ELSE ?3||'/'||run_id END,position,role,content,state,variant FROM conversation_messages WHERE conversation_id=?1 AND position<=?2",params![id,position,branch]).map_err(storage)?;
                tx.execute("INSERT INTO conversation_variants SELECT ?3||'/'||v.message_id,v.variant,CASE WHEN v.run_id IS NULL THEN NULL ELSE ?3||'/'||v.run_id END,v.content,v.state FROM conversation_variants v JOIN conversation_messages m ON m.id=v.message_id WHERE m.conversation_id=?1 AND m.position<=?2",params![id,position,branch]).map_err(storage)?;
                tx.execute("INSERT INTO conversation_summaries SELECT ?3,through_position,content FROM conversation_summaries WHERE conversation_id=?1 AND through_position<=?2",params![id,position,branch]).map_err(storage)?;
                tx.execute("INSERT INTO conversation_summary_usage SELECT ?2||'/'||s.run_id,s.model,s.input_tokens,s.output_tokens,s.usage_reported,s.cache_read_tokens,s.cache_write_tokens,s.reasoning_tokens FROM conversation_summary_usage s WHERE EXISTS(SELECT 1 FROM conversation_runs r WHERE r.id=?2||'/'||s.run_id)",params![id,branch]).map_err(storage)?;
                tx.execute(
                    "UPDATE conversation_state SET active_id=?1 WHERE id=1",
                    [branch],
                )
                .map_err(storage)?;
            }
            "edit" => {
                if text.trim().is_empty() || text.len() > 8 * 1024 * 1024 {
                    return Err(invalid("消息为空或超过8 MiB限制"));
                }
                tx.execute(
                    "UPDATE conversation_messages SET content=?2 WHERE id=?1",
                    params![message, text],
                )
                .map_err(storage)?;
                tx.execute("UPDATE conversation_messages SET state='completed' WHERE id=?1 AND role='summary'",[message]).map_err(storage)?;
            }
            "delete" => {
                tx.execute("DELETE FROM conversation_messages WHERE id=?1", [message])
                    .map_err(storage)?;
            }
            "deleteFrom" => {
                tx.execute(
                    "DELETE FROM conversation_messages WHERE conversation_id=?1 AND position>=?2",
                    params![id, position],
                )
                .map_err(storage)?;
            }
            _ => return Err(invalid("未知消息操作")),
        }
        touch(&tx, id)?;
        tx.commit().map_err(storage)
    }
}

impl Runtime {
    pub fn select_chat_character(&self, id: String) -> Result<(), CoreError> {
        self.with_store(|store| store.select_chat_character(&id))
    }
    pub fn conversation_statistics(&self, id: String) -> Result<Statistics, CoreError> {
        let mut statistics = self.with_store(|store| store.conversation_statistics(&id))?;
        let observation = self
            .chat_observations
            .lock()
            .map_err(|_| invalid("请求观测锁不可用"))?
            .get(&id)
            .map(|tracker| {
                tracker
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner)
                    .snapshot()
            });
        let v = observation.clone().unwrap_or_default();
        statistics.context_tokens = observation.as_ref().map(|v| v.context_tokens);
        statistics.context_limit = observation.as_ref().map(|v| v.context_limit);
        statistics.tokens_per_second = v.tokens_per_second;
        statistics.speed_estimated = v.estimated;
        statistics.recent_input_tokens = v.input_tokens;
        statistics.recent_output_tokens = v.output_tokens;
        statistics.recent_model = v.model;
        statistics.recent_cache_read_tokens = v.cache_read_tokens;
        statistics.recent_cache_write_tokens = v.cache_write_tokens;
        statistics.recent_reasoning_tokens = v.reasoning_tokens;
        statistics.first_output_ms = v.first_output_ms;
        statistics.duration_ms = v.duration_ms;
        Ok(statistics)
    }
    pub fn search_conversations(&self, query: &str) -> Result<Vec<String>, CoreError> {
        self.with_store(|store| store.search_conversations(query))
    }
    pub fn conversation_catalog(&self) -> Result<ConversationCatalog, CoreError> {
        self.with_store(AppStore::conversation_catalog)
    }
    pub fn conversation(&self, id: String) -> Result<ConversationSnapshot, CoreError> {
        self.with_store(|s| s.conversation(&id))
    }
    pub fn create_conversation(&self) -> Result<String, CoreError> {
        self.with_store(AppStore::create_conversation)
    }
    pub fn select_conversation(&self, id: String) -> Result<(), CoreError> {
        self.with_store(|s| s.select_conversation(&id))
    }
    pub fn change_conversation(
        &self,
        id: String,
        revision: u32,
        action: String,
        value: String,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.change_conversation(&id, revision, &action, &value))?;
        if action == "delete" {
            self.chat_observations
                .lock()
                .map_err(|_| invalid("请求观测锁不可用"))?
                .remove(&id);
        }
        Ok(())
    }
    pub fn change_message(
        &self,
        id: String,
        revision: u32,
        message: String,
        action: String,
        text: String,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.change_message(&id, revision, &message, &action, &text))
    }
    pub fn prepare_conversation(&self, id: String) -> Result<PreparedSend, CoreError> {
        self.prepare_conversation_target(id, None)
    }
    pub fn prepare_conversation_target(
        &self,
        id: String,
        target: Option<String>,
    ) -> Result<PreparedSend, CoreError> {
        let store = self.persistent_store()?;
        let lease = store.begin_model_secrets()?;
        let selection = {
            let mut connection = store
                .connection
                .lock()
                .map_err(|_| invalid("聊天存储锁不可用"))?;
            let tx = connection.transaction().map_err(storage)?;
            let selection = selection(&tx, &id, target.as_deref())?;
            tx.commit().map_err(storage)?;
            selection
        };
        Ok(PreparedSend {
            lease,
            store,
            conversation: id,
            selection,
            target,
        })
    }
    pub fn start_conversation(
        &self,
        prepared: PreparedSend,
        text: String,
        payload: String,
    ) -> Result<chat::ChatRun, CoreError> {
        self.start_conversation_replacing(prepared, text, payload, None, None)
    }
    pub fn start_conversation_replacing(
        &self,
        prepared: PreparedSend,
        text: String,
        payload: String,
        replace_from: Option<String>,
        revision: Option<u32>,
    ) -> Result<chat::ChatRun, CoreError> {
        self.start_conversation_replying(prepared, text, payload, replace_from, revision, None)
    }
    pub fn start_conversation_replying(
        &self,
        prepared: PreparedSend,
        text: String,
        payload: String,
        replace_from: Option<String>,
        revision: Option<u32>,
        reply_to: Option<String>,
    ) -> Result<chat::ChatRun, CoreError> {
        self.start_conversation_with_summary(
            prepared,
            text,
            payload,
            None,
            replace_from,
            revision,
            reply_to,
        )
    }
    #[allow(clippy::too_many_arguments)]
    pub fn start_conversation_with_summary(
        &self,
        prepared: PreparedSend,
        text: String,
        payload: String,
        summary_payload: Option<String>,
        replace_from: Option<String>,
        revision: Option<u32>,
        reply_to: Option<String>,
    ) -> Result<chat::ChatRun, CoreError> {
        self.ensure_open()?;
        let store = self.persistent_store()?;
        if !Arc::ptr_eq(&store, &prepared.store) {
            return Err(invalid("请求准备不属于当前运行时"));
        }
        if text.trim().is_empty() || text.len() > 8 * 1024 * 1024 {
            return Err(invalid("消息为空或超过8 MiB限制"));
        }
        let client = self
            .chat_client
            .get_or_init(|| chat::client().map(Arc::new))
            .clone()?;
        let run_guard = store.run_lock(&prepared.conversation)?;
        let (mut request,run_id,context_limit)=prepared.lease.with_store(&store,|| {
            let mut connection=store.connection.lock().map_err(|_|invalid("聊天存储锁不可用"))?;
            let tx=connection.transaction_with_behavior(TransactionBehavior::Immediate).map_err(storage)?;
            let selected=selection(&tx,&prepared.conversation,prepared.target.as_deref())?;
            if selected!=prepared.selection {return Err(invalid("配置、角色或模型已变化，请重新发送"));}
            if !matches!(selected.config.draft.protocol.as_str(),"chat"|"responses"|"messages"|"native") {return Err(invalid("该模型协议的请求执行尚未接入"));}
            let text = if let Some(reply) = &reply_to {
                let (content,name,created): (String,String,i64) = tx.query_row("SELECT m.content,coalesce(r.role_name,''),coalesce(r.created_at,0) FROM conversation_messages m LEFT JOIN conversation_runs r ON r.id=m.run_id WHERE m.id=?1 AND m.conversation_id=?2 AND m.role='assistant'",params![reply,prepared.conversation],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(|_| invalid("回复目标已不存在，请重新选择"))?;
                fn escape(value: &str) -> String { value.replace('&',"&amp;").replace('<',"&lt;").replace('>',"&gt;").replace('"',"&quot;") }
                // 保留完整引用正文，不用旧预览长度截断正式上下文；源消息不变。
                format!("{text}\n\n<reply_to sender=\"{}\" timestamp=\"{created}\">用户正在回复你之前的这条消息：\"{}\"</reply_to>",escape(&name),escape(&content))
            } else {text};
            if text.len() > 8 * 1024 * 1024 { return Err(invalid("引用后的消息超过8 MiB限制")); }
            let mut regenerating = false;
            let cutoff = if let Some(message) = &replace_from {
                let current:u32=tx.query_row("SELECT revision FROM conversations WHERE id=?1",[&prepared.conversation],|r|r.get(0)).map_err(storage)?;
                if revision != Some(current) {return Err(invalid("会话已变化，请重新载入"));}
                let (position,role):(i64,String)=tx.query_row("SELECT position,role FROM conversation_messages WHERE id=?1 AND conversation_id=?2",params![message,prepared.conversation],|r|Ok((r.get(0)?,r.get(1)?))).map_err(storage)?;
                regenerating = role == "assistant";
                if regenerating && prepared.target.as_deref() != Some(message.as_str()) {
                    return Err(invalid("重新生成必须先按目标角色准备请求"));
                }
                position
            } else {i64::MAX};
            // 重新生成也有当前问题：保留最后user及其后的目标前尾部，摘要不能吞掉它。
            // 更晚请求形成的缓存可能已经覆盖该问题，必须退回完整原文重新投影。
            let keep_from:i64=if regenerating {
                tx.query_row("SELECT coalesce(max(position),0) FROM conversation_messages WHERE conversation_id=?1 AND position<?2 AND role='user'",params![prepared.conversation,cutoff],|r|r.get(0)).map_err(storage)?
            } else {i64::MAX};
            let checkpoint=summary::checkpoint(&tx,&prepared.conversation,cutoff.min(keep_from))?;
            let cached=summary::cached(&tx,&prepared.conversation)?.filter(|(through,_)|*through<cutoff && *through<keep_from && selected.config.draft.options.summary_enabled && checkpoint.as_ref().is_none_or(|c|*through>c.0));
            let projected=cached.or(checkpoint);
            let after_position=projected.as_ref().map_or(-1,|(through,_)|*through);
            let previous=projected.map(|(_,content)|content);
            let mut statement=tx.prepare("SELECT position,role,content FROM conversation_messages WHERE conversation_id=?1 AND position<?2 AND position>?3 AND content<>'' AND role IN ('user','assistant') ORDER BY position").map_err(storage)?;
            let rows=statement.query_map(params![prepared.conversation,cutoff,after_position],|r|Ok((r.get::<_,i64>(0)?,chat::ChatMessage{role:r.get(1)?,content:r.get(2)?}))).map_err(storage)?;
            let mut recent=Vec::new(); let mut after=Vec::new(); let mut bytes=0usize; let mut through=after_position;
            for row in rows {
                let (position,row)=row.map_err(storage)?; bytes+=row.content.len();
                if position>=keep_from {after.push(row);} else {through=position; recent.push(row);}
                if recent.len()+after.len()>=999 || bytes>8*1024*1024 {return Err(invalid("历史超过当前总结请求限制，请增大上下文或新建会话；原文未截断"));}
            }
            drop(statement);
            let user_count=recent.iter().filter(|m|m.role=="user").count();
            if !regenerating {after.push(chat::ChatMessage{role:"user".into(),content:text.clone()});}
            let mut messages=summary::projection(&selected.system,previous.as_deref(),&recent);
            messages.extend_from_slice(&after);
            let options=&selected.config.draft.options;
            let context=if options.max_context_mode {options.max_context_length} else {options.context_length};
            let should_summarize=!recent.is_empty() && summary::triggered(options,&messages,user_count,context);
            if !should_summarize { summary::budget(&messages,context)?; }
            let (api_key,headers)=model_execution::select_credentials(&tx,&selected.config.id,&payload)?;
            let mut request=chat::probe::prepare(selected.config.draft.clone(),api_key,headers,"chat")?;
            request.admission=Some(self.model_limits.configure(&selected.config.id,selected.config.revision,options.request_limit,options.concurrent_limit));
            request.probe=None; request.messages=messages; request.model=selected.model.clone(); request.timeout_ms=600_000;
            request.stream = !selected.preferences.disable_stream;
            apply_thinking(&mut request,&selected.preferences)?;
            // 重发的截断与新消息同事务提交；凭据/配置校验失败不得先删历史。
            if replace_from.is_some() && !regenerating {
                tx.execute("DELETE FROM conversation_messages WHERE conversation_id=?1 AND position>=?2",params![prepared.conversation,cutoff]).map_err(storage)?;
                tx.execute("DELETE FROM conversation_summaries WHERE conversation_id=?1 AND through_position>=?2",params![prepared.conversation,cutoff]).map_err(storage)?;
            }
            let run_id=identity(&tx)?; let user_id=identity(&tx)?; let assistant_id=identity(&tx)?;
            if should_summarize {
                request.prelude=Some(Box::new(summary::prepare(summary::Input{
                    tx:&tx, selected:&selected,recent,previous,through,conversation:prepared.conversation.clone(),payload:&payload,
                    summary_payload:summary_payload.as_deref(),store:store.clone(),context,limits:&self.model_limits,run_id:run_id.clone(),after,target:prepared.target.clone(),
                })?));
            }
            let position:i64=tx.query_row("SELECT coalesce(max(position)+1,0) FROM conversation_messages WHERE conversation_id=?1",[&prepared.conversation],|r|r.get(0)).map_err(storage)?;
            tx.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at,role_name,role_id) VALUES(?1,?2,'running',?3,?4,?5,?6,?7,?8)",params![run_id,prepared.conversation,selected.config.id,selected.config.revision,selected.model,now(),selected.role_name,selected.character]).map_err(storage)?;
            if should_summarize {
                tx.execute("INSERT INTO conversation_summary_usage(run_id,model) VALUES(?1,?2)",params![run_id,selected.summary.as_ref().ok_or_else(||invalid("总结模型绑定不可用"))?.name]).map_err(storage)?;
            }
            if regenerating {
                let target=replace_from.as_ref().ok_or_else(||invalid("回复目标无效"))?;
                tx.execute("DELETE FROM conversation_summaries WHERE conversation_id=?1 AND through_position>=?2",params![prepared.conversation,keep_from]).map_err(storage)?;
                tx.execute("UPDATE conversation_messages SET state='invalidated' WHERE conversation_id=?1 AND role='summary' AND position>=?2",params![prepared.conversation,keep_from]).map_err(storage)?;
                tx.execute("INSERT OR REPLACE INTO conversation_variants SELECT id,variant,run_id,content,state FROM conversation_messages WHERE id=?1",[target]).map_err(storage)?;
                tx.execute("UPDATE conversation_messages SET run_id=?2,content='',state='running',variant=(SELECT max(variant)+1 FROM conversation_variants WHERE message_id=?1) WHERE id=?1",params![target,run_id]).map_err(storage)?;
            } else {
                tx.execute("INSERT INTO conversation_messages(id,conversation_id,run_id,position,role,content,state) VALUES(?1,?2,?3,?4,'user',?5,'completed')",params![user_id,prepared.conversation,run_id,position,text]).map_err(storage)?;
                tx.execute("INSERT INTO conversation_messages(id,conversation_id,run_id,position,role,content,state) VALUES(?1,?2,?3,?4,'assistant','','running')",params![assistant_id,prepared.conversation,run_id,position+1]).map_err(storage)?;
            }
            if position==0 {
                let title=text.trim().chars().take(30).collect::<String>();
                tx.execute("UPDATE conversations SET title=?2 WHERE id=?1 AND title='新对话'",params![prepared.conversation,title]).map_err(storage)?;
            }
            touch(&tx,&prepared.conversation)?;
            tx.commit().map_err(storage)?;
            Ok((request,run_id,(context*1024.) as i64))
        })?;
        let observation = Arc::new(std::sync::Mutex::new(chat::observation::Tracker::new(
            request.stream,
            format!(
                "{}:{}",
                prepared.selection.config.draft.provider, request.model
            ),
            &request.messages,
            context_limit,
        )));
        self.chat_observations
            .lock()
            .map_err(|_| invalid("请求观测锁不可用"))?
            .insert(prepared.conversation.clone(), observation.clone());
        // 安全引用已解析成短期请求，不把lease延长到网络/流式阶段。
        drop(prepared);
        self.bind_inference(&mut request);
        let cancellation = self.cancellation.child_token();
        let upstream = chat::start_observed(
            client,
            request,
            cancellation.child_token(),
            Some(observation),
        );
        Ok(chat::persist(upstream, cancellation, move |event| {
            let _keep_lock = &run_guard;
            store.persist_conversation_event(&run_id, event)
        }))
    }
}

pub(crate) fn apply_thinking(
    request: &mut chat::ChatRequest,
    preferences: &crate::chat_preferences::Preferences,
) -> Result<(), CoreError> {
    if let Some(extension) = &mut request.extension {
        extension.thinking = preferences.thinking;
        return Ok(());
    }
    if let Some(local) = &mut request.local {
        local.thinking = preferences.thinking;
        return Ok(());
    }
    let mut parameters: serde_json::Value =
        serde_json::from_str(&request.parameters).map_err(|_| invalid("模型参数无效"))?;
    let object = parameters
        .as_object_mut()
        .ok_or_else(|| invalid("模型参数无效"))?;
    if request.protocol == "native" {
        chat::gemini::thinking(
            object,
            &request.model,
            preferences.thinking,
            preferences.thinking_quality,
        )?;
        request.parameters = parameters.to_string();
        return Ok(());
    }
    // 显式模型参数优先；已支持的旧源合同之外不猜测供应商字段。
    if object.contains_key("reasoning")
        || object.contains_key("reasoning_effort")
        || object.contains_key("thinking")
    {
        return Ok(());
    }
    let model = request
        .model
        .trim()
        .rsplit('/')
        .next()
        .unwrap_or("")
        .to_ascii_lowercase();
    let deepseek = deepseek_model(&model);
    if request.protocol == "messages" {
        chat::messages::thinking(
            object,
            &request.model,
            preferences.thinking,
            preferences.thinking_quality,
            deepseek,
        )?;
        request.parameters = parameters.to_string();
        return Ok(());
    }
    let sol61 = model == "gpt-6.1-sol"
        || model.strip_prefix("gpt-6.1-sol-").is_some_and(|suffix| {
            let parts: Vec<_> = suffix.split('-').collect();
            parts.len() == 3
                && parts.iter().enumerate().all(|(i, p)| {
                    p.len() == if i == 0 { 4 } else { 2 } && p.bytes().all(|c| c.is_ascii_digit())
                })
        });
    let gpt = sol61
        || ["gpt-5.4", "gpt-5.5", "gpt-5.6", "gpt-6-astra"]
            .iter()
            .any(|prefix| model == *prefix || model.starts_with(&format!("{prefix}-")));
    if !deepseek && !gpt {
        if preferences.thinking {
            return Err(invalid(
                "当前模型的思考参数合同尚未接入，请关闭思考或在模型配置中显式设置",
            ));
        }
        return Ok(());
    }
    // 官方 Sol 6.1 不支持 none；代理接受 none 不证明已关闭思考。
    // 显式配置仍在上面优先返回；自动模式拒绝假装关闭或静默降成 low。
    if sol61 && !preferences.thinking {
        return Err(invalid(
            "gpt-6.1-sol不支持关闭思考，请开启思考或显式配置代理支持的参数",
        ));
    }
    let level = preferences.thinking_quality.saturating_sub(1).min(4) as usize;
    let effort = if !preferences.thinking && !model.starts_with("gpt-6-astra") {
        "none"
    } else if deepseek {
        ["low", "high", "max", "max", "max"][level]
    } else if sol61 || model.starts_with("gpt-5.6") || model.contains("astra") {
        ["low", "medium", "high", "xhigh", "max"][level]
    } else {
        ["low", "medium", "high", "xhigh", "xhigh"][level]
    };
    if request.protocol == "responses" {
        object.insert("reasoning".into(), serde_json::json!({"effort":effort}));
    } else if deepseek {
        object.insert(
            "thinking".into(),
            serde_json::json!({"type":if preferences.thinking {"enabled"}else{"disabled"}}),
        );
        if preferences.thinking {
            object.insert("reasoning_effort".into(), serde_json::json!(effort));
        }
    } else {
        object.insert("reasoning_effort".into(), serde_json::json!(effort));
    }
    request.parameters = parameters.to_string();
    Ok(())
}

// 旧源DeepSeekModelContract的模型别名合同。名称匹配不授予端点恢复、缓存或重试权限。
fn deepseek_model(model: &str) -> bool {
    if matches!(model, "deepseek-chat" | "deepseek-reasoner") {
        return true;
    }
    let Some(suffix) = model.strip_prefix("deepseek-") else {
        return false;
    };
    let suffix = suffix
        .strip_prefix("v4.1-")
        .or_else(|| suffix.strip_prefix("v4-"))
        .unwrap_or(suffix);
    let Some(date) = suffix
        .strip_prefix("flash")
        .or_else(|| suffix.strip_prefix("pro"))
    else {
        return false;
    };
    if date.is_empty() {
        return true;
    }
    let parts: Vec<_> = date.strip_prefix('-').unwrap_or("").split('-').collect();
    (parts.len() == 1 || parts.len() == 3)
        && parts.iter().enumerate().all(|(i, p)| {
            p.len() == if i == 0 { 4 } else { 2 } && p.bytes().all(|c| c.is_ascii_digit())
        })
}

impl AppStore {
    fn persist_conversation_event(
        &self,
        run: &str,
        event: chat::ChatEvent,
    ) -> Result<chat::ChatEvent, CoreError> {
        self.persist_event(run, event, None)
    }
    fn persist_event(
        &self,
        run: &str,
        mut event: chat::ChatEvent,
        manual: Option<&manual_summary::Commit>,
    ) -> Result<chat::ChatEvent, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("聊天存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let (conversation, state): (String, String) = tx
            .query_row(
                "SELECT conversation_id,state FROM conversation_runs WHERE id=?1",
                [run],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(storage)?;
        if state != "running" {
            return Err(invalid("执行已经结束"));
        }
        if let chat::ChatEvent::Completed { reason, .. } = &event
            && reason == "stop"
            && let Some(manual) = manual
            && let Err(error) = manual.insert(&tx, run)
        {
            if error.code == ErrorCode::Storage {
                return Err(error);
            }
            event = chat::ChatEvent::Failed(chat::ChatFailure::new(
                chat::ChatFailureKind::InvalidInput,
                &error.message,
            ));
        }
        if let chat::ChatEvent::Completed { reason, .. } = &event {
            let nonempty:bool=tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_messages WHERE run_id=?1 AND role IN ('assistant','summary') AND length(trim(content))>0)",[run],|r|r.get(0)).map_err(storage)?;
            if reason != "stop" || !nonempty {
                event = chat::ChatEvent::Failed(chat::ChatFailure::new(
                    chat::ChatFailureKind::Interrupted,
                    if reason != "stop" {
                        "回复未完整结束，已保留收到的内容"
                    } else {
                        "模型返回空回复"
                    },
                ));
            }
        }
        let mut terminal = None;
        match &event {
            chat::ChatEvent::Text(text) => {
                if manual.is_none() {
                    let bytes:i64=tx.query_row("SELECT length(CAST(content AS BLOB)) FROM conversation_messages WHERE run_id=?1 AND role='assistant'",[run],|r|r.get(0)).map_err(storage)?;
                    if bytes as usize + text.len() > 8 * 1024 * 1024 {
                        return Err(invalid("回复超过8 MiB存储限制"));
                    }
                    tx.execute("UPDATE conversation_messages SET content=content||?2 WHERE run_id=?1 AND role='assistant'",params![run,text]).map_err(storage)?;
                }
                if !text.is_empty() {
                    tx.execute("UPDATE conversation_runs SET first_output_at=coalesce(first_output_at,max(created_at,?2)) WHERE id=?1",params![run,now()]).map_err(storage)?;
                }
            }
            chat::ChatEvent::Usage {
                input,
                output,
                output_reported,
                cache_read,
                cache_write,
                reasoning,
                ..
            } => {
                let to_storage = |value: u64| {
                    i64::try_from(value).map_err(|_| invalid("供应商用量超出存储范围"))
                };
                let (input, output) = (to_storage(*input)?, to_storage(*output)?);
                let read = cache_read.map(to_storage).transpose()?;
                let write = cache_write.map(to_storage).transpose()?;
                let reasoning = reasoning
                    .map(to_storage)
                    .transpose()?
                    .filter(|value| *value <= output);
                let valid =
                    read.is_some_and(|read| read <= input && write.unwrap_or(0) <= input - read);
                tx.execute(
                    "UPDATE conversation_runs SET input_tokens=?2,output_tokens=?3,usage_reported=?7,cache_read_tokens=?4,cache_write_tokens=?5,reasoning_tokens=?6 WHERE id=?1",
                    params![run, input, output, if valid {read} else {None}, if valid {write} else {None}, reasoning, output_reported],
                )
                .map_err(storage)?;
            }
            chat::ChatEvent::Completed { .. } => terminal = Some(("completed", String::new())),
            chat::ChatEvent::Cancelled => terminal = Some(("cancelled", String::new())),
            chat::ChatEvent::Failed(error) => terminal = Some(("failed", error.message.clone())),
            _ => {}
        }
        if let Some((state, error)) = terminal {
            tx.execute(
                "UPDATE conversation_messages SET state=?2 WHERE run_id=?1 AND role='assistant'",
                params![run, state],
            )
            .map_err(storage)?;
            tx.execute(
                "UPDATE conversation_runs SET state=?2,error=?3,finished_at=?4 WHERE id=?1",
                params![run, state, error, now()],
            )
            .map_err(storage)?;
        }
        touch(&tx, &conversation)?;
        tx.commit().map_err(storage)?;
        Ok(event)
    }
}
