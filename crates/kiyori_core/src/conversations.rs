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

#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(connection: &Connection) {
    connection.execute_batch("DROP TABLE conversation_messages; DROP TABLE conversation_runs; DROP TABLE conversation_state; DROP TABLE conversations;").unwrap();
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
}
#[derive(Clone, Debug, PartialEq)]
pub struct Message {
    pub id: String,
    pub run_id: String,
    pub role: String,
    pub content: String,
    pub state: String,
    pub error: String,
    pub model: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConversationSnapshot {
    pub conversation: Conversation,
    pub messages: Vec<Message>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct ConversationCatalog {
    pub active_id: Option<String>,
    pub conversations: Vec<Conversation>,
}

#[derive(Clone, PartialEq)]
struct Selection {
    config: models::ModelConfig,
    model: String,
    character: String,
    system: String,
}
pub struct PreparedSend {
    lease: models::ModelSecretsLease,
    store: Arc<AppStore>,
    conversation: String,
    selection: Selection,
}
impl PreparedSend {
    pub fn secret_reference(&self) -> Option<String> {
        self.selection.config.secret_reference.clone()
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
    })
}
const SELECT_CONVERSATIONS: &str = "SELECT c.id,c.title,c.character_id,coalesce(p.name,c.character_id),c.revision,c.updated_at,(SELECT count(*) FROM conversation_messages m WHERE m.conversation_id=c.id) FROM conversations c LEFT JOIN prompt_characters p ON p.id=c.character_id";

fn selection(tx: &Connection, id: &str) -> Result<Selection, CoreError> {
    exists(tx, id)?;
    let character: String = tx
        .query_row(
            "SELECT character_id FROM conversations WHERE id=?1",
            [id],
            |r| r.get(0),
        )
        .map_err(storage)?;
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
    Ok(Selection {
        config,
        model,
        character,
        system,
    })
}

impl AppStore {
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
                "{SELECT_CONVERSATIONS} ORDER BY c.updated_at DESC,c.id"
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
        let messages = tx.prepare("SELECT m.id,coalesce(m.run_id,''),m.role,m.content,m.state,coalesce(r.error,''),coalesce(r.model,'') FROM conversation_messages m LEFT JOIN conversation_runs r ON r.id=m.run_id WHERE m.conversation_id=?1 ORDER BY m.position").map_err(storage)?
            .query_map([id],|r|Ok(Message {id:r.get(0)?,run_id:r.get(1)?,role:r.get(2)?,content:r.get(3)?,state:r.get(4)?,error:r.get(5)?,model:r.get(6)?})).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(ConversationSnapshot {
            conversation,
            messages,
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
            "INSERT INTO conversations VALUES(?1,'新对话',?2,?3,?3,1)",
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
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [id],
        )
        .map_err(storage)?;
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
            "clear" => {
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
        match action {
            "edit" => {
                if text.trim().is_empty() || text.len() > 8 * 1024 * 1024 {
                    return Err(invalid("消息为空或超过8 MiB限制"));
                }
                tx.execute(
                    "UPDATE conversation_messages SET content=?2 WHERE id=?1",
                    params![message, text],
                )
                .map_err(storage)?;
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
        self.with_store(|s| s.change_conversation(&id, revision, &action, &value))
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
        let store = self.persistent_store()?;
        let lease = store.begin_model_secrets()?;
        let selection = {
            let mut connection = store
                .connection
                .lock()
                .map_err(|_| invalid("聊天存储锁不可用"))?;
            let tx = connection.transaction().map_err(storage)?;
            let selection = selection(&tx, &id)?;
            tx.commit().map_err(storage)?;
            selection
        };
        Ok(PreparedSend {
            lease,
            store,
            conversation: id,
            selection,
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
        let (request,run_id)=prepared.lease.with_store(&store,|| {
            let mut connection=store.connection.lock().map_err(|_|invalid("聊天存储锁不可用"))?;
            let tx=connection.transaction_with_behavior(TransactionBehavior::Immediate).map_err(storage)?;
            let selected=selection(&tx,&prepared.conversation)?;
            if selected!=prepared.selection {return Err(invalid("配置、角色或模型已变化，请重新发送"));}
            if !matches!(selected.config.draft.protocol.as_str(),"chat"|"responses") {return Err(invalid("该模型协议的请求执行尚未接入"));}
            let mut messages=Vec::new();
            if !selected.system.is_empty() {messages.push(chat::ChatMessage{role:"system".into(),content:selected.system});}
            let cutoff = if let Some(message) = &replace_from {
                let current:u32=tx.query_row("SELECT revision FROM conversations WHERE id=?1",[&prepared.conversation],|r|r.get(0)).map_err(storage)?;
                if revision != Some(current) {return Err(invalid("会话已变化，请重新载入"));}
                tx.query_row("SELECT position FROM conversation_messages WHERE id=?1 AND conversation_id=?2 AND role='user'",params![message,prepared.conversation],|r|r.get::<_,i64>(0)).map_err(storage)?
            } else {i64::MAX};
            let mut statement=tx.prepare("SELECT role,content FROM conversation_messages WHERE conversation_id=?1 AND position<?2 AND content<>'' ORDER BY position").map_err(storage)?;
            let rows=statement.query_map(params![prepared.conversation,cutoff],|r|Ok(chat::ChatMessage{role:r.get(0)?,content:r.get(1)?})).map_err(storage)?;
            let mut bytes=messages.iter().map(|m|m.content.len()).sum::<usize>();
            for row in rows {
                let row=row.map_err(storage)?; bytes+=row.content.len(); messages.push(row);
                if messages.len()>=999 || bytes>8*1024*1024 {return Err(invalid("历史超过当前请求限制，请新建会话；原文未截断"));}
            }
            drop(statement);
            messages.push(chat::ChatMessage{role:"user".into(),content:text.clone()});
            // 尚无供应商统一tokenizer；使用UTF-8字节作为保守上界，明确拒绝而不静默裁剪。
            bytes+=text.len();
            let options=&selected.config.draft.options;
            let context=if options.max_context_mode {options.max_context_length} else {options.context_length};
            if bytes>8*1024*1024 || bytes as f64>context*1024. {
                return Err(invalid("对话超过配置的保守上下文预算，请增大上下文或新建会话；未截断或自动压缩"));
            }
            let (api_key,headers)=model_execution::select_credentials(&tx,&selected.config.id,&payload)?;
            let mut request=chat::probe::prepare(selected.config.draft.clone(),api_key,headers,"chat")?;
            request.probe=None; request.messages=messages; request.model=selected.model.clone(); request.timeout_ms=600_000;
            // 重发的截断与新消息同事务提交；凭据/配置校验失败不得先删历史。
            if replace_from.is_some() {
                tx.execute("DELETE FROM conversation_messages WHERE conversation_id=?1 AND position>=?2",params![prepared.conversation,cutoff]).map_err(storage)?;
            }
            let run_id=identity(&tx)?; let user_id=identity(&tx)?; let assistant_id=identity(&tx)?;
            let position:i64=tx.query_row("SELECT coalesce(max(position)+1,0) FROM conversation_messages WHERE conversation_id=?1",[&prepared.conversation],|r|r.get(0)).map_err(storage)?;
            tx.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at) VALUES(?1,?2,'running',?3,?4,?5,?6)",params![run_id,prepared.conversation,selected.config.id,selected.config.revision,selected.model,now()]).map_err(storage)?;
            tx.execute("INSERT INTO conversation_messages VALUES(?1,?2,?3,?4,'user',?5,'completed')",params![user_id,prepared.conversation,run_id,position,text]).map_err(storage)?;
            tx.execute("INSERT INTO conversation_messages VALUES(?1,?2,?3,?4,'assistant','','running')",params![assistant_id,prepared.conversation,run_id,position+1]).map_err(storage)?;
            if position==0 {
                let title=text.trim().chars().take(30).collect::<String>();
                tx.execute("UPDATE conversations SET title=?2 WHERE id=?1 AND title='新对话'",params![prepared.conversation,title]).map_err(storage)?;
            }
            touch(&tx,&prepared.conversation)?;
            tx.commit().map_err(storage)?;
            Ok((request,run_id))
        })?;
        // 安全引用已解析成短期请求，不把lease延长到网络/流式阶段。
        drop(prepared);
        let cancellation = self.cancellation.child_token();
        let upstream = chat::start(client, request, cancellation.child_token());
        Ok(chat::persist(upstream, cancellation, move |event| {
            let _keep_lock = &run_guard;
            store.persist_conversation_event(&run_id, event)
        }))
    }
}

impl AppStore {
    fn persist_conversation_event(
        &self,
        run: &str,
        mut event: chat::ChatEvent,
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
        if let chat::ChatEvent::Completed { reason, .. } = &event {
            let nonempty:bool=tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_messages WHERE run_id=?1 AND role='assistant' AND length(trim(content))>0)",[run],|r|r.get(0)).map_err(storage)?;
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
                let bytes:i64=tx.query_row("SELECT length(CAST(content AS BLOB)) FROM conversation_messages WHERE run_id=?1 AND role='assistant'",[run],|r|r.get(0)).map_err(storage)?;
                if bytes as usize + text.len() > 8 * 1024 * 1024 {
                    return Err(invalid("回复超过8 MiB存储限制"));
                }
                tx.execute("UPDATE conversation_messages SET content=content||?2 WHERE run_id=?1 AND role='assistant'",params![run,text]).map_err(storage)?;
            }
            chat::ChatEvent::Usage { input, output, .. } => {
                tx.execute(
                    "UPDATE conversation_runs SET input_tokens=?2,output_tokens=?3 WHERE id=?1",
                    params![run, *input as i64, *output as i64],
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
