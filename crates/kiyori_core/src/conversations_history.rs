//! 历史分组是会话集合；作用域与成员版本冻结，避免同名分组跨角色误修改。
use super::{identity, invalid, now, storage};
use crate::{runtime::CoreError, storage::AppStore};
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;
use std::collections::BTreeMap;

pub(crate) fn move_item(tx: &Connection, id: &str, value: &str) -> Result<(), CoreError> {
    #[derive(Deserialize)]
    #[serde(deny_unknown_fields)]
    struct Move {
        folder: String,
        character: String,
        anchor: Option<String>,
        anchor_revision: Option<u32>,
        before: bool,
    }
    let op: Move = serde_json::from_str(value).map_err(|_| invalid("移动参数无效"))?;
    validate_binding(tx, &op.character)?;
    if !op.folder.is_empty()
        && !tx
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM conversation_folders WHERE name=?1)",
                [&op.folder],
                |r| r.get::<_, bool>(0),
            )
            .map_err(storage)?
    {
        return Err(invalid("目标分组已不存在"));
    }
    let pinned: bool = tx
        .query_row("SELECT pinned FROM conversations WHERE id=?1", [id], |r| {
            r.get(0)
        })
        .map_err(storage)?;
    let (scoped, include_unbound) = ordering_scope(tx, &op.character)?;
    let mut ids=tx.prepare("SELECT id FROM conversations WHERE id<>?1 AND folder=?2 AND pinned=?3 AND (?4=0 OR character_id=?5 OR (?6 AND character_id IN ('','default_character'))) ORDER BY sort_order DESC,updated_at DESC,id").map_err(storage)?.query_map(params![id,op.folder,pinned,scoped,op.character,include_unbound],|r|r.get::<_,String>(0)).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
    let position = if let Some(anchor) = &op.anchor {
        let revision: u32 = tx
            .query_row(
                "SELECT revision FROM conversations WHERE id=?1",
                [anchor],
                |r| r.get(0),
            )
            .map_err(storage)?;
        if Some(revision) != op.anchor_revision {
            return Err(invalid("排序锚点已变化，请重新移动"));
        }
        ids.iter()
            .position(|c| c == anchor)
            .ok_or_else(|| invalid("排序锚点不属于目标分组"))?
            + usize::from(!op.before)
    } else {
        if !ids.is_empty() {
            return Err(invalid("目标分组已变化，请重新移动"));
        }
        0
    };
    tx.execute(
        "UPDATE conversations SET folder=?2,character_id=?3 WHERE id=?1",
        params![id, op.folder, op.character],
    )
    .map_err(storage)?;
    ids.insert(position, id.into());
    for (index, entry) in ids.iter().enumerate() {
        tx.execute(
            "UPDATE conversations SET sort_order=?2,revision=revision+1 WHERE id=?1",
            params![entry, (ids.len() - index) as i64],
        )
        .map_err(storage)?;
    }
    Ok(())
}

/// 当前默认角色包含未绑定历史；按角色分组仍保持两个独立排序桶。
pub(crate) fn ordering_scope(tx: &Connection, binding: &str) -> Result<(bool, bool), CoreError> {
    let mode = crate::chat_preferences::read(tx)?.value.history_mode;
    Ok((
        mode != "folder",
        mode == "current" && (binding.is_empty() || binding == crate::prompts::DEFAULT_CHARACTER),
    ))
}

pub(crate) fn validate_binding(tx: &Connection, id: &str) -> Result<(), CoreError> {
    if id.is_empty() || tx.query_row("SELECT EXISTS(SELECT 1 FROM prompt_characters WHERE id=?1 UNION ALL SELECT 1 FROM prompt_groups WHERE id=?1)", [id], |r| r.get::<_,bool>(0)).map_err(storage)? {
        Ok(())
    } else { Err(invalid("绑定角色或群组已不存在")) }
}

pub(crate) fn activate_binding(tx: &Connection, id: &str) -> Result<(), CoreError> {
    if id.is_empty() {
        return Ok(());
    }
    validate_binding(tx, id)?;
    tx.execute("UPDATE prompt_active SET character_id=(SELECT id FROM prompt_characters WHERE id=?1),group_id=(SELECT id FROM prompt_groups WHERE id=?1) WHERE id=1",[id]).map_err(storage)?;
    Ok(())
}

