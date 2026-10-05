use super::*;
use crate::{
    downloads::{TransferFile, TransferSpec},
    models,
};
use std::sync::atomic::{AtomicBool, Ordering};
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "kiyori-inference-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&path).unwrap();
        Self(path)
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
fn hash(bytes: &[u8]) -> String {
    ring::digest::digest(&ring::digest::SHA256, bytes)
        .as_ref()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}
fn fixture(runtime: &Runtime, config: Value) -> String {
    let files = [
        ("config.json", config.to_string().into_bytes()),
        ("llm_config.json", b"{}".to_vec()),
        ("llm.mnn", b"model".to_vec()),
        ("llm.mnn.weight", b"weight".to_vec()),
        ("tokenizer.txt", b"tokens".to_vec()),
    ];
    let id = runtime
        .create_transfer(TransferSpec {
            owner: "mnn:tiny".into(),
            name: "tiny".into(),
            files: files
                .iter()
                .map(|(path, bytes)| TransferFile {
                    path: (*path).into(),
                    url: "https://example.com/file".into(),
                    size: bytes.len() as u64,
                    sha256: hash(bytes),
                })
                .collect(),
        })
        .unwrap();
    runtime
        .with_store(|s| {
            let root = s.managed_path(&id, "")?;
            std::fs::create_dir_all(root).unwrap();
            for (path, bytes) in &files {
                std::fs::write(s.managed_path(&id, path)?, bytes).unwrap();
            }
            let c = s.connection.lock().unwrap();
            c.execute("UPDATE transfers SET phase='completed' WHERE id=?1", [&id])
                .unwrap();
            for (path,bytes) in files { c.execute("UPDATE transfer_files SET verified=1,confirmed=?3 WHERE transfer_id=?1 AND path=?2",rusqlite::params![id,path,bytes.len() as i64]).unwrap(); }
            Ok(())
        })
        .unwrap();
    id
}
fn request() -> ChatRequest {
    let draft = models::ModelConfigDraft {
        name: "tiny".into(),
        provider: "MNN".into(),
        protocol: "native".into(),
        endpoint: String::new(),
        models: vec!["tiny".into()],
        options: Default::default(),
    };
    let mut request = super::super::probe::prepare(draft, String::new(), vec![], "chat").unwrap();
    request.probe = None;
    request.timeout_ms = 1000;
    request
}
struct FixtureAdapter {
    ended: Arc<AtomicBool>,
    mode: u8,
}
impl InferenceAdapter for FixtureAdapter {
    fn generate(
        &self,
        input: &InferenceRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<InferenceResult, ChatFailure> {
        assert!(input.resource.model_path.is_file());
        if self.mode == 0 {
            let bytes = "中文".as_bytes();
            assert!(emit(&bytes[..1]));
            assert!(emit(&bytes[1..4]));
            assert!(emit(&bytes[4..]));
        } else if self.mode == 4 || self.mode == 5 {
            let text = "中".repeat(if self.mode == 4 { 700_001 } else { 3_000_000 });
            for bytes in text.as_bytes().chunks(1024 * 1024) {
                if !emit(bytes) {
                    break;
                }
            }
        } else if self.mode == 3 {
            assert!(emit(&[0xe4]));
        } else {
            assert!(emit(b"begin"));
            while !stopped() {
                if self.mode == 2 && !emit(b"x") {
                    break;
                }
                std::thread::sleep(Duration::from_millis(1));
            }
            std::thread::sleep(Duration::from_millis(30));
        }
        self.ended.store(true, Ordering::Release);
        Ok(InferenceResult {
            input_tokens: 2,
            output_tokens: 2,
            reason: "stop".into(),
        })
    }
}
#[tokio::test]
async fn large_utf8_outputs_respect_event_limit_and_fail_instead_of_truncating() {
    for (mode, stream) in [(4, false), (4, true), (5, false)] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        fixture(&runtime, json!({}));
        runtime
            .set_inference_adapter(Arc::new(FixtureAdapter {
                ended: Arc::new(AtomicBool::new(false)),
                mode,
            }))
            .unwrap();
        let mut input = request();
        input.stream = stream;
        input.timeout_ms = 10_000;
        let run = runtime.start_chat(input).unwrap();
        let mut text = String::new();
        let mut failed = None;
        let mut completed = false;
        while let Some(event) = run.next_event().await.unwrap() {
            match event {
                ChatEvent::Text(value) => {
                    assert!(value.len() <= 1024 * 1024);
                    text.push_str(&value);
                }
                ChatEvent::Failed(error) => failed = Some(error),
                ChatEvent::Completed { .. } => completed = true,
                _ => {}
            }
        }
        if mode == 4 {
            assert_eq!(text, "中".repeat(700_001));
            assert!(failed.is_none());
            assert!(completed);
        } else {
            assert!(text.is_empty());
            assert_eq!(failed.unwrap().kind, ChatFailureKind::Protocol);
            assert!(!completed);
        }
    }
}
#[tokio::test]
async fn utf8_stream_and_nonstream_preserve_usage() {
    for stream in [true, false] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        fixture(&runtime, json!({}));
        let ended = Arc::new(AtomicBool::new(false));
        runtime
            .set_inference_adapter(Arc::new(FixtureAdapter {
                ended: ended.clone(),
                mode: 0,
            }))
            .unwrap();
        let mut input = request();
        input.stream = stream;
        let run = runtime.start_chat(input).unwrap();
        let mut text = String::new();
        let mut usage = false;
        while let Some(event) = run.next_event().await.unwrap() {
            match event {
                ChatEvent::Text(t) => text.push_str(&t),
                ChatEvent::Usage {
                    input: 2,
                    output: 2,
                    ..
                } => usage = true,
                ChatEvent::Failed(f) => panic!("{f:?}"),
                _ => {}
            }
        }
        assert_eq!(text, "中文");
        assert!(usage);
        assert!(ended.load(Ordering::Acquire));
    }
}
#[tokio::test]
async fn cancel_and_close_wait_for_worker_and_release_delete_lock() {
    for mode in [1, 2] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let id = fixture(&runtime, json!({}));
        let ended = Arc::new(AtomicBool::new(false));
        runtime
            .set_inference_adapter(Arc::new(FixtureAdapter {
                ended: ended.clone(),
                mode,
            }))
            .unwrap();
        let run = runtime.start_chat(request()).unwrap();
        assert_eq!(run.next_event().await.unwrap(), Some(ChatEvent::Started));
        assert!(matches!(
            run.next_event().await.unwrap(),
            Some(ChatEvent::Text(_))
        ));
        assert!(runtime.delete_transfer(id.clone()).is_err());
        if mode == 2 {
            runtime.close();
        }
        tokio::time::timeout(Duration::from_secs(2), run.cancel_and_wait())
            .await
            .unwrap();
        assert!(ended.load(Ordering::Acquire));
        assert_eq!(run.next_event().await.unwrap(), Some(ChatEvent::Cancelled));
        assert!(run.next_event().await.unwrap().is_none());
        if mode == 1 {
            runtime.delete_transfer(id).unwrap();
        }
    }
}
#[tokio::test]
async fn timeout_waits_for_worker_and_invalid_utf8_fails() {
    for mode in [1, 3] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        fixture(&runtime, json!({}));
        let ended = Arc::new(AtomicBool::new(false));
        runtime
            .set_inference_adapter(Arc::new(FixtureAdapter {
                ended: ended.clone(),
                mode,
            }))
            .unwrap();
        let mut input = request();
        input.timeout_ms = 100;
        let run = runtime.start_chat(input).unwrap();
        let mut failed = false;
        while let Some(event) = run.next_event().await.unwrap() {
            if let ChatEvent::Failed(f) = event {
                assert_eq!(
                    f.kind,
                    if mode == 1 {
                        ChatFailureKind::Timeout
                    } else {
                        ChatFailureKind::Protocol
                    },
                    "{}",
                    f.message
                );
                failed = true;
            }
        }
        assert!(failed);
        assert!(ended.load(Ordering::Acquire));
    }
}
#[test]
fn resource_rejects_uncompleted_tamper_and_paths() {
    for config in [
        json!({"base_dir":"C:/private"}),
        json!({"llm_model":"../outside"}),
        json!({"mllm":{"tmp_path":"/tmp"}}),
        json!({"eagle_fc":"../outside"}),
        json!({"spk_dict":"unchecked.mnn"}),
        json!({"embedding_file":[]}),
        json!({"context_file":"context.json"}),
    ] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        fixture(&runtime, config);
        assert!(
            runtime
                .with_store(|s| s.inference_resource("MNN", "tiny"))
                .is_err()
        );
    }
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    let id = fixture(&runtime, json!({}));
    runtime
        .with_store(|s| {
            std::fs::write(s.managed_path(&id, "config.json")?, b"[]").unwrap();
            Ok(())
        })
        .unwrap();
    assert!(
        runtime
            .with_store(|s| s.inference_resource("MNN", "tiny"))
            .is_err()
    );
    assert!(
        runtime
            .with_store(|s| s.inference_resource("MNN", "missing"))
            .is_err()
    );
}

