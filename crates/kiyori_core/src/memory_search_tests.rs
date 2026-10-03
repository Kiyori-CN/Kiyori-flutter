use super::*;
use crate::knowledge::MemoryDraft;
use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        Self(std::env::temp_dir().join(format!(
                "kiyori-search-{}-{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            )))
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
fn memory(title: &str, content: &str, folder: &str) -> MemoryDraft {
    MemoryDraft {
        kind: "memory".into(),
        title: title.into(),
        content: content.into(),
        category: "other".into(),
        source: "user_input".into(),
        folder: folder.into(),
        credibility: 0.8,
        importance: 0.5,
        tags: vec!["学习".into()],
    }
}
fn query(text: &str) -> MemoryQuery {
    MemoryQuery {
        kind: Some("memory".into()),
        text: text.into(),
        ..Default::default()
    }
}

#[test]
fn settings_survive_reopen_isolate_spaces_and_do_not_overwrite_graph_choice() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    assert_eq!(
        store.memory_search_settings("default".into()).unwrap(),
        MemorySearchSettings::default()
    );
    let mut settings = MemorySearchSettings::default();
    store
        .set_memory_graph_visible("default".into(), true)
        .unwrap();
    settings.keyword_weight = 4.0;
    settings.extraction_rules = "只记录确认的偏好".into();
    settings.auto_interval = 99;
    store
        .save_memory_search_settings("default".into(), settings.clone())
        .unwrap();
    assert!(
        store
            .memory_search_settings("default".into())
            .unwrap()
            .graph_visible
    );
    let other = store.save_knowledge_space(None, "独立".into()).unwrap();
    assert_eq!(
        store.memory_search_settings(other.clone()).unwrap(),
        MemorySearchSettings::default()
    );
    store.set_memory_graph_visible(other.clone(), true).unwrap();
    store.delete_knowledge_space(other.clone()).unwrap();
    assert!(store.memory_search_settings(other).is_err());
    settings.vector_weight = f64::NAN;
    assert!(
        store
            .save_memory_search_settings("default".into(), settings)
            .is_err()
    );
    drop(store);
    let store = AppStore::open(&directory.0).unwrap();
    let restored = store.memory_search_settings("default".into()).unwrap();
    assert_eq!(restored.keyword_weight, 4.0);
    assert_eq!(restored.auto_interval, 30);
    assert_eq!(restored.extraction_rules, "只记录确认的偏好");
}

#[test]
fn search_uses_complete_body_chinese_tokens_wildcards_and_scoped_graph() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    let a = store
        .save_memory(
            "default".into(),
            None,
            memory(
                "长安大学",
                &format!("{}深处的事实", "正文".repeat(1000)),
                "学习",
            ),
        )
        .unwrap();
    let b = store
        .save_memory(
            "default".into(),
            None,
            memory("相邻节点", "关系补充", "学习"),
        )
        .unwrap();
    let outside = store
        .save_memory(
            "default".into(),
            None,
            memory("外部节点", "不会越界", "其他"),
        )
        .unwrap();
    for target in [&b, &outside] {
        store
            .save_memory_link(
                "default".into(),
                None,
                crate::graph::MemoryLinkDraft {
                    source_id: a.clone(),
                    target_id: target.clone(),
                    relation: "related".into(),
                    weight: 1.0,
                    description: String::new(),
                },
            )
            .unwrap();
    }
    let report = store
        .simulate_memory_search(
            "default".into(),
            MemoryQuery {
                folder: "学习".into(),
                ..query("长安大学在西安")
            },
        )
        .unwrap();
    assert_eq!(report.scope_count, 2);
    assert!(report.tokens.iter().any(|t| t == "长安大学" || t == "大学"));
    assert_eq!(report.reverse_matches, 1);
    assert_eq!(report.edges_traversed, 1);
    assert!(
        report
            .candidates
            .iter()
            .any(|r| r.id == b && r.edge_score > 0.0)
    );
    assert!(!report.candidates.iter().any(|r| r.id == outside));
    let report = store
        .simulate_memory_search("default".into(), query("深处*事实"))
        .unwrap();
    assert!(
        report
            .candidates
            .iter()
            .any(|r| r.id == a && r.keyword_score > 0.0)
    );
    let empty = store
        .simulate_memory_search("default".into(), query("事实*深处"))
        .unwrap();
    assert!(empty.candidates.is_empty());
    assert!(
        store
            .simulate_memory_search("default".into(), query("*?*"))
            .unwrap()
            .candidates
            .is_empty()
    );
    store
        .archive_memory("default".into(), a.clone(), true)
        .unwrap();
    assert!(
        !store
            .simulate_memory_search("default".into(), query("大学"))
            .unwrap()
            .candidates
            .iter()
            .any(|r| r.id == a)
    );
}

#[test]
fn weights_change_real_scores_and_reports_are_bounded_without_truncating_scope() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    for i in 0..105 {
        store
            .save_memory(
                "default".into(),
                None,
                memory(&format!("记录{i}"), "共同事实", ""),
            )
            .unwrap();
    }
    let report = store
        .simulate_memory_search("default".into(), query("*"))
        .unwrap();
    assert_eq!(report.scope_count, 105);
    assert_eq!(report.passed_count, 105);
    assert_eq!(report.candidates.len(), 100);
    assert!(report.has_more);
    store
        .save_memory_search_settings(
            "default".into(),
            MemorySearchSettings {
                keyword_weight: 0.0,
                tag_weight: 20.0,
                vector_weight: 1.0,
                edge_weight: 0.0,
                ..Default::default()
            },
        )
        .unwrap();
    let report = store
        .simulate_memory_search("default".into(), query("学习"))
        .unwrap();
    assert!(report.vector_unavailable);
    assert_eq!(report.tag_matches, 105);
    assert!(
        report
            .candidates
            .iter()
            .all(|r| r.keyword_score == 0.0 && r.tag_score > 0.0)
    );
    assert!(
        store
            .simulate_memory_search("default".into(), query("共同事实"))
            .unwrap()
            .candidates
            .is_empty()
    );
}

#[test]
fn schema_three_migration_and_runtime_close_keep_storage_contract() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    let id = store
        .save_memory("default".into(), None, memory("迁移保留", "正文", ""))
        .unwrap();
    store
        .connection
        .lock()
        .unwrap()
        .execute_batch("DROP TABLE memory_search_settings; PRAGMA user_version=3;")
        .unwrap();
    drop(store);
    let store = AppStore::open(&directory.0).unwrap();
    assert_eq!(
        store
            .simulate_memory_search("default".into(), query("迁移"))
            .unwrap()
            .candidates[0]
            .id,
        id
    );
    drop(store);
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    runtime.close();
    assert!(matches!(
        runtime
            .memory_search_settings("default".into())
            .unwrap_err()
            .code,
        ErrorCode::RuntimeClosed
    ));
}
