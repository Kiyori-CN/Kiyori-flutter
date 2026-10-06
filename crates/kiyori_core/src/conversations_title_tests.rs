use super::*;

#[test]
fn title_prompt_and_cleaning_follow_legacy_data_caps_and_metadata_order() {
    assert_eq!(
        title::sanitize(
            "<THINK>不要显示</THINK>\n### “目的标题。”<meta x=\"y\">协议</meta>\n第二行"
        ),
        "目的标题"
    );
    assert_eq!(title::sanitize("<thinking>未闭合"), "");
    assert_eq!(
        title::sanitize("<search x='y'>来源</search> **标题**"),
        "标题"
    );
    assert_eq!(title::sanitize(&"界".repeat(100)), "界".repeat(40));
    assert_eq!(title::sanitize("<think>隐藏</thinking>标题"), "标题");
    assert_eq!(title::sanitize("<thinking>隐藏</think>标题"), "标题");
    assert_eq!(title::sanitize("<meta-flag>隐藏</meta>标题"), "标题");
    assert_eq!(
        title::sanitize("<meta>外<meta>内</meta>剩</meta>标题"),
        "<meta>外剩</meta>标题"
    );
    assert_eq!(
        title::sanitize("<searching>保留</searching>"),
        "<searching>保留</searching>"
    );
    assert_eq!(
        title::sanitize(&format!("{}🧭尾", "界".repeat(39))),
        format!("{}�", "界".repeat(39))
    );
    let messages = title::prompts(" 用户\n\t 原始输入 ");
    assert_eq!(messages.len(), 2);
    assert!(messages[0].content.contains("待总结的数据"));
    assert!(messages[1].content.contains("用户 原始输入"));
    assert!(messages[1].content.contains("附件文件名：\n无"));
    assert!(
        !title::prompts(&"界".repeat(1201))[1]
            .content
            .contains(&"界".repeat(1201))
    );
}

#[tokio::test]
async fn title_generation_is_independent_nonstream_and_audits_actual_usage() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, worker) = fixture(1, response("聊天回复", "stop"));
    configure(&runtime, endpoint);
    runtime
        .select_function_model(
            "titleGeneration".into(),
            "default".into(),
            "chosen-model".into(),
        )
        .unwrap();
    let id = runtime.create_conversation().unwrap();
    let chat = runtime
        .start_conversation(
            runtime.prepare_conversation(id.clone()).unwrap(),
            "请写旅行计划".into(),
            payload(),
        )
        .unwrap();
    drain(&chat).await;
    assert_eq!(
        runtime.conversation(id.clone()).unwrap().conversation.title,
        "新对话"
    );
    let chat_requests = worker.join().unwrap();
    let (endpoint, worker) = fixture(1, json!({"choices":[{"index":0,"message":{"role":"assistant","content":"<think>隐藏</think>\n# “写旅行计划。”<meta>ignore</meta>"},"finish_reason":"stop"}],"usage":{"prompt_tokens":12,"completion_tokens":4,"total_tokens":16}}).to_string());
    let mut config = runtime.model_catalog().unwrap().configs.remove(0);
    config.draft.endpoint = endpoint;
    runtime
        .save_model_config(config.id, config.revision, config.draft, None, None)
        .unwrap();
    let run = runtime
        .start_conversation_title(
            runtime
                .prepare_conversation_title(id.clone())
                .unwrap()
                .unwrap(),
            payload(),
        )
        .unwrap();
    drain(&run).await;
    let snapshot = runtime.conversation(id.clone()).unwrap();
    assert_eq!(snapshot.conversation.title, "写旅行计划");
    assert_eq!(snapshot.messages.len(), 2);
    assert_eq!(
        runtime
            .conversation_statistics(id.clone())
            .unwrap()
            .requests,
        1
    );
    assert!(
        runtime
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_none()
    );
    let requests = worker.join().unwrap();
    assert_eq!(chat_requests[0]["stream"], true);
    assert_eq!(requests[0]["stream"], false);
    assert_eq!(requests[0]["model"], "chosen-model");
    assert!(
        requests[0]["messages"][1]["content"]
            .as_str()
            .unwrap()
            .contains("请写旅行计划")
    );
    runtime.with_store(|s|{
        let c=s.connection.lock().unwrap();
        assert_eq!(c.query_row("SELECT state FROM conversation_title_requests WHERE conversation_id=?1",[&id],|r|r.get::<_,String>(0)).unwrap(),"completed");
        let counts:(i64,i64)=c.query_row("SELECT input_tokens,output_tokens FROM conversation_title_requests WHERE conversation_id=?1",[&id],|r|Ok((r.get(0)?,r.get(1)?))).unwrap();
        assert_eq!(counts,(12,4));
        Ok(())
    }).unwrap();
    let events = audit_tests::audit_payloads(&runtime, &id);
    assert!(
        events
            .iter()
            .any(|(kind, p)| kind == "FINAL_PROVIDER_SEMANTIC_REQUEST"
                && p["phase"] == "TITLE_GENERATION"
                && p["stream"] == false)
    );
    assert!(
        events
            .iter()
            .any(|(kind, p)| kind == "TITLE_FINISHED" && p["usage"]["inputTokens"] == 12)
    );
    let before = runtime.conversation(id.clone()).unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(reopened.conversation(id).unwrap(), before);
    reopened.close();
}

