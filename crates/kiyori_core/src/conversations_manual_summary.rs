//! 手动检查点保留完整历史；仅完整成功终态与插入消息在同一事务提交。
use super::*;

type Row = (i64, String, String, String, u32);
#[derive(PartialEq)]
struct Slice {
    boundary: Row,
    insertion: i64,
    previous: Option<(i64, String)>,
    rows: Vec<Row>,
}
fn selected(tx: &Connection, id: &str) -> Result<Selection, CoreError> {
    let mut value = selection(tx, id, None)?;
    // 手动动作不受自动总结开关控制，仍使用独立SUMMARY绑定。
    value.summary = Some(summary::model(tx)?);
    Ok(value)
}
fn slice(tx: &Connection, id: &str, boundary: &str) -> Result<Slice, CoreError> {
    let boundary: Row = tx.query_row("SELECT position,id,role,content,variant FROM conversation_messages WHERE conversation_id=?1 AND id=?2",
        params![id,boundary], |r| Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?)))
        .map_err(|_| invalid("总结边界消息已不存在"))?;
    let insertion = match boundary.2.as_str() {
        "user" => boundary.0,
        "assistant" => boundary
            .0
            .checked_add(1)
            .ok_or_else(|| invalid("消息位置超出范围"))?,
        _ => return Err(invalid("只能在用户或AI消息处插入总结")),
    };
    let previous = summary::checkpoint(tx, id, insertion)?;
    let after = previous.as_ref().map_or(-1, |v| v.0);
    let mut query = tx.prepare("SELECT position,id,role,content,variant FROM conversation_messages WHERE conversation_id=?1 AND position>?2 AND position<?3 AND role IN ('user','assistant') ORDER BY position").map_err(storage)?;
    let mut rows = Vec::new();
    let mut bytes = 0usize;
    for row in query
        .query_map(params![id, after, insertion], |r| {
            Ok((
                r.get(0)?,
                r.get(1)?,
                r.get(2)?,
                r.get::<_, String>(3)?,
                r.get(4)?,
            ))
        })
        .map_err(storage)?
    {
        let row: Row = row.map_err(storage)?;
        bytes += row.3.len();
        if rows.len() >= 997 || bytes > 8 * 1024 * 1024 {
            return Err(invalid("总结历史超过请求限制，原文未截断"));
        }
        rows.push(row);
    }
    if rows.is_empty() {
        return Err(invalid("此边界之前没有可总结的消息"));
    }
    Ok(Slice {
        boundary,
        insertion,
        previous,
        rows,
    })
}

