use super::*;
use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        Self(std::env::temp_dir().join(format!(
                "kiyori-prompts-{}-{}",
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
fn card(name: &str) -> CharacterDraft {
    CharacterDraft {
        name: name.into(),
        setting: "设定".into(),
        chat: "聊天".into(),
        voice: "语音".into(),
        opening: "仅开场".into(),
        marks: "私人备注".into(),
        custom: "附加".into(),
        ..Default::default()
    }
}

#[test]
fn binding_validation_and_duplicate_group_activation_preserve_identity_scope() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let mut draft = card("空绑定");
    draft.model_config = Some(" ".into());
    draft.model_name = Some("模型".into());
    assert!(store.save_character(None, None, draft).is_err());
    let group = store
        .save_prompt_group(
            None,
            None,
            GroupDraft {
                name: "组".into(),
                description: String::new(),
                members: vec![],
            },
        )
        .unwrap();
    store
        .activate_prompt("character".into(), DEFAULT_CHARACTER.into())
        .unwrap();
    let copy = store.duplicate_prompt("group".into(), group, 1).unwrap();
    assert_eq!(
        store.prompt_catalog().unwrap().active_group,
        Some(copy.clone())
    );
    // 不同实体类型可以同名 ID，删除标签不能改变同 ID 群组的活跃事实。
    store
        .connection
        .lock()
        .unwrap()
        .execute(
            "INSERT INTO prompt_tags VALUES(?1,1,0,'标签','','')",
            [&copy],
        )
        .unwrap();
    store.delete_prompt("tag".into(), copy.clone(), 1).unwrap();
    assert_eq!(store.prompt_catalog().unwrap().active_group, Some(copy));
}
fn tag(name: &str) -> TagDraft {
    TagDraft {
        name: name.into(),
        description: String::new(),
        content: format!("标签{name}"),
    }
}

#[test]
fn initialized_default_is_unique_protected_and_reopens_full_fields() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let initial = store.prompt_catalog().unwrap();
    assert_eq!(initial.characters.len(), 1);
    assert!(initial.groups.is_empty());
    assert_eq!(initial.active_character.as_deref(), Some(DEFAULT_CHARACTER));
    assert!(initial.characters[0].draft.voice.contains("语音模式"));
    assert!(
        store
            .delete_prompt("character".into(), DEFAULT_CHARACTER.into(), 1)
            .is_err()
    );
    let id = store.save_character(None, None, card("测试角色")).unwrap();
    drop(store);
    let store = AppStore::open(&dir.0).unwrap();
    let value = store.prompt_catalog().unwrap();
    let restored = value.characters.iter().find(|c| c.id == id).unwrap();
    assert_eq!(restored.draft, card("测试角色"));
    store
        .save_character(Some(DEFAULT_CHARACTER.into()), Some(1), card("新名字"))
        .unwrap();
    store.reset_default_character(2).unwrap();
    assert_eq!(
        store.prompt_catalog().unwrap().characters[0].draft.name,
        "Kiyori"
    );
}

#[test]
fn prompt_composition_keeps_tag_order_voice_choice_and_excludes_private_fields() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let a = store.save_prompt_tag(None, None, tag("甲")).unwrap();
    let b = store.save_prompt_tag(None, None, tag("乙")).unwrap();
    let mut draft = card("角色");
    draft.tag_ids = vec![b.clone(), a.clone(), b.clone()];
    let id = store.save_character(None, None, draft).unwrap();
    assert_eq!(
        store.compose_character_prompt(id.clone(), false).unwrap(),
        "设定\n\n聊天\n\n标签乙\n\n标签甲\n\n附加"
    );
    assert_eq!(
        store.compose_character_prompt(id.clone(), true).unwrap(),
        "设定\n\n语音\n\n标签乙\n\n标签甲\n\n附加"
    );
    store.delete_prompt("tag".into(), b, 1).unwrap();
    let value = store.prompt_catalog().unwrap();
    let changed = value.characters.iter().find(|c| c.id == id).unwrap();
    assert_eq!(changed.revision, 2);
    assert_eq!(changed.draft.tag_ids, vec![a]);
}

