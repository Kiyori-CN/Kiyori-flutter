use super::*;
use crate::conversation_audit;
use base64::{Engine, engine::general_purpose::STANDARD};

#[test]
fn audit_notes_search_unicode_paging_signature_and_reopen_are_real() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    let first: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(first["status"], "BASIC");
    assert_eq!(first["eventCount"], 1);
    let note = format!("全文😀{}尾部", "界".repeat(9000));
    runtime
        .append_conversation_note(id.clone(), note.clone())
        .unwrap();
    let p0 = runtime
        .conversation_audit_payload(id.clone(), 2, 0)
        .unwrap();
    let p1 = runtime
        .conversation_audit_payload(id.clone(), 2, 1)
        .unwrap();
    let complete: Value = serde_json::from_str(&(p0 + &p1)).unwrap();
    assert_eq!(complete["note"], note);
    for index in 0..101 {
        runtime
            .append_conversation_note(id.clone(), format!("page-note-{index}"))
            .unwrap();
    }
    let page: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(page["events"].as_array().unwrap().len(), 100);
    assert_eq!(page["hasOlder"], true);
    let older: Value = serde_json::from_str(
        &runtime
            .conversation_audit(
                id.clone(),
                page["events"][0]["sequence"].as_i64().unwrap(),
                String::new(),
            )
            .unwrap(),
    )
    .unwrap();
    assert_eq!(older["events"].as_array().unwrap().len(), 3);
    let found: Value = serde_json::from_str(
        &runtime
            .conversation_audit(id.clone(), 0, "全文 尾部".into())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(found["events"].as_array().unwrap().len(), 1);
    assert!(
        runtime
            .conversation_audit(id.clone(), -1, String::new())
            .is_err()
    );
    assert!(
        runtime
            .append_conversation_note(id.clone(), " ".into())
            .is_err()
    );
    let bytes = runtime
        .export_conversation_audit(id.clone(), "zip".into())
        .unwrap();
    let mut zip = zip::ZipArchive::new(std::io::Cursor::new(bytes)).unwrap();
    let mut contents = std::collections::BTreeMap::new();
    for index in 0..zip.len() {
        let mut entry = zip.by_index(index).unwrap();
        let name = entry.name().to_owned();
        let mut bytes = Vec::new();
        entry.read_to_end(&mut bytes).unwrap();
        contents.insert(name, bytes);
    }
    assert_eq!(contents.len(), 4);
    let seal: Value = serde_json::from_slice(&contents["seal.json"]).unwrap();
    assert_eq!(
        seal["eventsSha256"],
        conversation_audit::hash(&contents["events.json"])
    );
    assert_eq!(
        seal["messagesSha256"],
        conversation_audit::hash(&contents["messages.json"])
    );
    let signature: Value = serde_json::from_slice(&contents["signature.json"]).unwrap();
    let key = STANDARD
        .decode(signature["publicKey"].as_str().unwrap())
        .unwrap();
    let sig = STANDARD
        .decode(signature["signature"].as_str().unwrap())
        .unwrap();
    ring::signature::UnparsedPublicKey::new(&ring::signature::ED25519, key)
        .verify(&contents["seal.json"], &sig)
        .unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    let again: Value = serde_json::from_str(
        &reopened
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(again["chainHead"], page["chainHead"]);
    reopened.with_store(|store|{let c=store.connection.lock().unwrap();assert!(c.execute("UPDATE conversation_audit_events SET summary='tamper' WHERE sequence=1",[]).is_err());c.execute_batch("DROP TRIGGER conversation_audit_no_update;UPDATE conversation_audit_events SET summary='tamper' WHERE sequence=1;").unwrap();Ok(())}).unwrap();
    assert!(
        reopened
            .export_conversation_audit(id, "zip".into())
            .is_err()
    );
    reopened.close();
}

#[test]
fn audit_message_revisions_do_not_change_usage_and_migration_preserves_messages() {
    let dir = Directory::new();
    let r = Runtime::with_data_dir(&dir.0).unwrap();
    let id = r.create_conversation().unwrap();
    r.with_store(|s|{let c=s.connection.lock().unwrap();c.execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state) VALUES('note',?1,0,'user','原始消息','completed')",[&id]).unwrap();Ok(())}).unwrap();
    let item = r.conversation(id.clone()).unwrap().conversation;
    r.change_message(
        id.clone(),
        item.revision,
        "note".into(),
        "edit".into(),
        "修改消息".into(),
    )
    .unwrap();
    let markdown = String::from_utf8(
        r.export_conversation_audit(id.clone(), "markdown".into())
            .unwrap(),
    )
    .unwrap();
    assert!(markdown.contains("原始消息"));
    assert!(markdown.contains("修改消息"));
    assert_eq!(r.conversation_statistics(id.clone()).unwrap().requests, 0);
    r.with_store(|s| {
        let c = s.connection.lock().unwrap();
        conversation_audit::remove_schema_for_fixture(&c);
        c.execute_batch("PRAGMA user_version=19").unwrap();
        Ok(())
    })
    .unwrap();
    r.close();
    let upgraded = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        upgraded.conversation(id.clone()).unwrap().messages[0].content,
        "修改消息"
    );
    assert_eq!(
        serde_json::from_str::<Value>(&upgraded.conversation_audit(id, 0, String::new()).unwrap())
            .unwrap()["status"],
        "BASIC"
    );
    upgraded.close();
}

#[test]
fn deletion_stays_in_binding_and_inherits_folder_but_group_delete_does_not() {
    let dir = Directory::new();
    let r = Runtime::with_data_dir(&dir.0).unwrap();
    let a = r.create_conversation().unwrap();
    let default = r.prompt_catalog().unwrap().characters.remove(0);
    let mut draft = default.draft;
    draft.name = "另一个角色".into();
    let role = r.save_character(None, None, draft).unwrap();
    r.activate_prompt("character".into(), role).unwrap();
    let unrelated = r.create_conversation().unwrap();
    r.select_conversation(a.clone()).unwrap();
    r.change_chat_preference(
        r.chat_preferences().unwrap().revision,
        "create_folder".into(),
        "保留分组".into(),
    )
    .unwrap();
    let a_item = r.conversation(a.clone()).unwrap().conversation;
    r.change_conversation(
        a.clone(),
        a_item.revision,
        "folder".into(),
        "保留分组".into(),
    )
    .unwrap();
    let a_item = r.conversation(a.clone()).unwrap().conversation;
    r.change_conversation(a, a_item.revision, "delete".into(), String::new())
        .unwrap();
    let next = r.conversation_catalog().unwrap().active_id.unwrap();
    assert_ne!(next, unrelated);
    let replacement = r.conversation(next).unwrap().conversation;
    assert_eq!(replacement.character_id, crate::prompts::DEFAULT_CHARACTER);
    assert_eq!(replacement.folder, "保留分组");
    r.close();
}
