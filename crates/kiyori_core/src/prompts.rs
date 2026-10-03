//! 角色、标签、群组及活跃选择只有一个事务owner；偏好不授予工具执行权限。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, OptionalExtension, Transaction, TransactionBehavior, params};
use std::collections::HashSet;

pub const DEFAULT_CHARACTER: &str = "default_character";
#[cfg(test)]
#[path = "prompts_tests.rs"]
mod tests;

#[cfg(test)]
pub(crate) fn remove_schema_five_for_fixture(connection: &Connection) {
    crate::models::remove_schema_six_for_fixture(connection);
    connection.execute_batch("DROP TABLE prompt_active; DROP TABLE prompt_group_members; DROP TABLE prompt_character_tools; DROP TABLE prompt_character_tags; DROP TABLE prompt_groups; DROP TABLE prompt_tags; DROP TABLE prompt_characters;").unwrap();
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptTool {
    pub kind: String,
    pub name: String,
}
#[derive(Clone, Debug, PartialEq, Eq, Default)]
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
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptCharacter {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: CharacterDraft,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TagDraft {
    pub name: String,
    pub description: String,
    pub content: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptTag {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: TagDraft,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GroupDraft {
    pub name: String,
    pub description: String,
    pub members: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptGroup {
    pub id: String,
    pub revision: u32,
    pub updated_at: i64,
    pub draft: GroupDraft,
}
#[derive(Clone, Debug)]
pub struct PromptCatalog {
    pub characters: Vec<PromptCharacter>,
    pub tags: Vec<PromptTag>,
    pub groups: Vec<PromptGroup>,
    pub active_character: Option<String>,
    pub active_group: Option<String>,
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
        message: "Prompt storage operation failed.".into(),
    }
}
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
fn default_draft() -> CharacterDraft {
    CharacterDraft {
        name: "Kiyori".into(),
        description: "系统默认的角色卡配置".into(),
        setting: "你是Kiyori，一个全能AI助手，旨在解决用户提出的任何任务。".into(),
        chat: "保持有帮助的语气，并清楚地传达限制。".into(),
        voice: include_str!("prompt_default_voice_zh.txt")
            .trim_end()
            .into(),
        ..Default::default()
    }
}
pub(crate) fn initialize(tx: &Transaction<'_>) -> Result<(), CoreError> {
    write_character(tx, DEFAULT_CHARACTER, 1, &default_draft())?;
    tx.execute(
        "INSERT INTO prompt_active VALUES(1,?1,NULL)",
        [DEFAULT_CHARACTER],
    )
    .map_err(storage)?;
    Ok(())
}
fn required(value: &str) -> Result<String, CoreError> {
    let value = value.trim();
    if value.is_empty() {
        return Err(invalid("Prompt name cannot be blank."));
    }
    Ok(value.into())
}
fn exists(tx: &Connection, table: &str, id: &str) -> Result<(), CoreError> {
    let exists: bool = tx
        .query_row(
            &format!("SELECT EXISTS(SELECT 1 FROM {table} WHERE id=?1)"),
            [id],
            |r| r.get(0),
        )
        .map_err(storage)?;
    if !exists {
        return Err(invalid("Prompt reference no longer exists."));
    }
    Ok(())
}
fn identity(
    tx: &Transaction<'_>,
    table: &str,
    id: Option<String>,
    expected: Option<u32>,
) -> Result<(String, u32), CoreError> {
    if let Some(id) = id {
        let revision: Option<u32> = tx
            .query_row(
                &format!("SELECT revision FROM {table} WHERE id=?1"),
                [&id],
                |r| r.get(0),
            )
            .optional()
            .map_err(storage)?;
        if revision.is_none() || revision != expected {
            return Err(invalid(
                "Prompt changed or was deleted; reload before saving.",
            ));
        }
        let next = revision
            .and_then(|r| r.checked_add(1))
            .ok_or_else(|| invalid("Prompt revision exhausted."))?;
        Ok((id, next))
    } else {
        if expected.is_some() {
            return Err(invalid("New prompt must not have a revision."));
        }
        Ok((
            tx.query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
                .map_err(storage)?,
            1,
        ))
    }
}
fn write_character(
    tx: &Transaction<'_>,
    id: &str,
    revision: u32,
    draft: &CharacterDraft,
) -> Result<(), CoreError> {
    tx.execute("INSERT INTO prompt_characters VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,updated_at=max(excluded.updated_at,prompt_characters.updated_at+1),name=excluded.name,description=excluded.description,setting=excluded.setting,opening=excluded.opening,chat=excluded.chat,voice=excluded.voice,custom=excluded.custom,marks=excluded.marks,model_config=excluded.model_config,model_name=excluded.model_name,memory_space=excluded.memory_space,tools_enabled=excluded.tools_enabled",
        params![id,revision,now(),draft.name,draft.description,draft.setting,draft.opening,draft.chat,draft.voice,draft.custom,draft.marks,draft.model_config,draft.model_name,draft.memory_space,draft.tools_enabled]).map_err(storage)?;
    tx.execute(
        "DELETE FROM prompt_character_tags WHERE character_id=?1",
        [id],
    )
    .map_err(storage)?;
    let mut tags = HashSet::new();
    for (position, tag) in draft.tag_ids.iter().enumerate() {
        exists(tx, "prompt_tags", tag)?;
        if tags.insert(tag) {
            tx.execute(
                "INSERT INTO prompt_character_tags VALUES(?1,?2,?3)",
                params![id, tag, position as i64],
            )
            .map_err(storage)?;
        }
    }
    tx.execute(
        "DELETE FROM prompt_character_tools WHERE character_id=?1",
        [id],
    )
    .map_err(storage)?;
    for tool in &draft.tools {
        if !matches!(tool.kind.as_str(), "builtin" | "package" | "skill" | "mcp")
            || tool.name.trim().is_empty()
        {
            return Err(invalid("Invalid tool preference."));
        }
        tx.execute(
            "INSERT OR IGNORE INTO prompt_character_tools VALUES(?1,?2,?3)",
            params![id, tool.kind, tool.name.trim()],
        )
        .map_err(storage)?;
    }
    Ok(())
}
pub(crate) fn read_character(
    connection: &Connection,
    id: &str,
) -> Result<PromptCharacter, CoreError> {
    let mut value=connection.query_row("SELECT id,revision,updated_at,name,description,setting,opening,chat,voice,custom,marks,model_config,model_name,memory_space,tools_enabled FROM prompt_characters WHERE id=?1",[id],|r|Ok(PromptCharacter{id:r.get(0)?,revision:r.get(1)?,updated_at:r.get(2)?,draft:CharacterDraft{name:r.get(3)?,description:r.get(4)?,setting:r.get(5)?,opening:r.get(6)?,chat:r.get(7)?,voice:r.get(8)?,custom:r.get(9)?,marks:r.get(10)?,model_config:r.get(11)?,model_name:r.get(12)?,memory_space:r.get(13)?,tools_enabled:r.get(14)?,tag_ids:vec![],tools:vec![]}})).optional().map_err(storage)?.ok_or_else(||invalid("Character no longer exists."))?;
    value.draft.tag_ids = connection
        .prepare("SELECT tag_id FROM prompt_character_tags WHERE character_id=?1 ORDER BY position")
        .map_err(storage)?
        .query_map([id], |r| r.get(0))
        .map_err(storage)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(storage)?;
    value.draft.tools = connection
        .prepare(
            "SELECT kind,name FROM prompt_character_tools WHERE character_id=?1 ORDER BY kind,name",
        )
        .map_err(storage)?
        .query_map([id], |r| {
            Ok(PromptTool {
                kind: r.get(0)?,
                name: r.get(1)?,
            })
        })
        .map_err(storage)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(storage)?;
    Ok(value)
}
fn read_group(connection: &Connection, id: &str) -> Result<PromptGroup, CoreError> {
    let mut value = connection
        .query_row(
            "SELECT id,revision,updated_at,name,description FROM prompt_groups WHERE id=?1",
            [id],
            |r| {
                Ok(PromptGroup {
                    id: r.get(0)?,
                    revision: r.get(1)?,
                    updated_at: r.get(2)?,
                    draft: GroupDraft {
                        name: r.get(3)?,
                        description: r.get(4)?,
                        members: vec![],
                    },
                })
            },
        )
        .optional()
        .map_err(storage)?
        .ok_or_else(|| invalid("Group no longer exists."))?;
    value.draft.members = connection
        .prepare(
            "SELECT character_id FROM prompt_group_members WHERE group_id=?1 ORDER BY position",
        )
        .map_err(storage)?
        .query_map([id], |r| r.get(0))
        .map_err(storage)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(storage)?;
    Ok(value)
}
impl Runtime {
    pub fn prompt_catalog(&self) -> Result<PromptCatalog, CoreError> {
        self.with_store(AppStore::prompt_catalog)
    }
    pub fn save_character(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: CharacterDraft,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_character(id, revision, draft))
    }
    pub fn save_prompt_tag(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: TagDraft,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_prompt_tag(id, revision, draft))
    }
    pub fn save_prompt_group(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        draft: GroupDraft,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_prompt_group(id, revision, draft))
    }
    pub fn activate_prompt(&self, kind: String, id: String) -> Result<(), CoreError> {
        self.with_store(|s| s.activate_prompt(kind, id))
    }
    pub fn delete_prompt(&self, kind: String, id: String, revision: u32) -> Result<(), CoreError> {
        self.with_store(|s| s.delete_prompt(kind, id, revision))
    }
    pub fn duplicate_prompt(
        &self,
        kind: String,
        id: String,
        revision: u32,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.duplicate_prompt(kind, id, revision))
    }
    pub fn reset_default_character(&self, revision: u32) -> Result<(), CoreError> {
        self.with_store(|s| s.reset_default_character(revision))
    }
    pub fn compose_character_prompt(&self, id: String, voice: bool) -> Result<String, CoreError> {
        self.with_store(|s| s.compose_character_prompt(id, voice))
    }
}
impl AppStore {
    pub fn prompt_catalog(&self) -> Result<PromptCatalog, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection.transaction().map_err(storage)?;
        let ids=tx.prepare("SELECT id FROM prompt_characters ORDER BY CASE WHEN id='default_character' THEN 0 ELSE 1 END,rowid").map_err(storage)?.query_map([],|r|r.get::<_,String>(0)).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
        let characters = ids
            .iter()
            .map(|id| read_character(&tx, id))
            .collect::<Result<Vec<_>, _>>()?;
        let tags=tx.prepare("SELECT id,revision,updated_at,name,description,content FROM prompt_tags ORDER BY name COLLATE NOCASE,id").map_err(storage)?.query_map([],|r|Ok(PromptTag{id:r.get(0)?,revision:r.get(1)?,updated_at:r.get(2)?,draft:TagDraft{name:r.get(3)?,description:r.get(4)?,content:r.get(5)?}})).map_err(storage)?.collect::<Result<Vec<_>,_>>().map_err(storage)?;
        let group_ids = tx
            .prepare("SELECT id FROM prompt_groups ORDER BY updated_at DESC,id")
            .map_err(storage)?
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let groups = group_ids
            .iter()
            .map(|id| read_group(&tx, id))
            .collect::<Result<Vec<_>, _>>()?;
        let (active_character, active_group) = tx
            .query_row(
                "SELECT character_id,group_id FROM prompt_active WHERE id=1",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(PromptCatalog {
            characters,
            tags,
            groups,
            active_character,
            active_group,
        })
    }
    pub fn save_character(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        mut draft: CharacterDraft,
    ) -> Result<String, CoreError> {
        draft.name = required(&draft.name)?;
        if draft
            .model_config
            .as_ref()
            .is_some_and(|v| v.trim().is_empty())
            || draft
                .model_name
                .as_ref()
                .is_some_and(|v| v.trim().is_empty())
        {
            return Err(invalid("Fixed model identity cannot be blank."));
        }
        if draft.model_config.is_some() != draft.model_name.is_some() {
            return Err(invalid(
                "Fixed model requires configuration and model identity.",
            ));
        }
        if draft.tools_enabled
            && draft.tools.iter().any(|t| t.kind != "builtin")
            && !draft
                .tools
                .iter()
                .any(|t| t.kind == "builtin" && t.name == "use_package")
        {
            return Err(invalid("External tools require use_package preference."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let (id, revision) = identity(&tx, "prompt_characters", id, revision)?;
        if let (Some(config), Some(model)) = (&draft.model_config, &draft.model_name) {
            crate::models::require_model(&tx, config, model)?;
        }
        if let Some(space) = &draft.memory_space {
            crate::knowledge::require_space(&tx, space)?;
        }
        write_character(&tx, &id, revision, &draft)?;
        tx.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn save_prompt_tag(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        mut draft: TagDraft,
    ) -> Result<String, CoreError> {
        draft.name = required(&draft.name)?;
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let (id, revision) = identity(&tx, "prompt_tags", id, revision)?;
        tx.execute("INSERT INTO prompt_tags VALUES(?1,?2,?3,?4,?5,?6) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,updated_at=max(excluded.updated_at,prompt_tags.updated_at+1),name=excluded.name,description=excluded.description,content=excluded.content",params![id,revision,now(),draft.name,draft.description,draft.content]).map_err(storage)?;
        tx.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn save_prompt_group(
        &self,
        id: Option<String>,
        revision: Option<u32>,
        mut draft: GroupDraft,
    ) -> Result<String, CoreError> {
        draft.name = required(&draft.name)?;
        let new = id.is_none();
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let (id, revision) = identity(&tx, "prompt_groups", id, revision)?;
        write_group(&tx, &id, revision, &draft)?;
        if new {
            tx.execute("UPDATE prompt_active SET character_id=NULL,group_id=?1 WHERE id=1 AND group_id IS NULL",[&id]).map_err(storage)?;
        }
        tx.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn activate_prompt(&self, kind: String, id: String) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let table = table(&kind)?;
        if kind == "tag" {
            return Err(invalid("Tags cannot be active prompts."));
        }
        exists(&tx, table, &id)?;
        let (card, group) = if kind == "character" {
            (Some(id), None)
        } else {
            (None, Some(id))
        };
        tx.execute(
            "UPDATE prompt_active SET character_id=?1,group_id=?2 WHERE id=1",
            params![card, group],
        )
        .map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn delete_prompt(&self, kind: String, id: String, revision: u32) -> Result<(), CoreError> {
        if kind == "character" && id == DEFAULT_CHARACTER {
            return Err(invalid("Default character cannot be deleted."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let table = table(&kind)?;
        identity(&tx, table, Some(id.clone()), Some(revision))?;
        if kind != "tag" {
            let column = if kind == "character" {
                "character_id"
            } else {
                "group_id"
            };
            tx.execute(
                &format!(
                    "UPDATE prompt_active SET character_id=?1,group_id=NULL WHERE {column}=?2"
                ),
                params![DEFAULT_CHARACTER, id],
            )
            .map_err(storage)?;
        }
        if kind == "character" {
            tx.execute("UPDATE prompt_groups SET revision=revision+1,updated_at=max(?1,updated_at+1) WHERE id IN (SELECT group_id FROM prompt_group_members WHERE character_id=?2)",params![now(),id]).map_err(storage)?;
        }
        if kind == "tag" {
            tx.execute("UPDATE prompt_characters SET revision=revision+1,updated_at=max(?1,updated_at+1) WHERE id IN (SELECT character_id FROM prompt_character_tags WHERE tag_id=?2)",params![now(),id]).map_err(storage)?;
        }
        tx.execute(&format!("DELETE FROM {table} WHERE id=?1"), [id])
            .map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn reset_default_character(&self, revision: u32) -> Result<(), CoreError> {
        self.save_character(
            Some(DEFAULT_CHARACTER.into()),
            Some(revision),
            default_draft(),
        )
        .map(|_| ())
    }
    pub fn duplicate_prompt(
        &self,
        kind: String,
        id: String,
        revision: u32,
    ) -> Result<String, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let table = table(&kind)?;
        identity(&tx, table, Some(id.clone()), Some(revision))?;
        let (new_id, _) = identity(&tx, table, None, None)?;
        match kind.as_str() {
            "character" => {
                let mut draft = read_character(&tx, &id)?.draft;
                draft.name.push_str(" (副本)");
                write_character(&tx, &new_id, 1, &draft)?;
            }
            "group" => {
                let mut draft = read_group(&tx, &id)?.draft;
                draft.name.push_str(" (副本)");
                write_group(&tx, &new_id, 1, &draft)?;
                tx.execute("UPDATE prompt_active SET character_id=NULL,group_id=?1 WHERE id=1 AND group_id IS NULL",[&new_id]).map_err(storage)?;
            }
            _ => return Err(invalid("Tag duplication is not supported.")),
        }
        tx.commit().map_err(storage)?;
        Ok(new_id)
    }
    pub fn compose_character_prompt(&self, id: String, voice: bool) -> Result<String, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection.transaction().map_err(storage)?;
        let result = compose_prompt(&tx, &id, voice)?;
        tx.commit().map_err(storage)?;
        Ok(result)
    }
}

pub(crate) fn compose_prompt(tx: &Connection, id: &str, voice: bool) -> Result<String, CoreError> {
    let draft = read_character(tx, id)?.draft;
    let mut parts = vec![draft.setting, if voice { draft.voice } else { draft.chat }];
    for tag in draft.tag_ids {
        parts.push(
            tx.query_row("SELECT content FROM prompt_tags WHERE id=?1", [tag], |r| {
                r.get(0)
            })
            .map_err(storage)?,
        );
    }
    parts.push(draft.custom);
    let result = parts
        .into_iter()
        .filter(|p| !p.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n\n")
        .trim()
        .to_owned();
    Ok(result)
}
fn table(kind: &str) -> Result<&'static str, CoreError> {
    match kind {
        "character" => Ok("prompt_characters"),
        "tag" => Ok("prompt_tags"),
        "group" => Ok("prompt_groups"),
        _ => Err(invalid("Unknown prompt kind.")),
    }
}
fn write_group(
    tx: &Transaction<'_>,
    id: &str,
    revision: u32,
    draft: &GroupDraft,
) -> Result<(), CoreError> {
    tx.execute("INSERT INTO prompt_groups VALUES(?1,?2,?3,?4,?5) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,updated_at=max(excluded.updated_at,prompt_groups.updated_at+1),name=excluded.name,description=excluded.description",params![id,revision,now(),draft.name,draft.description]).map_err(storage)?;
    tx.execute("DELETE FROM prompt_group_members WHERE group_id=?1", [id])
        .map_err(storage)?;
    for (position, member) in draft.members.iter().enumerate() {
        exists(tx, "prompt_characters", member)?;
        tx.execute(
            "INSERT INTO prompt_group_members VALUES(?1,?2,?3)",
            params![id, member, position as i64],
        )
        .map_err(storage)?;
    }
    Ok(())
}
