//! TOOLPKG身份/资源/持久注册归同一AppStore；生命周期变更先撤销新调用，再等待旧worker。
mod archive;
pub mod http;
use crate::{
    files::{self, ResourceRef, error},
    runtime::{CoreError, Runtime},
    scripts::{
        self, ProviderHandler, ProviderRegistration, ScriptEvent, ScriptLimits, ScriptOperation,
        ScriptRequest, ScriptRun,
    },
    storage::AppStore,
};
use ring::digest::{SHA256, digest};
use rusqlite::{OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    collections::HashMap,
    fs::{File, OpenOptions},
    io::{Read, Seek, Write},
    path::PathBuf,
    sync::{
        Arc, Condvar, Mutex,
        atomic::{AtomicU64, Ordering},
    },
};
use tokio_util::sync::CancellationToken;

pub(crate) const SCHEMA:&str="CREATE TABLE extension_packages(package_id TEXT PRIMARY KEY NOT NULL,revision INTEGER NOT NULL,resource_id TEXT REFERENCES resources(id),version TEXT NOT NULL,name TEXT NOT NULL,description TEXT NOT NULL,enabled INTEGER NOT NULL,archive_hash TEXT NOT NULL,source_hash TEXT NOT NULL,providers TEXT NOT NULL);
CREATE TABLE extension_installs(resource_id TEXT PRIMARY KEY REFERENCES resources(id) ON DELETE CASCADE);
PRAGMA user_version=19;";
#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(connection: &rusqlite::Connection) {
    crate::conversation_audit::remove_schema_for_fixture(connection);
    // 旧版本夹具必须先去掉子表，不能留下19版结构再伪装旧user_version。
    connection
        .execute_batch("DROP TABLE extension_installs; DROP TABLE extension_packages;")
        .unwrap();
}
const MAX_ARCHIVE: u64 = 16 * 1024 * 1024;
#[derive(Debug, Clone)]
pub struct ExtensionPackage {
    pub cleanup_pending: u32,
    pub id: String,
    pub revision: u32,
    pub version: String,
    pub name: String,
    pub description: String,
    pub enabled: bool,
    pub resource: ResourceRef,
    pub archive_hash: String,
    pub source_hash: String,
    pub providers: Vec<ProviderRegistration>,
}
#[derive(Debug, Clone)]
pub struct ExtensionProvider {
    pub id: String,
    pub package_id: String,
    pub provider_id: String,
    pub revision: u32,
    pub display_name: String,
    pub description: String,
}
#[derive(Debug, Clone)]
pub struct ExtensionDetails {
    pub package: ExtensionPackage,
    pub authors: Vec<String>,
    pub category: String,
    pub api_version: String,
}
fn stable_id(package: &str, provider: &str) -> String {
    format!("TOOLPKG:{package}:{provider}")
}
fn hash(bytes: &[u8]) -> String {
    digest(&SHA256, bytes)
        .as_ref()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}
