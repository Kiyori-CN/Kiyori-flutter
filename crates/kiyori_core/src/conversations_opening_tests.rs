use super::*;

fn card(runtime: &Runtime, opening: &str) -> String {
    let source = runtime.prompt_catalog().unwrap().characters.remove(0);
    let mut draft = source.draft;
    draft.name = "开场角色".into();
    draft.opening = opening.into();
    let id = runtime.save_character(None, None, draft).unwrap();
    runtime
        .activate_prompt("character".into(), id.clone())
        .unwrap();
    id
}
fn update(runtime: &Runtime, id: &str, text: &str, name: &str) {
    let source = runtime
        .prompt_catalog()
        .unwrap()
        .characters
        .into_iter()
        .find(|c| c.id == id)
        .unwrap();
    let mut draft = source.draft;
    draft.opening = text.into();
    draft.name = name.into();
    runtime
        .save_character(Some(id.into()), Some(source.revision), draft)
        .unwrap();
}

#[test]
fn opening_creation_sync_is_idempotent_and_preserves_timestamp_without_run_usage() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let role = card(&runtime, "  初始开场  ");
    let id = runtime.create_conversation().unwrap();
    let first = runtime.conversation(id.clone()).unwrap();
    assert_eq!(first.conversation.revision, 1);
    assert_eq!(first.conversation.message_count, 1);
    let message = &first.messages[0];
    assert_eq!(message.content, "  初始开场  ");
    assert_eq!(message.role_name.as_deref(), Some("开场角色"));
    assert!(message.run_id.is_empty() && message.model.is_empty());
    assert_eq!(message.sent_at, None);
    assert!(message.created_at.is_some_and(|v| v > 0));
    assert_eq!(message.input_tokens, None);
    let created = runtime
        .with_store(|s| {
            let c = s.connection.lock().unwrap();
            Ok(c.query_row(
                "SELECT created_at FROM conversation_message_metadata WHERE message_id=?1",
                [&message.id],
                |r| r.get::<_, i64>(0),
            )
            .unwrap())
        })
        .unwrap();
    assert!(created > 0);
    assert_eq!(
        runtime
            .conversation_statistics(id.clone())
            .unwrap()
            .requests,
        0
    );
    for _ in 0..3 {
        runtime.select_conversation(id.clone()).unwrap();
        assert_eq!(runtime.conversation(id.clone()).unwrap(), first);
    }
    update(&runtime, &role, "新的开场", "新角色名");
    let next = runtime.conversation(id.clone()).unwrap();
    assert_eq!(next.conversation.revision, 2);
    assert_eq!(next.messages[0].id, message.id);
    assert_eq!(next.messages[0].role_name.as_deref(), Some("新角色名"));
    assert_eq!(next.messages[0].content, "新的开场");
    runtime
        .with_store(|s| {
            let c = s.connection.lock().unwrap();
            assert_eq!(
                c.query_row(
                    "SELECT created_at FROM conversation_message_metadata WHERE message_id=?1",
                    [&message.id],
                    |r| r.get::<_, i64>(0)
                )
                .unwrap(),
                created
            );
            assert_eq!(
                c.query_row(
                    "SELECT count(*) FROM conversation_runs WHERE conversation_id=?1",
                    [&id],
                    |r| r.get::<_, i64>(0)
                )
                .unwrap(),
                0
            );
            Ok(())
        })
        .unwrap();
    update(&runtime, &role, " \n\t ", "新角色名");
    assert!(
        runtime
            .conversation(id.clone())
            .unwrap()
            .messages
            .is_empty()
    );
    assert!(
        String::from_utf8(
            runtime
                .export_conversation_audit(id.clone(), "markdown".into())
                .unwrap()
        )
        .unwrap()
        .contains("初始开场")
    );
    update(&runtime, &role, "恢复开场", "新角色名");
    let restored = runtime.conversation(id.clone()).unwrap();
    assert_ne!(restored.messages[0].id, message.id);
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(reopened.conversation(id).unwrap(), restored);
    reopened.close();
}

