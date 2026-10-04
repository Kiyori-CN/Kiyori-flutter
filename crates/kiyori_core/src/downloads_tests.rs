use super::*;
use std::{
    io::{Read, Write},
    net::TcpListener,
    time::Duration,
};
struct Directory(std::path::PathBuf);
impl Directory {
    fn new() -> Self {
        let id = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("kiyori-transfer-{id}"));
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
type Fixture = (String, std::thread::JoinHandle<Vec<String>>);
fn server(responses: Vec<(u16, String, Vec<u8>)>) -> Fixture {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let url = format!("http://{}/file", listener.local_addr().unwrap());
    let worker = std::thread::spawn(move || {
        let mut seen = Vec::new();
        for (status, headers, body) in responses {
            let deadline = Instant::now() + Duration::from_secs(4);
            let mut socket = loop {
                match listener.accept() {
                    Ok((s, _)) => break s,
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline);
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(e) => panic!("{e}"),
                }
            };
            socket.set_nonblocking(false).unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(2)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.windows(4).any(|v| v == b"\r\n\r\n") {
                let n = socket.read(&mut buffer).unwrap();
                assert!(n > 0);
                request.extend_from_slice(&buffer[..n]);
            }
            seen.push(String::from_utf8(request).unwrap().to_ascii_lowercase());
            write!(socket,"HTTP/1.1 {status} Status\r\nContent-Length: {}\r\nConnection: close\r\n{headers}\r\n",body.len()).unwrap();
            let _ = socket.write_all(&body);
        }
        seen
    });
    (url, worker)
}
fn spec(url: String, body: &[u8]) -> TransferSpec {
    TransferSpec {
        owner: "mnn:test".into(),
        name: "测试模型".into(),
        files: vec![TransferFile {
            path: "nested/model.bin".into(),
            url,
            size: body.len() as u64,
            sha256: hash(body),
        }],
    }
}
async fn drain(run: &TransferRun) -> Vec<TransferSnapshot> {
    let mut events = Vec::new();
    while let Some(e) = tokio::time::timeout(Duration::from_secs(5), run.next_event())
        .await
        .unwrap()
        .unwrap()
    {
        events.push(e);
    }
    events
}
#[tokio::test]
async fn download_verifies_persists_reopens_and_deletes_only_managed_resource() {
    let directory = Directory::new();
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    let body = b"complete bytes";
    let (url, worker) = server(vec![(200, String::new(), body.to_vec())]);
    let input = spec(url, body);
    let id = runtime.create_transfer(input.clone()).unwrap();
    assert_eq!(runtime.create_transfer(input).unwrap(), id);
    let run = runtime.start_transfer(id.clone()).unwrap();
    assert_eq!(drain(&run).await.last().unwrap().phase, "completed");
    worker.join().unwrap();
    assert_eq!(
        std::fs::read(
            runtime
                .resource_file_path(id.clone(), "nested/model.bin".into())
                .unwrap()
        )
        .unwrap(),
        body
    );
    assert!(
        runtime
            .resource_file_path(id.clone(), "../kiyori.sqlite3".into())
            .is_err()
    );
    runtime.close();
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    assert_eq!(runtime.transfers().unwrap()[0].phase, "completed");
    runtime.delete_transfer(id).unwrap();
    assert!(runtime.transfers().unwrap().is_empty());
    assert!(directory.0.join("kiyori.sqlite3").exists());
    runtime.close();
}
#[tokio::test]
async fn resume_checks_range_entity_and_final_digest_without_blind_append() {
    for mode in ["valid", "ignored", "range", "entity", "digest"] {
        let directory = Directory::new();
        let runtime = Runtime::with_data_dir(&directory.0).unwrap();
        let body = b"abcdef";
        let status = if mode == "ignored" { 200 } else { 206 };
        let span = if mode == "range" {
            "bytes 0-5/6"
        } else {
            "bytes 3-5/6"
        };
        let etag = if mode == "entity" {
            "\"other\""
        } else {
            "\"same\""
        };
        let bytes = if mode == "digest" {
            b"xxx".to_vec()
        } else {
            b"def".to_vec()
        };
        let (url, worker) = server(vec![(
            status,
            format!("Content-Range: {span}\r\nETag: {etag}\r\n"),
            bytes,
        )]);
        let id = runtime.create_transfer(spec(url, body)).unwrap();
        let store = runtime.persistent_store().unwrap();
        let part = store
            .managed_path(&id, ".partial/nested/model.bin")
            .unwrap();
        std::fs::create_dir_all(part.parent().unwrap()).unwrap();
        std::fs::write(&part, b"abc").unwrap();
        store
            .connection
            .lock()
            .unwrap()
            .execute(
                "UPDATE transfer_files SET confirmed=3,etag='\"same\"' WHERE transfer_id=?1",
                [&id],
            )
            .unwrap();
        let run = runtime.start_transfer(id.clone()).unwrap();
        let events = drain(&run).await;
        let requests = worker.join().unwrap();
        assert!(requests[0].contains("range: bytes=3-"));
        assert!(requests[0].contains("if-range: \"same\""));
        assert_eq!(
            events.last().unwrap().phase,
            if mode == "valid" {
                "completed"
            } else {
                "failed"
            }
        );
        if mode != "valid" {
            assert!(
                runtime
                    .resource_file_path(id, "nested/model.bin".into())
                    .is_err()
            );
            if mode != "digest" {
                assert_eq!(std::fs::read(part).unwrap(), b"abc");
            }
        }
        runtime.close();
    }
}
#[test]
fn paths_collisions_sources_and_schema_upgrade_are_rejected_without_writes() {
    let directory = Directory::new();
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    for path in [
        "../x",
        "/tmp/x",
        "C:/a",
        "a\\b",
        "CON.txt",
        "a/b.",
        ".partial/x",
    ] {
        let mut input = spec("https://example.test/file".into(), b"x");
        input.files[0].path = path.into();
        assert!(runtime.create_transfer(input).is_err());
    }
    let mut input = spec("https://example.test/file".into(), b"x");
    let mut duplicate = input.files[0].clone();
    duplicate.path = duplicate.path.to_uppercase();
    input.files.push(duplicate);
    assert!(runtime.create_transfer(input).is_err());
    assert!(
        runtime
            .create_transfer(spec("https://user:secret@example.test/file".into(), b"x"))
            .is_err()
    );
    assert!(runtime.transfers().unwrap().is_empty());
    runtime.close();
    let conn = rusqlite::Connection::open(directory.0.join("kiyori.sqlite3")).unwrap();
    conn.execute_batch("ALTER TABLE conversation_runs DROP COLUMN kind;DROP TABLE transfer_files;DROP TABLE transfers;DROP TABLE resources;DROP TABLE local_model_market;PRAGMA user_version=15;").unwrap();
    drop(conn);
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    assert!(runtime.transfers().unwrap().is_empty());
    runtime.close();
}

