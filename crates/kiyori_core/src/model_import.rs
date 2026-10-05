//! 平台仅提供用户选择的有界字节流；核心拥有暂存、hash与Transfer原子交付。
use crate::{
    downloads::{TransferFile, TransferSpec},
    files::{self, error},
    runtime::{CoreError, Runtime},
};
use ring::digest::{Context, SHA256};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Seek, Write},
    path::PathBuf,
    sync::{Arc, Mutex},
};
pub(crate) const IMPORT_SOURCE: &str = "kiyori-import://gguf";
const LIMIT: u64 = 64 * 1024 * 1024 * 1024;
struct State {
    file: File,
    hash: Context,
    bytes: u64,
}
pub struct ModelImport {
    runtime: Arc<Runtime>,
    name: String,
    path: PathBuf,
    state: Mutex<Option<State>>,
    _guard: File,
}
impl Runtime {
    pub fn begin_model_import(self: &Arc<Self>, name: String) -> Result<ModelImport, CoreError> {
        if !files::valid_relative(&name)
            || name.contains('/')
            || !name.to_ascii_lowercase().ends_with(".gguf")
        {
            return Err(error("请选择有效名称的单个GGUF文件"));
        }
        let store = self.persistent_store()?;
        let lock_path = store.directory.join("model-import.lock");
        files::plain(&lock_path)?;
        let guard = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(lock_path)
            .map_err(|_| error("导入锁不可用"))?;
        guard
            .try_lock()
            .map_err(|_| error("已有模型正在导入，请先取消"))?;
        let root = store.directory.join("model-import");
        files::plain(&root)?;
        std::fs::create_dir_all(&root).map_err(|_| error("模型暂存目录不可写"))?;
        // 独占锁取得后，只回收本入口生成的hex临时文件，不触及用户路径。
        for entry in std::fs::read_dir(&root).map_err(|_| error("模型暂存目录不可读"))? {
            let entry = entry.map_err(|_| error("模型暂存目录不可读"))?;
            if entry.file_name().to_str().is_some_and(files::valid_id) {
                files::plain(&entry.path())?;
                if entry.path().is_file() {
                    std::fs::remove_file(entry.path())
                        .map_err(|_| error("中断导入暂存不可回收"))?;
                }
            }
        }
        let id: String = store
            .connection
            .lock()
            .map_err(|_| error("资源存储锁不可用"))?
            .query_row("SELECT lower(hex(randomblob(16)))", [], |r| r.get(0))
            .map_err(|_| error("导入身份创建失败"))?;
        let path = root.join(id);
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create_new(true)
            .open(&path)
            .map_err(|_| error("模型暂存文件不可写"))?;
        Ok(ModelImport {
            runtime: self.clone(),
            name,
            path,
            state: Mutex::new(Some(State {
                file,
                hash: Context::new(&SHA256),
                bytes: 0,
            })),
            _guard: guard,
        })
    }
}
impl ModelImport {
    pub fn append(&self, bytes: Vec<u8>) -> Result<u64, CoreError> {
        self.runtime.ensure_open()?;
        let mut state = self.state.lock().map_err(|_| error("导入状态锁不可用"))?;
        let result = (|| {
            let state = state.as_mut().ok_or_else(|| error("模型导入已结束"))?;
            if bytes.is_empty()
                || bytes.len() > 1024 * 1024
                || bytes.len() as u64 > LIMIT - state.bytes
            {
                return Err(error("导入分片超过1 MiB或模型超过64 GiB"));
            }
            state
                .file
                .write_all(&bytes)
                .map_err(|_| error("模型导入写入失败，请检查可用空间"))?;
            state.hash.update(&bytes);
            state.bytes += bytes.len() as u64;
            Ok(state.bytes)
        })();
        if result.is_err() {
            state.take();
        }
        result
    }
    pub fn finish(&self) -> Result<String, CoreError> {
        self.runtime.ensure_open()?;
        // 持锁直至交付结束；close不能提前删暂存或释放全局导入锁。
        let mut locked = self.state.lock().map_err(|_| error("导入状态锁不可用"))?;
        let mut state = locked.take().ok_or_else(|| error("模型导入已结束"))?;
        // llama_load负责完整格式校验；交付前拒绝截断头、非GGUF与无tensor空壳。
        let mut header = [0u8; 24];
        state.file.rewind().map_err(|_| error("模型导入校验失败"))?;
        state
            .file
            .read_exact(&mut header)
            .map_err(|_| error("GGUF头已截断"))?;
        let version = u32::from_le_bytes(header[4..8].try_into().map_err(|_| error("GGUF头无效"))?);
        let tensors =
            u64::from_le_bytes(header[8..16].try_into().map_err(|_| error("GGUF头无效"))?);
        let metadata =
            u64::from_le_bytes(header[16..24].try_into().map_err(|_| error("GGUF头无效"))?);
        if &header[..4] != b"GGUF"
            || !matches!(version, 2 | 3)
            || tensors == 0
            || tensors > 1_000_000
            || metadata > 1_000_000
            || state.bytes <= 24
        {
            return Err(error("GGUF格式、版本或tensor数量无效"));
        }
        state
            .file
            .sync_all()
            .map_err(|_| error("模型导入落盘失败"))?;
        let size = state.bytes;
        let sha256: String = state
            .hash
            .finish()
            .as_ref()
            .iter()
            .map(|v| format!("{v:02x}"))
            .collect();
        drop(state.file);
        let id = self.runtime.create_transfer(TransferSpec {
            owner: format!("llama:{}", self.name),
            name: self.name.clone(),
            files: vec![TransferFile {
                path: self.name.clone(),
                url: IMPORT_SOURCE.into(),
                size,
                sha256,
            }],
        })?;
        let store = self.runtime.persistent_store()?;
        let _guard = store.transfer_lock(&id)?;
        store.transfer(&id)?;
        let root = store.managed_path(&id, "")?;
        std::fs::create_dir_all(&root).map_err(|_| error("模型资源目录不可写"))?;
        let target = store.managed_path(&id, &self.name)?;
        if target.exists() {
            // 崩溃可能发生在rename后、事务前；只在完整hash再次一致时对账，不覆盖现有文件。
            let mut file = File::open(&target).map_err(|_| error("未完成资源不可读"))?;
            if file
                .metadata()
                .map_err(|_| error("未完成资源状态不可读"))?
                .len()
                != size
            {
                return Err(error("未完成资源大小已变化，请先删除该资源再导入"));
            }
            let mut hash = Context::new(&SHA256);
            let mut chunk = vec![0; 1024 * 1024];
            loop {
                self.runtime.ensure_open()?;
                let count = file
                    .read(&mut chunk)
                    .map_err(|_| error("未完成资源不可读"))?;
                if count == 0 {
                    break;
                }
                hash.update(&chunk[..count]);
            }
            let actual: String = hash
                .finish()
                .as_ref()
                .iter()
                .map(|v| format!("{v:02x}"))
                .collect();
            if actual != store.transfer(&id)?.0.files[0].sha256 {
                return Err(error("未完成资源内容已变化，请先删除该资源再导入"));
            }
        } else {
            std::fs::rename(&self.path, target).map_err(|_| error("模型导入原子交付失败"))?;
        }
        self.runtime.with_store(|s| {
            let mut conn = s.connection.lock().map_err(|_| error("资源存储锁不可用"))?;
            let tx = conn.transaction().map_err(|_| error("导入事务不可用"))?;
            tx.execute(
                "UPDATE transfer_files SET confirmed=?2,verified=1 WHERE transfer_id=?1",
                rusqlite::params![id, size as i64],
            )
            .map_err(|_| error("导入文件状态保存失败"))?;
            tx.execute(
                "UPDATE transfers SET phase='completed',error='' WHERE id=?1",
                [&id],
            )
            .map_err(|_| error("导入资源状态保存失败"))?;
            tx.commit().map_err(|_| error("导入事务提交失败"))
        })?;
        Ok(self.name.clone())
    }
    pub fn close(&self) {
        if let Ok(mut state) = self.state.lock() {
            state.take();
            let _ = std::fs::remove_file(&self.path);
            let _ = self._guard.unlock();
        }
    }
}
impl Drop for ModelImport {
    fn drop(&mut self) {
        self.close();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn data() -> (PathBuf, Arc<Runtime>) {
        // Windows时钟分辨率不能保证同一测试进程的并行夹具目录唯一。
        static NEXT: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let path = std::env::temp_dir().join(format!(
            "kiyori-import-{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed),
        ));
        let runtime = Arc::new(Runtime::with_data_dir(&path).unwrap());
        (path, runtime)
    }
    fn gguf() -> Vec<u8> {
        let mut bytes = Vec::from(b"GGUF".as_slice());
        bytes.extend(3u32.to_le_bytes());
        bytes.extend(1u64.to_le_bytes());
        bytes.extend(1u64.to_le_bytes());
        bytes.extend(vec![17; 1024 * 1024 + 7]);
        bytes
    }
    fn cleanup(path: &std::path::Path) {
        // Windows安全软件可短暂打开刚写入的临时文件；重试仍保留最终删除成功断言。
        for attempt in 0..10 {
            match std::fs::remove_dir_all(path) {
                Ok(()) => return,
                Err(_) if attempt < 9 => std::thread::sleep(std::time::Duration::from_millis(20)),
                Err(error) => panic!("temporary import fixture cleanup failed: {error}"),
            }
        }
    }
    #[test]
    fn import_hash_atomic_delivery_repeat_conflict_and_managed_resource() {
        let (path, runtime) = data();
        let bytes = gguf();
        let import = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in bytes.chunks(1024 * 1024) {
            import.append(chunk.to_vec()).unwrap();
        }
        assert!(runtime.transfers().unwrap().is_empty());
        assert_eq!(import.finish().unwrap(), "fixture.gguf");
        import.close();
        let transfers = runtime.transfers().unwrap();
        assert_eq!(transfers.len(), 1);
        let snapshot = &transfers[0];
        assert_eq!(snapshot.phase, "completed");
        assert_eq!(snapshot.total, bytes.len() as u64);
        let resource = runtime
            .resource_file_path(snapshot.resource.id.clone(), "fixture.gguf".into())
            .unwrap();
        assert_eq!(std::fs::read(resource).unwrap(), bytes);
        let store = runtime.persistent_store().unwrap();
        let (spec, _) = store.transfer(&snapshot.resource.id).unwrap();
        let expected: String = ring::digest::digest(&SHA256, &bytes)
            .as_ref()
            .iter()
            .map(|v| format!("{v:02x}"))
            .collect();
        assert_eq!(spec.files[0].sha256, expected);
        assert!(
            runtime
                .start_transfer(snapshot.resource.id.clone())
                .is_err()
        );
        let same = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in bytes.chunks(1024 * 1024) {
            same.append(chunk.to_vec()).unwrap();
        }
        assert_eq!(same.finish().unwrap(), "fixture.gguf");
        same.close();
        // 模拟rename已完成而SQLite事务未提交；重选同一文件能hash对账完成。
        store
            .connection
            .lock()
            .unwrap()
            .execute(
                "UPDATE transfers SET phase='queued' WHERE id=?1",
                [&snapshot.resource.id],
            )
            .unwrap();
        store
            .connection
            .lock()
            .unwrap()
            .execute(
                "UPDATE transfer_files SET confirmed=0,verified=0 WHERE transfer_id=?1",
                [&snapshot.resource.id],
            )
            .unwrap();
        let recovered = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in bytes.chunks(1024 * 1024) {
            recovered.append(chunk.to_vec()).unwrap();
        }
        assert_eq!(recovered.finish().unwrap(), "fixture.gguf");
        recovered.close();
        assert_eq!(runtime.transfers().unwrap()[0].phase, "completed");
        // completed是数据库事实，不能跳过资源检查；重选可补回缺失文件，篡改内容须拒绝。
        let resource = runtime
            .resource_file_path(snapshot.resource.id.clone(), "fixture.gguf".into())
            .unwrap();
        std::fs::remove_file(&resource).unwrap();
        let repaired = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in bytes.chunks(1024 * 1024) {
            repaired.append(chunk.to_vec()).unwrap();
        }
        assert_eq!(repaired.finish().unwrap(), "fixture.gguf");
        repaired.close();
        assert_eq!(std::fs::read(&resource).unwrap(), bytes);
        let mut changed = bytes.clone();
        *changed.last_mut().unwrap() = 1;
        std::fs::write(&resource, &changed).unwrap();
        let tampered = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in bytes.chunks(1024 * 1024) {
            tampered.append(chunk.to_vec()).unwrap();
        }
        assert!(tampered.finish().is_err());
        tampered.close();
        assert_eq!(std::fs::read(&resource).unwrap(), changed);
        std::fs::write(&resource, &bytes).unwrap();
        let conflict = runtime.begin_model_import("fixture.gguf".into()).unwrap();
        for chunk in changed.chunks(1024 * 1024) {
            conflict.append(chunk.to_vec()).unwrap();
        }
        assert!(conflict.finish().is_err());
        conflict.close();
        assert_eq!(runtime.transfers().unwrap().len(), 1);
        runtime
            .delete_transfer(snapshot.resource.id.clone())
            .unwrap();
        assert!(runtime.transfers().unwrap().is_empty());
        runtime.close();
        drop(runtime);
        drop(store);
        drop(import);
        drop(same);
        drop(conflict);
        drop(recovered);
        drop(repaired);
        drop(tampered);
        cleanup(&path);
    }
    #[test]
    fn invalid_input_cancel_exclusion_and_interrupted_staging_cleanup() {
        let (path, runtime) = data();
        for name in [
            "../bad.gguf",
            "C:/bad.gguf",
            "file.bin",
            "folder/file.gguf",
            "CON.gguf",
        ] {
            assert!(runtime.begin_model_import(name.into()).is_err());
        }
        let first = runtime.begin_model_import("one.gguf".into()).unwrap();
        assert!(runtime.begin_model_import("two.gguf".into()).is_err());
        assert!(first.append(vec![0; 1024 * 1024 + 1]).is_err());
        assert!(first.append(vec![1]).is_err());
        first.close();
        let bad = runtime.begin_model_import("bad.gguf".into()).unwrap();
        bad.append(vec![1; 100]).unwrap();
        assert!(bad.finish().is_err());
        bad.close();
        let cancelled = runtime.begin_model_import("cancelled.gguf".into()).unwrap();
        cancelled.append(gguf()[..50].to_vec()).unwrap();
        cancelled.close();
        assert!(runtime.transfers().unwrap().is_empty());
        assert!(!cancelled.path.exists());
        let stale = path.join("model-import/0123456789abcdef0123456789abcdef");
        std::fs::write(&stale, b"interrupted").unwrap();
        let resumed = runtime.begin_model_import("again.gguf".into()).unwrap();
        assert!(!stale.exists());
        runtime.close();
        assert!(resumed.append(vec![1]).is_err());
        assert!(resumed.finish().is_err());
        resumed.close();
        drop(first);
        drop(bad);
        drop(cancelled);
        drop(resumed);
        drop(runtime);
        cleanup(&path);
    }
}