#[tokio::test]
async fn title_cas_protects_manual_rename_even_when_restored_to_fallback() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, worker) = fixture(1, response("回复", "stop"));
    configure(&runtime, endpoint);
    runtime
        .select_function_model(
            "titleGeneration".into(),
            "default".into(),
            "chosen-model".into(),
        )
        .unwrap();
    let id = runtime.create_conversation().unwrap();
    drain(
        &runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "第一轮".into(),
                payload(),
            )
            .unwrap(),
    )
    .await;
    worker.join().unwrap();
    let prepared = runtime
        .prepare_conversation_title(id.clone())
        .unwrap()
        .unwrap();
    for name in ["手工改名", "新对话"] {
        let revision = runtime
            .conversation(id.clone())
            .unwrap()
            .conversation
            .revision;
        runtime
            .change_conversation(id.clone(), revision, "rename".into(), name.into())
            .unwrap();
    }
    runtime
        .with_store(|s| {
            let c = s.connection.lock().unwrap();
            c.execute(
                "UPDATE conversation_title_requests SET state='running',started_at=1 WHERE id=?1",
                [&prepared.pending.id],
            )
            .unwrap();
            Ok(())
        })
        .unwrap();
    title::save(
        &prepared.store,
        &id,
        &prepared.pending,
        "自动标题",
        chat::ChatEvent::Completed {
            reason: "stop".into(),
            verified: None,
        },
    )
    .unwrap();
    assert_eq!(
        runtime.conversation(id).unwrap().conversation.title,
        "新对话"
    );
    runtime.close();
}

#[tokio::test]
async fn title_preparation_failure_and_interrupted_recovery_never_retry() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, worker) = fixture(1, response("回复", "stop"));
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    drain(
        &runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "输入".into(),
                payload(),
            )
            .unwrap(),
    )
    .await;
    worker.join().unwrap();
    runtime.fail_conversation_title(id.clone(), false).unwrap();
    assert!(
        runtime
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_none()
    );
    runtime.with_store(|s|{
        let c=s.connection.lock().unwrap();
        c.execute("UPDATE conversation_title_requests SET state='running',started_at=1 WHERE conversation_id=?1",[&id]).unwrap();
        Ok(())
    }).unwrap();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(
        reopened
            .conversation(id.clone())
            .unwrap()
            .conversation
            .title,
        "新对话"
    );
    assert!(
        reopened
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_none()
    );
    reopened
        .with_store(|s| {
            assert_eq!(
                s.connection
                    .lock()
                    .unwrap()
                    .query_row(
                        "SELECT state FROM conversation_title_requests WHERE conversation_id=?1",
                        [&id],
                        |r| r.get::<_, String>(0)
                    )
                    .unwrap(),
                "interrupted"
            );
            Ok(())
        })
        .unwrap();
    reopened.close();
}

