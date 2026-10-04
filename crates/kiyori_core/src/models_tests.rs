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
fn model_names_delete_and_undo_restore_order_and_bindings_atomically() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    let initial = config(&store, "default");
    let first = initial.draft.models[0].clone();
    let mut draft = initial.draft;
    draft.models.push("replacement".into());
    store
        .save_model_config("default".into(), initial.revision, draft, None, None)
        .unwrap();
    let current = config(&store, "default");
    assert!(
        store
            .change_model_names("default".into(), current.revision, vec![], None)
            .is_err()
    );
    assert_eq!(config(&store, "default"), current);
    let undo = store
        .change_model_names(
            "default".into(),
            current.revision,
            vec!["replacement".into()],
            Some("replacement".into()),
        )
        .unwrap();
    assert!(
        store
            .model_catalog()
            .unwrap()
            .functions
            .iter()
            .all(|f| f.model_name == "replacement")
    );
    store.undo_model_names(undo).unwrap();
    assert_eq!(
        config(&store, "default").draft.models,
        vec![first.clone(), "replacement".into()]
    );
    assert!(
        store
            .model_catalog()
            .unwrap()
            .functions
            .iter()
            .all(|f| f.model_name == first)
    );
}

#[test]
fn model_names_undo_rejects_later_function_edits_without_partial_changes() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    let initial = config(&store, "default");
    let mut draft = initial.draft;
    draft.models.extend(["replacement".into(), "third".into()]);
    store
        .save_model_config("default".into(), initial.revision, draft, None, None)
        .unwrap();
    let current = config(&store, "default");
    let undo = store
        .change_model_names(
            "default".into(),
            current.revision,
            vec!["replacement".into(), "third".into()],
            Some("replacement".into()),
        )
        .unwrap();
    store
        .select_function_model("chat".into(), "default".into(), "third".into())
        .unwrap();
    let before = store.model_catalog().unwrap();
    assert!(store.undo_model_names(undo).is_err());
    assert_eq!(store.model_catalog().unwrap(), before);
}

#[test]
fn model_names_undo_checks_character_revision_and_preserves_later_edits() {
    let directory = Directory::new();
    let store = AppStore::open(&directory.0).unwrap();
    let mut initial = config(&store, "default");
    let first = initial.draft.models[0].clone();
    initial.draft.models.push("replacement".into());
    store
        .save_model_config(
            "default".into(),
            initial.revision,
            initial.draft,
            None,
            None,
        )
        .unwrap();
    let id = store
        .save_character(
            None,
            None,
            CharacterDraft {
                name: "bound".into(),
                model_config: Some("default".into()),
                model_name: Some(first.clone()),
                ..Default::default()
            },
        )
        .unwrap();
    let undo = store
        .change_model_names(
            "default".into(),
            2,
            vec!["replacement".into()],
            Some("replacement".into()),
        )
        .unwrap();
    let character = store
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    assert_eq!(character.draft.model_name.as_deref(), Some("replacement"));
    store.undo_model_names(undo).unwrap();
    let character = store
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    assert_eq!(character.draft.model_name.as_ref(), Some(&first));
    let undo = store
        .change_model_names(
            "default".into(),
            4,
            vec!["replacement".into()],
            Some("replacement".into()),
        )
        .unwrap();
    let mut character = store
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    character.draft.description = "later change".into();
    store
        .save_character(Some(id.clone()), Some(character.revision), character.draft)
        .unwrap();
    let before = store.model_catalog().unwrap();
    assert!(store.undo_model_names(undo).is_err());
    assert_eq!(store.model_catalog().unwrap(), before);
    let character = store
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    assert_eq!(character.draft.description, "later change");
}

fn context_options(config: &ModelConfig) -> crate::context::ContextOptions {
    let o = &config.draft.options;
    crate::context::ContextOptions {
        context_length: o.context_length,
        max_context_length: o.max_context_length,
        summary_enabled: o.summary_enabled,
        summary_threshold: o.summary_threshold,
        summary_by_count: o.summary_by_count,
        summary_count: o.summary_count,
        summary_rules: o.summary_rules.clone(),
    }
}

