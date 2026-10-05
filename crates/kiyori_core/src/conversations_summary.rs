//! 摘要是同一会话的请求投影；原始消息始终保留，网络不持有SQLite事务或凭据租约。
use super::*;
use rusqlite::OptionalExtension;

#[derive(Clone, PartialEq)]
pub(super) struct Model {
    pub config: models::ModelConfig,
    pub name: String,
}
pub(super) fn model(tx: &Connection) -> Result<Model, CoreError> {
    let (id, name): (String, String) = tx
        .query_row(
            "SELECT config_id,model_name FROM function_models WHERE function='summary'",
            [],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .map_err(storage)?;
    models::require_model(tx, &id, &name)?;
    Ok(Model {
        config: models::read_config(tx, &id)?,
        name,
    })
}

pub(super) fn cached(
    tx: &Connection,
    conversation: &str,
) -> Result<Option<(i64, String)>, CoreError> {
    tx.query_row(
        "SELECT through_position,content FROM conversation_summaries WHERE conversation_id=?1",
        [conversation],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )
    .optional()
    .map_err(storage)
}

// 手动摘要与自动缓存使用同一请求编译，规则、预算及凭据轮换不能分叉。
pub(super) fn request(
    tx: &rusqlite::Transaction<'_>,
    selected: &Selection,
    recent: Vec<chat::ChatMessage>,
    previous: Option<String>,
    credentials: &str,
    limits: &chat::limits::Registry,
) -> Result<chat::ChatRequest, CoreError> {
    let summary = selected
        .summary
        .as_ref()
        .ok_or_else(|| invalid("总结模型绑定不可用"))?;
    let (key, headers) = model_execution::select_credentials(tx, &summary.config.id, credentials)?;
    compile(selected, recent, previous, (key, headers), limits, false)
}

fn compile(
    selected: &Selection,
    recent: Vec<chat::ChatMessage>,
    previous: Option<String>,
    credentials: (String, Vec<(String, String)>),
    limits: &chat::limits::Registry,
    deferred: bool,
) -> Result<chat::ChatRequest, CoreError> {
    let summary = selected
        .summary
        .as_ref()
        .ok_or_else(|| invalid("总结模型绑定不可用"))?;
    let mut request = chat::probe::prepare(
        summary.config.draft.clone(),
        credentials.0,
        credentials.1,
        "chat",
    )?;
    request.probe = None;
    request.model = summary.name.clone();
    request.timeout_ms = 600_000;
    request.stream = !selected.preferences.disable_stream;
    request.admission = Some(limits.configure(
        &summary.config.id,
        summary.config.revision,
        summary.config.draft.options.request_limit,
        summary.config.draft.options.concurrent_limit,
    ));
    let mut prompt = include_str!("summary_prompt_zh.txt").trim().to_owned();
    if let Some(previous) = previous {
        prompt.push_str(&format!(
            "\n\n上一次的摘要（请继承其中的上下文信息）：\n{previous}"
        ));
    }
    if !selected
        .config
        .draft
        .options
        .summary_rules
        .trim()
        .is_empty()
    {
        prompt.push_str("\n\n");
        prompt.push_str(selected.config.draft.options.summary_rules.trim());
    }
    request.messages = vec![chat::ChatMessage {
        role: "system".into(),
        content: prompt,
    }];
    request.messages.extend(recent);
    request.messages.push(chat::ChatMessage {
        role: "user".into(),
        content: "请根据以上对话内容生成完整的对话摘要。".into(),
    });
    let options = &summary.config.draft.options;
    let context = if options.max_context_mode {
        options.max_context_length
    } else {
        options.context_length
    };
    if let Some(extension) = &mut request.extension {
        bounded(&request.messages)?;
        extension.context_limit = Some((context * 1024.) as i64);
    } else if !deferred {
        budget(&request.messages, context)?;
    } else {
        bounded(&request.messages)?;
    }
    if !deferred {
        apply_thinking(&mut request, &selected.preferences)?;
    }
    Ok(request)
}

pub(super) fn checkpoint(
    tx: &Connection,
    id: &str,
    before: i64,
) -> Result<Option<(i64, String)>, CoreError> {
    tx.query_row("SELECT position,content FROM conversation_messages WHERE conversation_id=?1 AND position<?2 AND role='summary' AND state='completed' ORDER BY position DESC LIMIT 1",
        params![id,before], |r| Ok((r.get(0)?,r.get(1)?))).optional().map_err(storage)
}

pub(super) fn projection(
    system: &str,
    previous: Option<&str>,
    recent: &[chat::ChatMessage],
) -> Vec<chat::ChatMessage> {
    let mut messages = Vec::new();
    if !system.is_empty() {
        messages.push(chat::ChatMessage {
            role: "system".into(),
            content: system.into(),
        });
    }
    if let Some(summary) = previous {
        messages.push(chat::ChatMessage {
            role: "user".into(),
            content: summary.into(),
        });
    }
    messages.extend_from_slice(recent);
    messages
}

pub(super) fn budget(messages: &[chat::ChatMessage], context: f64) -> Result<(), CoreError> {
    bounded(messages)?;
    let bytes = messages.iter().map(|m| m.content.len()).sum::<usize>();
    if bytes as f64 > context * 1024. {
        return Err(invalid(
            "对话超过配置的保守上下文预算；原文保留，请增大上下文或调整总结模型",
        ));
    }
    Ok(())
}

pub(super) fn bounded(messages: &[chat::ChatMessage]) -> Result<(), CoreError> {
    let bytes = messages.iter().map(|m| m.content.len()).sum::<usize>();
    if messages.len() > 999 || bytes > 8 * 1024 * 1024 {
        return Err(invalid("对话超过请求大小限制；原文保留"));
    }
    Ok(())
}

pub(super) fn triggered(
    options: &models::ModelOptions,
    messages: &[chat::ChatMessage],
    user_count: usize,
    context: f64,
) -> bool {
    let bytes = messages.iter().map(|m| m.content.len()).sum::<usize>();
    let tokens = messages
        .iter()
        .map(|m| chat::observation::estimate(&m.content))
        .sum::<i64>();
    options.summary_enabled
        && (tokens as f64 >= context * 1024. * options.summary_threshold
        // 没有统一tokenizer时保守预算也必须能触发总结，不能先拒绝再永远不执行。
        || bytes as f64 >= context * 1024. * options.summary_threshold
        || (options.summary_by_count && user_count >= options.summary_count as usize))
}

pub(super) struct Input<'a> {
    pub tx: &'a rusqlite::Transaction<'a>,
    pub selected: &'a Selection,
    pub recent: Vec<chat::ChatMessage>,
    pub previous: Option<String>,
    pub through: i64,
    pub conversation: String,
    pub payload: &'a str,
    pub summary_payload: Option<&'a str>,
    pub store: Arc<AppStore>,
    pub context: f64,
    pub limits: &'a chat::limits::Registry,
    pub run_id: String,
    pub after: Vec<chat::ChatMessage>,
    pub target: Option<String>,
    pub condition: Option<chat::PreludeCondition>,
}