#[test]
fn activation_cascade_and_stale_edits_are_atomic() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let a = store.save_character(None, None, card("甲")).unwrap();
    let b = store.save_character(None, None, card("乙")).unwrap();
    let group = store
        .save_prompt_group(
            None,
            None,
            GroupDraft {
                name: "组".into(),
                description: "描述".into(),
                members: vec![b.clone(), a.clone(), b.clone()],
            },
        )
        .unwrap();
    let value = store.prompt_catalog().unwrap();
    assert_eq!(value.active_group.as_deref(), Some(group.as_str()));
    assert!(value.active_character.is_none());
    assert_eq!(
        value.groups[0].draft.members,
        vec![b.clone(), a.clone(), b.clone()]
    );
    store
        .activate_prompt("character".into(), a.clone())
        .unwrap();
    store
        .delete_prompt("character".into(), a.clone(), 1)
        .unwrap();
    let value = store.prompt_catalog().unwrap();
    assert_eq!(value.active_character.as_deref(), Some(DEFAULT_CHARACTER));
    assert_eq!(value.groups[0].draft.members, vec![b.clone(), b]);
    assert_eq!(value.groups[0].revision, 2);
    assert!(
        store
            .save_character(Some(a), Some(1), card("复活"))
            .is_err()
    );
    assert!(
        store
            .save_prompt_group(
                Some(group.clone()),
                Some(1),
                GroupDraft {
                    name: "旧".into(),
                    description: String::new(),
                    members: vec![]
                }
            )
            .is_err()
    );
    assert!(
        store
            .save_prompt_group(
                Some(group.clone()),
                Some(2),
                GroupDraft {
                    name: "错误".into(),
                    description: String::new(),
                    members: vec!["missing".into()]
                }
            )
            .is_err()
    );
    assert_eq!(store.prompt_catalog().unwrap().groups[0].draft.name, "组");
    store
        .activate_prompt("group".into(), group.clone())
        .unwrap();
    store.delete_prompt("group".into(), group, 2).unwrap();
    assert_eq!(
        store.prompt_catalog().unwrap().active_character.as_deref(),
        Some(DEFAULT_CHARACTER)
    );
}

#[test]
fn duplicates_keep_bindings_and_space_deletion_invalidates_old_character_revision() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    let space = store.save_knowledge_space(None, "关联空间".into()).unwrap();
    let mut draft = card("绑定角色");
    draft.memory_space = Some(space.clone());
    draft.tools_enabled = true;
    draft.tools = vec![
        PromptTool {
            kind: "builtin".into(),
            name: "use_package".into(),
        },
        PromptTool {
            kind: "skill".into(),
            name: "私有选择".into(),
        },
    ];
    let id = store.save_character(None, None, draft).unwrap();
    let copy = store
        .duplicate_prompt("character".into(), id.clone(), 1)
        .unwrap();
    let value = store.prompt_catalog().unwrap();
    let copied = value.characters.iter().find(|c| c.id == copy).unwrap();
    assert_eq!(copied.draft.name, "绑定角色 (副本)");
    assert_eq!(copied.draft.tools.len(), 2);
    store.delete_knowledge_space(space).unwrap();
    let value = store.prompt_catalog().unwrap();
    assert!(
        value
            .characters
            .iter()
            .filter(|c| c.id == id || c.id == copy)
            .all(|c| c.revision == 2 && c.draft.memory_space.is_none())
    );
    let second = AppStore::open(&dir.0).unwrap();
    let mut draft = value
        .characters
        .iter()
        .find(|c| c.id == id)
        .unwrap()
        .draft
        .clone();
    draft.name = "当前".into();
    store
        .save_character(Some(id.clone()), Some(2), draft.clone())
        .unwrap();
    assert!(second.save_character(Some(id), Some(2), draft).is_err());
}

#[test]
fn schema_four_migration_preserves_knowledge_and_closed_runtime_rejects_prompts() {
    let dir = Directory::new();
    let store = AppStore::open(&dir.0).unwrap();
    store.create("工作流".into(), "保留".into()).unwrap();
    remove_schema_five_for_fixture(&store.connection.lock().unwrap());
    store
        .connection
        .lock()
        .unwrap()
        .execute_batch("PRAGMA user_version=4;")
        .unwrap();
    drop(store);
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    assert_eq!(runtime.prompt_catalog().unwrap().characters.len(), 1);
    runtime.close();
    assert!(runtime.prompt_catalog().is_err());
    let store = AppStore::open(&dir.0).unwrap();
    assert_eq!(store.list().unwrap().len(), 1);
}
