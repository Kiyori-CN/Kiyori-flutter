//! 关系与正文共用空间和事务，图谱仅是当前查询的有界投影。
use crate::{
    knowledge::MemoryQuery,
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{OptionalExtension, TransactionBehavior, params, params_from_iter};
use std::collections::HashSet;

#[derive(Clone, Debug, PartialEq)]
pub struct MemoryLinkDraft {
    pub source_id: String,
    pub target_id: String,
    pub relation: String,
    pub weight: f64,
    pub description: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::knowledge::MemoryDraft;
    use std::{
        path::PathBuf,
        time::{SystemTime, UNIX_EPOCH},
    };

    struct TestDirectory(PathBuf);
    impl TestDirectory {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!(
                "kiyori-graph-{}-{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
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
    fn memory(title: &str, folder: &str) -> MemoryDraft {
        MemoryDraft {
            kind: "memory".into(),
            title: title.into(),
            content: "完整正文".into(),
            category: "other".into(),
            source: "user_input".into(),
            folder: folder.into(),
            credibility: 0.8,
            importance: 0.5,
            tags: vec!["Concept".into()],
        }
    }
    fn link(source: &str, target: &str) -> MemoryLinkDraft {
        MemoryLinkDraft {
            source_id: source.into(),
            target_id: target.into(),
            relation: "related".into(),
            weight: 0.7,
            description: "保留关系描述".into(),
        }
    }
    fn query() -> MemoryQuery {
        MemoryQuery {
            kind: Some("memory".into()),
            text: "完整正文".into(),
            ..Default::default()
        }
    }

    #[test]
    fn graph_preserves_description_filters_endpoints_and_cascades_atomically() {
        let dir = TestDirectory::new();
        let store = AppStore::open(&dir.0).unwrap();
        let one = store
            .save_memory("default".into(), None, memory("一", "工作"))
            .unwrap();
        let two = store
            .save_memory("default".into(), None, memory("二", "学习"))
            .unwrap();
        let id = store
            .save_memory_link("default".into(), None, link(&one, &two))
            .unwrap();
        assert_eq!(
            store
                .save_memory_link("default".into(), None, link(&one, &two))
                .unwrap(),
            id
        );
        let graph = store.memory_graph(query()).unwrap();
        assert_eq!(graph.nodes.len(), 2);
        assert_eq!(graph.nodes[0].node_type, "concept");
        assert_eq!(graph.edges[0].draft.description, "保留关系描述");
        assert!(graph.edges[0].cross_folder);
        let mut edited = link(&one, &two);
        edited.description = "修订说明".into();
        edited.weight = 5.;
        store
            .save_memory_link("default".into(), Some(id.clone()), edited)
            .unwrap();
        drop(store);
        let store = AppStore::open(&dir.0).unwrap();
        let graph = store.memory_graph(query()).unwrap();
        assert_eq!(graph.edges[0].draft.description, "修订说明");
        assert_eq!(graph.edges[0].draft.weight, 1.);
        assert!(
            store
                .memory_graph(MemoryQuery {
                    text: "一".into(),
                    ..query()
                })
                .unwrap()
                .edges
                .is_empty()
        );
        assert!(
            store
                .delete_memories("default".into(), vec![one.clone(), "missing".into()])
                .is_err()
        );
        assert_eq!(store.memory_graph(query()).unwrap().nodes.len(), 2);
        assert_eq!(
            store
                .delete_memories("default".into(), vec![one.clone(), one, two])
                .unwrap(),
            2
        );
        assert!(!store.delete_memory_link("default".into(), id).unwrap());
        assert!(store.memory_graph(query()).unwrap().nodes.is_empty());
    }

    #[test]
    fn relationship_writes_reject_cross_space_self_nan_and_stale_edits() {
        let dir = TestDirectory::new();
        let store = AppStore::open(&dir.0).unwrap();
        let one = store
            .save_memory("default".into(), None, memory("一", ""))
            .unwrap();
        let two = store
            .save_memory("default".into(), None, memory("二", ""))
            .unwrap();
        assert!(
            store
                .save_memory_link("default".into(), None, link(&one, &one))
                .is_err()
        );
        let mut draft = link(&one, &two);
        draft.weight = f64::NAN;
        assert!(
            store
                .save_memory_link("default".into(), None, draft)
                .is_err()
        );
        assert!(
            store
                .save_memory_link("other".into(), None, link(&one, &two))
                .is_err()
        );
        assert!(
            store
                .save_memory_link("default".into(), Some("missing".into()), link(&one, &two))
                .is_err()
        );
        let id = store
            .save_memory_link("default".into(), None, link(&one, &two))
            .unwrap();
        let mut second = link(&one, &two);
        second.relation = "explains".into();
        let second_id = store
            .save_memory_link("default".into(), None, second.clone())
            .unwrap();
        assert!(
            store
                .save_memory_link("default".into(), Some(id.clone()), second)
                .is_err()
        );
        assert!(
            !store
                .delete_memory_link("other".into(), id.clone())
                .unwrap()
        );
        assert!(
            store
                .delete_memory_link("default".into(), id.clone())
                .unwrap()
        );
        assert!(
            store
                .save_memory_link("default".into(), Some(id), link(&one, &two))
                .is_err()
        );
        assert_eq!(store.memory_graph(query()).unwrap().edges[0].id, second_id);
    }

    #[test]
    fn graph_caps_nodes_after_filtering_without_changing_list_pagination() {
        let dir = TestDirectory::new();
        let store = AppStore::open(&dir.0).unwrap();
        for index in 0..205 {
            store
                .save_memory("default".into(), None, memory(&format!("条目{index}"), ""))
                .unwrap();
        }
        let graph = store.memory_graph(query()).unwrap();
        assert_eq!(graph.nodes.len(), 200);
        assert!(graph.has_more);
        assert_eq!(store.query_knowledge(query()).unwrap().records.len(), 100);
        let ids: Vec<_> = graph.nodes.iter().map(|n| n.id.clone()).collect();
        assert_eq!(store.delete_memories("default".into(), ids).unwrap(), 200);
        assert_eq!(store.memory_graph(query()).unwrap().nodes.len(), 5);
    }

    #[test]
    fn migration_from_schema_two_preserves_content_and_workflows() {
        let dir = TestDirectory::new();
        let store = AppStore::open(&dir.0).unwrap();
        let id = store
            .save_memory("default".into(), None, memory("迁移", ""))
            .unwrap();
        store.create("工作流".into(), "保留".into()).unwrap();
        // 构造精确schema2：关系表尚不存在，正文和工作流已经有内容。
        store
            .connection
            .lock()
            .unwrap()
            .execute_batch("DROP TABLE memory_search_settings; DROP TABLE memory_links; PRAGMA user_version=2;")
            .unwrap();
        drop(store);
        let store = AppStore::open(&dir.0).unwrap();
        assert_eq!(
            store
                .get_memory("default".into(), id)
                .unwrap()
                .unwrap()
                .draft
                .content,
            "完整正文"
        );
        assert_eq!(store.list().unwrap()[0].description, "保留");
        assert!(store.memory_graph(query()).unwrap().edges.is_empty());
    }

    #[test]
    fn concurrent_duplicate_links_share_identity_and_closed_runtime_rejects_writes() {
        let dir = TestDirectory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let one = runtime
            .save_memory("default".into(), None, memory("一", ""))
            .unwrap();
        let two = runtime
            .save_memory("default".into(), None, memory("二", ""))
            .unwrap();
        let paths: Vec<_> = (0..4).map(|_| dir.0.clone()).collect();
        let ids: HashSet<_> = paths
            .into_iter()
            .map(|path| {
                let draft = link(&one, &two);
                std::thread::spawn(move || {
                    Runtime::with_data_dir(path)
                        .unwrap()
                        .save_memory_link("default".into(), None, draft)
                        .unwrap()
                })
            })
            .collect::<Vec<_>>()
            .into_iter()
            .map(|thread| thread.join().unwrap())
            .collect();
        assert_eq!(ids.len(), 1);
        assert_eq!(runtime.memory_graph(query()).unwrap().edges.len(), 1);
        runtime.close();
        assert_eq!(
            runtime
                .save_memory_link("default".into(), None, link(&one, &two))
                .unwrap_err()
                .code,
            ErrorCode::RuntimeClosed
        );
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct MemoryLink {
    pub id: String,
    pub draft: MemoryLinkDraft,
    pub cross_folder: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct GraphNode {
    pub id: String,
    pub title: String,
    pub node_type: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct MemoryGraph {
    pub space_id: String,
    pub nodes: Vec<GraphNode>,
    pub edges: Vec<MemoryLink>,
    pub has_more: bool,
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
        message: "Memory relationship storage failed.".into(),
    }
}

impl Runtime {
    pub fn memory_graph(&self, query: MemoryQuery) -> Result<MemoryGraph, CoreError> {
        self.with_store(|s| s.memory_graph(query))
    }
    pub fn save_memory_link(
        &self,
        space: String,
        id: Option<String>,
        draft: MemoryLinkDraft,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.save_memory_link(space, id, draft))
    }
    pub fn delete_memory_link(&self, space: String, id: String) -> Result<bool, CoreError> {
        self.with_store(|s| s.delete_memory_link(space, id))
    }
    pub fn delete_memories(&self, space: String, ids: Vec<String>) -> Result<u32, CoreError> {
        self.with_store(|s| s.delete_memories(space, ids))
    }
}

impl AppStore {
    pub fn memory_graph(&self, mut query: MemoryQuery) -> Result<MemoryGraph, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection.transaction().map_err(storage)?;
        // 不能分别读两个100条分页：中间写入会让端点与边属于不同快照。
        query.offset = 0;
        let snapshot = Self::query_knowledge_in(&transaction, query, 200)?;
        let ids: Vec<_> = snapshot.records.iter().map(|r| r.id.as_str()).collect();
        let mut edges = vec![];
        if !ids.is_empty() {
            let placeholders = vec!["?"; ids.len()].join(",");
            let sql = format!(
                "SELECT l.id,l.source_id,l.target_id,l.relation,l.weight,l.description,s.folder<>t.folder
                 FROM memory_links l JOIN memories s ON s.id=l.source_id JOIN memories t ON t.id=l.target_id
                 WHERE l.space_id=? AND l.source_id IN ({placeholders}) AND l.target_id IN ({placeholders}) ORDER BY l.rowid"
            );
            let values = std::iter::once(snapshot.active_space.as_str())
                .chain(ids.iter().copied())
                .chain(ids.iter().copied());
            edges = transaction
                .prepare(&sql)
                .map_err(storage)?
                .query_map(params_from_iter(values), |r| {
                    Ok(MemoryLink {
                        id: r.get(0)?,
                        draft: MemoryLinkDraft {
                            source_id: r.get(1)?,
                            target_id: r.get(2)?,
                            relation: r.get(3)?,
                            weight: r.get(4)?,
                            description: r.get(5)?,
                        },
                        cross_folder: r.get(6)?,
                    })
                })
                .map_err(storage)?
                .collect::<Result<Vec<_>, _>>()
                .map_err(storage)?;
        }
        let nodes = snapshot
            .records
            .into_iter()
            .map(|record| {
                let node_type = if record.draft.kind == "knowledge"
                    && record.draft.source == "document_import"
                {
                    "document"
                } else {
                    match record.draft.tags.first().map(String::as_str) {
                        Some("Person") => "person",
                        Some("Concept") => "concept",
                        _ => "other",
                    }
                };
                GraphNode {
                    id: record.id,
                    title: record.draft.title,
                    node_type: node_type.into(),
                }
            })
            .collect();
        transaction.commit().map_err(storage)?;
        Ok(MemoryGraph {
            space_id: snapshot.active_space,
            nodes,
            edges,
            has_more: snapshot.has_more,
        })
    }

    pub fn save_memory_link(
        &self,
        space: String,
        id: Option<String>,
        mut draft: MemoryLinkDraft,
    ) -> Result<String, CoreError> {
        draft.relation = draft.relation.trim().into();
        if draft.source_id == draft.target_id
            || draft.relation.is_empty()
            || !draft.weight.is_finite()
        {
            return Err(invalid(
                "A relationship needs distinct endpoints, a type and a finite weight.",
            ));
        }
        draft.weight = draft.weight.clamp(0., 1.);
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        for endpoint in [&draft.source_id, &draft.target_id] {
            let exists: bool = transaction
                .query_row(
                    "SELECT EXISTS(SELECT 1 FROM memories WHERE space_id=?1 AND id=?2)",
                    params![space, endpoint],
                    |r| r.get(0),
                )
                .map_err(storage)?;
            if !exists {
                return Err(invalid(
                    "Relationship endpoint no longer exists in this space.",
                ));
            }
        }
        if let Some(ref id) = id {
            let endpoints: Option<(String, String)> = transaction
                .query_row(
                    "SELECT source_id,target_id FROM memory_links WHERE space_id=?1 AND id=?2",
                    params![space, id],
                    |r| Ok((r.get(0)?, r.get(1)?)),
                )
                .optional()
                .map_err(storage)?;
            if endpoints != Some((draft.source_id.clone(), draft.target_id.clone())) {
                return Err(invalid(
                    "Relationship no longer exists or its endpoints changed.",
                ));
            }
        }
        let duplicate: Option<String> = transaction.query_row("SELECT id FROM memory_links WHERE space_id=?1 AND source_id=?2 AND target_id=?3 AND relation=?4",params![space,draft.source_id,draft.target_id,draft.relation], |r| r.get(0)).optional().map_err(storage)?;
        if let Some(existing) = duplicate {
            if id.is_none() {
                return Ok(existing);
            }
            if id.as_ref() != Some(&existing) {
                return Err(invalid(
                    "This relationship type already exists between these endpoints.",
                ));
            }
        }
        let id = match id {
            Some(id) => {
                transaction.execute("UPDATE memory_links SET relation=?3,weight=?4,description=?5 WHERE space_id=?1 AND id=?2",params![space,id,draft.relation,draft.weight,draft.description]).map_err(storage)?;
                id
            }
            None => {
                let id: String = transaction
                    .query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
                    .map_err(storage)?;
                transaction.execute("INSERT INTO memory_links(id,space_id,source_id,target_id,relation,weight,description) VALUES(?1,?2,?3,?4,?5,?6,?7)",params![id,space,draft.source_id,draft.target_id,draft.relation,draft.weight,draft.description]).map_err(storage)?;
                id
            }
        };
        transaction.commit().map_err(storage)?;
        Ok(id)
    }

    pub fn delete_memory_link(&self, space: String, id: String) -> Result<bool, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        Ok(connection
            .execute(
                "DELETE FROM memory_links WHERE space_id=?1 AND id=?2",
                params![space, id],
            )
            .map_err(storage)?
            == 1)
    }

    pub fn delete_memories(&self, space: String, ids: Vec<String>) -> Result<u32, CoreError> {
        let ids: HashSet<_> = ids.into_iter().collect();
        if ids.is_empty() || ids.len() > 200 {
            return Err(invalid("Select between 1 and 200 graph nodes."));
        }
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let transaction = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        // 任意端点失效都取消整批，不能把局部删除报告为完整成功。
        for id in &ids {
            let exists: bool = transaction
                .query_row(
                    "SELECT EXISTS(SELECT 1 FROM memories WHERE space_id=?1 AND id=?2)",
                    params![space, id],
                    |r| r.get(0),
                )
                .map_err(storage)?;
            if !exists {
                return Err(invalid("Selected memory no longer exists in this space."));
            }
        }
        for id in &ids {
            transaction
                .execute(
                    "DELETE FROM memories WHERE space_id=?1 AND id=?2",
                    params![space, id],
                )
                .map_err(storage)?;
        }
        transaction.commit().map_err(storage)?;
        Ok(ids.len() as u32)
    }
}