pub(crate) fn select_latest(tx: &Connection, binding: &str) -> Result<(), CoreError> {
    let recent:Option<String>=tx.query_row("SELECT id FROM conversations WHERE character_id=?1 OR (?1='default_character' AND character_id='') ORDER BY updated_at DESC,id DESC LIMIT 1",[binding],|r|r.get(0)).optional().map_err(storage)?;
    if let Some(id) = recent {
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [id],
        )
        .map_err(storage)?;
    } else {
        create(tx, binding, "")?;
    }
    Ok(())
}

pub(crate) fn create(tx: &Connection, binding: &str, folder: &str) -> Result<String, CoreError> {
    validate_binding(tx, binding)?;
    let id = identity(tx)?;
    tx.execute("INSERT INTO conversations(id,title,character_id,created_at,updated_at,revision,folder) VALUES(?1,'新对话',?2,?3,?3,1,?4)",params![id,binding,now(),folder]).map_err(storage)?;
    tx.execute(
        "UPDATE conversation_state SET active_id=?1 WHERE id=1",
        [&id],
    )
    .map_err(storage)?;
    Ok(id)
}

/// 删除与替代同一事务：其它进程永远看不到删除成功却没有可用活跃会话的中间态。
pub(crate) fn ensure_active(tx: &Connection) -> Result<(), CoreError> {
    let active: Option<String> = tx
        .query_row(
            "SELECT active_id FROM conversation_state WHERE id=1",
            [],
            |r| r.get(0),
        )
        .map_err(storage)?;
    if active.is_some() {
        return Ok(());
    }
    let next: Option<String> = tx.query_row("SELECT id FROM conversations ORDER BY pinned DESC,sort_order DESC,updated_at DESC,id LIMIT 1",[],|r|r.get(0)).optional().map_err(storage)?;
    if let Some(next) = next {
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [next],
        )
        .map_err(storage)?;
    } else {
        let binding: String = tx
            .query_row(
                "SELECT coalesce(character_id,group_id,'') FROM prompt_active WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(storage)?;
        create(tx, &binding, "")?;
    }
    Ok(())
}