#[test]
fn opening_bound_card_wins_and_inactive_chat_waits_for_selection() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let p = runtime.chat_preferences().unwrap();
    runtime
        .change_chat_preference(p.revision, "auto_character".into(), "false".into())
        .unwrap();
    let bound = card(&runtime, "绑定开场");
    let id = runtime.create_conversation().unwrap();
    let first = runtime.conversation(id.clone()).unwrap();
    let other = card(&runtime, "另一开场");
    let other_chat = runtime.create_conversation().unwrap();
    update(&runtime, &bound, "绑定更新", "绑定名字");
    let inactive = runtime.conversation(id.clone()).unwrap();
    assert_eq!(inactive.messages, first.messages);
    assert_eq!(inactive.conversation.revision, first.conversation.revision);
    runtime.select_conversation(id.clone()).unwrap();
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().messages[0].content,
        "绑定更新"
    );
    assert_eq!(
        runtime
            .prompt_catalog()
            .unwrap()
            .active_character
            .as_deref(),
        Some(other.as_str())
    );
    runtime
        .with_store(|s| {
            s.connection
                .lock()
                .unwrap()
                .execute(
                    "UPDATE conversations SET character_id='removed-role' WHERE id=?1",
                    [&id],
                )
                .unwrap();
            Ok(())
        })
        .unwrap();
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().messages[0].content,
        "另一开场"
    );
    assert_eq!(
        runtime.conversation(other_chat).unwrap().messages[0].content,
        "另一开场"
    );
    runtime.close();
}

#[test]
fn opening_same_name_and_content_role_switch_refreshes_origin_only() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let first_role = card(&runtime, "相同开场");
    let id = runtime.create_conversation().unwrap();
    let first = runtime.conversation(id.clone()).unwrap();
    let next_role = card(&runtime, "相同开场");
    assert_ne!(first_role, next_role);
    runtime
        .with_store(|s| {
            s.connection
                .lock()
                .unwrap()
                .execute(
                    "UPDATE conversations SET character_id=?2 WHERE id=?1",
                    params![id, next_role],
                )
                .unwrap();
            Ok(())
        })
        .unwrap();
    let next = runtime.conversation(id.clone()).unwrap();
    assert_eq!(next.messages, first.messages);
    assert_eq!(next.conversation.revision, first.conversation.revision + 1);
    runtime
        .with_store(|s| {
            let c = s.connection.lock().unwrap();
            assert_eq!(
                c.query_row(
                    "SELECT role_id FROM conversation_message_metadata WHERE message_id=?1",
                    [&first.messages[0].id],
                    |r| r.get::<_, String>(0)
                )
                .unwrap(),
                next_role
            );
            Ok(())
        })
        .unwrap();
    assert_eq!(runtime.conversation(id).unwrap(), next);
    runtime.close();
}

#[test]
fn opening_group_and_generated_assistant_are_never_replaced() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let role = card(&runtime, "角色开场");
    let group = runtime
        .save_prompt_group(
            None,
            None,
            crate::prompts::GroupDraft {
                name: "群聊".into(),
                description: String::new(),
                members: vec![role.clone()],
            },
        )
        .unwrap();
    let p = runtime.chat_preferences().unwrap();
    runtime
        .change_chat_preference(p.revision, "history_create".into(), group)
        .unwrap();
    let group_chat = runtime.conversation_catalog().unwrap().active_id.unwrap();
    assert!(
        runtime
            .conversation(group_chat)
            .unwrap()
            .messages
            .is_empty()
    );
    runtime.activate_prompt("character".into(), role).unwrap();
    let id = runtime.create_conversation().unwrap();
    runtime.with_store(|s| {
        let c = s.connection.lock().unwrap();
        c.execute("DELETE FROM conversation_messages WHERE conversation_id=?1", [&id]).unwrap();
        c.execute("INSERT INTO conversation_runs(id,conversation_id,state,config_id,config_revision,model,created_at) VALUES('real',?1,'completed','default',1,'real-model',123)", [&id]).unwrap();
        c.execute("INSERT INTO conversation_messages(id,conversation_id,run_id,position,role,content,state) VALUES('real-answer',?1,'real',0,'assistant','模型回复','completed')", [&id]).unwrap();
        Ok(())
    }).unwrap();
    let before = runtime.conversation(id.clone()).unwrap();
    runtime.select_conversation(id.clone()).unwrap();
    assert_eq!(runtime.conversation(id).unwrap(), before);
    runtime.close();
}

