use crate::runtime::{CoreError, ErrorCode};
use rusqlite::Connection;
use std::{path::Path, sync::Mutex};

const SCHEMA_VERSION: i32 = 3;

pub struct AppStore {
    pub(crate) connection: Mutex<Connection>,
}

impl AppStore {
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
        if version < 2 {
            transaction.execute_batch(
                "CREATE TABLE knowledge_spaces (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL);
                 INSERT INTO knowledge_spaces VALUES ('default', '默认配置');
                 CREATE TABLE knowledge_settings (id INTEGER PRIMARY KEY CHECK(id=1), active_space TEXT NOT NULL REFERENCES knowledge_spaces(id));
                 INSERT INTO knowledge_settings VALUES (1, 'default');
                 CREATE TABLE knowledge_folders (space_id TEXT NOT NULL REFERENCES knowledge_spaces(id) ON DELETE CASCADE, path TEXT NOT NULL, PRIMARY KEY(space_id,path));
                 CREATE TABLE memories (
                   id TEXT PRIMARY KEY NOT NULL, space_id TEXT NOT NULL REFERENCES knowledge_spaces(id) ON DELETE CASCADE,
                   kind TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, category TEXT NOT NULL,
                   source TEXT NOT NULL, folder TEXT NOT NULL, credibility REAL NOT NULL, importance REAL NOT NULL,
                   archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
                 CREATE INDEX memories_space_kind ON memories(space_id,kind,archived,updated_at DESC);
                 CREATE TABLE memory_tags (memory_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE, name TEXT NOT NULL, PRIMARY KEY(memory_id,name));
                 PRAGMA user_version = 2;"
            ).map_err(|_| error("Cannot migrate knowledge storage."))?;
        }
        if version < 3 {
            transaction
                .execute_batch(
                    "CREATE TABLE memory_links (
                    id TEXT PRIMARY KEY NOT NULL,
                    space_id TEXT NOT NULL REFERENCES knowledge_spaces(id) ON DELETE CASCADE,
                    source_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
                    target_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
                    relation TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>=0 AND weight<=1),
                    description TEXT NOT NULL, CHECK(source_id<>target_id),
                    UNIQUE(space_id,source_id,target_id,relation));
                 CREATE INDEX memory_links_target ON memory_links(target_id);
                 PRAGMA user_version = 3;",
                )
                .map_err(|_| error("Cannot migrate memory relationships."))?;
        }
        transaction
            .commit()
            .map_err(|e| error(&format!("Cannot commit schema: {e}")))?;
        Ok(Self {
            connection: Mutex::new(connection),
        })
    }
}

fn error(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: message.to_owned(),
    }
}