#[test]
fn interrupted_transfer_reconciles_physical_progress_and_completed_missing_file_is_not_success() {
    let directory = Directory::new();
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    let id = runtime
        .create_transfer(spec("https://example.test/file".into(), b"abcdef"))
        .unwrap();
    let store = runtime.persistent_store().unwrap();
    let part = store
        .managed_path(&id, ".partial/nested/model.bin")
        .unwrap();
    std::fs::create_dir_all(part.parent().unwrap()).unwrap();
    std::fs::write(&part, b"abc").unwrap();
    store.phase(&id, "running", "").unwrap();
    let snapshot = runtime.transfers().unwrap().remove(0);
    assert_eq!(snapshot.phase, "paused");
    assert_eq!(snapshot.transferred, 3);
    store.phase(&id, "completed", "").unwrap();
    store.confirmed(&id, "nested/model.bin", 6, true).unwrap();
    let snapshot = runtime.transfers().unwrap().remove(0);
    assert_eq!(snapshot.phase, "failed");
    assert!(
        runtime
            .resource_file_path(id, "nested/model.bin".into())
            .is_err()
    );
    runtime.close();
}
#[tokio::test]
async fn active_owner_pause_cancel_runtime_close_and_recovery_preserve_partial_data() {
    for action in ["pause", "cancel", "close"] {
        let directory = Directory::new();
        let runtime = Runtime::with_data_dir(&directory.0).unwrap();
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/file", listener.local_addr().unwrap());
        let (entered, received) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            let (mut socket, _) = listener.accept().unwrap();
            let mut request = [0; 4096];
            assert!(socket.read(&mut request).unwrap() > 0);
            socket.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\nETag: \"same\"\r\n\r\nabc").unwrap();
            entered.send(()).unwrap();
            std::thread::sleep(Duration::from_millis(400));
        });
        let id = runtime.create_transfer(spec(url, b"abcdef")).unwrap();
        let run = runtime.start_transfer(id.clone()).unwrap();
        tokio::task::spawn_blocking(move || received.recv_timeout(Duration::from_secs(3)).unwrap())
            .await
            .unwrap();
        tokio::time::sleep(Duration::from_millis(40)).await;
        let other = Runtime::with_data_dir(&directory.0).unwrap();
        assert_eq!(other.transfers().unwrap()[0].phase, "running");
        assert!(other.start_transfer(id.clone()).is_err());
        assert!(other.delete_transfer(id.clone()).is_err());
        if action == "close" {
            runtime.close();
        } else {
            run.stop(action == "cancel").await;
        }
        let events = drain(&run).await;
        assert_eq!(
            events.last().unwrap().phase,
            if action == "cancel" {
                "cancelled"
            } else {
                "paused"
            }
        );
        worker.join().unwrap();
        let snapshot = other.transfers().unwrap().remove(0);
        assert_eq!(snapshot.transferred, 3);
        assert_eq!(
            snapshot.phase,
            if action == "cancel" {
                "cancelled"
            } else {
                "paused"
            }
        );
        other.delete_transfer(id).unwrap();
        other.close();
        runtime.close();
    }
}