#[tokio::test]
async fn opening_first_user_send_titles_context_and_branch_keep_exact_origin() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let role = card(&runtime, "真实开场");
    let (endpoint, worker) = fixture(1, response("模型答复", "stop"));
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    let opening = runtime.conversation(id.clone()).unwrap().messages[0].clone();
    let run = runtime
        .start_conversation_with_summary(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "第一条用户消息".into(),
            payload(),
            None,
            None,
            None,
            Some(opening.id.clone()),
        )
        .unwrap();
    drain(&run).await;
    let requests = worker.join().unwrap();
    assert_eq!(requests[0]["messages"][1]["content"], "真实开场");
    assert!(
        requests[0]["messages"][2]["content"]
            .as_str()
            .unwrap()
            .contains("sender=\"开场角色\"")
    );
    let before = runtime.conversation(id.clone()).unwrap();
    assert_eq!(before.conversation.title, "第一条用户消息");
    assert_eq!(before.messages.len(), 3);
    update(&runtime, &role, "后来开场", "后来角色");
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().messages,
        before.messages
    );
    runtime
        .change_message(
            id.clone(),
            before.conversation.revision,
            before.messages[1].id.clone(),
            "branch".into(),
            String::new(),
        )
        .unwrap();
    let branch = runtime.conversation_catalog().unwrap().active_id.unwrap();
    let snapshot = runtime.conversation(branch).unwrap();
    assert_eq!(snapshot.messages[0].content, "真实开场");
    assert_eq!(snapshot.messages[0].role_name.as_deref(), Some("开场角色"));
    assert_eq!(runtime.conversation_statistics(id).unwrap().requests, 1);
    runtime.close();
}

#[test]
fn opening_schema22_migration_preserves_unknown_time_and_original_audit_hashes() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = runtime.create_conversation().unwrap();
    runtime.with_store(|s| {
        let mut c = s.connection.lock().unwrap();
        let tx = c.transaction().unwrap();
        tx.execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state) VALUES('old-opening',?1,0,'assistant','旧开场','completed')", [&id]).unwrap();
        tx.execute("UPDATE conversations SET character_id='' WHERE id=?1", [&id]).unwrap();
        crate::conversation_audit::initialize(&tx, &id).unwrap();
        tx.execute_batch("DROP TABLE conversation_message_metadata; PRAGMA user_version=22;").unwrap();
        tx.commit().unwrap();
        Ok(())
    }).unwrap();
    runtime.close();
    let c = Connection::open(dir.0.join("kiyori.sqlite3")).unwrap();
    let hash: String = c.query_row("SELECT event_hash FROM conversation_audit_events WHERE conversation_id=?1 AND sequence=1", [&id], |r| r.get(0)).unwrap();
    drop(c);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    card(&runtime, "迁移后开场");
    let snapshot = runtime.conversation(id.clone()).unwrap();
    assert_eq!(snapshot.messages[0].id, "old-opening");
    assert_eq!(snapshot.messages[0].content, "迁移后开场");
    assert_eq!(snapshot.messages[0].sent_at, None);
    assert_eq!(snapshot.messages[0].created_at, None);
    runtime.with_store(|s| {
        let c = s.connection.lock().unwrap();
        assert_eq!(c.pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0)).unwrap(), 23);
        assert_eq!(c.query_row("SELECT event_hash FROM conversation_audit_events WHERE conversation_id=?1 AND sequence=1", [&id], |r| r.get::<_, String>(0)).unwrap(), hash);
        assert_eq!(c.query_row("SELECT created_at FROM conversation_message_metadata WHERE message_id='old-opening'", [], |r| r.get::<_, Option<i64>>(0)).unwrap(), None);
        Ok(())
    }).unwrap();
    assert!(
        String::from_utf8(
            runtime
                .export_conversation_audit(id, "markdown".into())
                .unwrap()
        )
        .unwrap()
        .contains("旧开场")
    );
    runtime.close();
}

#[test]
fn opening_failed_audit_rolls_back_selection_and_message_change() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let role = card(&runtime, "原开场");
    let id = runtime.create_conversation().unwrap();
    let other = runtime.create_conversation().unwrap();
    update(&runtime, &role, "新开场", "新名字");
    runtime.with_store(|s| {
        s.connection.lock().unwrap().execute_batch("CREATE TRIGGER fail_opening BEFORE INSERT ON conversation_audit_events WHEN NEW.event_type='OPENING_SYNCHRONIZED' BEGIN SELECT RAISE(ABORT,'fixture failure'); END;").unwrap();
        Ok(())
    }).unwrap();
    assert!(runtime.select_conversation(id.clone()).is_err());
    runtime
        .with_store(|s| {
            let c = s.connection.lock().unwrap();
            assert_eq!(
                c.query_row(
                    "SELECT active_id FROM conversation_state WHERE id=1",
                    [],
                    |r| r.get::<_, String>(0)
                )
                .unwrap(),
                other
            );
            assert_eq!(
                c.query_row(
                    "SELECT content FROM conversation_messages WHERE conversation_id=?1",
                    [&id],
                    |r| r.get::<_, String>(0)
                )
                .unwrap(),
                "原开场"
            );
            c.execute_batch("DROP TRIGGER fail_opening").unwrap();
            Ok(())
        })
        .unwrap();
    runtime.select_conversation(id.clone()).unwrap();
    assert_eq!(
        runtime.conversation(id).unwrap().messages[0].content,
        "新开场"
    );
    runtime.close();
}
