use super::*;
use serde_json::json;
use std::time::{SystemTime, UNIX_EPOCH};

fn payload(keys: &[(&str, &str, bool)], fallback: &str) -> String {
    json!({"version":3,"apiKey":fallback,"headers":{},"usePool":true,"rotation":"ROUND_ROBIN",
        "keys":keys.iter().enumerate().map(|(i,(key,status,enabled))|json!({"id":i.to_string(),"key":key,"enabled":enabled,"availability":status})).collect::<Vec<_>>()}).to_string()
}
fn directory() -> std::path::PathBuf {
    std::env::temp_dir().join(format!(
        "kiyori-rotation-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ))
}

#[test]
fn rotation_survives_reopen_without_changing_revision_and_rejects_stale_snapshot() {
    let path = directory();
    let p = payload(
        &[
            ("a", "UNTESTED", true),
            ("b", "UNTESTED", true),
            ("c", "UNTESTED", false),
        ],
        "",
    );
    {
        let store = AppStore::open(&path).unwrap();
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .unwrap()
                .api_key,
            "a"
        );
        assert_eq!(store.model_catalog().unwrap().configs[0].revision, 1);
        assert!(
            store
                .prepare_configured_probe("default", 2, &p, "chat")
                .is_err()
        );
    }
    {
        let store = AppStore::open(&path).unwrap();
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .unwrap()
                .api_key,
            "b"
        );
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "system")
                .unwrap()
                .api_key,
            "a"
        );
    }
    std::fs::remove_dir_all(path).unwrap();
}

#[test]
fn marks_filter_candidates_and_never_fallback_from_known_unavailable() {
    let path = directory();
    {
        let store = AppStore::open(&path).unwrap();
        let p = payload(
            &[
                ("a", "UNTESTED", true),
                ("b", "AVAILABLE", true),
                ("c", "UNAVAILABLE", true),
            ],
            "fallback",
        );
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .unwrap()
                .api_key,
            "b"
        );
        let p = payload(
            &[("a", "UNTESTED", true), ("b", "UNAVAILABLE", true)],
            "fallback",
        );
        assert!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .is_err()
        );
        let p = payload(&[("disabled", "UNAVAILABLE", false)], "fallback");
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .unwrap()
                .api_key,
            "fallback"
        );
        assert!(
            store
                .prepare_configured_probe("default", 1, &payload(&[], ""), "chat")
                .is_err()
        );
        let mut random: serde_json::Value = serde_json::from_str(&payload(
            &[("a", "UNTESTED", true), ("b", "UNTESTED", true)],
            "",
        ))
        .unwrap();
        random["rotation"] = json!("RANDOM");
        for _ in 0..20 {
            assert!(
                ["a", "b"].contains(
                    &store
                        .prepare_configured_probe("default", 1, &random.to_string(), "chat")
                        .unwrap()
                        .api_key
                        .as_str()
                )
            );
        }
    }
    std::fs::remove_dir_all(path).unwrap();
}

#[test]
fn independent_connections_serialize_cursor_and_schema_seven_migrates() {
    let path = directory();
    {
        let store = AppStore::open(&path).unwrap();
        store
            .connection
            .lock()
            .unwrap()
            .execute_batch("DROP TABLE conversation_messages; DROP TABLE conversation_runs; DROP TABLE conversation_state; DROP TABLE conversations; DROP TABLE model_key_cursors; PRAGMA user_version=7;")
            .unwrap();
    }
    let p = payload(&[("a", "UNTESTED", true), ("b", "UNTESTED", true)], "");
    let workers: Vec<_> = (0..10)
        .map(|_| {
            let path = path.clone();
            let p = p.clone();
            std::thread::spawn(move || {
                AppStore::open(path)
                    .unwrap()
                    .prepare_configured_probe("default", 1, &p, "chat")
                    .unwrap()
                    .api_key
            })
        })
        .collect();
    let results: Vec<_> = workers.into_iter().map(|w| w.join().unwrap()).collect();
    assert_eq!(results.iter().filter(|k| *k == "a").count(), 5);
    assert_eq!(results.iter().filter(|k| *k == "b").count(), 5);
    std::fs::remove_dir_all(path).unwrap();
}

#[test]
fn invalid_payload_kind_and_removed_config_never_advance_cursor_or_expose_secrets() {
    let path = directory();
    {
        let store = AppStore::open(&path).unwrap();
        let p = payload(&[("a", "UNTESTED", true), ("b", "UNTESTED", true)], "");
        assert!(
            store
                .prepare_configured_probe("default", 1, &p, "unknown")
                .is_err()
        );
        let error = store
            .prepare_configured_probe("default", 1, "private-fixture", "chat")
            .err()
            .unwrap();
        assert!(!error.message.contains("private-fixture"));
        assert_eq!(
            store
                .prepare_configured_probe("default", 1, &p, "chat")
                .unwrap()
                .api_key,
            "a"
        );
        let id = store.create_model_config("removable".into()).unwrap();
        let initial = store
            .model_catalog()
            .unwrap()
            .configs
            .into_iter()
            .find(|c| c.id == id)
            .unwrap();
        let mut draft = initial.draft;
        draft.endpoint = "http://127.0.0.1:8080".into();
        draft.models = vec!["fixture".into()];
        store
            .save_model_config(id.clone(), 1, draft, None, None)
            .unwrap();
        store.prepare_configured_probe(&id, 2, &p, "chat").unwrap();
        store
            .delete_model_config(id.clone(), 2, None, None)
            .unwrap();
        let count: u32 = store
            .connection
            .lock()
            .unwrap()
            .query_row(
                "SELECT count(*) FROM model_key_cursors WHERE config_id=?1",
                [&id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(count, 0);
        assert!(store.prepare_configured_probe(&id, 2, &p, "chat").is_err());
    }
    std::fs::remove_dir_all(path).unwrap();
}
