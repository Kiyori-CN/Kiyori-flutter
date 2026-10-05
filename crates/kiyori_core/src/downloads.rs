//! 唯一前台传输执行者。OS锁跨Runtime/进程；网络不持有SQLite事务。
use crate::{
    files::{self, ResourceRef},
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use files::error;
use reqwest::{Client, Url};
use rusqlite::{OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    fs::{File, OpenOptions},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Instant,
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    sync::{Mutex, mpsc},
};
use tokio_util::sync::CancellationToken;

#[cfg(test)]
#[path = "downloads_tests.rs"]
mod tests;

#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(connection: &rusqlite::Connection) {
    crate::extensions::remove_schema_for_fixture(connection);
    connection.execute_batch("DROP TABLE transfer_files;DROP TABLE transfers;DROP TABLE resources;DROP TABLE local_model_market;").unwrap();
}

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct TransferFile {
    pub path: String,
    pub url: String,
    pub size: u64,
    pub sha256: String,
}
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct TransferSpec {
    pub owner: String,
    pub name: String,
    pub files: Vec<TransferFile>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct TransferSnapshot {
    pub resource: ResourceRef,
    pub owner: String,
    pub phase: String,
    pub error: String,
    pub transferred: u64,
    pub total: u64,
    pub current_file: String,
    pub file_index: u32,
    pub total_files: u32,
    pub bytes_per_second: f64,
}
pub struct TransferRun {
    cancellation: CancellationToken,
    finished: CancellationToken,
    cancel_requested: Arc<AtomicBool>,
    receiver: Mutex<mpsc::Receiver<Result<TransferSnapshot, CoreError>>>,
}
impl TransferRun {
    pub async fn next_event(&self) -> Result<Option<TransferSnapshot>, CoreError> {
        self.receiver
            .try_lock()
            .map_err(|_| error("下载任务只允许一个事件读取者"))?
            .recv()
            .await
            .transpose()
    }
    pub async fn stop(&self, cancel: bool) {
        if cancel {
            self.cancel_requested.store(true, Ordering::Release);
        }
        self.cancellation.cancel();
        self.finished.cancelled().await;
    }
}
// Drop只取消；worker仍负责落盘与释放锁，停止入口显式等待finished。
impl Drop for TransferRun {
    fn drop(&mut self) {
        self.cancellation.cancel();
    }
}
fn source_url(value: &str) -> Result<Url, CoreError> {
    let url = Url::parse(value).map_err(|_| error("下载地址无效"))?;
    let local = matches!(url.host_str(), Some("127.0.0.1" | "localhost" | "[::1]"));
    if value.len() > 4096
        || !(url.scheme() == "https" || url.scheme() == "http" && local)
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
        || url.fragment().is_some()
    {
        return Err(error("下载地址必须为无凭据HTTPS地址"));
    }
    Ok(url)
}
fn validate(spec: &TransferSpec) -> Result<(), CoreError> {
    if spec.owner.is_empty()
        || spec.owner.len() > 512
        || spec.name.trim().is_empty()
        || spec.name.len() > 512
        || spec.files.is_empty()
        || spec.files.len() > 4096
    {
        return Err(error("下载清单无效或超过限制"));
    }
    let mut paths = HashSet::new();
    let mut total = 0u64;
    for f in &spec.files {
        if !files::valid_relative(&f.path)
            || f.path
                .split('/')
                .next()
                .is_some_and(|p| p.eq_ignore_ascii_case(".partial"))
            || !paths.insert(f.path.to_lowercase())
            || f.size > 64 * 1024 * 1024 * 1024
            || f.sha256.len() != 64
            || !f.sha256.bytes().all(|b| b.is_ascii_hexdigit())
        {
            return Err(error("下载文件路径、大小或SHA256无效"));
        }
        if f.url == crate::model_import::IMPORT_SOURCE {
            if spec.files.len() != 1 || spec.owner != format!("llama:{}", f.path) {
                return Err(error("导入资源清单身份无效"));
            }
        } else {
            source_url(&f.url)?;
        }
        total = total
            .checked_add(f.size)
            .ok_or_else(|| error("下载大小溢出"))?;
    }
    if total > 256 * 1024 * 1024 * 1024 {
        return Err(error("下载包超过256 GiB限制"));
    }
    for f in &spec.files {
        let lower = f.path.to_lowercase();
        for (position, _) in lower.match_indices('/') {
            if paths.contains(&lower[..position]) {
                return Err(error("下载清单包含文件与目录冲突"));
            }
        }
    }
    if serde_json::to_vec(spec)
        .map_err(|_| error("下载清单编码失败"))?
        .len()
        > 8 * 1024 * 1024
    {
        return Err(error("下载清单超过8 MiB限制"));
    }
    Ok(())
}
fn restart_error(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    }
}
impl AppStore {
    pub(crate) fn transfer_lock(&self, id: &str) -> Result<File, CoreError> {
        if !files::valid_id(id) {
            return Err(error("下载标识无效"));
        }
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(self.directory.join(format!("transfer-{id}.lock")))
            .map_err(|_| error("无法打开下载执行锁"))?;
        file.try_lock()
            .map_err(|_| error("下载任务已有执行者，请先暂停"))?;
        Ok(file)
    }
    pub(crate) fn transfer(&self, id: &str) -> Result<(TransferSpec, TransferSnapshot), CoreError> {
        let conn = self
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?;
        let (raw,owner,phase,message,name):(String,String,String,String,String)=conn.query_row("SELECT t.spec,t.owner,t.phase,t.error,r.name FROM transfers t JOIN resources r ON r.id=t.id WHERE t.id=?1",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?))).map_err(|_|error("下载任务不存在"))?;
        let spec: TransferSpec = serde_json::from_str(&raw).map_err(|_| error("下载清单已损坏"))?;
        validate(&spec)?;
        let mut transferred = 0;
        let mut index = 0;
        let mut current = String::new();
        for (i, f) in spec.files.iter().enumerate() {
            let (confirmed,verified):(i64,bool)=conn.query_row("SELECT confirmed,verified FROM transfer_files WHERE transfer_id=?1 AND path=?2",params![id,f.path],|r|Ok((r.get(0)?,r.get(1)?))).map_err(|_|error("下载文件状态读取失败"))?;
            if confirmed < 0 || confirmed as u64 > f.size {
                return Err(error("下载文件进度无效"));
            }
            transferred += confirmed as u64;
            if !verified && current.is_empty() {
                current = f.path.clone();
                index = (i + 1) as u32;
            }
        }
        let total = spec.files.iter().map(|f| f.size).sum();
        let total_files = spec.files.len() as u32;
        Ok((
            spec,
            TransferSnapshot {
                resource: ResourceRef {
                    id: id.into(),
                    workspace: "default".into(),
                    source: "application_private".into(),
                    name,
                    mime: "application/octet-stream".into(),
                },
                owner,
                phase,
                error: message,
                transferred,
                total,
                current_file: current,
                file_index: index,
                total_files,
                bytes_per_second: 0.,
            },
        ))
    }
    fn phase(&self, id: &str, phase: &str, message: &str) -> Result<(), CoreError> {
        self.connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .execute(
                "UPDATE transfers SET phase=?2,error=?3 WHERE id=?1",
                params![id, phase, message],
            )
            .map_err(|_| error("下载状态保存失败"))?;
        Ok(())
    }
    fn confirmed(&self, id: &str, path: &str, bytes: u64, verified: bool) -> Result<(), CoreError> {
        let bytes = i64::try_from(bytes).map_err(|_| error("下载进度超出存储范围"))?;
        self.connection.lock().map_err(|_|error("下载存储锁不可用"))?.execute("UPDATE transfer_files SET confirmed=?3,verified=?4 WHERE transfer_id=?1 AND path=?2",params![id,path,bytes,verified]).map_err(|_|error("下载进度保存失败"))?;
        Ok(())
    }
}
impl Runtime {
    pub fn create_transfer(&self, spec: TransferSpec) -> Result<String, CoreError> {
        validate(&spec)?;
        self.with_store(|store|{
            let mut conn=store.connection.lock().map_err(|_|error("下载存储锁不可用"))?;
            let tx=conn.transaction_with_behavior(rusqlite::TransactionBehavior::Immediate).map_err(|_|error("无法准备下载任务"))?;
            if let Some((id,raw))=tx.query_row("SELECT id,spec FROM transfers WHERE owner=?1",[&spec.owner],|r|Ok((r.get::<_,String>(0)?,r.get::<_,String>(1)?))).optional().map_err(|_|error("下载读取失败"))?{
                if serde_json::from_str::<TransferSpec>(&raw).ok().as_ref()!=Some(&spec){return Err(error("下载来源已变化，请删除旧任务后重新下载"));} return Ok(id);
            }
            let id:String=tx.query_row("SELECT lower(hex(randomblob(16)))",[],|r|r.get(0)).map_err(|_|error("资源标识创建失败"))?;
            tx.execute("INSERT INTO resources VALUES(?1,'default','application_private',?2,'application/octet-stream')",params![id,spec.name]).map_err(|_|error("资源保存失败"))?;
            tx.execute("INSERT INTO transfers(id,owner,phase,spec) VALUES(?1,?2,'queued',?3)",params![id,spec.owner,serde_json::to_string(&spec).map_err(|_|error("清单编码失败"))?]).map_err(|_|error("下载保存失败"))?;
            for f in &spec.files {tx.execute("INSERT INTO transfer_files(transfer_id,path) VALUES(?1,?2)",params![id,f.path]).map_err(|_|error("下载文件保存失败"))?;}
            tx.commit().map_err(|_|error("下载事务提交失败"))?; Ok(id)
        })
    }
    pub fn transfers(&self) -> Result<Vec<TransferSnapshot>, CoreError> {
        let store = self.persistent_store()?;
        let ids = {
            let conn = store
                .connection
                .lock()
                .map_err(|_| error("下载存储锁不可用"))?;
            conn.prepare("SELECT id FROM transfers ORDER BY rowid")
                .map_err(|_| error("下载读取失败"))?
                .query_map([], |r| r.get::<_, String>(0))
                .map_err(|_| error("下载读取失败"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|_| error("下载读取失败"))?
        };
        let mut output = Vec::new();
        for id in ids {
            let (spec, mut snapshot) = store.transfer(&id)?;
            if let Ok(_guard) = store.transfer_lock(&id) {
                let interrupted =
                    matches!(snapshot.phase.as_str(), "running" | "verifying" | "queued");
                let mut missing = false;
                for file in &spec.files {
                    let target = store.managed_path(&id, &file.path)?;
                    let meta = match std::fs::metadata(&target) {
                        Ok(m) => Some(m),
                        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
                        Err(_) => return Err(error("模型文件状态读取失败")),
                    };
                    if let Some(meta) = meta {
                        if !meta.is_file() || meta.len() != file.size {
                            missing = true;
                            store.confirmed(&id, &file.path, 0, false)?;
                        }
                    } else {
                        if snapshot.phase == "completed" {
                            missing = true;
                        }
                        let part = store.managed_path(&id, &format!(".partial/{}", file.path))?;
                        let size = match std::fs::metadata(part) {
                            Ok(m) if m.is_file() => m.len().min(file.size),
                            Ok(_) => return Err(error("部分文件类型无效")),
                            Err(e) if e.kind() == std::io::ErrorKind::NotFound => 0,
                            Err(_) => return Err(error("部分文件状态读取失败")),
                        };
                        store.confirmed(&id, &file.path, size, false)?;
                    }
                }
                if missing && snapshot.phase == "completed" {
                    store.phase(&id, "failed", "模型文件已缺失或改变，请重新下载")?;
                } else if interrupted {
                    store.phase(&id, "paused", "上次下载已中断，可以继续")?;
                }
                snapshot = store.transfer(&id)?.1;
            }
            output.push(snapshot);
        }
        Ok(output)
    }
    pub fn delete_transfer(&self, id: String) -> Result<(), CoreError> {
        let store = self.persistent_store()?;
        let _guard = store.transfer_lock(&id)?;
        store.transfer(&id)?;
        let root = store.managed_path(&id, "")?;
        // 仅删除从内部hex身份推导的托管包；不接受上游/用户绝对路径。
        if root.exists() {
            std::fs::remove_dir_all(root)
                .map_err(|_| error("模型文件删除失败；任务保留，可重试"))?;
        }
        store
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .execute("DELETE FROM resources WHERE id=?1", [id])
            .map_err(|_| error("下载记录删除失败，可以重试"))?;
        Ok(())
    }
    pub fn start_transfer(&self, id: String) -> Result<TransferRun, CoreError> {
        let store = self.persistent_store()?;
        let guard = store.transfer_lock(&id)?;
        let (spec, snapshot) = store.transfer(&id)?;
        if spec
            .files
            .iter()
            .any(|f| f.url == crate::model_import::IMPORT_SOURCE)
        {
            return Err(error("本地导入资源不能网络续传，请重新选择同一文件"));
        }
        if snapshot.phase == "completed" {
            return Err(error("该模型已下载完成"));
        }
        let restart: bool = store
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .query_row(
                "SELECT restart_required FROM transfers WHERE id=?1",
                [&id],
                |r| r.get(0),
            )
            .map_err(|_| error("下载恢复状态读取失败"))?;
        if restart {
            // 重试是用户明确动作；只重置本清单未验证文件，已交付前缀继续复用。
            for file in &spec.files {
                let verified: bool = store
                    .connection
                    .lock()
                    .map_err(|_| error("下载存储锁不可用"))?
                    .query_row(
                        "SELECT verified FROM transfer_files WHERE transfer_id=?1 AND path=?2",
                        params![id, file.path],
                        |r| r.get(0),
                    )
                    .map_err(|_| error("下载恢复状态读取失败"))?;
                if verified {
                    continue;
                }
                for relative in [file.path.clone(), format!(".partial/{}", file.path)] {
                    let path = store.managed_path(&id, &relative)?;
                    match std::fs::remove_file(path) {
                        Ok(()) => {}
                        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                        Err(_) => return Err(error("损坏下载文件重置失败，可以重试")),
                    }
                }
                store.connection.lock().map_err(|_|error("下载存储锁不可用"))?.execute(
                    "UPDATE transfer_files SET confirmed=0,verified=0,etag=NULL,modified=NULL WHERE transfer_id=?1 AND path=?2",params![id,file.path])
                    .map_err(|_|error("下载恢复状态保存失败"))?;
            }
            store
                .connection
                .lock()
                .map_err(|_| error("下载存储锁不可用"))?
                .execute("UPDATE transfers SET restart_required=0 WHERE id=?1", [&id])
                .map_err(|_| error("下载恢复状态保存失败"))?;
        }
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(Arc::new))
            .clone()?;
        store.phase(&id, "running", "")?;
        let cancellation = self.cancellation.child_token();
        let cancel = cancellation.clone();
        let requested = Arc::new(AtomicBool::new(false));
        let cancel_requested = requested.clone();
        let finished = CancellationToken::new();
        let finished_guard = finished.clone().drop_guard();
        let (sender, receiver) = mpsc::channel(8);
        tokio::spawn(async move {
            let _finished = finished_guard;
            let _guard = guard;
            let result = download(&client, &store, &id, &spec, &cancel, &sender).await;
            let phase = if cancel.is_cancelled() {
                if requested.load(Ordering::Acquire) {
                    "cancelled"
                } else {
                    "paused"
                }
            } else if result.is_ok() {
                "completed"
            } else {
                "failed"
            };
            let terminal = finish(&store, &id, phase, result);
            tokio::select! {biased;_=cancel.cancelled()=>{let _=sender.try_send(terminal);},_=sender.send(terminal.clone())=>{}}
        });
        Ok(TransferRun {
            cancellation,
            finished,
            cancel_requested,
            receiver: Mutex::new(receiver),
        })
    }
}