#[test]
fn context_settings_preserve_other_options_and_global_media_across_chat_binding() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let initial = store.context_settings().unwrap();
    assert_eq!(
        (initial.history.image_turns, initial.history.media_turns),
        (2, 1)
    );
    let mut options = context_options(&initial.config);
    options.context_length = 80.;
    options.summary_rules = "完整保留中文规则".into();
    let mut history = initial.history.clone();
    history.image_turns = 0;
    history.media_turns = 5;
    let saved = store
        .save_context_settings(
            initial.config.id.clone(),
            initial.config.revision,
            options.clone(),
            history,
        )
        .unwrap();
    assert_eq!(saved.config.revision, initial.config.revision + 1);
    assert_eq!(
        saved.config.draft.options.parameters,
        initial.config.draft.options.parameters
    );
    assert_eq!(
        saved.config.secret_reference,
        initial.config.secret_reference
    );
    assert!(
        store
            .save_context_settings(
                initial.config.id.clone(),
                initial.config.revision,
                options.clone(),
                initial.history
            )
            .is_err()
    );
    let other = store.create_model_config("第二个".into()).unwrap();
    let other_config = config(&store, &other);
    let mut draft = other_config.draft;
    draft.models = vec!["local-fixture".into()];
    store
        .save_model_config(other.clone(), other_config.revision, draft, None, None)
        .unwrap();
    store
        .select_function_model("chat".into(), other.clone(), "local-fixture".into())
        .unwrap();
    assert!(
        store
            .save_context_settings(
                saved.config.id,
                saved.config.revision,
                options,
                saved.history.clone()
            )
            .is_err()
    );
    let rebound = store.context_settings().unwrap();
    assert_eq!(rebound.config.id, other);
    assert_eq!(rebound.history, saved.history);
    let reset = crate::context::HistoryRetention {
        revision: rebound.history.revision,
        image_turns: 2,
        media_turns: 1,
    };
    let reset = store
        .save_context_settings(
            other,
            rebound.config.revision,
            context_options(&rebound.config),
            reset,
        )
        .unwrap();
    assert_eq!(reset.config, rebound.config);
    drop(store);
    assert_eq!(
        AppStore::open(&dir.0).unwrap().context_settings().unwrap(),
        reset
    );
}

#[test]
fn context_invalid_options_roll_back_media_and_schema_six_migrates() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let initial = store.context_settings().unwrap();
    let mut options = context_options(&initial.config);
    options.context_length = f64::NAN;
    let mut history = initial.history.clone();
    history.image_turns = 99;
    assert!(
        store
            .save_context_settings(
                initial.config.id.clone(),
                initial.config.revision,
                options,
                history
            )
            .is_err()
    );
    assert_eq!(store.context_settings().unwrap(), initial);
    crate::downloads::remove_schema_for_fixture(&store.connection.lock().unwrap());
    store
        .connection
        .lock()
        .unwrap()
        .execute_batch("DROP TABLE conversation_variants; DROP TABLE chat_preferences; DROP TABLE conversation_folders; DROP TABLE conversation_messages; DROP TABLE conversation_runs; DROP TABLE conversation_state; DROP TABLE conversations; DROP TABLE history_retention; PRAGMA user_version=6;")
        .unwrap();
    drop(store);
    let reopened = AppStore::open(&dir.0).unwrap();
    assert_eq!(reopened.context_settings().unwrap(), initial);
}

#[test]
fn secret_lease_child_process() {
    let Some(path) = std::env::var_os("KIYORI_SECRET_LEASE_TEST_DIR") else {
        return;
    };
    let store = AppStore::open(PathBuf::from(path)).unwrap();
    let lease = store.begin_model_secrets().unwrap();
    let reference = store
        .reserve_model_secret("default".into(), 1, &lease)
        .unwrap();
    std::fs::write(store.directory.join("child-ready"), reference).unwrap();
    // 父测试终止这个专用子进程，验证真实OS锁在异常退出后释放。
    loop {
        std::thread::park_timeout(std::time::Duration::from_secs(1));
    }
}

#[test]
fn crashed_writer_is_recovered_only_after_its_process_releases_the_lock() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let mut child = std::process::Command::new(std::env::current_exe().unwrap())
        .args([
            "--exact",
            "models::tests::secret_lease_child_process",
            "--nocapture",
        ])
        .env("KIYORI_SECRET_LEASE_TEST_DIR", &dir.0)
        .stdout(std::process::Stdio::null())
        .spawn()
        .unwrap();
    let ready = dir.0.join("child-ready");
    for _ in 0..200 {
        if ready.exists() {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }
    if !ready.exists() {
        child.kill().unwrap();
        child.wait().unwrap();
        panic!("Child did not acquire its secret lease");
    }
    let reference = std::fs::read_to_string(ready).unwrap();
    assert!(store.begin_model_secrets().is_err());
    assert!(store.retired_model_secrets().unwrap().is_empty());
    child.kill().unwrap();
    child.wait().unwrap();
    let recovery = store.begin_model_secrets().unwrap();
    assert_eq!(store.retired_model_secrets().unwrap(), vec![reference]);
    assert!(store.begin_model_secrets().is_err());
    recovery.close();
    assert!(
        store
            .reserve_model_secret("default".into(), 1, &recovery)
            .is_err()
    );
    let next = store.begin_model_secrets().unwrap();
    let other_dir = Directory::new();
    let other_store = AppStore::open(&other_dir.0).unwrap();
    assert!(
        other_store
            .reserve_model_secret("default".into(), 1, &next)
            .is_err()
    );
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
    let lease = store.begin_model_secrets().unwrap();
    let first = store
        .reserve_model_secret("default".into(), 1, &lease)
        .unwrap();
    let stale = other
        .reserve_model_secret("default".into(), 1, &lease)
        .unwrap();
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