#[derive(Default)]
pub(crate) struct Registry {
    mutation: tokio::sync::Mutex<()>,
    scopes: Mutex<HashMap<String, std::sync::Weak<Scope>>>,
    sequence: AtomicU64,
}
#[derive(Default)]
struct Scope {
    state: Mutex<ScopeState>,
    wake: Condvar,
}
#[derive(Default)]
struct ScopeState {
    blocked: bool,
    calls: HashMap<u64, CancellationToken>,
}
struct Lease {
    scope: Arc<Scope>,
    id: u64,
    file: Option<File>,
}
pub(crate) struct Invocation {
    pub request: ScriptRequest,
    pub lease: Box<dyn Send>,
}
pub(crate) struct ProviderCall {
    pub handler: ProviderHandler,
    pub payload: Value,
    pub limits: ScriptLimits,
}
impl Drop for Lease {
    fn drop(&mut self) {
        // 撤销等待被唤醒之前先释放OS共享锁，不能让同线程析构的尾部误报忙。
        self.file.take();
        let mut state = self
            .scope
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        state.calls.remove(&self.id);
        self.scope.wake.notify_all();
    }
}
struct Suspended(Arc<Scope>);
impl Drop for Suspended {
    fn drop(&mut self) {
        self.0
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .blocked = false;
    }
}
impl Registry {
    pub(crate) fn wait_idle(&self) {
        let scopes: Vec<_> = self
            .scopes
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .values()
            .filter_map(std::sync::Weak::upgrade)
            .collect();
        for scope in scopes {
            let mut state = scope
                .state
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            for token in state.calls.values() {
                token.cancel();
            }
            while !state.calls.is_empty() {
                state = scope
                    .wake
                    .wait(state)
                    .unwrap_or_else(std::sync::PoisonError::into_inner);
            }
        }
    }
    pub(crate) fn prepare(
        &self,
        store: &AppStore,
        id: &str,
        revision: u32,
        call: ProviderCall,
        token: CancellationToken,
    ) -> Result<Invocation, CoreError> {
        let (package_id, provider_id) = provider_parts(id)?;
        let lease = self.lease(store, package_id, token)?;
        let package = store.extension(package_id)?;
        if !package.enabled
            || package.revision != revision
            || !package.providers.iter().any(|p| p.id == provider_id)
        {
            return Err(error("扩展已停用、变更或供应商不存在"));
        }
        Ok(Invocation {
            request: ScriptRequest {
                source: store.source(&package)?,
                operation: ScriptOperation::Invoke {
                    provider_id: provider_id.into(),
                    handler: call.handler,
                    payload: call.payload,
                },
                limits: call.limits,
            },
            lease: Box::new(lease),
        })
    }
    fn scope(&self, id: &str) -> Arc<Scope> {
        let mut scopes = self
            .scopes
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        // 只保留正在使用的scope；不存在/已卸载ID不能积累第二个常驻目录。
        scopes.retain(|_, scope| scope.strong_count() != 0);
        if let Some(scope) = scopes.get(id).and_then(std::sync::Weak::upgrade) {
            return scope;
        }
        let scope = Arc::new(Scope::default());
        scopes.insert(id.into(), Arc::downgrade(&scope));
        scope
    }
    async fn suspend(&self, id: &str) -> Result<Suspended, CoreError> {
        let scope = self.scope(id);
        {
            let mut state = scope
                .state
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            state.blocked = true;
            for token in state.calls.values() {
                token.cancel();
            }
        }
        let guard = Suspended(scope.clone());
        tokio::task::spawn_blocking(move || {
            let mut state = scope
                .state
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            while !state.calls.is_empty() {
                state = scope
                    .wake
                    .wait(state)
                    .unwrap_or_else(std::sync::PoisonError::into_inner);
            }
        })
        .await
        .map_err(|_| error("扩展停止等待失败"))?;
        Ok(guard)
    }
    fn lease(
        &self,
        store: &AppStore,
        id: &str,
        token: CancellationToken,
    ) -> Result<Lease, CoreError> {
        let scope = self.scope(id);
        let mut state = scope
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if state.blocked || token.is_cancelled() {
            return Err(error("扩展正在变更，请稍后重试"));
        }
        let file = package_lock(store, id)?;
        file.try_lock_shared()
            .map_err(|_| error("另一个运行时正在变更此扩展"))?;
        let key = self.sequence.fetch_add(1, Ordering::Relaxed);
        state.calls.insert(key, token);
        drop(state);
        Ok(Lease {
            scope,
            id: key,
            file: Some(file),
        })
    }
}
pub(crate) fn provider_parts(id: &str) -> Result<(&str, &str), CoreError> {
    let mut parts = id.split(':');
    if parts.next() != Some("TOOLPKG") {
        return Err(error("扩展供应商身份无效"));
    }
    let package = parts
        .next()
        .filter(|v| scripts::valid_id(v))
        .ok_or_else(|| error("扩展供应商身份无效"))?;
    let provider = parts
        .next()
        .filter(|v| scripts::valid_id(v))
        .ok_or_else(|| error("扩展供应商身份无效"))?;
    if parts.next().is_some() {
        return Err(error("扩展供应商身份无效"));
    }
    Ok((package, provider))
}
fn lock(store: &AppStore, name: &str) -> Result<File, CoreError> {
    let path = store.directory.join(name);
    files::plain(&path)?;
    OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(path)
        .map_err(|_| error("扩展生命周期锁不可用"))
}
fn package_lock(store: &AppStore, id: &str) -> Result<File, CoreError> {
    if !scripts::valid_id(id) {
        return Err(error("扩展包ID无效"));
    }
    // 包ID经摘要转为路径，不受大小写或Windows设备名影响。
    lock(store, &format!("extension-{}.lock", hash(id.as_bytes())))
}
fn mutation_lock(store: &AppStore) -> Result<File, CoreError> {
    let file = lock(store, "extension-mutation.lock")?;
    file.try_lock().map_err(|_| error("已有扩展生命周期变更"))?;
    Ok(file)
}
impl AppStore {
    fn extension_cleanup_pending(&self) -> Result<u32, CoreError> {
        self.connection
            .lock()
            .map_err(|_| error("扩展存储锁不可用"))?
            .query_row("SELECT count(*) FROM extension_installs", [], |r| r.get(0))
            .map_err(|_| error("扩展维护状态不可读"))
    }
    fn extension(&self, id: &str) -> Result<ExtensionPackage, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| error("扩展存储锁不可用"))?;
        let row=connection.query_row("SELECT e.revision,e.version,e.name,e.description,e.enabled,e.resource_id,e.archive_hash,e.source_hash,e.providers,r.workspace,r.source,r.mime FROM extension_packages e JOIN resources r ON r.id=e.resource_id WHERE e.package_id=?1",[id],|r|Ok((r.get::<_,u32>(0)?,r.get::<_,String>(1)?,r.get::<_,String>(2)?,r.get::<_,String>(3)?,r.get::<_,bool>(4)?,r.get::<_,String>(5)?,r.get::<_,String>(6)?,r.get::<_,String>(7)?,r.get::<_,String>(8)?,r.get::<_,String>(9)?,r.get::<_,String>(10)?,r.get::<_,String>(11)?))).optional().map_err(|_|error("扩展读取失败"))?.ok_or_else(||error("扩展已卸载或不存在"))?;
        let providers = serde_json::from_str(&row.8).map_err(|_| error("扩展目录数据无效"))?;
        Ok(ExtensionPackage {
            cleanup_pending: connection
                .query_row("SELECT count(*) FROM extension_installs", [], |r| r.get(0))
                .map_err(|_| error("扩展维护状态不可读"))?,
            id: id.into(),
            revision: row.0,
            version: row.1,
            name: row.2.clone(),
            description: row.3,
            enabled: row.4,
            resource: ResourceRef {
                id: row.5,
                workspace: row.9,
                source: row.10,
                name: row.2,
                mime: row.11,
            },
            archive_hash: row.6,
            source_hash: row.7,
            providers,
        })
    }
    fn source(&self, package: &ExtensionPackage) -> Result<String, CoreError> {
        let path = self.managed_path(&package.resource.id, "source.js")?;
        let file = File::open(path).map_err(|_| error("扩展入口已不可用"))?;
        if !file
            .metadata()
            .map_err(|_| error("扩展入口不可读"))?
            .is_file()
        {
            return Err(error("扩展入口不是普通文件"));
        }
        let mut bytes = Vec::new();
        file.take(2 * 1024 * 1024 + 1)
            .read_to_end(&mut bytes)
            .map_err(|_| error("扩展入口不可读"))?;
        if bytes.len() > 2 * 1024 * 1024 || hash(&bytes) != package.source_hash {
            return Err(error("扩展入口完整性校验失败，请重新安装"));
        }
        String::from_utf8(bytes).map_err(|_| error("扩展入口编码无效"))
    }
    fn cleanup_resource(&self, id: &str) -> Result<(), CoreError> {
        let root = self.managed_path(id, "")?;
        // 仅本入口拥有的两份文件；异常用户内容/链接拒绝删除，不递归遍历未知目录。
        if root.exists() {
            for entry in std::fs::read_dir(&root).map_err(|_| error("扩展资源不可读"))? {
                let entry = entry.map_err(|_| error("扩展资源不可读"))?;
                if !matches!(
                    entry.file_name().to_str(),
                    Some("source.js" | "archive.toolpkg")
                ) {
                    return Err(error("扩展资源含未知文件，无法自动回收"));
                }
                files::plain(&entry.path())?;
                if !entry
                    .file_type()
                    .map_err(|_| error("扩展资源不可读"))?
                    .is_file()
                {
                    return Err(error("扩展资源不是普通文件"));
                }
            }
            for name in ["source.js", "archive.toolpkg"] {
                let file = root.join(name);
                if file.exists() {
                    std::fs::remove_file(file).map_err(|_| error("扩展资源回收失败"))?;
                }
            }
            std::fs::remove_dir(root).map_err(|_| error("扩展资源回收失败"))?;
        }
        self.connection.lock().map_err(|_|error("扩展存储锁不可用"))?.execute("DELETE FROM resources WHERE id=?1 AND NOT EXISTS(SELECT 1 FROM extension_packages WHERE resource_id=?1)",[id]).map_err(|_|error("扩展资源记录回收失败"))?;
        Ok(())
    }
    fn recover_extensions(&self) -> Result<(), CoreError> {
        let ids=self.connection.lock().map_err(|_|error("扩展存储锁不可用"))?.prepare("SELECT resource_id FROM extension_installs WHERE NOT EXISTS(SELECT 1 FROM extension_packages WHERE resource_id=extension_installs.resource_id)").map_err(|_|error("扩展恢复读取失败"))?.query_map([],|r|r.get::<_,String>(0)).map_err(|_|error("扩展恢复读取失败"))?.collect::<Result<Vec<_>,_>>().map_err(|_|error("扩展恢复读取失败"))?;
        for id in ids {
            self.cleanup_resource(&id)?;
        }
        Ok(())
    }
}
impl Runtime {
    /// 仅详情读取原包；持共享租约并在blocking worker核验摘要，不在UI帧中解压。
    pub async fn extension_details(
        &self,
        id: String,
        revision: u32,
    ) -> Result<ExtensionDetails, CoreError> {
        let store = self.persistent_store()?;
        let cancellation = self.cancellation.child_token();
        let lease = self.extensions.lease(&store, &id, cancellation.clone())?;
        tokio::task::spawn_blocking(move || {
            let _lease = lease;
            let package = store.extension(&id)?;
            if package.revision != revision {
                return Err(error("扩展已变更，请重新打开详情"));
            }
            let path = store.managed_path(&package.resource.id, "archive.toolpkg")?;
            let mut file = File::open(path).map_err(|_| error("扩展原包不可读"))?;
            if file.metadata().map_err(|_| error("扩展原包不可读"))?.len() > MAX_ARCHIVE {
                return Err(error("扩展原包超过限制"));
            }
            let mut digest = ring::digest::Context::new(&SHA256);
            let mut chunk = [0u8; 64 * 1024];
            let mut total = 0u64;
            loop {
                if cancellation.is_cancelled() {
                    return Err(error("扩展详情读取已取消"));
                }
                let size = file.read(&mut chunk).map_err(|_| error("扩展原包不可读"))?;
                if size == 0 {
                    break;
                }
                total += size as u64;
                if total > MAX_ARCHIVE {
                    return Err(error("扩展原包超过限制"));
                }
                digest.update(&chunk[..size]);
            }
            let digest: String = digest
                .finish()
                .as_ref()
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect();
            if digest != package.archive_hash {
                return Err(error("扩展原包完整性校验失败"));
            }
            let manifest = archive::read(&mut file)?.manifest;
            let authors = match manifest.extra.get("author") {
                None | Some(Value::Null) => vec![],
                Some(Value::String(author)) => vec![author.clone()],
                Some(Value::Array(values)) => values
                    .iter()
                    .map(|v| {
                        v.as_str()
                            .map(str::to_owned)
                            .ok_or_else(|| error("扩展作者无效"))
                    })
                    .collect::<Result<Vec<_>, _>>()?,
                _ => return Err(error("扩展作者无效")),
            };
            if authors.len() > 32 || authors.iter().any(|v| v.len() > 1024 || v.contains('\0')) {
                return Err(error("扩展作者无效"));
            }
            let category = archive::label(manifest.extra.get("category").unwrap_or(&Value::Null))?;
            let api_version = manifest
                .extra
                .get("api_version")
                .and_then(Value::as_str)
                .unwrap_or("1.0.0")
                .to_owned();
            Ok(ExtensionDetails {
                package,
                authors,
                category,
                api_version,
            })
        })
        .await
        .map_err(|_| error("扩展详情读取中断"))?
    }
    pub fn extension_packages(&self) -> Result<Vec<ExtensionPackage>, CoreError> {
        self.with_store(|store|{
            let ids=store.connection.lock().map_err(|_|error("扩展存储锁不可用"))?.prepare("SELECT package_id FROM extension_packages WHERE resource_id IS NOT NULL ORDER BY name,package_id").map_err(|_|error("扩展目录读取失败"))?.query_map([],|r|r.get::<_,String>(0)).map_err(|_|error("扩展目录读取失败"))?.collect::<Result<Vec<_>,_>>().map_err(|_|error("扩展目录读取失败"))?;
            ids.iter().map(|id|store.extension(id)).collect()
        })
    }
    pub fn extension_providers(&self) -> Result<Vec<ExtensionProvider>, CoreError> {
        Ok(self
            .extension_packages()?
            .into_iter()
            .filter(|p| p.enabled)
            .flat_map(|p| {
                p.providers.into_iter().map(move |entry| ExtensionProvider {
                    id: stable_id(&p.id, &entry.id),
                    package_id: p.id.clone(),
                    provider_id: entry.id,
                    revision: p.revision,
                    display_name: entry.display_name,
                    description: entry.description,
                })
            })
            .collect())
    }
    pub async fn start_extension(
        &self,
        id: String,
        revision: u32,
        handler: ProviderHandler,
        payload: Value,
        limits: ScriptLimits,
    ) -> Result<ScriptRun, CoreError> {
        self.start_extension_with_http(id, revision, handler, payload, limits, None)
            .await
    }
    /// HTTP能力由可信模型owner冻结配置后装配，原始FFI调用不会自动获网络权限。
    pub async fn start_extension_with_http(
        &self,
        id: String,
        revision: u32,
        handler: ProviderHandler,
        payload: Value,
        limits: ScriptLimits,
        http: Option<Arc<dyn scripts::ScriptHttpHost>>,
    ) -> Result<ScriptRun, CoreError> {
        let store = self.persistent_store()?;
        let token = self.cancellation.child_token();
        let call = self.extensions.prepare(
            &store,
            &id,
            revision,
            ProviderCall {
                handler,
                payload,
                limits,
            },
            token.clone(),
        )?;
        self.start_script_owned(call.request, token, Some(call.lease), http)
            .await
            .map_err(|e| error(&e.to_string()))
    }
    pub async fn change_extension(
        &self,
        id: String,
        revision: u32,
        enabled: Option<bool>,
    ) -> Result<u32, CoreError> {
        let _mutation = self.extensions.mutation.lock().await;
        let store = self.persistent_store()?;
        let _global = mutation_lock(&store)?;
        let package = store.extension(&id)?;
        if package.revision != revision {
            return Err(error("扩展已变更，请刷新"));
        }
        if revision == u32::MAX {
            return Err(error("扩展代次已耗尽"));
        }
        let _suspended = self.extensions.suspend(&id).await?;
        let exclusive = package_lock(&store, &id)?;
        exclusive
            .try_lock()
            .map_err(|_| error("其他进程仍在使用此扩展"))?;
        self.with_store(|store|{
            let mut conn=store.connection.lock().map_err(|_|error("扩展存储锁不可用"))?;
            let tx=conn.transaction().map_err(|_|error("扩展变更事务失败"))?;
            let changed=if let Some(enabled)=enabled{tx.execute("UPDATE extension_packages SET revision=revision+1,enabled=?3 WHERE package_id=?1 AND revision=?2 AND resource_id IS NOT NULL",params![id,revision,enabled])}else{
                // 卸载保留墓碑代次与配置引用；不能同ID重装后接受旧请求。
                tx.execute("UPDATE extension_packages SET revision=revision+1,enabled=0,resource_id=NULL,providers='[]' WHERE package_id=?1 AND revision=?2 AND resource_id IS NOT NULL",params![id,revision])
            }.map_err(|_|error("扩展变更保存失败"))?;
            if changed!=1{return Err(error("扩展已变更，请刷新"));}
            if enabled.is_none(){tx.execute("INSERT OR IGNORE INTO extension_installs VALUES(?1)",[&package.resource.id]).map_err(|_|error("扩展回收记录失败"))?;}
            tx.commit().map_err(|_|error("扩展变更提交失败"))
        })?;
        // 事务已成为事实；回收失败仍留持久记录，由下次安装恢复，不能误报为未卸载。
        if enabled.is_none() {
            let _ = store.recover_extensions();
        }
        store.extension_cleanup_pending()
    }
    pub fn begin_extension_import(self: &Arc<Self>) -> Result<Arc<ExtensionImport>, CoreError> {
        let store = self.persistent_store()?;
        let guard = lock(&store, "extension-import.lock")?;
        guard.try_lock().map_err(|_| error("已有扩展包正在导入"))?;
        let path = store.directory.join("extension-import.tmp");
        files::plain(&path)?;
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(true)
            .open(&path)
            .map_err(|_| error("扩展暂存不可写"))?;
        Ok(Arc::new(ExtensionImport {
            runtime: self.clone(),
            path,
            state: Mutex::new(Some(ImportState { file, bytes: 0 })),
            operation: tokio::sync::Mutex::new(()),
            cancellation: self.cancellation.child_token(),
            _guard: guard,
        }))
    }
}
struct ImportState {
    file: File,
    bytes: u64,
}
pub struct ExtensionImport {
    runtime: Arc<Runtime>,
    path: PathBuf,
    state: Mutex<Option<ImportState>>,
    operation: tokio::sync::Mutex<()>,
    cancellation: CancellationToken,
    _guard: File,
}
impl Drop for ExtensionImport {
    fn drop(&mut self) {
        self.state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .take();
        let _ = std::fs::remove_file(&self.path);
    }
}
impl ExtensionImport {
    pub fn append(&self, bytes: Vec<u8>) -> Result<u64, CoreError> {
        self.runtime.ensure_open()?;
        if self.cancellation.is_cancelled() {
            return Err(error("扩展导入已取消"));
        }
        let mut state = self.state.lock().map_err(|_| error("扩展导入锁不可用"))?;
        let state = state.as_mut().ok_or_else(|| error("扩展导入已结束"))?;
        if bytes.is_empty()
            || bytes.len() > 1024 * 1024
            || bytes.len() as u64 > MAX_ARCHIVE - state.bytes
        {
            return Err(error("扩展分片超过1 MiB或包超过16 MiB"));
        }
        state
            .file
            .write_all(&bytes)
            .map_err(|_| error("扩展暂存写入失败"))?;
        state.bytes += bytes.len() as u64;
        Ok(state.bytes)
    }
    pub async fn close(&self) -> Result<(), CoreError> {
        self.cancellation.cancel();
        let _operation = self.operation.lock().await;
        self.state
            .lock()
            .map_err(|_| error("扩展导入锁不可用"))?
            .take();
        match std::fs::remove_file(&self.path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(_) => Err(error("扩展暂存回收失败")),
        }
    }
    pub async fn finish(self: &Arc<Self>) -> Result<ExtensionPackage, CoreError> {
        let import = self.clone();
        // 外部Future丢弃也取消内部任务；close等待它释放暂存/JS句柄后再删除。
        let guard = self.cancellation.clone().drop_guard();
        let result = tokio::spawn(async move { import.finish_inner().await })
            .await
            .map_err(|_| error("扩展安装任务中断"))?;
        guard.disarm();
        result
    }
    async fn finish_inner(&self) -> Result<ExtensionPackage, CoreError> {
        let _operation = self.operation.lock().await;
        self.runtime.ensure_open()?;
        if self.cancellation.is_cancelled() {
            return Err(error("扩展导入已取消"));
        }
        let mut state = self
            .state
            .lock()
            .map_err(|_| error("扩展导入锁不可用"))?
            .take()
            .ok_or_else(|| error("扩展导入已结束"))?;
        let (checked, archive_hash) = tokio::task::spawn_blocking(move || {
            state
                .file
                .sync_all()
                .map_err(|_| error("扩展暂存同步失败"))?;
            let checked = archive::read(&mut state.file)?;
            state.file.rewind().map_err(|_| error("扩展暂存读取失败"))?;
            let mut bytes = Vec::new();
            state
                .file
                .take(MAX_ARCHIVE + 1)
                .read_to_end(&mut bytes)
                .map_err(|_| error("扩展暂存读取失败"))?;
            if bytes.len() > MAX_ARCHIVE as usize {
                return Err(error("扩展包超过16 MiB"));
            }
            Ok((checked, hash(&bytes)))
        })
        .await
        .map_err(|_| error("扩展校验任务失败"))??;
        let run = self
            .runtime
            .start_script_owned(
                ScriptRequest {
                    source: checked.source.clone(),
                    operation: ScriptOperation::Register,
                    limits: ScriptLimits::default(),
                },
                self.cancellation.child_token(),
                None,
                None,
            )
            .await
            .map_err(|e| error(&e.to_string()))?;
        let providers = match run.next_event().await.map_err(|e| error(&e.to_string()))? {
            Some(ScriptEvent::Completed(value)) => {
                scripts::registrations(value).map_err(|e| error(&e.to_string()))?
            }
            Some(ScriptEvent::Failed(e)) => return Err(error(&e.to_string())),
            Some(ScriptEvent::Intermediate(_)) => {
                run.cancel_and_wait()
                    .await
                    .map_err(|e| error(&e.to_string()))?;
                return Err(error("注册阶段不能发布业务结果"));
            }
            None => return Err(error("扩展注册终态缺失")),
        };
        if providers.is_empty() {
            return Err(error("扩展未注册模型供应商"));
        }
        let _mutation = self.runtime.extensions.mutation.lock().await;
        if self.cancellation.is_cancelled() {
            return Err(error("扩展导入已取消"));
        }
        let store = self.runtime.persistent_store()?;
        let _global = mutation_lock(&store)?;
        store.recover_extensions()?;
        let id = &checked.manifest.toolpkg_id;
        let _suspended = self.runtime.extensions.suspend(id).await?;
        let exclusive = package_lock(&store, id)?;
        exclusive
            .try_lock()
            .map_err(|_| error("其他进程仍在使用此扩展"))?;
        let source_hash = hash(checked.source.as_bytes());
        let resource_id=self.runtime.with_store(|store|{
            let mut conn=store.connection.lock().map_err(|_|error("扩展存储锁不可用"))?;let tx=conn.transaction().map_err(|_|error("扩展安装事务失败"))?;
            let resource_id:String=tx.query_row("SELECT lower(hex(randomblob(16)))",[],|r|r.get(0)).map_err(|_|error("扩展资源身份失败"))?;
            tx.execute("INSERT INTO resources VALUES(?1,'default','application_private',?2,'application/vnd.kiyori.toolpkg')",params![resource_id,archive::label(&checked.manifest.display_name)?]).map_err(|_|error("扩展资源保存失败"))?;
            tx.execute("INSERT INTO extension_installs VALUES(?1)",[&resource_id]).map_err(|_|error("扩展恢复记录失败"))?;tx.commit().map_err(|_|error("扩展恢复记录提交失败"))?;Ok(resource_id)
        })?;
        let result = (|| {
            let root = store.managed_path(&resource_id, "")?;
            std::fs::create_dir_all(&root).map_err(|_| error("扩展资源目录不可写"))?;
            let mut source = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(root.join("source.js"))
                .map_err(|_| error("扩展入口不可写"))?;
            source
                .write_all(checked.source.as_bytes())
                .map_err(|_| error("扩展入口写入失败"))?;
            source.sync_all().map_err(|_| error("扩展入口同步失败"))?;
            drop(source);
            std::fs::rename(&self.path, root.join("archive.toolpkg"))
                .map_err(|_| error("扩展包原子交付失败"))?;
            self.runtime.with_store(|store|{
                let mut conn=store.connection.lock().map_err(|_|error("扩展存储锁不可用"))?;let tx=conn.transaction().map_err(|_|error("扩展安装事务失败"))?;
                let previous=tx.query_row("SELECT revision,enabled,resource_id FROM extension_packages WHERE package_id=?1",[id],|r|Ok((r.get::<_,u32>(0)?,r.get::<_,bool>(1)?,r.get::<_,Option<String>>(2)?))).optional().map_err(|_|error("扩展读取失败"))?;
                let revision=previous.as_ref().map_or(Some(1),|p|p.0.checked_add(1)).ok_or_else(||error("扩展代次已耗尽"))?;
                let enabled=previous.as_ref().filter(|p|p.2.is_some()).map_or(checked.manifest.enabled_by_default,|p|p.1);
                if let Some(old)=previous.and_then(|p|p.2){tx.execute("INSERT OR IGNORE INTO extension_installs VALUES(?1)",[old]).map_err(|_|error("扩展旧资源回收记录失败"))?;}
                tx.execute("INSERT INTO extension_packages VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10) ON CONFLICT(package_id) DO UPDATE SET revision=excluded.revision,resource_id=excluded.resource_id,version=excluded.version,name=excluded.name,description=excluded.description,enabled=excluded.enabled,archive_hash=excluded.archive_hash,source_hash=excluded.source_hash,providers=excluded.providers",params![id,revision,resource_id,checked.manifest.version,archive::label(&checked.manifest.display_name)?,archive::label(&checked.manifest.description)?,enabled,archive_hash,source_hash,serde_json::to_string(&providers).map_err(|_|error("扩展注册目录编码失败"))?]).map_err(|_|error("扩展安装保存失败"))?;
                tx.execute("DELETE FROM extension_installs WHERE resource_id=?1",[&resource_id]).map_err(|_|error("扩展安装记录释放失败"))?;tx.commit().map_err(|_|error("扩展安装提交失败"))
            })
        })();
        if let Err(e) = result {
            let _ = store.recover_extensions();
            return Err(e);
        }
        let _ = store.recover_extensions();
        store.extension(id)
    }
}

#[cfg(test)]
mod tests;
