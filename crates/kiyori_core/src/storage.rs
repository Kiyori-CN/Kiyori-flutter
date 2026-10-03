use crate::runtime::{CoreError, ErrorCode};
use rusqlite::Connection;
use std::{path::Path, sync::Mutex};

const SCHEMA_VERSION: i32 = 5;

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
        if version < 4 {
            transaction
                .execute_batch(
                    "CREATE TABLE memory_search_settings (
                  space_id TEXT PRIMARY KEY REFERENCES knowledge_spaces(id) ON DELETE CASCADE,
                  graph_visible INTEGER NOT NULL DEFAULT 0,
                  score_mode TEXT NOT NULL DEFAULT 'balanced',
                  keyword_weight REAL NOT NULL DEFAULT 10,
                  tag_weight REAL NOT NULL DEFAULT 0,
                  vector_weight REAL NOT NULL DEFAULT 0,
                  edge_weight REAL NOT NULL DEFAULT 0.4,
                  auto_interval INTEGER NOT NULL DEFAULT 5,
                  extraction_rules TEXT NOT NULL DEFAULT '');
                 PRAGMA user_version = 4;",
                )
                .map_err(|_| error("Cannot migrate memory search preferences."))?;
        }
        if version < 5 {
            transaction
                .execute_batch(
                    "CREATE TABLE prompt_characters (
                  id TEXT PRIMARY KEY, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL,
                  name TEXT NOT NULL, description TEXT NOT NULL, setting TEXT NOT NULL,
                  opening TEXT NOT NULL, chat TEXT NOT NULL, voice TEXT NOT NULL,
                  custom TEXT NOT NULL, marks TEXT NOT NULL,
                  model_config TEXT, model_name TEXT,
                  memory_space TEXT REFERENCES knowledge_spaces(id) ON DELETE SET NULL,
                  tools_enabled INTEGER NOT NULL DEFAULT 0);
                 CREATE TABLE prompt_tags (
                  id TEXT PRIMARY KEY, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL,
                  name TEXT NOT NULL, description TEXT NOT NULL, content TEXT NOT NULL);
                 CREATE TABLE prompt_character_tags (
                  character_id TEXT REFERENCES prompt_characters(id) ON DELETE CASCADE,
                  tag_id TEXT REFERENCES prompt_tags(id) ON DELETE CASCADE,
                  position INTEGER NOT NULL, PRIMARY KEY(character_id,tag_id));
                 CREATE TABLE prompt_character_tools (
                  character_id TEXT REFERENCES prompt_characters(id) ON DELETE CASCADE,
                  kind TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY(character_id,kind,name));
                 CREATE TABLE prompt_groups (
                  id TEXT PRIMARY KEY, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL,
                  name TEXT NOT NULL, description TEXT NOT NULL);
                 CREATE TABLE prompt_group_members (
                  group_id TEXT REFERENCES prompt_groups(id) ON DELETE CASCADE,
                  character_id TEXT REFERENCES prompt_characters(id) ON DELETE CASCADE,
                  position INTEGER NOT NULL, PRIMARY KEY(group_id,position));
                 CREATE TABLE prompt_active (
                  id INTEGER PRIMARY KEY CHECK(id=1),
                  character_id TEXT REFERENCES prompt_characters(id),
                  group_id TEXT REFERENCES prompt_groups(id),
                  CHECK((character_id IS NULL)<>(group_id IS NULL)));
                 PRAGMA user_version=5;",
                )
                .map_err(|_| error("Cannot migrate prompt storage."))?;
            crate::prompts::initialize(&transaction)?;
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
