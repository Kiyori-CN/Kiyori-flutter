//! 输入与历史偏好使用共享SQLite；只接受已知字段与范围，不建立Dart持久副本。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{TransactionBehavior, params};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Preferences {
    pub history_mode: String,
    pub auto_character: bool,
    pub auto_chat: bool,
    pub thinking: bool,
    pub thinking_quality: u32,
    pub message_style: String,
    pub input_style: String,
    pub memory_auto: bool,
    pub tools_enabled: bool,
    pub permission: String,
    pub disable_stream: bool,
    pub auto_read: bool,
    pub disable_preferences: bool,
    pub show_swipe_hint: bool,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            history_mode: "folder".into(),
            auto_character: false,
            auto_chat: false,
            thinking: false,
            thinking_quality: 2,
            message_style: "cursor".into(),
            input_style: "agent".into(),
            memory_auto: true,
            tools_enabled: true,
            permission: "ask".into(),
            disable_stream: false,
            auto_read: false,
            disable_preferences: false,
            show_swipe_hint: true,
        }
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct Snapshot {
    pub revision: u32,
    pub value: Preferences,
    pub folders: Vec<String>,
}
fn failure() -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: "聊天偏好无效或已经变化，请重新载入".into(),
    }
}
pub(crate) fn read(connection: &rusqlite::Connection) -> Result<Snapshot, CoreError> {
    let (revision, json): (u32, String) = connection
        .query_row(
            "SELECT revision,value FROM chat_preferences WHERE id=1",
            [],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .map_err(|_| failure())?;
    let folders = connection
        .prepare("SELECT name FROM conversation_folders ORDER BY name")
        .map_err(|_| failure())?
        .query_map([], |r| r.get(0))
        .map_err(|_| failure())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| failure())?;
    Ok(Snapshot {
        revision,
        value: serde_json::from_str(&json).map_err(|_| failure())?,
        folders,
    })
}
impl AppStore {
    fn chat_preferences(&self) -> Result<Snapshot, CoreError> {
        let connection = self.connection.lock().map_err(|_| failure())?;
        read(&connection)
    }
    fn change_chat_preference(
        &self,
        revision: u32,
        key: &str,
        value: &str,
    ) -> Result<Snapshot, CoreError> {
        let mut connection = self.connection.lock().map_err(|_| failure())?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(|_| failure())?;
        let mut current = read(&tx)?;
        if revision != current.revision {
            return Err(failure());
        }
        let boolean = || match value {
            "true" => Ok(true),
            "false" => Ok(false),
            _ => Err(failure()),
        };
        let mut execution_guards = Vec::new();
        match key {
            "history_group" => {
                execution_guards = crate::conversations::history::apply_group(self, &tx, value)?
            }
            "history_create" => {
                crate::conversations::history::create_from_history(&tx, value)?;
            }
            "history_mode" if matches!(value, "folder" | "character" | "current") => {
                current.value.history_mode = value.into()
            }
            "message_style" if matches!(value, "cursor" | "bubble") => {
                current.value.message_style = value.into()
            }
            "input_style" if matches!(value, "agent" | "classic") => {
                current.value.input_style = value.into()
            }
            "permission" if matches!(value, "forbid" | "ask" | "allow") => {
                current.value.permission = value.into();
                current.value.tools_enabled = value != "forbid";
            }
            "thinking_quality" => {
                let n = value.parse().map_err(|_| failure())?;
                if !(1..=5).contains(&n) {
                    return Err(failure());
                }
                current.value.thinking_quality = n;
            }
            "thinking" => current.value.thinking = boolean()?,
            "auto_character" => current.value.auto_character = boolean()?,
            "auto_chat" => current.value.auto_chat = boolean()?,
            "memory_auto" => current.value.memory_auto = boolean()?,
            "disable_stream" => current.value.disable_stream = boolean()?,
            "auto_read" => current.value.auto_read = boolean()?,
            "disable_preferences" => current.value.disable_preferences = boolean()?,
            "show_swipe_hint" => current.value.show_swipe_hint = boolean()?,
            "create_folder" => {
                if value.trim().is_empty() || value.len() > 512 {
                    return Err(failure());
                }
                tx.execute(
                    "INSERT INTO conversation_folders VALUES(?1)",
                    [value.trim()],
                )
                .map_err(|_| failure())?;
            }
            "delete_folder" => {
                if !current.folders.iter().any(|name| name == value) {
                    return Err(failure());
                }
                tx.execute(
                    "UPDATE conversations SET folder='',revision=revision+1 WHERE folder=?1",
                    [value],
                )
                .map_err(|_| failure())?;
                tx.execute("DELETE FROM conversation_folders WHERE name=?1", [value])
                    .map_err(|_| failure())?;
            }
            "rename_folder" => {
                let (old, new): (String, String) =
                    serde_json::from_str(value).map_err(|_| failure())?;
                let new = new.trim();
                if new.is_empty() || new.len() > 512 || !current.folders.contains(&old) {
                    return Err(failure());
                }
                tx.execute(
                    "UPDATE conversation_folders SET name=?2 WHERE name=?1",
                    params![old, new],
                )
                .map_err(|_| failure())?;
                tx.execute(
                    "UPDATE conversations SET folder=?2,revision=revision+1 WHERE folder=?1",
                    params![old, new],
                )
                .map_err(|_| failure())?;
            }
            _ => return Err(failure()),
        }
        let revision = revision.checked_add(1).ok_or_else(failure)?;
        tx.execute(
            "UPDATE chat_preferences SET revision=?1,value=?2 WHERE id=1",
            params![
                revision,
                serde_json::to_string(&current.value).map_err(|_| failure())?
            ],
        )
        .map_err(|_| failure())?;
        let result = read(&tx)?;
        tx.commit().map_err(|_| failure())?;
        drop(execution_guards);
        Ok(result)
    }
}
impl Runtime {
    pub fn chat_preferences(&self) -> Result<Snapshot, CoreError> {
        self.with_store(AppStore::chat_preferences)
    }
    pub fn change_chat_preference(
        &self,
        revision: u32,
        key: String,
        value: String,
    ) -> Result<Snapshot, CoreError> {
        self.with_store(|s| s.change_chat_preference(revision, &key, &value))
    }
}

#[cfg(test)]
mod tests {
    use super::Preferences;

    #[test]
    fn legacy_preferences_keep_swipe_hint_until_explicitly_hidden() {
        let legacy: Preferences = serde_json::from_str(
            r#"{"history_mode":"current","thinking":true,"thinking_quality":5}"#,
        )
        .unwrap();
        assert!(legacy.show_swipe_hint);
        assert_eq!(legacy.history_mode, "current");
        assert_eq!(legacy.thinking_quality, 5);
        let hidden = Preferences {
            show_swipe_hint: false,
            ..legacy
        };
        let restored: Preferences =
            serde_json::from_str(&serde_json::to_string(&hidden).unwrap()).unwrap();
        assert!(!restored.show_swipe_hint);
    }
}
