//! 空间、目录及手工记忆的事实存储；共用 Runtime 的连接、迁移与关闭边界。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, OptionalExtension, Transaction, params};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KnowledgeSpace {
    pub id: String,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MemoryDraft {
    pub kind: String,
    pub title: String,
    pub content: String,
    pub category: String,
    pub source: String,
    pub folder: String,
    pub credibility: f64,
    pub importance: f64,
    pub tags: Vec<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MemoryRecord {
    pub id: String,
    pub space_id: String,
    pub draft: MemoryDraft,
    pub archived: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub diary: Option<crate::diary::DiarySummary>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct KnowledgeSnapshot {
    pub spaces: Vec<KnowledgeSpace>,
    pub active_space: String,
    pub folders: Vec<String>,
    pub records: Vec<MemoryRecord>,
    pub has_more: bool,
    pub available_tags: Vec<String>,
}

#[derive(Clone, Debug, Default)]
pub struct MemoryQuery {
    pub kind: Option<String>,
    pub folder: String,
    pub text: String,
    pub category: Option<String>,
    pub tag: Option<String>,
    pub archived: bool,
    pub sort_title: bool,
    pub offset: u32,
    pub diary_closed: Option<bool>,
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
        message: "Knowledge storage operation failed.".into(),
    }
}
fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

// 逻辑目录不映射宿主路径，仍拒绝点段，避免未来资源适配错误地解析为跨目录访问。
fn folder_path(path: &str) -> Result<String, CoreError> {
    if path.chars().any(char::is_control) {
        return Err(invalid("Invalid folder path."));
    }
    let normalized = path
        .replace('\\', "/")
        .split('/')
        .map(str::trim)
        .filter(|p| !p.is_empty())
        .map(str::to_owned)
        .collect::<Vec<_>>();
    if normalized
        .iter()
        .any(|p| p == "." || p == ".." || p.contains('\0'))
    {
        return Err(invalid("Invalid folder path."));
    }
    Ok(normalized.join("/"))
}
fn require_space(connection: &Connection, id: &str) -> Result<(), CoreError> {
    if !connection
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM knowledge_spaces WHERE id=?1)",
            [id],
            |r| r.get::<_, bool>(0),
        )
        .map_err(storage)?
    {
        return Err(invalid("Memory space no longer exists."));
    }
    Ok(())
}
fn ensure_folders(transaction: &Transaction<'_>, space: &str, path: &str) -> Result<(), CoreError> {
    let mut current = String::new();
    for part in path.split('/').filter(|p| !p.is_empty()) {
        if !current.is_empty() {
            current.push('/');
        }
        current.push_str(part);
        transaction
            .execute(
                "INSERT OR IGNORE INTO knowledge_folders VALUES (?1,?2)",
                params![space, current],
            )
            .map_err(storage)?;
    }
    Ok(())
}

impl Runtime {
    pub fn create_diary(
        &self,
        space: String,
        draft: MemoryDraft,
        phase: String,
        stamp: String,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.create_diary(space, draft, phase, stamp))
    }
    pub fn append_diary(
        &self,
        space: String,
        id: String,
        body: String,
        phase: String,
        stamp: String,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.append_diary(space, id, body, phase, stamp))
    }
    pub fn query_knowledge(&self, query: MemoryQuery) -> Result<KnowledgeSnapshot, CoreError> {
        self.with_store(|s| s.query_knowledge(query))
    }
    pub fn get_memory(&self, space: String, id: String) -> Result<Option<MemoryRecord>, CoreError> {
        self.with_store(|s| s.get_memory(space, id))
    }
    pub fn rename_knowledge_folder(
        &self,
        space: String,
        old: String,
        new: String,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.rename_knowledge_folder(space, old, new))
    }
    pub fn delete_knowledge_folder(&self, space: String, path: String) -> Result<(), CoreError> {
        self.with_store(|s| s.delete_knowledge_folder(space, path))
    }
    pub fn knowledge_snapshot(&self) -> Result<KnowledgeSnapshot, CoreError> {
        self.with_store(AppStore::knowledge_snapshot)
    }
    pub fn save_knowledge_space(
        &self,
        id: Option<String>,
        name: String,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_knowledge_space(id, name))
    }
    pub fn select_knowledge_space(&self, id: String) -> Result<(), CoreError> {
        self.with_store(|s| s.select_knowledge_space(id))
    }
    pub fn delete_knowledge_space(&self, id: String) -> Result<bool, CoreError> {
        self.with_store(|s| s.delete_knowledge_space(id))
    }
    pub fn create_knowledge_folder(&self, space: String, path: String) -> Result<(), CoreError> {
        self.with_store(|s| s.create_knowledge_folder(space, path))
    }
    pub fn save_memory(
        &self,
        space: String,
        id: Option<String>,
        draft: MemoryDraft,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_memory(space, id, draft))
    }
    pub fn archive_memory(
        &self,
        space: String,
        id: String,
        archived: bool,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.archive_memory(space, id, archived))
    }
    pub fn delete_memory(&self, space: String, id: String) -> Result<bool, CoreError> {
        self.with_store(|s| s.delete_memory(space, id))
    }
}