pub(super) fn prepare(input: Input<'_>) -> Result<chat::Prelude, CoreError> {
    let Input {
        tx,
        selected,
        recent,
        previous,
        through,
        conversation,
        payload,
        summary_payload,
        store,
        context,
        limits,
        run_id,
        after,
        target,
        condition,
    } = input;
    let summary = selected
        .summary
        .as_ref()
        .ok_or_else(|| invalid("总结模型绑定不可用"))?;
    let credentials = if summary.config.id == selected.config.id {
        Some(payload)
    } else {
        summary_payload
    };
    let deferred = condition.is_some();
    let request = if deferred {
        compile(
            selected,
            recent,
            previous,
            (String::new(), vec![]),
            limits,
            true,
        )?
    } else {
        request(
            tx,
            selected,
            recent,
            previous,
            credentials.ok_or_else(|| invalid("总结需要独立模型的安全凭据，请在总结配置中填写"))?,
            limits,
        )?
    };
    let activate: Option<chat::PreludeActivation> = if deferred {
        let activation_store = store.clone();
        let activation_selection = selected.clone();
        let activation_conversation = conversation.clone();
        let activation_target = target.clone();
        let activation_run = run_id.clone();
        let credentials = credentials.map(str::to_owned);
        Some(Box::new(move |request| {
            let mut connection = activation_store
                .connection
                .lock()
                .map_err(|_| invalid("总结存储锁不可用"))?;
            let tx = connection
                .transaction_with_behavior(TransactionBehavior::Immediate)
                .map_err(storage)?;
            if selection(&tx, &activation_conversation, activation_target.as_deref())?
                != activation_selection
            {
                return Err(invalid("计数期间配置或角色已变化，请重新发送；原文保留"));
            }
            let running: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE id=?1 AND conversation_id=?2 AND state='running')",params![activation_run,activation_conversation],|r|r.get(0)).map_err(storage)?;
            if !running {
                return Err(invalid("总结执行已失效"));
            }
            let model = activation_selection
                .summary
                .as_ref()
                .ok_or_else(|| invalid("总结模型绑定不可用"))?;
            if request.extension.is_none() {
                let options = &model.config.draft.options;
                budget(
                    &request.messages,
                    if options.max_context_mode {
                        options.max_context_length
                    } else {
                        options.context_length
                    },
                )?;
            }
            apply_thinking(request, &activation_selection.preferences)?;
            let (key, headers) = model_execution::select_credentials(
                &tx,
                &model.config.id,
                credentials
                    .as_deref()
                    .ok_or_else(|| invalid("总结需要独立模型的安全凭据，请在总结配置中填写"))?,
            )?;
            tx.execute(
                "INSERT INTO conversation_summary_usage(run_id,model) VALUES(?1,?2)",
                params![activation_run, model.name],
            )
            .map_err(storage)?;
            tx.commit().map_err(storage)?;
            request.api_key = key;
            request.headers = headers;
            Ok(())
        }))
    } else {
        None
    };
    let frozen = selected.clone();
    let usage_store = store.clone();
    let usage_run = run_id.clone();
    Ok(chat::Prelude {
        request,
        condition,
        activate,
        usage: Box::new(move |event| {
            let chat::ChatEvent::Usage {
                input,
                output,
                output_reported,
                cache_read,
                cache_write,
                reasoning,
                ..
            } = event
            else {
                return Ok(());
            };
            let to_storage = |v: u64| i64::try_from(v).map_err(|_| invalid("总结用量超出存储范围"));
            let (input, output) = (to_storage(input)?, to_storage(output)?);
            let read = cache_read.map(to_storage).transpose()?;
            let write = cache_write.map(to_storage).transpose()?;
            let reasoning = reasoning
                .map(to_storage)
                .transpose()?
                .filter(|v| *v <= output);
            let valid = read.is_some_and(|v| v <= input && write.unwrap_or(0) <= input - v);
            let conn = usage_store
                .connection
                .lock()
                .map_err(|_| invalid("总结存储锁不可用"))?;
            conn.execute("UPDATE conversation_summary_usage SET input_tokens=?2,output_tokens=?3,usage_reported=?4,cache_read_tokens=?5,cache_write_tokens=?6,reasoning_tokens=?7 WHERE run_id=?1 AND EXISTS(SELECT 1 FROM conversation_runs WHERE id=?1 AND state='running')",params![usage_run,input,output,output_reported,if valid {read} else {None},if valid {write} else {None},reasoning]).map_err(storage)?;
            Ok(())
        }),
        finish: Box::new(move |content| {
            let projected = projection(&frozen.system, Some(&content), &after);
            if deferred {
                bounded(&projected)?;
            } else {
                budget(&projected, context)?;
            }
            let mut connection = store
                .connection
                .lock()
                .map_err(|_| invalid("聊天存储锁不可用"))?;
            let tx = connection
                .transaction_with_behavior(TransactionBehavior::Immediate)
                .map_err(storage)?;
            // 本次Run持有会话OS锁；仍复核绑定及running事实，撤权/换模不能提交迟到摘要。
            if selection(&tx, &conversation, target.as_deref())? != frozen {
                return Err(invalid("总结期间配置或角色已变化，请重新发送；原文保留"));
            }
            let running: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE id=?1 AND conversation_id=?2 AND state='running')",
                params![run_id,conversation], |r| r.get(0)).map_err(storage)?;
            if !running {
                return Err(invalid("总结执行已失效"));
            }
            tx.execute("INSERT INTO conversation_summaries VALUES(?1,?2,?3) ON CONFLICT(conversation_id) DO UPDATE SET through_position=excluded.through_position,content=excluded.content",
                params![conversation,through,content]).map_err(storage)?;
            tx.commit().map_err(storage)?;
            Ok(projected)
        }),
    })
}