fn finish(
    store: &AppStore,
    id: &str,
    phase: &str,
    result: Result<(), CoreError>,
) -> Result<TransferSnapshot, CoreError> {
    if result
        .as_ref()
        .is_err_and(|e| e.code == ErrorCode::InvalidInput)
    {
        store
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .execute("UPDATE transfers SET restart_required=1 WHERE id=?1", [id])
            .map_err(|_| error("下载恢复状态保存失败"))?;
    }
    let message = result.err().map(|e| e.message).unwrap_or_default();
    store.phase(id, phase, &message)?;
    Ok(store.transfer(id)?.1)
}

async fn response(
    client: &Client,
    url: &str,
    offset: u64,
    etag: Option<&str>,
    modified: Option<&str>,
) -> Result<reqwest::Response, CoreError> {
    let mut url = source_url(url)?;
    let original = url.host_str().unwrap_or_default().to_owned();
    let model_scope = original == "modelscope.cn" || original.ends_with(".modelscope.cn");
    let hugging = original == "huggingface.co" || original.ends_with(".huggingface.co");
    for _ in 0..6 {
        let mut request = client
            .get(url.clone())
            .header("User-Agent", "Kiyori/0.1")
            // ModelScope重定向含短期CDN签名，禁止复用缓存的旧Location。
            .header("Cache-Control", "no-cache")
            .header("Accept-Encoding", "identity");
        if offset > 0 {
            request = request.header("Range", format!("bytes={offset}-"));
            if let Some(v) = etag.or(modified) {
                request = request.header("If-Range", v);
            }
        }
        let result = request
            .send()
            .await
            .map_err(|_| error("下载连接失败或超时"))?;
        if !result.status().is_redirection() {
            return Ok(result);
        }
        let location = result
            .headers()
            .get("location")
            .and_then(|h| h.to_str().ok())
            .ok_or_else(|| error("下载重定向无效"))?;
        let next = url.join(location).map_err(|_| error("下载重定向无效"))?;
        source_url(next.as_str())?;
        let host = next.host_str().unwrap_or_default();
        if next.scheme() != url.scheme()
            || !(host == original
                || model_scope
                    && (host.ends_with(".modelscope.cn") || host.ends_with(".aliyuncs.com"))
                || hugging && (host.ends_with(".huggingface.co") || host.ends_with(".hf.co")))
        {
            return Err(error("下载重定向目标不在来源范围内"));
        }
        url = next;
    }
    Err(error("下载重定向次数超过限制"))
}
fn range(value: &str, offset: u64, total: u64) -> bool {
    let Some(raw) = value.strip_prefix("bytes ") else {
        return false;
    };
    let Some((span, size)) = raw.split_once('/') else {
        return false;
    };
    let Some((start, end)) = span.split_once('-') else {
        return false;
    };
    start.parse::<u64>().ok() == Some(offset)
        && end.parse::<u64>().ok() == total.checked_sub(1)
        && size.parse::<u64>().ok() == Some(total)
}
async fn verify(
    path: &std::path::Path,
    expected: &TransferFile,
    cancel: &CancellationToken,
) -> Result<(), CoreError> {
    let mut file = tokio::fs::File::open(path)
        .await
        .map_err(|_| error("校验文件读取失败"))?;
    let mut hash = ring::digest::Context::new(&ring::digest::SHA256);
    let mut bytes = 0;
    let mut buffer = vec![0; 64 * 1024];
    loop {
        if cancel.is_cancelled() {
            return Err(error("下载已暂停"));
        }
        let n = file
            .read(&mut buffer)
            .await
            .map_err(|_| error("文件校验读取失败"))?;
        if n == 0 {
            break;
        }
        bytes += n as u64;
        hash.update(&buffer[..n]);
    }
    let actual = hash
        .finish()
        .as_ref()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect::<String>();
    if bytes != expected.size || !actual.eq_ignore_ascii_case(&expected.sha256) {
        return Err(restart_error(
            "文件大小或SHA256校验失败，重试将重新下载损坏文件",
        ));
    }
    Ok(())
}
async fn download(
    client: &Client,
    store: &Arc<AppStore>,
    id: &str,
    spec: &TransferSpec,
    cancel: &CancellationToken,
    sender: &mpsc::Sender<Result<TransferSnapshot, CoreError>>,
) -> Result<(), CoreError> {
    let started = Instant::now();
    let initial = store.transfer(id)?.1.transferred;
    let _ = sender.try_send(Ok(store.transfer(id)?.1));
    for f in &spec.files {
        if cancel.is_cancelled() {
            return Err(error("下载已暂停"));
        }
        let target = store.managed_path(id, &f.path)?;
        let part = store.managed_path(id, &format!(".partial/{}", f.path))?;
        if let Some(parent) = target.parent() {
            tokio::fs::create_dir_all(parent)
                .await
                .map_err(|_| error("无法创建模型目录，检查存储空间或权限"))?;
        }
        if let Some(parent) = part.parent() {
            tokio::fs::create_dir_all(parent)
                .await
                .map_err(|_| error("无法创建下载临时目录"))?;
        }
        // 覆盖前再次拒绝新出现的链接；最终文件也必须重新校验，不能只凭长度报告完成。
        store.managed_path(id, &f.path)?;
        store.managed_path(id, &format!(".partial/{}", f.path))?;
        if target.exists() {
            if let Err(e) = verify(&target, f, cancel).await {
                if e.code == ErrorCode::InvalidInput {
                    store.confirmed(id, &f.path, 0, false)?;
                }
                return Err(e);
            }
            store.confirmed(id, &f.path, f.size, true)?;
            continue;
        }
        let mut offset = match tokio::fs::metadata(&part).await {
            Ok(m) => m.len(),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => 0,
            Err(_) => return Err(error("部分文件无法读取")),
        };
        if offset > f.size {
            return Err(restart_error(
                "部分文件超过清单大小，重试将重新下载损坏文件",
            ));
        }
        let (etag, modified): (Option<String>, Option<String>) = store
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .query_row(
                "SELECT etag,modified FROM transfer_files WHERE transfer_id=?1 AND path=?2",
                params![id, f.path],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .map_err(|_| error("文件来源状态读取失败"))?;
        if offset < f.size {
            let mut result = tokio::select! {biased;_=cancel.cancelled()=>return Err(error("下载已暂停")),r=response(client,&f.url,offset,etag.as_deref(),modified.as_deref())=>r?};
            if result.status().is_client_error() || result.status().is_server_error() {
                return Err(error(&format!(
                    "下载服务器拒绝请求（HTTP {}），可以重试",
                    result.status().as_u16()
                )));
            }
            if (offset == 0 && result.status() != 200)
                || (offset > 0
                    && (result.status() != 206
                        || !result
                            .headers()
                            .get("content-range")
                            .and_then(|v| v.to_str().ok())
                            .is_some_and(|v| range(v, offset, f.size))))
            {
                return Err(restart_error(
                    "服务器不支持该断点或文件已变化，重试将重新下载该文件",
                ));
            }
            if result
                .headers()
                .get("content-encoding")
                .and_then(|v| v.to_str().ok())
                .is_some_and(|v| v != "identity")
                || result
                    .content_length()
                    .is_some_and(|n| n != f.size - offset)
            {
                return Err(restart_error(
                    "下载响应编码或长度与清单不一致，重试将重新下载该文件",
                ));
            }
            let header = |name| {
                result
                    .headers()
                    .get(name)
                    .and_then(|v| v.to_str().ok())
                    .filter(|s| s.len() <= 1024)
                    .map(str::to_owned)
            };
            let new_etag = header("etag").filter(|e| !e.starts_with("W/"));
            let new_modified = header("last-modified");
            if offset > 0
                && (etag.as_ref().is_some_and(|v| new_etag.as_ref() != Some(v))
                    || etag.is_none()
                        && modified
                            .as_ref()
                            .is_some_and(|v| new_modified.as_ref() != Some(v)))
            {
                return Err(restart_error("断点文件实体已变化，重试将重新下载该文件"));
            }
            store.connection.lock().map_err(|_|error("下载存储锁不可用"))?.execute("UPDATE transfer_files SET etag=?3,modified=?4,verified=0 WHERE transfer_id=?1 AND path=?2",params![id,f.path,new_etag,new_modified]).map_err(|_|error("文件实体保存失败"))?;
            let mut file = tokio::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .append(offset > 0)
                .truncate(offset == 0)
                .open(&part)
                .await
                .map_err(|_| error("无法写入模型文件，检查存储空间或权限"))?;
            let mut checkpoint = offset;
            let body_result=async{
                loop{
                    let chunk=tokio::select!{biased;_=cancel.cancelled()=>return Err(error("下载已暂停")),r=result.chunk()=>r.map_err(|_|error("下载连接中断，可以继续"))?};
                    let Some(chunk)=chunk else{break;};
                    if chunk.len() as u64>f.size-offset{return Err(restart_error("下载正文超过清单大小，重试将重新下载该文件"));}
                    file.write_all(&chunk).await.map_err(|_|error("模型写入失败，检查存储空间或权限"))?;offset+=chunk.len() as u64;
                    if offset-checkpoint>=1024*1024{file.flush().await.map_err(|_|error("模型刷新失败"))?;file.sync_data().await.map_err(|_|error("模型进度落盘失败"))?;store.confirmed(id,&f.path,offset,false)?;checkpoint=offset;
                        let mut snapshot=store.transfer(id)?.1;snapshot.bytes_per_second=(snapshot.transferred.saturating_sub(initial)) as f64/started.elapsed().as_secs_f64().max(0.001);let _=sender.try_send(Ok(snapshot));
                    }
                }Ok(())
            }.await;
            file.flush().await.map_err(|_| error("模型刷新失败"))?;
            file.sync_data()
                .await
                .map_err(|_| error("模型进度落盘失败"))?;
            store.confirmed(id, &f.path, offset, false)?;
            drop(file);
            body_result?;
            if offset != f.size {
                return Err(error("下载内容不完整，可以继续"));
            }
        } else if !part.exists() {
            tokio::fs::File::create(&part)
                .await
                .map_err(|_| error("无法创建空文件"))?;
        }
        store.phase(id, "verifying", "")?;
        let _ = sender.try_send(Ok(store.transfer(id)?.1));
        verify(&part, f, cancel).await?;
        store.managed_path(id, &f.path)?;
        tokio::fs::rename(&part, &target)
            .await
            .map_err(|_| error("文件校验通过但交付失败，可以重试"))?;
        store.confirmed(id, &f.path, f.size, true)?;
        store.phase(id, "running", "")?;
    }
    Ok(())
}