/// 旧服务按绑定寻找最新替代，不受列表的置顶/手工排序影响。替代先在事务内就位。
pub(crate) fn prepare_deletion(
    tx: &Connection,
    excluded: &[String],
    inherit_folder: bool,
) -> Result<(), CoreError> {
    let active: Option<String> = tx
        .query_row(
            "SELECT active_id FROM conversation_state WHERE id=1",
            [],
            |r| r.get(0),
        )
        .map_err(storage)?;
    let Some(active) = active.filter(|id| excluded.contains(id)) else {
        return Ok(());
    };
    let (mut binding, folder): (String, String) = tx
        .query_row(
            "SELECT character_id,folder FROM conversations WHERE id=?1",
            [&active],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .map_err(storage)?;
    if binding.is_empty() {
        binding = tx
            .query_row(
                "SELECT coalesce(character_id,group_id,'') FROM prompt_active WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(storage)?;
    }
    // 默认卡允许未绑定历史；失效绑定仍保留原ID的范围，避免跳到别的角色。
    let default_binding = crate::prompts::DEFAULT_CHARACTER;
    let candidates=tx.prepare("SELECT id FROM conversations WHERE character_id=?1 OR (?2 AND character_id='') ORDER BY updated_at DESC,id").map_err(storage)?.query_map(params![binding,binding==default_binding],|r|r.get::<_,String>(0)).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
    if let Some(next) = candidates.into_iter().find(|id| !excluded.contains(id)) {
        tx.execute(
            "UPDATE conversation_state SET active_id=?1 WHERE id=1",
            [next],
        )
        .map_err(storage)?;
    } else {
        if validate_binding(tx, &binding).is_err() {
            binding = tx
                .query_row(
                    "SELECT coalesce(character_id,group_id,'') FROM prompt_active WHERE id=1",
                    [],
                    |r| r.get(0),
                )
                .map_err(storage)?;
        }
        create(tx, &binding, if inherit_folder { &folder } else { "" })?;
    }
    Ok(())
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct GroupOperation {
    pub action: String,
    pub name: String,
    #[serde(default)]
    pub next_name: String,
    /// None为全部角色，Some("")为未绑定；不能以空值混淆这两个作用域。
    pub binding: Option<String>,
    /// 弹层打开时冻结；仅默认角色允许包含未绑定，旧请求默认精确作用域。
    #[serde(default)]
    pub include_unbound: bool,
    #[serde(default)]
    pub members: BTreeMap<String, u32>,
}

pub(crate) fn apply_group(
    store: &AppStore,
    tx: &Connection,
    value: &str,
) -> Result<Vec<std::fs::File>, CoreError> {
    let op: GroupOperation = serde_json::from_str(value).map_err(|_| invalid("分组操作无效"))?;
    if op.include_unbound && op.binding.as_deref() != Some(crate::prompts::DEFAULT_CHARACTER) {
        return Err(invalid("仅默认角色可以包含未绑定对话"));
    }
    if op.name.trim().is_empty()
        || op.name.len() > 512
        || !matches!(
            op.action.as_str(),
            "create" | "rename" | "dissolve" | "delete"
        )
    {
        return Err(invalid("分组名称或操作无效"));
    }
    if op.action == "create" {
        let binding = op.binding.as_deref().unwrap_or("");
        validate_binding(tx, binding)?;
        if tx.query_row("SELECT EXISTS(SELECT 1 FROM conversations WHERE folder=?1 AND (?2 IS NULL OR character_id=?2 OR (?3 AND character_id='')))",params![op.name.trim(),op.binding,op.include_unbound],|r|r.get::<_,bool>(0)).map_err(storage)? { return Err(invalid("此作用域已有同名分组")); }
        tx.execute(
            "INSERT OR IGNORE INTO conversation_folders(name) VALUES(?1)",
            [op.name.trim()],
        )
        .map_err(storage)?;
        create(tx, binding, op.name.trim())?;
        return Ok(Vec::new());
    }
    let members: BTreeMap<String,u32> = tx.prepare("SELECT id,revision FROM conversations WHERE folder=?1 AND (?2 IS NULL OR character_id=?2 OR (?3 AND character_id=''))").map_err(storage)?.query_map(params![op.name,op.binding,op.include_unbound],|r|Ok((r.get(0)?,r.get(1)?))).map_err(storage)?.collect::<Result<_,_>>().map_err(storage)?;
    if members != op.members {
        return Err(invalid("分组内容已变化，请重新打开后操作"));
    }
    let next = if op.action == "rename" {
        op.next_name.trim()
    } else {
        ""
    };
    if op.action == "rename" {
        if next.is_empty() || next.len() > 512 {
            return Err(invalid("分组名称为空或过长"));
        }
        if next == op.name {
            return Ok(Vec::new());
        }
        if tx.query_row("SELECT EXISTS(SELECT 1 FROM conversations WHERE folder=?1 AND (?2 IS NULL OR character_id=?2 OR (?3 AND character_id='')))",params![next,op.binding,op.include_unbound],|r|r.get::<_,bool>(0)).map_err(storage)? { return Err(invalid("此作用域已有同名分组")); }
        tx.execute(
            "INSERT OR IGNORE INTO conversation_folders(name) VALUES(?1)",
            [next],
        )
        .map_err(storage)?;
    }
    // 持有所有执行锁直至提交；任一项正在生成/锁定则整组删除回滚。
    let mut guards = Vec::new();
    // 必须先验证全部锁定/执行状态，再创建替代；任意失败由外层事务回滚。
    for id in members.keys() {
        guards.push(store.run_lock(id)?);
        if op.action == "delete"
            && tx
                .query_row("SELECT locked FROM conversations WHERE id=?1", [id], |r| {
                    r.get::<_, bool>(0)
                })
                .map_err(storage)?
        {
            return Err(invalid("分组包含锁定对话，请先解锁"));
        }
    }
    if op.action == "delete" {
        prepare_deletion(tx, &members.keys().cloned().collect::<Vec<_>>(), false)?;
    }
    for id in members.keys() {
        if op.action == "delete" {
            if tx
                .query_row("SELECT locked FROM conversations WHERE id=?1", [id], |r| {
                    r.get::<_, bool>(0)
                })
                .map_err(storage)?
            {
                return Err(invalid("分组包含锁定对话，请先解锁"));
            }
            tx.execute("DELETE FROM conversations WHERE id=?1", [id])
                .map_err(storage)?;
        } else {
            tx.execute(
                "UPDATE conversations SET folder=?2,revision=revision+1 WHERE id=?1",
                params![id, next],
            )
            .map_err(storage)?;
        }
    }
    tx.execute("DELETE FROM conversation_folders WHERE name=?1 AND NOT EXISTS(SELECT 1 FROM conversations WHERE folder=?1)",[&op.name]).map_err(storage)?;
    ensure_active(tx)?;
    Ok(guards)
}