impl AppStore {
    pub fn create_diary(
        &self,
        space: String,
        mut draft: MemoryDraft,
        phase: String,
        stamp: String,
    ) -> Result<String, CoreError> {
        if draft.kind != "diary" || phase == "closed" {
            return Err(invalid("A diary must start with an opening entry."));
        }
        draft.content = crate::diary::append("", &draft.content, &phase, &stamp)?;
        self.save_memory_inner(space, None, draft, true)
    }

    pub fn append_diary(
        &self,
        space: String,
        id: String,
        body: String,
        phase: String,
        stamp: String,
    ) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        let current: Option<(String, bool)> = transaction.query_row(
            "SELECT content,archived FROM memories WHERE id=?1 AND space_id=?2 AND kind='diary'",
            params![id,space], |r| Ok((r.get(0)?,r.get(1)?)),
        ).optional().map_err(storage)?;
        let (content, archived) =
            current.ok_or_else(|| invalid("Diary no longer exists in this space."))?;
        if archived {
            return Err(invalid("Restore the diary before appending."));
        }
        // 在写事务内重读最新正文，两个 runtime 追加时不能用调用方旧快照互相覆盖。
        let content = crate::diary::append(&content, &body, &phase, &stamp)?;
        transaction.execute(
            "UPDATE memories SET content=?3,updated_at=max(?4,(SELECT coalesce(max(updated_at),0)+1 FROM memories)) WHERE id=?1 AND space_id=?2",
            params![id,space,content,now_ms()],
        ).map_err(storage)?;
        transaction.commit().map_err(storage)
    }
    pub fn rename_knowledge_folder(
        &self,
        space: String,
        old: String,
        new: String,
    ) -> Result<(), CoreError> {
        let old = folder_path(&old)?;
        let new = folder_path(&new)?;
        if old.is_empty() || new.is_empty() || old == new || new.starts_with(&format!("{old}/")) {
            return Err(invalid("Invalid folder move."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&transaction, &space)?;
        let exists = |path: &str| {
            transaction
                .query_row(
                    "SELECT EXISTS(SELECT 1 FROM knowledge_folders WHERE space_id=?1 AND path=?2)",
                    params![space, path],
                    |r| r.get::<_, bool>(0),
                )
                .map_err(storage)
        };
        if !exists(&old)? || exists(&new)? {
            return Err(invalid("Source is missing or target already exists."));
        }
        // 用精确前缀而不是 LIKE，名称中的 %、_ 不能扩大影响范围。
        transaction.execute("UPDATE knowledge_folders SET path=?3 || substr(path,length(?2)+1) WHERE space_id=?1 AND (path=?2 OR substr(path,1,length(?2)+1)=?2||'/')",params![space,old,new]).map_err(storage)?;
        transaction.execute("UPDATE memories SET folder=?3 || substr(folder,length(?2)+1) WHERE space_id=?1 AND (folder=?2 OR substr(folder,1,length(?2)+1)=?2||'/')",params![space,old,new]).map_err(storage)?;
        ensure_folders(&transaction, &space, &new)?;
        transaction.commit().map_err(storage)
    }
    pub fn delete_knowledge_folder(&self, space: String, path: String) -> Result<(), CoreError> {
        let path = folder_path(&path)?;
        if path.is_empty() {
            return Err(invalid("Cannot delete the root folder."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&transaction, &space)?;
        transaction.execute("UPDATE memories SET folder='' WHERE space_id=?1 AND (folder=?2 OR substr(folder,1,length(?2)+1)=?2||'/')",params![space,path]).map_err(storage)?;
        transaction.execute("DELETE FROM knowledge_folders WHERE space_id=?1 AND (path=?2 OR substr(path,1,length(?2)+1)=?2||'/')",params![space,path]).map_err(storage)?;
        transaction.commit().map_err(storage)
    }
    pub fn knowledge_snapshot(&self) -> Result<KnowledgeSnapshot, CoreError> {
        self.query_knowledge(MemoryQuery::default())
    }
    pub fn query_knowledge(&self, query: MemoryQuery) -> Result<KnowledgeSnapshot, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        // 目录、活跃空间、正文和标签来自同一读事务，不能跨空间拼接两个时刻的事实。
        let transaction = connection.transaction().map_err(storage)?;
        let active_space: String = transaction
            .query_row(
                "SELECT active_space FROM knowledge_settings WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(storage)?;
        let spaces = transaction
            .prepare("SELECT id,name FROM knowledge_spaces ORDER BY rowid")
            .map_err(storage)?
            .query_map([], |r| {
                Ok(KnowledgeSpace {
                    id: r.get(0)?,
                    name: r.get(1)?,
                })
            })
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let folders = transaction
            .prepare(
                "SELECT path FROM knowledge_folders WHERE space_id=?1 ORDER BY path COLLATE NOCASE",
            )
            .map_err(storage)?
            .query_map([&active_space], |r| r.get(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let folder = folder_path(&query.folder)?;
        let text = query.text.trim();
        let subtree = !text.is_empty()
            || query.category.is_some()
            || query.tag.is_some()
            || query.archived
            || query.diary_closed.is_some();
        // 标签来自分页前的查询范围，主题/标签筛选不能让其它候选消失。
        let available_tags = transaction.prepare(
            "SELECT DISTINCT t.name FROM memory_tags t JOIN memories m ON m.id=t.memory_id
             WHERE m.space_id=?1 AND (?2 IS NULL OR m.kind=?2) AND (?2 IS NULL OR m.archived=?3)
             AND (?4='' OR instr(lower(m.title),lower(?4))>0 OR instr(lower(m.content),lower(?4))>0
               OR EXISTS(SELECT 1 FROM memory_tags st WHERE st.memory_id=m.id AND instr(lower(st.name),lower(?4))>0))
             AND (?5 OR m.folder=?6 OR (?7 AND (?6='' OR substr(m.folder,1,length(?6)+1)=?6||'/')))
             ORDER BY t.name COLLATE NOCASE,t.name"
        ).map_err(storage)?.query_map(params![active_space,query.kind,query.archived,text,query.kind.is_none(),folder,subtree], |r| r.get(0))
            .map_err(storage)?.collect::<Result<Vec<String>,_>>().map_err(storage)?;
        // 每页只传400字符列表摘要；正文保持原样存储，打开详情时按身份读取完整正文。
        let filter_status = query
            .diary_closed
            .filter(|_| query.kind.as_deref() == Some("diary"));
        let mut statement = transaction.prepare("SELECT id,kind,title,CASE WHEN kind='diary' THEN content ELSE substr(content,1,400) END,category,source,folder,credibility,importance,archived,created_at,updated_at FROM memories WHERE space_id=?1 AND (?2 IS NULL OR kind=?2) AND (?2 IS NULL OR archived=?3) AND (?4 IS NULL OR category=?4) AND (?5 IS NULL OR EXISTS(SELECT 1 FROM memory_tags WHERE memory_id=memories.id AND name=?5)) AND (?6='' OR instr(lower(title),lower(?6))>0 OR instr(lower(content),lower(?6))>0 OR EXISTS(SELECT 1 FROM memory_tags WHERE memory_id=memories.id AND instr(lower(name),lower(?6))>0)) AND (?7 OR folder=?8 OR (?9 AND (?8='' OR substr(folder,1,length(?8)+1)=?8||'/'))) ORDER BY CASE WHEN ?10 THEN title END COLLATE NOCASE ASC,updated_at DESC,id DESC LIMIT ?12 OFFSET ?11").map_err(storage)?;
        let rows = statement
            .query_map(
                params![
                    active_space,
                    query.kind,
                    query.archived,
                    query.category,
                    query.tag,
                    text,
                    query.kind.is_none(),
                    folder,
                    subtree,
                    query.sort_title,
                    if filter_status.is_some() {
                        0
                    } else {
                        query.offset
                    },
                    if filter_status.is_some() { -1 } else { 101 }
                ],
                |r| {
                    Ok(MemoryRecord {
                        id: r.get(0)?,
                        space_id: active_space.clone(),
                        draft: MemoryDraft {
                            kind: r.get(1)?,
                            title: r.get(2)?,
                            content: r.get(3)?,
                            category: r.get(4)?,
                            source: r.get(5)?,
                            folder: r.get(6)?,
                            credibility: r.get(7)?,
                            importance: r.get(8)?,
                            tags: vec![],
                        },
                        archived: r.get(9)?,
                        created_at: r.get(10)?,
                        updated_at: r.get(11)?,
                        diary: None,
                    })
                },
            )
            .map_err(storage)?;
        let mut records = Vec::new();
        let mut skipped = 0;
        for row in rows {
            let mut record = row.map_err(storage)?;
            if record.draft.kind == "diary" {
                let document = crate::diary::parse(&record.draft.content);
                if filter_status.is_some_and(|closed| closed != document.closed()) {
                    continue;
                }
                record.diary = Some(document.metadata());
                record.draft.content = document.summary().chars().take(400).collect();
            }
            if filter_status.is_some() && skipped < query.offset {
                skipped += 1;
                continue;
            }
            records.push(record);
            if records.len() == 101 {
                break;
            }
        }
        drop(statement);

        let has_more = records.len() > 100;
        records.truncate(100);
        let mut tag_statement = transaction
            .prepare("SELECT name FROM memory_tags WHERE memory_id=?1 ORDER BY rowid")
            .map_err(storage)?;
        for record in &mut records {
            record.draft.tags = tag_statement
                .query_map([&record.id], |r| r.get(0))
                .map_err(storage)?
                .collect::<Result<Vec<_>, _>>()
                .map_err(storage)?;
        }
        drop(tag_statement);
        transaction.commit().map_err(storage)?;
        Ok(KnowledgeSnapshot {
            spaces,
            active_space,
            folders,
            records,
            has_more,
            available_tags,
        })
    }
    pub fn get_memory(&self, space: String, id: String) -> Result<Option<MemoryRecord>, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection.transaction().map_err(storage)?;
        let mut record=transaction.query_row("SELECT kind,title,content,category,source,folder,credibility,importance,archived,created_at,updated_at FROM memories WHERE space_id=?1 AND id=?2",params![space,id],|r|Ok(MemoryRecord{id:id.clone(),space_id:space.clone(),draft:MemoryDraft{kind:r.get(0)?,title:r.get(1)?,content:r.get(2)?,category:r.get(3)?,source:r.get(4)?,folder:r.get(5)?,credibility:r.get(6)?,importance:r.get(7)?,tags:vec![]},archived:r.get(8)?,created_at:r.get(9)?,updated_at:r.get(10)?,diary:None})).optional().map_err(storage)?;
        if let Some(record) = record.as_mut() {
            if record.draft.kind == "diary" {
                record.diary = Some(crate::diary::parse(&record.draft.content).metadata());
            }
            record.draft.tags = transaction
                .prepare("SELECT name FROM memory_tags WHERE memory_id=?1 ORDER BY rowid")
                .map_err(storage)?
                .query_map([&id], |r| r.get(0))
                .map_err(storage)?
                .collect::<Result<Vec<_>, _>>()
                .map_err(storage)?;
        }
        transaction.commit().map_err(storage)?;
        Ok(record)
    }
    pub fn save_knowledge_space(
        &self,
        id: Option<String>,
        name: String,
    ) -> Result<String, CoreError> {
        let name = name.trim();
        if name.is_empty() {
            return Err(invalid("Space name cannot be blank."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        if let Some(id) = id {
            if connection
                .execute(
                    "UPDATE knowledge_spaces SET name=?2 WHERE id=?1",
                    params![id, name],
                )
                .map_err(storage)?
                == 0
            {
                return Err(invalid("Memory space no longer exists."));
            }
            Ok(id)
        } else {
            let transaction = connection
                .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
                .map_err(storage)?;
            let id:String=transaction.query_row("INSERT INTO knowledge_spaces VALUES (lower(hex(randomblob(16))),?1) RETURNING id",[name],|r|r.get(0)).map_err(storage)?;
            transaction
                .execute(
                    "UPDATE knowledge_settings SET active_space=?1 WHERE id=1",
                    [&id],
                )
                .map_err(storage)?;
            transaction.commit().map_err(storage)?;
            Ok(id)
        }
    }
    pub fn select_knowledge_space(&self, id: String) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&transaction, &id)?;
        transaction
            .execute(
                "UPDATE knowledge_settings SET active_space=?1 WHERE id=1",
                [id],
            )
            .map_err(storage)?;
        transaction.commit().map_err(storage)
    }
    pub fn delete_knowledge_space(&self, id: String) -> Result<bool, CoreError> {
        if id == "default" {
            return Err(invalid("The default memory space cannot be deleted."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        transaction
            .execute(
                "UPDATE knowledge_settings SET active_space='default' WHERE active_space=?1",
                [&id],
            )
            .map_err(storage)?;
        let deleted = transaction
            .execute("DELETE FROM knowledge_spaces WHERE id=?1", [id])
            .map_err(storage)?;
        transaction.commit().map_err(storage)?;
        Ok(deleted == 1)
    }
    pub fn create_knowledge_folder(&self, space: String, path: String) -> Result<(), CoreError> {
        let path = folder_path(&path)?;
        if path.is_empty() {
            return Err(invalid("Folder name cannot be blank."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&transaction, &space)?;
        ensure_folders(&transaction, &space, &path)?;
        transaction.commit().map_err(storage)
    }
    pub fn save_memory(
        &self,
        space: String,
        id: Option<String>,
        draft: MemoryDraft,
    ) -> Result<String, CoreError> {
        self.save_memory_inner(space, id, draft, false)
    }

    fn save_memory_inner(
        &self,
        space: String,
        id: Option<String>,
        mut draft: MemoryDraft,
        diary_seed: bool,
    ) -> Result<String, CoreError> {
        draft.title = draft.title.trim().into();
        if draft.title.is_empty() || draft.content.trim().is_empty() {
            return Err(invalid("Title and content are required."));
        }
        // 新日记必须从阶段开篇入口创建；已有日记可显式编辑全文。
        if (!(["memory", "knowledge"].contains(&draft.kind.as_str())
            || (draft.kind == "diary" && (diary_seed || id.is_some()))))
            || ![
                "other",
                "preference",
                "fact",
                "decision",
                "experience",
                "event",
            ]
            .contains(&draft.category.as_str())
        {
            return Err(invalid("Unsupported memory kind or category."));
        }
        if !draft.credibility.is_finite()
            || !draft.importance.is_finite()
            || !(0.0..=1.0).contains(&draft.credibility)
            || !(0.0..=1.0).contains(&draft.importance)
        {
            return Err(invalid("Invalid memory score."));
        }
        draft.folder = folder_path(&draft.folder)?;
        draft.source = draft.source.trim().into();
        if draft.source.is_empty() {
            draft.source = "user_input".into();
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(rusqlite::TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&transaction, &space)?;
        let now: i64 = transaction
            .query_row(
                "SELECT max(?1,coalesce(max(updated_at),0)+1) FROM memories",
                [now_ms()],
                |r| r.get(0),
            )
            .map_err(storage)?;
        let id = if let Some(id) = id {
            let kind: Option<String> = transaction
                .query_row(
                    "SELECT kind FROM memories WHERE id=?1 AND space_id=?2",
                    params![id, space],
                    |r| r.get(0),
                )
                .optional()
                .map_err(storage)?;
            if kind.as_deref() != Some(&draft.kind) {
                return Err(invalid(
                    "Memory no longer exists in this space or its kind changed.",
                ));
            }
            transaction.execute("UPDATE memories SET title=?3,content=?4,category=?5,source=?6,folder=?7,credibility=?8,importance=?9,updated_at=?10 WHERE id=?1 AND space_id=?2",params![id,space,draft.title,draft.content,draft.category,draft.source,draft.folder,draft.credibility,draft.importance,now]).map_err(storage)?;
            id
        } else {
            transaction.query_row("INSERT INTO memories VALUES (lower(hex(randomblob(16))),?1,?2,?3,?4,?5,?6,?7,?8,?9,0,?10,?10) RETURNING id",params![space,draft.kind,draft.title,draft.content,draft.category,draft.source,draft.folder,draft.credibility,draft.importance,now],|r|r.get(0)).map_err(storage)?
        };
        ensure_folders(&transaction, &space, &draft.folder)?;
        transaction
            .execute("DELETE FROM memory_tags WHERE memory_id=?1", [&id])
            .map_err(storage)?;
        for tag in draft
            .tags
            .iter()
            .map(|t| t.trim())
            .filter(|t| !t.is_empty())
        {
            transaction
                .execute(
                    "INSERT OR IGNORE INTO memory_tags VALUES (?1,?2)",
                    params![id, tag],
                )
                .map_err(storage)?;
        }
        transaction.commit().map_err(storage)?;
        Ok(id)
    }
    pub fn archive_memory(
        &self,
        space: String,
        id: String,
        archived: bool,
    ) -> Result<(), CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let count=connection.execute("UPDATE memories SET archived=?3,updated_at=max(?4,(SELECT coalesce(max(updated_at),0)+1 FROM memories)) WHERE id=?1 AND space_id=?2",params![id,space,archived,now_ms()]).map_err(storage)?;
        if count == 0 {
            return Err(invalid("Memory no longer exists in this space."));
        }
        Ok(())
    }
    pub fn delete_memory(&self, space: String, id: String) -> Result<bool, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        Ok(connection
            .execute(
                "DELETE FROM memories WHERE id=?1 AND space_id=?2",
                params![id, space],
            )
            .map_err(storage)?
            == 1)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn diary_status_filter_scans_before_paging_and_keeps_latest_summary() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        for i in 0..103 {
            let mut value = draft();
            value.kind = "diary".into();
            let id = runtime
                .create_diary(
                    "default".into(),
                    value,
                    "plan".into(),
                    "2026-10-03 10:00".into(),
                )
                .unwrap();
            if i != 102 {
                runtime
                    .append_diary(
                        "default".into(),
                        id,
                        "收尾证据".into(),
                        "closed".into(),
                        "2026-10-03 10:01".into(),
                    )
                    .unwrap();
            }
        }
        let query = |offset| MemoryQuery {
            kind: Some("diary".into()),
            diary_closed: Some(true),
            offset,
            ..Default::default()
        };
        let first = runtime.query_knowledge(query(0)).unwrap();
        assert_eq!(first.records.len(), 100);
        assert!(first.has_more);
        assert!(
            first
                .records
                .iter()
                .all(|r| r.diary.as_ref().unwrap().closed && r.draft.content == "收尾证据")
        );
        let second = runtime.query_knowledge(query(100)).unwrap();
        assert_eq!(second.records.len(), 2);
        assert!(!second.has_more);
        assert!(
            !first
                .records
                .iter()
                .any(|r| second.records.iter().any(|s| r.id == s.id))
        );
    }
    #[test]
    fn diary_append_is_atomic_across_runtimes_and_archive_blocks_writes() {
        let dir = TestDirectory::new();
        let first = Runtime::with_data_dir(&dir.0).unwrap();
        let mut value = draft();
        value.kind = "diary".into();
        let id = first
            .create_diary(
                "default".into(),
                value,
                "plan".into(),
                "2026-10-03 09:25".into(),
            )
            .unwrap();
        let second = Runtime::with_data_dir(&dir.0).unwrap();
        std::thread::scope(|scope| {
            for (runtime, text) in [(&first, "并发一"), (&second, "并发二")] {
                let id = id.clone();
                scope.spawn(move || {
                    runtime
                        .append_diary(
                            "default".into(),
                            id,
                            text.into(),
                            "progress".into(),
                            "2026-10-03 09:26".into(),
                        )
                        .unwrap()
                });
            }
        });
        let record = first
            .get_memory("default".into(), id.clone())
            .unwrap()
            .unwrap();
        let parsed = crate::diary::parse(&record.draft.content);
        assert_eq!(parsed.entries.len(), 3);
        assert!(record.draft.content.contains("并发一"));
        assert!(record.draft.content.contains("并发二"));
        first
            .append_diary(
                "default".into(),
                id.clone(),
                "".into(),
                "closed".into(),
                "2026-10-03 09:27".into(),
            )
            .unwrap();
        assert!(
            crate::diary::parse(
                &first
                    .get_memory("default".into(), id.clone())
                    .unwrap()
                    .unwrap()
                    .draft
                    .content
            )
            .closed()
        );
        first
            .archive_memory("default".into(), id.clone(), true)
            .unwrap();
        assert!(
            first
                .append_diary(
                    "default".into(),
                    id.clone(),
                    "拒绝".into(),
                    "progress".into(),
                    "2026-10-03 09:28".into()
                )
                .is_err()
        );
        first
            .archive_memory("default".into(), id.clone(), false)
            .unwrap();
        first
            .append_diary(
                "default".into(),
                id.clone(),
                "恢复续写".into(),
                "progress".into(),
                "2026-10-03 09:29".into(),
            )
            .unwrap();
        assert!(
            !crate::diary::parse(
                &first
                    .get_memory("default".into(), id.clone())
                    .unwrap()
                    .unwrap()
                    .draft
                    .content
            )
            .closed()
        );
        assert!(
            first
                .append_diary(
                    "other".into(),
                    id,
                    "跨空间".into(),
                    "note".into(),
                    "2026-10-03 09:30".into()
                )
                .is_err()
        );
    }
    #[test]
    fn query_pages_use_literal_search_and_details_preserve_full_content() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let mut value = draft();
        value.folder = "".into();
        value.content = "正文🐱".repeat(220);
        value.content.push_str("needle%_末尾");
        value.tags = vec!["末页独有标签".into()];
        let id = runtime
            .save_memory("default".into(), None, value.clone())
            .unwrap();
        for i in 0..104 {
            let mut next = draft();
            next.folder = "".into();
            next.title = format!("条目{i:03}");
            runtime.save_memory("default".into(), None, next).unwrap();
        }
        let first = runtime
            .query_knowledge(MemoryQuery {
                kind: Some("memory".into()),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(first.records.len(), 100);
        assert!(first.has_more);
        assert!(first.available_tags.contains(&"末页独有标签".into()));
        assert!(!first.records.iter().any(|r| r.id == id));
        let filtered = runtime
            .query_knowledge(MemoryQuery {
                kind: Some("memory".into()),
                tag: Some("标记".into()),
                ..Default::default()
            })
            .unwrap();
        assert!(filtered.available_tags.contains(&"末页独有标签".into()));
        let second = runtime
            .query_knowledge(MemoryQuery {
                kind: Some("memory".into()),
                offset: 100,
                ..Default::default()
            })
            .unwrap();
        assert_eq!(second.records.len(), 5);
        assert!(!second.has_more);
        assert!(
            !second
                .records
                .iter()
                .any(|r| first.records.iter().any(|p| p.id == r.id))
        );
        let found = runtime
            .query_knowledge(MemoryQuery {
                kind: Some("memory".into()),
                text: "needle%_".into(),
                ..Default::default()
            })
            .unwrap();
        assert_eq!(found.records.len(), 1);
        assert_eq!(found.records[0].id, id);
        assert!(found.records[0].draft.content.chars().count() <= 400);
        assert_eq!(
            runtime
                .get_memory("default".into(), id.clone())
                .unwrap()
                .unwrap()
                .draft
                .content,
            value.content
        );
        assert!(runtime.get_memory("missing".into(), id).unwrap().is_none());
    }
    #[test]
    fn folder_rename_is_atomic_and_delete_preserves_content_at_root() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let mut value = draft();
        value.folder = "项目%_/子".into();
        let id = runtime
            .save_memory("default".into(), None, value.clone())
            .unwrap();
        value.folder = "项目xx/子".into();
        runtime.save_memory("default".into(), None, value).unwrap();
        runtime
            .rename_knowledge_folder("default".into(), "项目%_".into(), "迁移/新位置".into())
            .unwrap();
        let snapshot = runtime.knowledge_snapshot().unwrap();
        assert_eq!(
            snapshot
                .records
                .iter()
                .find(|r| r.id == id)
                .unwrap()
                .draft
                .folder,
            "迁移/新位置/子"
        );
        assert!(snapshot.folders.contains(&"项目xx/子".into()));
        assert!(
            runtime
                .rename_knowledge_folder("default".into(), "迁移".into(), "迁移/子".into())
                .is_err()
        );
        assert!(
            runtime
                .rename_knowledge_folder("default".into(), "迁移".into(), "项目xx".into())
                .is_err()
        );
        assert_eq!(runtime.knowledge_snapshot().unwrap(), snapshot);
        runtime
            .delete_knowledge_folder("default".into(), "迁移".into())
            .unwrap();
        let after = runtime.knowledge_snapshot().unwrap();
        assert_eq!(after.records.len(), 2);
        assert_eq!(
            after
                .records
                .iter()
                .find(|r| r.id == id)
                .unwrap()
                .draft
                .folder,
            ""
        );
        assert_eq!(
            after
                .records
                .iter()
                .find(|r| r.id == id)
                .unwrap()
                .draft
                .content,
            draft().content
        );
    }
    struct TestDirectory(std::path::PathBuf);
    impl TestDirectory {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!(
                "kiyori-knowledge-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
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
    fn draft() -> MemoryDraft {
        MemoryDraft {
            kind: "memory".into(),
            title: "中文标题".into(),
            content: "完整正文 ' % _ 🐱".into(),
            category: "fact".into(),
            source: "".into(),
            folder: " 项目 / 子目录 ".into(),
            credibility: 0.8,
            importance: 0.5,
            tags: vec![" 标记 ".into(), "标记".into()],
        }
    }
    #[test]
    fn memory_reopens_with_tags_and_preserves_workflows() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let workflow = runtime
            .create_workflow("保留".into(), "工作流".into())
            .unwrap();
        let id = runtime
            .save_memory("default".into(), None, draft())
            .unwrap();
        runtime.close();
        let reopened = Runtime::with_data_dir(&dir.0).unwrap();
        assert_eq!(reopened.list_workflows().unwrap()[0].id, workflow.id);
        let snapshot = reopened.knowledge_snapshot().unwrap();
        assert_eq!(snapshot.records[0].id, id);
        assert_eq!(snapshot.records[0].draft.tags, vec!["标记"]);
        assert_eq!(snapshot.records[0].draft.content, draft().content);
        assert_eq!(snapshot.folders, vec!["项目", "项目/子目录"]);
        let created = snapshot.records[0].created_at;
        let mut updated = draft();
        updated.title = "编辑".into();
        updated.tags = vec![];
        reopened
            .save_memory("default".into(), Some(id.clone()), updated)
            .unwrap();
        reopened
            .archive_memory("default".into(), id.clone(), true)
            .unwrap();
        let record = &reopened.knowledge_snapshot().unwrap().records[0];
        assert_eq!(record.created_at, created);
        assert!(record.updated_at > created);
        assert!(record.archived);
        assert!(record.draft.tags.is_empty());
        assert!(
            reopened
                .delete_memory("default".into(), id.clone())
                .unwrap()
        );
        assert!(
            reopened
                .save_memory("default".into(), Some(id), draft())
                .is_err()
        );
    }
    #[test]
    fn space_identity_prevents_cross_space_writes_and_cascades_atomically() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let id = runtime
            .save_memory("default".into(), None, draft())
            .unwrap();
        let space = runtime
            .save_knowledge_space(None, "第二空间".into())
            .unwrap();
        runtime.select_knowledge_space(space.clone()).unwrap();
        assert!(runtime.knowledge_snapshot().unwrap().records.is_empty());
        assert!(
            runtime
                .save_memory(space.clone(), Some(id.clone()), draft())
                .is_err()
        );
        assert!(!runtime.delete_memory(space.clone(), id).unwrap());
        runtime.save_memory(space.clone(), None, draft()).unwrap();
        assert!(runtime.delete_knowledge_space(space.clone()).unwrap());
        let snapshot = runtime.knowledge_snapshot().unwrap();
        assert_eq!(snapshot.active_space, "default");
        assert_eq!(snapshot.records.len(), 1);
        assert!(runtime.save_memory(space, None, draft()).is_err());
        assert!(runtime.delete_knowledge_space("default".into()).is_err());
        runtime.close();
        assert_eq!(
            runtime.knowledge_snapshot().unwrap_err().code,
            ErrorCode::RuntimeClosed
        );
    }
    #[test]
    fn invalid_input_does_not_create_partial_folders_or_records() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        for bad in ["", " "] {
            let mut value = draft();
            value.title = bad.into();
            assert!(runtime.save_memory("default".into(), None, value).is_err());
        }
        let mut value = draft();
        value.importance = f64::NAN;
        assert!(runtime.save_memory("default".into(), None, value).is_err());
        let mut value = draft();
        value.folder = "项目/../越界".into();
        assert!(runtime.save_memory("default".into(), None, value).is_err());
        let mut value = draft();
        value.kind = "diary".into();
        assert!(runtime.save_memory("default".into(), None, value).is_err());
        let snapshot = runtime.knowledge_snapshot().unwrap();
        assert!(snapshot.records.is_empty());
        assert!(snapshot.folders.is_empty());
    }
    #[test]
    fn migrates_schema_one_without_overwriting_workflow_data() {
        let dir = TestDirectory::new();
        let connection = Connection::open(dir.0.join("kiyori.sqlite3")).unwrap();
        connection.execute_batch("CREATE TABLE workflows(id TEXT PRIMARY KEY,name TEXT,description TEXT,created_at INTEGER,updated_at INTEGER,enabled INTEGER); INSERT INTO workflows VALUES('old','旧工作流','说明',1,2,1); PRAGMA user_version=1;").unwrap();
        drop(connection);
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        assert_eq!(runtime.list_workflows().unwrap()[0].id, "old");
        assert_eq!(
            runtime.knowledge_snapshot().unwrap().spaces[0].id,
            "default"
        );
    }
}
