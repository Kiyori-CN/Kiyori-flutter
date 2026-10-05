use super::*;
use serde_json::json;
use std::sync::atomic::{AtomicUsize, Ordering};

struct Fixture {
    mode: &'static str,
    active: Arc<AtomicUsize>,
}
struct Exit(Arc<AtomicUsize>);
impl Drop for Exit {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::SeqCst);
    }
}
impl ScriptAdapter for Fixture {
    fn execute(
        &self,
        _: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure> {
        self.active.fetch_add(1, Ordering::SeqCst);
        let _exit = Exit(self.active.clone());
        match self.mode {
            "panic" => panic!("private diagnostic must not propagate"),
            "wait" => {
                while !stopped() {
                    std::thread::sleep(Duration::from_millis(1));
                }
                // Simulate native handle cleanup after detecting cancellation.
                std::thread::sleep(Duration::from_millis(20));
            }
            "stream" => {
                for _ in 0..32 {
                    if !emit(r#"{"chunk":"中文"}"#.as_bytes()) {
                        break;
                    }
                }
            }
            "bad" => {
                emit(b"not-json");
            }
            "large" => {
                emit(&vec![b' '; MAX_EVENT + 1]);
            }
            _ => {
                assert!(emit(br#"{"chunk":"hello"}"#));
            }
        }
        Ok(json!({"done":true}))
    }
}
fn runtime(mode: &'static str) -> (Arc<Runtime>, Arc<AtomicUsize>) {
    let active = Arc::new(AtomicUsize::new(0));
    let runtime = Arc::new(Runtime::new());
    runtime
        .set_script_adapter(Arc::new(Fixture {
            mode,
            active: active.clone(),
        }))
        .unwrap();
    (runtime, active)
}
fn request(timeout_ms: u32) -> ScriptRequest {
    ScriptRequest {
        source: "fixture".into(),
        operation: ScriptOperation::Register,
        limits: ScriptLimits {
            timeout_ms,
            ..Default::default()
        },
    }
}
async fn finish(run: &ScriptRun) -> Result<Value, ScriptFailure> {
    loop {
        match run.next_event().await?.unwrap() {
            ScriptEvent::Intermediate(_) => {}
            ScriptEvent::Completed(value) => return Ok(value),
            ScriptEvent::Failed(error) => return Err(error),
        }
    }
}
async fn await_active(active: &AtomicUsize, value: usize) {
    tokio::time::timeout(Duration::from_secs(2), async {
        while active.load(Ordering::SeqCst) != value {
            tokio::task::yield_now().await;
        }
    })
    .await
    .unwrap();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn stream_completion_and_failures_wait_for_worker_release() {
    for (mode, expected) in [
        ("ok", None),
        ("bad", Some(ScriptFailureKind::Protocol)),
        ("large", Some(ScriptFailureKind::OutputLimit)),
        ("panic", Some(ScriptFailureKind::Interrupted)),
    ] {
        let (runtime, active) = runtime(mode);
        let run = runtime.start_script(request(1000)).await.unwrap();
        let result = finish(&run).await;
        assert_eq!(result.err().map(|e| e.kind), expected);
        assert_eq!(active.load(Ordering::SeqCst), 0);
        assert!(run.next_event().await.unwrap().is_none());
        runtime.close();
    }
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn cancellation_timeout_drop_and_close_settle_without_consumers() {
    let (runtime, active) = runtime("wait");
    let run = runtime.start_script(request(5000)).await.unwrap();
    await_active(&active, 1).await;
    run.cancel_and_wait().await.unwrap();
    assert_eq!(active.load(Ordering::SeqCst), 0);
    let timed = runtime.start_script(request(20)).await.unwrap();
    assert_eq!(
        finish(&timed).await.unwrap_err().kind,
        ScriptFailureKind::Timeout
    );
    assert_eq!(active.load(Ordering::SeqCst), 0);
    let dropped = runtime.start_script(request(5000)).await.unwrap();
    await_active(&active, 1).await;
    drop(dropped);
    await_active(&active, 0).await;
    let closing = runtime.start_script(request(5000)).await.unwrap();
    await_active(&active, 1).await;
    let closing_runtime = runtime.clone();
    tokio::task::spawn_blocking(move || closing_runtime.close())
        .await
        .unwrap();
    assert_eq!(active.load(Ordering::SeqCst), 0);
    assert_eq!(
        finish(&closing).await.unwrap_err().kind,
        ScriptFailureKind::Cancelled
    );
    assert!(matches!(
        runtime.start_script(request(100)).await,
        Err(ScriptFailure {
            kind: ScriptFailureKind::RuntimeClosed
        })
    ));
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn stop_waits_independently_of_the_pending_event_reader() {
    let (runtime, active) = runtime("wait");
    let run = Arc::new(runtime.start_script(request(5000)).await.unwrap());
    await_active(&active, 1).await;
    let reading = run.clone();
    let reader = tokio::spawn(async move { reading.next_event().await });
    tokio::time::sleep(Duration::from_millis(10)).await;
    run.cancel_and_wait().await.unwrap();
    assert_eq!(active.load(Ordering::SeqCst), 0);
    assert!(matches!(
        reader.await.unwrap().unwrap(),
        Some(ScriptEvent::Failed(ScriptFailure {
            kind: ScriptFailureKind::Cancelled
        }))
    ));
    assert!(run.next_event().await.unwrap().is_none());
    runtime.close();
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn bounded_queue_close_and_admission_timeout_do_not_leak_slots() {
    let (runtime, active) = runtime("stream");
    let run = runtime.start_script(request(5000)).await.unwrap();
    await_active(&active, 1).await;
    tokio::time::sleep(Duration::from_millis(20)).await;
    let closing = runtime.clone();
    tokio::task::spawn_blocking(move || closing.close())
        .await
        .unwrap();
    assert_eq!(active.load(Ordering::SeqCst), 0);
    assert_eq!(
        finish(&run).await.unwrap_err().kind,
        ScriptFailureKind::Cancelled
    );
    let (runtime, active) = self::runtime("wait");
    let mut runs = Vec::new();
    for _ in 0..4 {
        runs.push(runtime.start_script(request(5000)).await.unwrap());
    }
    await_active(&active, 4).await;
    assert!(matches!(
        runtime.start_script(request(20)).await,
        Err(ScriptFailure {
            kind: ScriptFailureKind::Timeout
        })
    ));
    assert_eq!(active.load(Ordering::SeqCst), 4);
    for run in &runs {
        run.cancel();
    }
    for run in &runs {
        run.cancel_and_wait().await.unwrap();
    }
    assert_eq!(active.load(Ordering::SeqCst), 0);
    let retry = runtime.start_script(request(20)).await.unwrap();
    assert_eq!(
        finish(&retry).await.unwrap_err().kind,
        ScriptFailureKind::Timeout
    );
    runtime.close();
}
#[test]
fn registration_identity_and_limit_validation_reject_forged_snapshots() {
    assert!(
        registrations(json!([{ "id":"example", "displayName":"示例", "description":"" }])).is_ok()
    );
    for bad in [
        json!([{"id":"../x","displayName":"x","description":""}]),
        json!([{"id":"x","displayName":"x","description":"","extra":true}]),
        json!([{"id":"x","displayName":"x","description":""},{"id":"x","displayName":"x","description":""}]),
    ] {
        assert_eq!(
            registrations(bad).unwrap_err().kind,
            ScriptFailureKind::Protocol
        );
    }
    assert!(!request(0).valid());
    assert!(!valid_id("toolpkg:a/b"));
}