#[tokio::test]
async fn explicit_retry_resets_invalid_partial_or_target_and_completes_without_stale_range() {
    for damage in ["digest", "range", "target"] {
        let directory = Directory::new();
        let runtime = Runtime::with_data_dir(&directory.0).unwrap();
        let body = b"abcdef";
        let responses = if damage == "target" {
            vec![(200, String::new(), body.to_vec())]
        } else {
            vec![
                (
                    206,
                    format!(
                        "Content-Range: {}\r\n",
                        if damage == "range" {
                            "bytes 0-5/6"
                        } else {
                            "bytes 3-5/6"
                        }
                    ),
                    b"xxx".to_vec(),
                ),
                (200, String::new(), body.to_vec()),
            ]
        };
        let (url, worker) = server(responses);
        let id = runtime.create_transfer(spec(url, body)).unwrap();
        let store = runtime.persistent_store().unwrap();
        let path = store
            .managed_path(
                &id,
                if damage == "target" {
                    "nested/model.bin"
                } else {
                    ".partial/nested/model.bin"
                },
            )
            .unwrap();
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(
            &path,
            if damage == "target" {
                b"xxxxxx".as_slice()
            } else {
                b"abc".as_slice()
            },
        )
        .unwrap();
        let first = runtime.start_transfer(id.clone()).unwrap();
        assert_eq!(drain(&first).await.last().unwrap().phase, "failed");
        assert!(path.exists());
        let retry = runtime.start_transfer(id.clone()).unwrap();
        assert_eq!(drain(&retry).await.last().unwrap().phase, "completed");
        let requests = worker.join().unwrap();
        assert!(!requests.last().unwrap().contains("range:"));
        assert_eq!(
            std::fs::read(
                runtime
                    .resource_file_path(id, "nested/model.bin".into())
                    .unwrap()
            )
            .unwrap(),
            body
        );
        runtime.close();
    }
}

#[test]
fn terminal_storage_error_is_observable_and_schema16_upgrade_preserves_frozen_task() {
    let directory = Directory::new();
    let runtime = Runtime::with_data_dir(&directory.0).unwrap();
    let id = runtime
        .create_transfer(spec("https://example.test/file".into(), b"x"))
        .unwrap();
    let store = runtime.persistent_store().unwrap();
    store.connection.lock().unwrap().execute_batch("CREATE TRIGGER fail_phase BEFORE UPDATE OF phase ON transfers BEGIN SELECT RAISE(ABORT,'fixture'); END;").unwrap();
    assert!(
        finish(&store, &id, "completed", Ok(()))
            .unwrap_err()
            .message
            .contains("保存失败")
    );
    store.connection.lock().unwrap().execute_batch("ALTER TABLE conversation_runs DROP COLUMN kind; DROP TRIGGER fail_phase; ALTER TABLE transfers DROP COLUMN restart_required; PRAGMA user_version=16;").unwrap();
    runtime.close();
    drop(store);
    let reopened = Runtime::with_data_dir(&directory.0).unwrap();
    assert_eq!(reopened.transfers().unwrap()[0].resource.id, id);
    assert_eq!(reopened.transfers().unwrap()[0].total, 1);
    reopened.close();
}
