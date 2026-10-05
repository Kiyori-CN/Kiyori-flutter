use super::*;
use crate::scripts::{ScriptAdapter, ScriptFailure};
use serde_json::json;
use std::{io::Cursor, sync::atomic::AtomicUsize, time::Duration};
use zip::{ZipWriter, write::SimpleFileOptions};
#[path = "archive_tests.rs"]
mod archive_tests;
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        static ID: AtomicU64 = AtomicU64::new(0);
        Self(std::env::temp_dir().join(format!(
                "kiyori-ext-{}-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos(),
                ID.fetch_add(1, Ordering::Relaxed)
            )))
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        if self.0.exists() {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }
}
struct Adapter(Arc<AtomicUsize>);
impl ScriptAdapter for Adapter {
    fn execute(
        &self,
        request: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        _: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure> {
        match &request.operation {
            ScriptOperation::Register => {
                Ok(json!([{"id":"fixture","displayName":"供应商","description":"合成目录"}]))
            }
            ScriptOperation::Invoke { payload, .. } => {
                if payload["wait"] == true {
                    self.0.fetch_add(1, Ordering::SeqCst);
                    while !stopped() {
                        std::thread::sleep(Duration::from_millis(1));
                    }
                    std::thread::sleep(Duration::from_millis(15));
                    self.0.fetch_sub(1, Ordering::SeqCst);
                }
                Ok(json!({"count":7}))
            }
        }
    }
}
fn runtime(dir: &Directory, active: Arc<AtomicUsize>) -> Arc<Runtime> {
    let r = Arc::new(Runtime::with_data_dir(&dir.0).unwrap());
    r.set_script_adapter(Arc::new(Adapter(active))).unwrap();
    r
}
fn package(id: &str, version: &str, extra: Vec<(&str, Vec<u8>)>) -> Vec<u8> {
    let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);
    for (name,bytes) in [
        ("manifest.json",json!({"schema_version":1,"toolpkg_id":id,"version":version,"main":"dist/main.js","display_name":{"zh":"合成包"},"enabled_by_default":true,"subpackages":[]}).to_string().into_bytes()),
        ("dist/main.js",b"exports.registerToolPkg = function () {};".to_vec()),
    ].into_iter().chain(extra){zip.start_file(name,options).unwrap();zip.write_all(&bytes).unwrap();}
    zip.finish().unwrap().into_inner()
}
async fn install(r: &Arc<Runtime>, bytes: Vec<u8>) -> Result<ExtensionPackage, CoreError> {
    let import = r.begin_extension_import()?;
    for chunk in bytes.chunks(1024 * 1024) {
        import.append(chunk.to_vec())?;
    }
    import.finish().await
}
#[tokio::test]
async fn metadata_is_bounded_and_tampered_original_is_rejected_without_changing_directory() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("manifest.json", options).unwrap();
    zip.write_all(json!({"schema_version":1,"toolpkg_id":"meta","version":"1.0.0","main":"main.js","author":["甲","乙"],"category":{"zh":"AI"},"api_version":"1.0"}).to_string().as_bytes()).unwrap();
    zip.start_file("main.js", options).unwrap();
    zip.write_all(b"exports.registerToolPkg=function(){};")
        .unwrap();
    let p = install(&r, zip.finish().unwrap().into_inner())
        .await
        .unwrap();
    let details = r.extension_details(p.id.clone(), p.revision).await.unwrap();
    assert_eq!(details.authors, ["甲", "乙"]);
    assert_eq!(details.category, "AI");
    let path = r
        .persistent_store()
        .unwrap()
        .managed_path(&p.resource.id, "archive.toolpkg")
        .unwrap();
    std::fs::write(path, b"tampered").unwrap();
    assert!(r.extension_details(p.id.clone(), p.revision).await.is_err());
    assert_eq!(r.extension_packages().unwrap()[0].revision, p.revision);
    r.close();
}
#[tokio::test]
async fn install_handlers_reopen_upgrade_disable_and_uninstall_preserve_identity() {
    let dir = Directory::new();
    let active = Arc::new(AtomicUsize::new(0));
    let r = runtime(&dir, active.clone());
    let first = install(&r, package("com.kiyori.fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    assert_eq!(first.revision, 1);
    assert!(first.enabled);
    let details = r
        .extension_details(first.id.clone(), first.revision)
        .await
        .unwrap();
    assert_eq!(details.package.archive_hash, first.archive_hash);
    assert!(details.authors.is_empty());
    assert_eq!(details.api_version, "1.0.0");
    assert!(
        r.extension_details(first.id.clone(), first.revision + 1)
            .await
            .is_err()
    );
    let provider = r.extension_providers().unwrap().pop().unwrap();
    assert_eq!(provider.id, "TOOLPKG:com.kiyori.fixture:fixture");
    for handler in [
        ProviderHandler::ListModels,
        ProviderHandler::SendMessage,
        ProviderHandler::TestConnection,
        ProviderHandler::CalculateInputTokens,
    ] {
        let run = r
            .start_extension(
                provider.id.clone(),
                1,
                handler,
                json!({}),
                ScriptLimits::default(),
            )
            .await
            .unwrap();
        assert!(
            matches!(run.next_event().await.unwrap(),Some(ScriptEvent::Completed(v)) if v["count"]==7)
        );
    }
    r.close();
    drop(r);
    let r = runtime(&dir, active);
    assert_eq!(
        r.extension_packages().unwrap()[0].archive_hash,
        first.archive_hash
    );
    r.change_extension(first.id.clone(), 1, Some(false))
        .await
        .unwrap();
    assert!(r.extension_providers().unwrap().is_empty());
    let second = install(&r, package(&first.id, "1.1.0", vec![]))
        .await
        .unwrap();
    assert_eq!(second.revision, 3);
    assert!(!second.enabled);
    assert!(
        !std::path::Path::new(
            &r.persistent_store()
                .unwrap()
                .managed_path(&first.resource.id, "")
                .unwrap()
        )
        .exists()
    );
    r.change_extension(first.id.clone(), 3, Some(true))
        .await
        .unwrap();
    assert!(
        r.start_extension(
            provider.id.clone(),
            1,
            ProviderHandler::SendMessage,
            json!({}),
            ScriptLimits::default()
        )
        .await
        .is_err()
    );
    r.change_extension(first.id.clone(), 4, None).await.unwrap();
    assert!(r.extension_packages().unwrap().is_empty());
    let third = install(&r, package(&first.id, "1.2.0", vec![]))
        .await
        .unwrap();
    assert_eq!(third.revision, 6);
    assert!(
        r.start_extension(
            provider.id,
            4,
            ProviderHandler::SendMessage,
            json!({}),
            ScriptLimits::default()
        )
        .await
        .is_err()
    );
    r.close();
}
#[tokio::test]
async fn disable_waits_for_worker_even_without_event_consumer_and_other_runtime_cannot_revoke() {
    let dir = Directory::new();
    let active = Arc::new(AtomicUsize::new(0));
    let r = runtime(&dir, active.clone());
    let p = install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    let run = r
        .start_extension(
            stable_id(&p.id, "fixture"),
            1,
            ProviderHandler::SendMessage,
            json!({"wait":true}),
            ScriptLimits::default(),
        )
        .await
        .unwrap();
    while active.load(Ordering::SeqCst) == 0 {
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    let other = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    assert!(
        other
            .change_extension(p.id.clone(), 1, Some(false))
            .await
            .is_err()
    );
    assert!(other.extension_packages().unwrap()[0].enabled);
    other.close();
    tokio::time::timeout(
        Duration::from_secs(2),
        r.change_extension(p.id, 1, Some(false)),
    )
    .await
    .unwrap()
    .unwrap();
    assert_eq!(active.load(Ordering::SeqCst), 0);
    assert!(
        matches!(run.next_event().await.unwrap(),Some(ScriptEvent::Failed(e)) if e.kind==scripts::ScriptFailureKind::Cancelled)
    );
    r.close();
}
#[tokio::test]
async fn unsafe_paths_native_entries_case_aliases_bad_manifest_crc_and_tampering_are_rejected() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    for name in [
        "../escape",
        "/outside",
        "C:/outside",
        "dist\\file.js",
        ".env",
        "x.dll",
        "DIST/MAIN.JS",
        "con.txt",
    ] {
        assert!(
            install(&r, package("fixture", "1.0.0", vec![(name, b"x".to_vec())]))
                .await
                .is_err(),
            "{name}"
        );
        assert!(r.extension_packages().unwrap().is_empty());
    }
    assert!(
        install(&r, package("fixture", &"x".repeat(129), vec![]))
            .await
            .is_err()
    );
    let mut corrupt = package("fixture", "1.0.0", vec![]);
    let offset = corrupt.windows(7).position(|v| v == b"exports").unwrap();
    corrupt[offset] = b'X';
    assert!(install(&r, corrupt).await.is_err());
    let p = install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    let source = r
        .persistent_store()
        .unwrap()
        .managed_path(&p.resource.id, "source.js")
        .unwrap();
    std::fs::write(source, "changed").unwrap();
    assert!(
        r.start_extension(
            stable_id(&p.id, "fixture"),
            1,
            ProviderHandler::SendMessage,
            json!({}),
            ScriptLimits::default()
        )
        .await
        .is_err()
    );
    r.close();
}
#[tokio::test]
async fn cancelled_partial_import_and_orphaned_install_recover_without_touching_unrelated_resources()
 {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    {
        let import = r.begin_extension_import().unwrap();
        import.append(b"partial".to_vec()).unwrap();
        assert!(r.begin_extension_import().is_err());
    }
    assert!(!dir.0.join("extension-import.tmp").exists());
    let store = r.persistent_store().unwrap();
    let orphan = "0123456789abcdef0123456789abcdef";
    {
        let conn = store.connection.lock().unwrap();
        conn.execute("INSERT INTO resources VALUES(?1,'default','application_private','orphan','application/vnd.kiyori.toolpkg')",[orphan]).unwrap();
        conn.execute("INSERT INTO extension_installs VALUES(?1)", [orphan])
            .unwrap();
    }
    let path = store.managed_path(orphan, "").unwrap();
    std::fs::create_dir_all(&path).unwrap();
    std::fs::write(path.join("source.js"), "partial").unwrap();
    install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    assert!(!path.exists());
    assert_eq!(r.extension_packages().unwrap().len(), 1);
    r.close();
}

struct WaitingRegistration(Arc<AtomicUsize>);
impl ScriptAdapter for WaitingRegistration {
    fn execute(
        &self,
        _: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        _: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure> {
        self.0.fetch_add(1, Ordering::SeqCst);
        while !stopped() {
            std::thread::sleep(Duration::from_millis(1));
        }
        std::thread::sleep(Duration::from_millis(15));
        self.0.fetch_sub(1, Ordering::SeqCst);
        Err(scripts::ScriptFailureKind::Cancelled.into())
    }
}

#[tokio::test]
async fn closing_or_dropping_install_waits_for_registration_and_never_publishes() {
    for drop_future in [false, true] {
        let dir = Directory::new();
        let active = Arc::new(AtomicUsize::new(0));
        let r = Arc::new(Runtime::with_data_dir(&dir.0).unwrap());
        r.set_script_adapter(Arc::new(WaitingRegistration(active.clone())))
            .unwrap();
        let importer = r.begin_extension_import().unwrap();
        importer
            .append(package("fixture", "1.0.0", vec![]))
            .unwrap();
        let running = importer.clone();
        let mut finish = tokio::spawn(async move { running.finish().await });
        tokio::time::timeout(Duration::from_secs(5), async {
            while active.load(Ordering::SeqCst) == 0 {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
        })
        .await
        .unwrap();
        if drop_future {
            finish.abort();
            assert!((&mut finish).await.unwrap_err().is_cancelled());
        }
        tokio::time::timeout(Duration::from_secs(5), importer.close())
            .await
            .unwrap()
            .unwrap();
        if !drop_future {
            assert!(finish.await.unwrap().is_err());
        }
        assert_eq!(active.load(Ordering::SeqCst), 0);
        assert!(!dir.0.join("extension-import.tmp").exists());
        assert!(r.extension_packages().unwrap().is_empty());
        assert_eq!(
            r.persistent_store()
                .unwrap()
                .extension_cleanup_pending()
                .unwrap(),
            0
        );
        r.close();
        drop(importer);
        drop(r);
        let reopened = runtime(&dir, Arc::new(AtomicUsize::new(0)));
        assert!(reopened.extension_packages().unwrap().is_empty());
        install(&reopened, package("fixture", "1.0.0", vec![]))
            .await
            .unwrap();
        reopened.close();
    }
}

#[test]
fn schema18_migration_preserves_resources_and_rolls_back_conflicting_structure() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let id = r.create_conversation().unwrap();
    let store = r.persistent_store().unwrap();
    {
        let connection = store.connection.lock().unwrap();
        remove_schema_for_fixture(&connection);
        connection.execute("INSERT INTO resources VALUES('retained','default','application_private','keep','text/plain')", []).unwrap();
        connection.execute_batch("PRAGMA user_version=18;").unwrap();
    }
    r.close();
    drop(store);
    drop(r);
    let reopened = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    assert!(reopened.conversation(id).is_ok());
    assert!(reopened.extension_packages().unwrap().is_empty());
    let store = reopened.persistent_store().unwrap();
    {
        let connection = store.connection.lock().unwrap();
        assert_eq!(
            connection
                .query_row("SELECT name FROM resources WHERE id='retained'", [], |r| {
                    r.get::<_, String>(0)
                })
                .unwrap(),
            "keep"
        );
        assert_eq!(
            connection
                .pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0))
                .unwrap(),
            20
        );
        // 非法旧库保留19版同名表时必须失败，不静默采纳不兼容结构。
        connection
            .execute_batch("DROP TABLE extension_installs; PRAGMA user_version=18;")
            .unwrap();
    }
    reopened.close();
    drop(store);
    drop(reopened);
    assert!(Runtime::with_data_dir(&dir.0).is_err());
    let connection = rusqlite::Connection::open(dir.0.join("kiyori.sqlite3")).unwrap();
    assert_eq!(
        connection
            .pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0))
            .unwrap(),
        18
    );
    assert_eq!(
        connection
            .query_row(
                "SELECT count(*) FROM sqlite_master WHERE name='extension_installs'",
                [],
                |r| r.get::<_, u32>(0)
            )
            .unwrap(),
        0
    );
}
