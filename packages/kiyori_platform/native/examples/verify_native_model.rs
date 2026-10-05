//! 显式本机验收，复用已经完成校验的模型包；不下载/安装设备或读取用户会话。
use kiyori_core::{
    chat::{self, ChatEvent, ChatMessage},
    models::{ModelConfigDraft, ModelOptions},
    runtime::Runtime,
};
use std::{sync::Arc, time::Duration};
#[tokio::main]
async fn main() {
    let args: Vec<_> = std::env::args().collect();
    assert!(
        (4..=5).contains(&args.len()),
        "Usage: verify_native_model <isolated-data-dir> <MNN|LLAMA_CPP> <model-name> [public-transfer-manifest]"
    );
    let runtime = Runtime::with_data_dir(&args[1]).unwrap();
    if let Some(manifest) = args.get(4) {
        let spec: kiyori_core::downloads::TransferSpec =
            serde_json::from_slice(&std::fs::read(manifest).unwrap()).unwrap();
        assert_eq!(spec.owner, format!("llama:{}", args[3]));
        let existing = runtime
            .transfers()
            .unwrap()
            .into_iter()
            .find(|t| t.owner == spec.owner);
        let id = match &existing {
            Some(t) => t.resource.id.clone(),
            None => runtime.create_transfer(spec).unwrap(),
        };
        if !existing.is_some_and(|t| t.phase == "completed") {
            let run = runtime.start_transfer(id).unwrap();
            let mut reported = std::time::Instant::now();
            let mut complete = false;
            while let Some(event) = run.next_event().await.unwrap() {
                if reported.elapsed() >= Duration::from_secs(5)
                    || matches!(event.phase.as_str(), "completed" | "failed")
                {
                    println!(
                        "DOWNLOAD={} BYTES={}/{}",
                        event.phase, event.transferred, event.total
                    );
                    reported = std::time::Instant::now();
                }
                assert!(
                    !matches!(event.phase.as_str(), "failed" | "cancelled"),
                    "{}",
                    event.error
                );
                complete |= event.phase == "completed";
            }
            assert!(complete);
        }
    }
    runtime
        .set_inference_adapter(Arc::new(kiyori_inference::NativeInference))
        .unwrap();
    let options = ModelOptions {
        summary_enabled: false,
        ..Default::default()
    };
    let draft = ModelConfigDraft {
        name: "native acceptance".into(),
        provider: args[2].clone(),
        protocol: "native".into(),
        endpoint: String::new(),
        models: vec![args[3].clone()],
        options,
    };
    for round in 0..3 {
        let mut input = chat::probe::prepare(draft.clone(), String::new(), vec![], "chat").unwrap();
        input.probe = None;
        input.parameters = "{\"temperature\":0,\"max_tokens\":48}".into();
        input.timeout_ms = 120_000;
        input.messages = vec![
            ChatMessage {
                role: "system".into(),
                content: "Answer only the arithmetic result.".into(),
            },
            ChatMessage {
                role: "user".into(),
                content: if round == 1 {
                    "Count from 1 to 100."
                } else {
                    "What is 2 + 3?"
                }
                .into(),
            },
        ];
        let run = runtime.start_chat(input).unwrap();
        let mut text = String::new();
        let mut terminal = false;
        let mut cancelled = false;
        while let Some(event) = tokio::time::timeout(Duration::from_secs(180), run.next_event())
            .await
            .unwrap()
            .unwrap()
        {
            match event {
                ChatEvent::Text(t) => {
                    text.push_str(&t);
                    if round == 1 && !cancelled {
                        run.cancel_and_wait().await;
                        cancelled = true;
                    }
                }
                ChatEvent::Completed { reason, .. } => {
                    assert_eq!(reason, "stop");
                    terminal = true;
                }
                ChatEvent::Cancelled => {
                    assert_eq!(round, 1);
                    terminal = true;
                }
                ChatEvent::Failed(f) => panic!("Native acceptance failed: {f:?}"),
                _ => {}
            }
        }
        assert!(terminal);
        if round != 1 {
            assert!(text.contains('5'));
        }
        println!(
            "ROUND={} CANCELLED={} TEXT={}",
            round + 1,
            cancelled,
            text.trim()
        );
    }
    runtime.close();
}
