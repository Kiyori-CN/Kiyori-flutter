//! 开场白是角色资料投影，不是模型执行；只同步当前尚无用户消息的单角色会话。
use super::{identity, now, storage};
use crate::runtime::CoreError;
use rusqlite::{Connection, OptionalExtension, params};

pub(crate) const SCHEMA: &str = "
CREATE TABLE conversation_message_metadata (
 message_id TEXT PRIMARY KEY NOT NULL REFERENCES conversation_messages(id) ON DELETE CASCADE,
 role_id TEXT NOT NULL, role_name TEXT NOT NULL, created_at INTEGER);
PRAGMA user_version=23;";

struct Existing {
    id: String,
    run: Option<String>,
    content: String,
    name: Option<String>,
    role: Option<String>,
}

/// 返回是否真正修改消息，调用者在同一事务推进revision；创建时保留初始revision。
pub(crate) fn sync(tx: &Connection, id: &str) -> Result<bool, CoreError> {
    let eligible: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM conversations c JOIN conversation_state s ON s.active_id=c.id WHERE c.id=?1 AND NOT EXISTS(SELECT 1 FROM conversation_messages m WHERE m.conversation_id=c.id AND m.role='user') AND NOT EXISTS(SELECT 1 FROM conversation_runs r WHERE r.conversation_id=c.id AND r.state='running') AND NOT EXISTS(SELECT 1 FROM prompt_groups g WHERE g.id=c.character_id))", [id], |r| r.get(0)).map_err(storage)?;
    if !eligible {
        return Ok(false);
    }
    // 绑定卡优先；旧绑定找不到时回落当前单卡，当前群聊不会成为单卡回落。
    let card: Option<(String, String, String)> = tx.query_row("SELECT p.id,p.name,p.opening FROM prompt_characters p WHERE p.id=(SELECT character_id FROM conversations WHERE id=?1) OR p.id=(SELECT character_id FROM prompt_active WHERE id=1) ORDER BY CASE WHEN p.id=(SELECT character_id FROM conversations WHERE id=?1) THEN 0 ELSE 1 END LIMIT 1", [id], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?))).optional().map_err(storage)?;
    let Some((role, name, content)) = card else {
        return Ok(false);
    };
    let existing: Option<Existing> = tx.query_row("SELECT m.id,m.run_id,m.content,d.role_name,d.role_id FROM conversation_messages m LEFT JOIN conversation_message_metadata d ON d.message_id=m.id WHERE m.conversation_id=?1 AND m.role='assistant' ORDER BY m.position LIMIT 1", [id], |r| Ok(Existing { id: r.get(0)?, run: r.get(1)?, content: r.get(2)?, name: r.get(3)?, role: r.get(4)? })).optional().map_err(storage)?;
    if existing
        .as_ref()
        .is_some_and(|message| message.run.is_some())
    {
        // 即使失败回复没有正文，也不能把真实模型尝试当作角色开场白替换。
        return Ok(false);
    }
    let blank = content.trim().is_empty();
    match &existing {
        None if blank => return Ok(false),
        Some(old)
            if !blank
                && old.content == content
                && old.name.as_deref() == Some(name.as_str())
                && old.role.as_deref() == Some(role.as_str()) =>
        {
            return Ok(false);
        }
        _ => {}
    }
    crate::conversation_audit::initialize(tx, id)?;
    let before = crate::conversation_audit::messages(tx, id, None)?;
    let action = if let Some(existing) = existing {
        let message = existing.id;
        if blank {
            tx.execute("DELETE FROM conversation_messages WHERE id=?1", [&message])
                .map_err(storage)?;
            "delete"
        } else {
            tx.execute(
                "UPDATE conversation_messages SET content=?2 WHERE id=?1",
                params![message, content],
            )
            .map_err(storage)?;
            // 旧同步不改消息timestamp；对无元数据的旧非生成消息保留未知时间。
            tx.execute("INSERT INTO conversation_message_metadata(message_id,role_id,role_name,created_at) VALUES(?1,?2,?3,NULL) ON CONFLICT(message_id) DO UPDATE SET role_id=excluded.role_id,role_name=excluded.role_name", params![message, role, name]).map_err(storage)?;
            "update"
        }
    } else {
        let message = identity(tx)?;
        tx.execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state) SELECT ?1,?2,coalesce(max(position)+1,0),'assistant',?3,'completed' FROM conversation_messages WHERE conversation_id=?2", params![message, id, content]).map_err(storage)?;
        tx.execute(
            "INSERT INTO conversation_message_metadata VALUES(?1,?2,?3,?4)",
            params![message, role, name, now()],
        )
        .map_err(storage)?;
        "add"
    };
    crate::conversation_audit::append(
        tx,
        id,
        "HISTORY",
        "OPENING_SYNCHRONIZED",
        "已同步角色开场白",
        serde_json::json!({"action":action,"character":role,"before":before,"messages":crate::conversation_audit::messages(tx,id,None)?}),
    )?;
    Ok(true)
}