pub struct PreparedSummary {
    lease: models::ModelSecretsLease,
    store: Arc<AppStore>,
    conversation: String,
    selection: Selection,
    slice: Slice,
    revision: u32,
}
impl PreparedSummary {
    pub fn secret_reference(&self) -> Option<String> {
        self.selection
            .summary
            .as_ref()
            .and_then(|s| s.config.secret_reference.clone())
    }
}
pub(super) struct Commit {
    conversation: String,
    selection: Selection,
    slice: Slice,
    pub output: String,
}
impl Commit {
    pub(super) fn insert(&self, tx: &Connection, run: &str) -> Result<(), CoreError> {
        if selected(tx, &self.conversation)? != self.selection
            || slice(tx, &self.conversation, &self.slice.boundary.1)? != self.slice
        {
            return Err(invalid(
                "总结期间配置、角色或历史已变化，请重新生成；原文保留",
            ));
        }
        if self.output.trim().is_empty() {
            return Err(invalid("模型返回空摘要，原文保留"));
        }
        // 两步搬移避免UNIQUE(conversation_id,position)在逐行更新时与相邻消息冲突。
        tx.execute("UPDATE conversation_messages SET position=-position-1 WHERE conversation_id=?1 AND position>=?2",params![self.conversation,self.slice.insertion]).map_err(storage)?;
        tx.execute("UPDATE conversation_messages SET position=-position WHERE conversation_id=?1 AND position<0",[&self.conversation]).map_err(storage)?;
        tx.execute("INSERT INTO conversation_messages(id,conversation_id,run_id,position,role,content,state) VALUES(?1,?2,?3,?4,'summary',?5,'completed')",
            params![identity(tx)?,self.conversation,run,self.slice.insertion,self.output]).map_err(storage)?;
        tx.execute(
            "DELETE FROM conversation_summaries WHERE conversation_id=?1",
            [&self.conversation],
        )
        .map_err(storage)?;
        Ok(())
    }
}
impl Runtime {
    pub fn prepare_summary(
        &self,
        id: String,
        boundary: String,
        revision: u32,
    ) -> Result<PreparedSummary, CoreError> {
        let store = self.persistent_store()?;
        let lease = store.begin_model_secrets()?;
        let (selection, slice) = {
            let mut conn = store
                .connection
                .lock()
                .map_err(|_| invalid("聊天存储锁不可用"))?;
            let tx = conn.transaction().map_err(storage)?;
            let current: u32 = tx
                .query_row(
                    "SELECT revision FROM conversations WHERE id=?1",
                    [&id],
                    |r| r.get(0),
                )
                .map_err(storage)?;
            if current != revision {
                return Err(invalid("会话已变化，请重新载入"));
            }
            let value = (selected(&tx, &id)?, slice(&tx, &id, &boundary)?);
            tx.commit().map_err(storage)?;
            value
        };
        Ok(PreparedSummary {
            lease,
            store,
            conversation: id,
            selection,
            slice,
            revision,
        })
    }
    pub fn start_summary(
        &self,
        prepared: PreparedSummary,
        payload: String,
    ) -> Result<chat::ChatRun, CoreError> {
        self.ensure_open()?;
        let store = self.persistent_store()?;
        if !Arc::ptr_eq(&store, &prepared.store) {
            return Err(invalid("总结准备不属于当前运行时"));
        }
        let client = self
            .chat_client
            .get_or_init(|| chat::client().map(Arc::new))
            .clone()?;
        let run_guard = store.run_lock(&prepared.conversation)?;
        let (request,run_id) = prepared.lease.with_store(&store,|| {
            let mut conn = store.connection.lock().map_err(|_|invalid("聊天存储锁不可用"))?;
            let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate).map_err(storage)?;
            let revision: u32 = tx.query_row("SELECT revision FROM conversations WHERE id=?1",[&prepared.conversation],|r|r.get(0)).map_err(storage)?;
            if revision!=prepared.revision || selected(&tx,&prepared.conversation)?!=prepared.selection || slice(&tx,&prepared.conversation,&prepared.slice.boundary.1)?!=prepared.slice {
                return Err(invalid("总结配置或历史已变化，请重新生成"));
            }
            let recent = prepared.slice.rows.iter().map(|r|chat::ChatMessage { role:r.2.clone(),content:r.3.clone() }).collect();
            let request = summary::request(&tx,&prepared.selection,recent,prepared.slice.previous.as_ref().map(|v|v.1.clone()),&payload,&self.model_limits)?;
            let model = prepared.selection.summary.as_ref().ok_or_else(||invalid("总结模型绑定不可用"))?;
            let run_id = identity(&tx)?;
            tx.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at,role_name,role_id,kind) VALUES(?1,?2,'running',?3,?4,?5,?6,?7,?8,'summary')",
                params![run_id,prepared.conversation,model.config.id,model.config.revision,model.name,now(),prepared.selection.role_name,prepared.selection.character]).map_err(storage)?;
            touch(&tx,&prepared.conversation)?;
            crate::conversation_audit::initialize(&tx,&prepared.conversation)?;
            crate::conversation_audit::append(&tx,&prepared.conversation,"EXECUTION","RUN_STARTED","开始生成摘要",serde_json::json!({"runId":run_id,"model":model.name,"kind":"summary"}))?;
            tx.commit().map_err(storage)?;
            Ok((request,run_id))
        })?;
        let PreparedSummary {
            lease,
            conversation,
            selection,
            slice,
            ..
        } = prepared;
        drop(lease);
        let mut commit = Commit {
            conversation,
            selection,
            slice,
            output: String::new(),
        };
        let cancellation = self.cancellation.child_token();
        let mut request = request;
        self.bind_inference(&mut request);
        let audit = Arc::new(chat::audit::ProviderAudit::new(
            store.clone(),
            commit.conversation.clone(),
            run_id.clone(),
            "SUMMARY",
        ));
        let upstream = chat::start_observed(
            client,
            request,
            cancellation.child_token(),
            None,
            Some(audit),
        );
        Ok(chat::persist(upstream, cancellation, move |event| {
            let _lock = &run_guard;
            if let chat::ChatEvent::Text(text) = &event {
                if commit.output.len() + text.len() > 8 * 1024 * 1024 {
                    return Err(invalid("摘要超过8 MiB存储限制"));
                }
                commit.output.push_str(text);
            }
            store.persist_event(&run_id, event, Some(&commit))
        }))
    }
}
