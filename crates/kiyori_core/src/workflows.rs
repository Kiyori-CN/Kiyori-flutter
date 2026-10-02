use rusqlite::{Connection, OptionalExtension, params};
use std::{
    path::Path,
    sync::Mutex,
    time::{SystemTime, UNIX_EPOCH},
};

use crate::runtime::{CoreError, ErrorCode};

const SCHEMA_VERSION: i32 = 1;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkflowRecord {
    pub id: String,
    pub name: String,
    pub description: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub enabled: bool,
}

pub struct WorkflowStore {
    connection: Mutex<Connection>,
}

impl WorkflowStore {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, CoreError> {
        let path = path.as_ref();
        if !path.is_absolute() {
            return Err(error("The application support path must be absolute."));
        }
        std::fs::create_dir_all(path)
            .map_err(|e| error(&format!("Cannot create application data directory: {e}")))?;
        let database_path = path.join("kiyori.sqlite3");
        let mut connection = Connection::open(database_path)
            .map_err(|e| error(&format!("Cannot open Kiyori database: {e}")))?;
        connection
            .pragma_update(None, "foreign_keys", "ON")
            .map_err(|e| error(&format!("Cannot configure Kiyori database: {e}")))?;
        connection
            .busy_timeout(std::time::Duration::from_secs(3))
            .map_err(|e| error(&format!("Cannot set storage timeout: {e}")))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(|e| error(&format!("Cannot start schema transaction: {e}")))?;
        let version: i32 = transaction
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .map_err(|e| error(&format!("Cannot read Kiyori schema version: {e}")))?;
        if version > SCHEMA_VERSION {
            return Err(error("Kiyori data was created by a newer app version."));
        }
        if version < 1 {
            transaction
                .execute_batch(
                    "CREATE TABLE workflows (
                       id TEXT PRIMARY KEY NOT NULL,
                       name TEXT NOT NULL,
                       description TEXT NOT NULL DEFAULT '',
                       created_at INTEGER NOT NULL,
                       updated_at INTEGER NOT NULL,
                       enabled INTEGER NOT NULL DEFAULT 1
                     );
                     CREATE INDEX workflows_updated_at ON workflows(updated_at DESC, id DESC);
                     PRAGMA user_version = 1;",
                )
                .map_err(|e| error(&format!("Cannot migrate Kiyori database: {e}")))?;
        }
        transaction
            .commit()
            .map_err(|e| error(&format!("Cannot commit schema: {e}")))?;
        Ok(Self {
            connection: Mutex::new(connection),
        })
    }

    pub fn list(&self) -> Result<Vec<WorkflowRecord>, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| error("Kiyori database is busy."))?;
        let mut statement = connection
            .prepare("SELECT id, name, description, created_at, updated_at, enabled FROM workflows ORDER BY updated_at DESC, id DESC")
            .map_err(|e| error(&format!("Cannot read workflows: {e}")))?;
        let rows = statement
            .query_map([], |row| {
                Ok(WorkflowRecord {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    enabled: row.get::<_, i64>(5)? != 0,
                })
            })
            .map_err(|e| error(&format!("Cannot read workflows: {e}")))?;
        rows.collect::<Result<Vec<_>, _>>()
            .map_err(|e| error(&format!("Cannot decode workflows: {e}")))
    }

    pub fn create(&self, name: String, description: String) -> Result<WorkflowRecord, CoreError> {
        let name = name.trim().to_owned();
        if name.is_empty() {
            return Err(CoreError {
                code: ErrorCode::InvalidInput,
                message: "Workflow name cannot be blank.".into(),
            });
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| error("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(|e| error(&format!("Cannot begin workflow creation: {e}")))?;
        // 数据库生成随机身份；时间相同时仍保持创建顺序，进程重启不复用计数器。
        let (id, now): (String, i64) = transaction.query_row(
            "SELECT lower(hex(randomblob(16))), max(?1, coalesce(max(updated_at), 0) + 1) FROM workflows",
            [now_ms()], |row| Ok((row.get(0)?, row.get(1)?)),
        ).map_err(|e| error(&format!("Cannot allocate workflow identity: {e}")))?;
        let record = WorkflowRecord {
            id,
            name,
            description,
            created_at: now,
            updated_at: now,
            enabled: true,
        };
        transaction.execute(
            "INSERT INTO workflows (id, name, description, created_at, updated_at, enabled) VALUES (?1, ?2, ?3, ?4, ?5, 1)",
            params![record.id, record.name, record.description, record.created_at, record.updated_at],
        ).map_err(|e| error(&format!("Cannot create workflow: {e}")))?;
        transaction
            .commit()
            .map_err(|e| error(&format!("Cannot commit workflow: {e}")))?;
        Ok(record)
    }

    pub fn update(
        &self,
        id: String,
        name: String,
        description: String,
        enabled: bool,
    ) -> Result<WorkflowRecord, CoreError> {
        let name = name.trim();
        if name.is_empty() {
            return Err(CoreError {
                code: ErrorCode::InvalidInput,
                message: "Workflow name cannot be blank.".into(),
            });
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| error("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(|e| error(&format!("Cannot begin workflow update: {e}")))?;
        let result = transaction.query_row(
            "UPDATE workflows SET name = ?2, description = ?3, enabled = ?4, updated_at = max(?5, (SELECT coalesce(max(updated_at), 0) + 1 FROM workflows)) WHERE id = ?1 RETURNING id, name, description, created_at, updated_at, enabled",
            params![id, name, description, enabled, now_ms()],
            |row| Ok(WorkflowRecord { id: row.get(0)?, name: row.get(1)?, description: row.get(2)?, created_at: row.get(3)?, updated_at: row.get(4)?, enabled: row.get(5)? }),
        ).optional().map_err(|e| error(&format!("Cannot update workflow: {e}")))?
        .ok_or_else(|| CoreError { code: ErrorCode::InvalidInput, message: "Workflow no longer exists.".into() })?;
        transaction
            .commit()
            .map_err(|e| error(&format!("Cannot commit workflow update: {e}")))?;
        Ok(result)
    }

    pub fn delete(&self, id: String) -> Result<bool, CoreError> {
        if id.trim().is_empty() {
            return Err(error("Workflow id cannot be empty."));
        }
        let connection = self
            .connection
            .lock()
            .map_err(|_| error("Kiyori database is busy."))?;
        let deleted = connection
            .execute("DELETE FROM workflows WHERE id = ?1", [id.trim()])
            .map_err(|e| error(&format!("Cannot delete workflow: {e}")))?;
        Ok(deleted == 1)
    }

    pub fn delete_many(&self, ids: Vec<String>) -> Result<u32, CoreError> {
        if ids.iter().any(|id| id.trim().is_empty()) {
            return Err(CoreError {
                code: ErrorCode::InvalidInput,
                message: "Workflow id cannot be blank.".into(),
            });
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| error("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(|e| error(&format!("Cannot start workflow deletion: {e}")))?;
        let mut deleted = 0;
        for id in ids {
            deleted += transaction
                .execute("DELETE FROM workflows WHERE id = ?1", [id])
                .map_err(|e| error(&format!("Cannot delete workflows: {e}")))?
                as u32;
        }
        transaction
            .commit()
            .map_err(|e| error(&format!("Cannot commit workflow deletion: {e}")))?;
        Ok(deleted)
    }

    pub fn get(&self, id: String) -> Result<Option<WorkflowRecord>, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| error("Kiyori database is busy."))?;
        connection.query_row(
            "SELECT id, name, description, created_at, updated_at, enabled FROM workflows WHERE id = ?1",
            [id.trim()],
            |row| Ok(WorkflowRecord { id: row.get(0)?, name: row.get(1)?, description: row.get(2)?, created_at: row.get(3)?, updated_at: row.get(4)?, enabled: row.get::<_, i64>(5)? != 0 }),
        ).optional().map_err(|e| error(&format!("Cannot read workflow: {e}")))
    }
}

fn error(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: message.to_owned(),
    }
}
fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

#[cfg(test)]
mod tests {
    use super::*;
    struct TestDirectory(std::path::PathBuf);
    impl TestDirectory {
        fn new() -> Self {
            static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
            let path = std::env::temp_dir().join(format!(
                "kiyori-workflows-{}-{}-{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_nanos(),
                NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            ));
            std::fs::create_dir(&path).unwrap();
            Self(path)
        }
    }
    impl Drop for TestDirectory {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }
    #[test]
    fn creates_lists_and_deletes_workflows_in_updated_order() {
        let dir = TestDirectory::new();
        let store = WorkflowStore::open(&dir.0).unwrap();
        assert!(store.list().unwrap().is_empty());
        let first = store.create("First".into(), "one".into()).unwrap();
        let second = store.create("Second".into(), "two".into()).unwrap();
        assert_eq!(
            store
                .list()
                .unwrap()
                .iter()
                .map(|w| w.name.as_str())
                .collect::<Vec<_>>(),
            vec!["Second", "First"]
        );
        assert!(store.delete(first.id).unwrap());
        assert!(!store.delete("missing".into()).unwrap());
        assert_eq!(store.get(second.id).unwrap().unwrap().description, "two");
    }
    #[test]
    fn rejects_blank_names_and_preserves_unicode_and_sql_characters() {
        let dir = TestDirectory::new();
        let store = WorkflowStore::open(&dir.0).unwrap();
        assert_eq!(
            store.create(" ".into(), String::new()).unwrap_err().code,
            ErrorCode::InvalidInput
        );
        let record = store
            .create("  中文 ' ; --  ".into(), "正文\n第二行".into())
            .unwrap();
        assert_eq!(record.name, "中文 ' ; --");
        drop(store);
        let reopened = WorkflowStore::open(&dir.0).unwrap();
        assert_eq!(reopened.get(record.id.clone()).unwrap(), Some(record));
    }

    #[test]
    fn update_keeps_identity_and_creation_time_and_never_resurrects_deleted_rows() {
        let dir = TestDirectory::new();
        let store = WorkflowStore::open(&dir.0).unwrap();
        let first = store.create("before".into(), "".into()).unwrap();
        store.create("second".into(), "".into()).unwrap();
        let updated = store
            .update(
                first.id.clone(),
                "after".into(),
                "description".into(),
                false,
            )
            .unwrap();
        assert_eq!(updated.id, first.id);
        assert_eq!(updated.created_at, first.created_at);
        assert!(updated.updated_at > first.updated_at);
        assert!(!updated.enabled);
        assert_eq!(store.list().unwrap()[0], updated);
        store.delete(first.id.clone()).unwrap();
        assert!(
            store
                .update(first.id, "late".into(), "".into(), true)
                .is_err()
        );
        assert_eq!(store.list().unwrap().len(), 1);
    }

    #[test]
    fn batch_delete_is_atomic_and_duplicate_ids_do_not_overcount() {
        let dir = TestDirectory::new();
        let store = WorkflowStore::open(&dir.0).unwrap();
        let one = store.create("one".into(), "".into()).unwrap();
        let two = store.create("two".into(), "".into()).unwrap();
        assert!(store.delete_many(vec![one.id.clone(), "".into()]).is_err());
        assert_eq!(store.list().unwrap().len(), 2);
        assert_eq!(
            store
                .delete_many(vec![one.id.clone(), one.id, two.id, "missing".into()])
                .unwrap(),
            2
        );
        assert!(store.list().unwrap().is_empty());
    }

    #[test]
    fn future_schema_and_invalid_database_are_preserved() {
        let dir = TestDirectory::new();
        let path = dir.0.join("kiyori.sqlite3");
        let conn = Connection::open(&path).unwrap();
        conn.pragma_update(None, "user_version", 100).unwrap();
        drop(conn);
        let before = std::fs::read(&path).unwrap();
        assert!(WorkflowStore::open(&dir.0).is_err());
        assert_eq!(before, std::fs::read(&path).unwrap());
        std::fs::write(&path, b"not a database").unwrap();
        assert!(WorkflowStore::open(&dir.0).is_err());
        assert_eq!(std::fs::read(&path).unwrap(), b"not a database");
        assert!(WorkflowStore::open("relative").is_err());
    }

    #[test]
    fn parallel_creates_are_unique_and_close_prevents_late_writes() {
        let dir = TestDirectory::new();
        let runtime = std::sync::Arc::new(crate::runtime::Runtime::with_data_dir(&dir.0).unwrap());
        let threads: Vec<_> = (0..12)
            .map(|i| {
                let runtime = runtime.clone();
                std::thread::spawn(move || {
                    runtime
                        .create_workflow(format!("工作流{i}"), String::new())
                        .unwrap()
                })
            })
            .collect();
        let ids: std::collections::HashSet<_> = threads
            .into_iter()
            .map(|thread| thread.join().unwrap().id)
            .collect();
        assert_eq!(ids.len(), 12);
        runtime.close();
        assert_eq!(
            runtime
                .create_workflow("late".into(), String::new())
                .unwrap_err()
                .code,
            ErrorCode::RuntimeClosed
        );
        assert_eq!(
            runtime.list_workflows().unwrap_err().code,
            ErrorCode::RuntimeClosed
        );
        let reopened = WorkflowStore::open(&dir.0).unwrap();
        assert_eq!(reopened.list().unwrap().len(), 12);
    }
}
