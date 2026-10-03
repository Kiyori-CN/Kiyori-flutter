use super::*;
use crate::prompts::CharacterDraft;
use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        Self(std::env::temp_dir().join(format!(
                "kiyori-models-{}-{}",
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
fn config(store: &AppStore, id: &str) -> ModelConfig {
    store
        .model_catalog()
        .unwrap()
        .configs
        .into_iter()
        .find(|c| c.id == id)
        .unwrap()
}

#[test]
fn model_reorder_preserves_bindings_and_removal_requires_explicit_replacement() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let id = store.create_model_config("测试".into()).unwrap();
    let mut draft = config(&store, &id).draft;
    draft.models = vec!["a".into(), "b".into()];
    store
        .save_model_config(id.clone(), 1, draft.clone(), None, None)
        .unwrap();
    store
        .select_function_model("chat".into(), id.clone(), "a".into())
        .unwrap();
    store.reset_function_models().unwrap();
    assert!(
        store
            .model_catalog()
            .unwrap()
            .functions
            .iter()
            .all(|f| f.config_id == "default")
    );
    store
        .select_function_model("chat".into(), id.clone(), "a".into())
        .unwrap();
    let character = store
        .save_character(
            None,
            None,
            CharacterDraft {
                name: "角色".into(),
                model_config: Some(id.clone()),
                model_name: Some("a".into()),
                ..Default::default()
            },
        )
        .unwrap();
    draft.models.reverse();
    store
        .save_model_config(id.clone(), 2, draft.clone(), None, None)
        .unwrap();
    assert_eq!(
        store
            .model_catalog()
            .unwrap()
            .functions
            .iter()
            .find(|f| f.function == "chat")
            .unwrap()
            .model_name,
        "a"
    );
    draft.models = vec!["b".into()];
    assert!(
        store
            .save_model_config(id.clone(), 3, draft.clone(), None, None)
            .is_err()
    );
    assert_eq!(config(&store, &id).revision, 3);
    store
        .save_model_config(id.clone(), 3, draft, None, Some("b".into()))
        .unwrap();
    let card = store
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == character)
        .unwrap();
    assert_eq!(card.draft.model_name.as_deref(), Some("b"));
    assert_eq!(card.revision, 2);
    assert!(
        store
            .delete_model_config(id.clone(), 4, None, None)
            .is_err()
    );
    store
        .delete_model_config(
            id.clone(),
            4,
            Some("default".into()),
            Some("deepseek-v4-flash".into()),
        )
        .unwrap();
    assert!(
        store
            .model_catalog()
            .unwrap()
            .configs
            .iter()
            .all(|c| c.id != id)
    );
    assert!(
        store
            .delete_model_config("default".into(), 1, None, None)
            .is_err()
    );
}

#[test]
fn immutable_secret_references_survive_conflicts_and_retirement_cannot_delete_active() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let other = AppStore::open(&dir.0).unwrap();
    let draft = config(&store, "default").draft;
    let first = store.reserve_model_secret("default".into(), 1).unwrap();
    let stale = other.reserve_model_secret("default".into(), 1).unwrap();
    store
        .save_model_config(
            "default".into(),
            1,
            draft.clone(),
            Some(first.clone()),
            None,
        )
        .unwrap();
    assert!(other.retire_model_secret(first.clone()).is_err());
    assert!(
        other
            .save_model_config(
                "default".into(),
                1,
                draft.clone(),
                Some(stale.clone()),
                None
            )
            .is_err()
    );
    other.retire_model_secret(stale.clone()).unwrap();
    assert_eq!(store.retired_model_secrets().unwrap(), vec![stale.clone()]);
    assert!(
        store
            .save_model_config(
                "default".into(),
                2,
                draft.clone(),
                Some(stale.clone()),
                None
            )
            .is_err()
    );
    store.forget_retired_model_secret(first.clone()).unwrap();
    assert_eq!(
        config(&store, "default").secret_reference,
        Some(first.clone())
    );
    store
        .save_model_config("default".into(), 2, draft, None, None)
        .unwrap();
    assert!(store.retired_model_secrets().unwrap().contains(&first));
    store.forget_retired_model_secret(stale).unwrap();
    assert_eq!(store.retired_model_secrets().unwrap(), vec![first]);
}

#[test]
fn invalid_endpoints_numeric_values_and_missing_bindings_do_not_change_storage() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let before = config(&store, "default");
    for endpoint in [
        "https://user:secret@host/v1",
        "https://host/v1?key=value",
        "https://host/#secret",
        "file:///tmp",
        "https://",
        "https://ho st",
        "https://host\\evil",
    ] {
        let mut draft = before.draft.clone();
        draft.endpoint = endpoint.into();
        assert!(
            store
                .save_model_config("default".into(), 1, draft, None, None)
                .is_err()
        );
    }
    let mut draft = before.draft.clone();
    draft.options.context_length = f64::NAN;
    assert!(
        store
            .save_model_config("default".into(), 1, draft, None, None)
            .is_err()
    );
    assert!(
        store
            .save_character(
                None,
                None,
                CharacterDraft {
                    name: "角色".into(),
                    model_config: Some("missing".into()),
                    model_name: Some("model".into()),
                    ..Default::default()
                }
            )
            .is_err()
    );
    assert_eq!(before, config(&store, "default"));
}

#[test]
fn schema_five_migration_keeps_legacy_unresolved_bindings_and_reopen_defaults() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    store.create("保留工作流".into(), "正文".into()).unwrap();
    {
        let connection = store.connection.lock().unwrap();
        remove_schema_six_for_fixture(&connection);
        connection.execute_batch("UPDATE prompt_characters SET model_config='legacy',model_name='unresolved'; PRAGMA user_version=5;").unwrap();
    }
    drop(store);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(runtime.model_catalog().unwrap().functions.len(), 11);
    let card = runtime.prompt_catalog().unwrap().characters.remove(0);
    assert_eq!(card.draft.model_config.as_deref(), Some("legacy"));
    assert!(
        runtime
            .save_character(Some(card.id), Some(card.revision), card.draft)
            .is_err()
    );
    runtime.close();
    assert_eq!(
        runtime.model_catalog().unwrap_err().code,
        ErrorCode::RuntimeClosed
    );
    let store = AppStore::open(&dir.0).unwrap();
    assert_eq!(store.list().unwrap().len(), 1);
    assert_eq!(store.model_catalog().unwrap().configs.len(), 1);
}