#[tokio::test]
async fn title_pending_owner_survives_live_reader_but_never_restarts_after_close() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let (endpoint, worker) = fixture(1, response("回复", "stop"));
    configure(&runtime, endpoint);
    let id = runtime.create_conversation().unwrap();
    drain(
        &runtime
            .start_conversation(
                runtime.prepare_conversation(id.clone()).unwrap(),
                "原始问题".into(),
                payload(),
            )
            .unwrap(),
    )
    .await;
    worker.join().unwrap();
    let reader = Runtime::with_data_dir(&dir.0).unwrap();
    reader.conversation_catalog().unwrap();
    assert!(
        reader
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_none()
    );
    assert!(
        runtime
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_some()
    );
    reader.close();
    runtime.close();
    let reopened = Runtime::with_data_dir(&dir.0).unwrap();
    reopened.conversation_catalog().unwrap();
    assert!(
        reopened
            .prepare_conversation_title(id.clone())
            .unwrap()
            .is_none()
    );
    let events = audit_tests::audit_payloads(&reopened, &id);
    assert!(
        events
            .iter()
            .any(|(kind, p)| kind == "TITLE_INTERRUPTED" && p["providerRequestStarted"] == false)
    );
    reopened.close();
}

#[tokio::test]
async fn title_preparation_cancel_and_source_edit_cas_preserve_user_changes() {
    for cancel in [true, false] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let (endpoint, worker) = fixture(1, response("回复", "stop"));
        configure(&runtime, endpoint);
        let id = runtime.create_conversation().unwrap();
        drain(
            &runtime
                .start_conversation(
                    runtime.prepare_conversation(id.clone()).unwrap(),
                    "原问".into(),
                    payload(),
                )
                .unwrap(),
        )
        .await;
        worker.join().unwrap();
        if cancel {
            runtime.fail_conversation_title(id.clone(), true).unwrap();
            assert!(
                runtime
                    .prepare_conversation_title(id.clone())
                    .unwrap()
                    .is_none()
            );
            assert!(
                audit_tests::audit_payloads(&runtime, &id)
                    .iter()
                    .any(|(kind, p)| kind == "TITLE_PREPARATION_FINISHED"
                        && p["state"] == "cancelled"
                        && p["providerRequestStarted"] == false)
            );
        } else {
            let prepared = runtime
                .prepare_conversation_title(id.clone())
                .unwrap()
                .unwrap();
            for text in ["改过的原问", "原问"] {
                let s = runtime.conversation(id.clone()).unwrap();
                runtime
                    .change_message(
                        id.clone(),
                        s.conversation.revision,
                        s.messages[0].id.clone(),
                        "edit".into(),
                        text.into(),
                    )
                    .unwrap();
            }
            runtime
                .with_store(|s| {
                    s.connection
                        .lock()
                        .unwrap()
                        .execute(
                            "UPDATE conversation_title_requests SET state='running' WHERE id=?1",
                            [&prepared.pending.id],
                        )
                        .unwrap();
                    Ok(())
                })
                .unwrap();
            title::save(
                &prepared.store,
                &id,
                &prepared.pending,
                "迟到标题",
                chat::ChatEvent::Completed {
                    reason: "stop".into(),
                    verified: None,
                },
            )
            .unwrap();
            assert_eq!(
                runtime.conversation(id.clone()).unwrap().conversation.title,
                "新对话"
            );
            drop(prepared);
        }
        runtime.close();
    }
}