#[tokio::test]
async fn text_cannot_open_implicit_media_paths() {
    let dir = Directory::new();
    let runtime = Runtime::with_data_dir(&dir.0).unwrap();
    fixture(&runtime, json!({}));
    let ended = Arc::new(AtomicBool::new(false));
    runtime
        .set_inference_adapter(Arc::new(FixtureAdapter {
            ended: ended.clone(),
            mode: 0,
        }))
        .unwrap();
    for content in [
        "<img>C:/private.png</img>",
        "<audio>https://example.com/private</audio>",
    ] {
        let mut input = request();
        input.messages = vec![ChatMessage {
            role: "user".into(),
            content: content.into(),
        }];
        let run = runtime.start_chat(input).unwrap();
        let mut failed = false;
        while let Some(event) = run.next_event().await.unwrap() {
            if let ChatEvent::Failed(f) = event {
                assert_eq!(f.kind, ChatFailureKind::Unsupported);
                failed = true;
            }
        }
        assert!(failed);
        assert!(!ended.load(Ordering::Acquire));
    }
}

#[test]
fn implicit_context_and_auxiliary_files_need_manifest_verification() {
    for path in ["context.json", "visual.mnn.weight"] {
        let dir = Directory::new();
        let runtime = Runtime::with_data_dir(&dir.0).unwrap();
        let id = fixture(&runtime, json!({}));
        runtime
            .with_store(|s| {
                std::fs::write(s.managed_path(&id, path)?, b"{}").unwrap();
                Ok(())
            })
            .unwrap();
        assert!(
            runtime
                .with_store(|s| s.inference_resource("MNN", "tiny"))
                .is_err()
        );
    }
}
