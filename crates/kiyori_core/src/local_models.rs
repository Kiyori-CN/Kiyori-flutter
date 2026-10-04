//! MNN市场与仓库清单是下载用例；执行/资源仍复用共享Transfer，不新建模型下载器。
use crate::{
    downloads::{TransferFile, TransferRun, TransferSpec},
    files,
    runtime::{CoreError, Runtime},
};
use files::error;
use rusqlite::OptionalExtension;
use serde::{Deserialize, Serialize};
use std::{
    collections::{BTreeMap, HashSet},
    sync::Arc,
    time::Duration,
};
const MARKET: &str = "https://meta.alicdn.com/data/mnn/apis/model_market.json";
const MODELSCOPE: &str = "https://modelscope.cn";

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct LocalModel {
    #[serde(rename = "modelName")]
    pub name: String,
    pub size_gb: f64,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub sources: BTreeMap<String, String>,
    #[serde(default)]
    pub description: String,
}
#[derive(Deserialize)]
struct Market {
    models: Vec<LocalModel>,
}
#[derive(Deserialize)]
struct Repo {
    #[serde(rename = "Code")]
    code: u32,
    #[serde(rename = "Success")]
    success: bool,
    #[serde(rename = "Data")]
    data: RepoData,
}
#[derive(Deserialize)]
struct RepoData {
    #[serde(rename = "Files")]
    files: Vec<RepoFile>,
}
#[derive(Deserialize)]
struct RepoFile {
    #[serde(rename = "Path")]
    path: String,
    #[serde(rename = "Size")]
    size: u64,
    #[serde(rename = "Type")]
    kind: String,
    #[serde(rename = "Sha256", default)]
    sha256: String,
    #[serde(rename = "Revision", default)]
    revision: String,
}
fn market(raw: &str) -> Result<Vec<LocalModel>, CoreError> {
    let models = serde_json::from_str::<Market>(raw)
        .map_err(|_| error("模型目录格式无效"))?
        .models;
    if models.len() > 2000 {
        return Err(error("模型目录超过2000项限制"));
    }
    let mut ids = HashSet::new();
    for model in &models {
        if model.name.trim().is_empty()
            || model.name.len() > 512
            || !ids.insert(&model.name)
            || !model.size_gb.is_finite()
            || model.size_gb < 0.
            || model.tags.len() > 64
            || model.tags.iter().any(|s| s.len() > 128)
            || model.description.len() > 16384
            || model.sources.len() > 16
            || model.sources.values().any(|s| s.len() > 4096)
        {
            return Err(error("模型目录条目无效或重复"));
        }
    }
    Ok(models)
}
fn repo_id(value: &str) -> Result<(), CoreError> {
    if value.split('/').count() != 2
        || value.split('/').any(|s| {
            s.is_empty()
                || s.len() > 128
                || s == "."
                || s == ".."
                || !s
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.'))
        })
    {
        return Err(error("ModelScope仓库标识无效"));
    }
    Ok(())
}
fn manifest(
    raw: &str,
    model: &LocalModel,
    repo: &str,
    base: &str,
) -> Result<TransferSpec, CoreError> {
    repo_id(repo)?;
    let response: Repo = serde_json::from_str(raw).map_err(|_| error("仓库文件目录格式无效"))?;
    if response.code != 200 || !response.success || response.data.files.len() > 8192 {
        return Err(error("仓库文件目录失败或超过限制"));
    }
    let mut files = Vec::new();
    for file in response.data.files {
        if file.kind != "blob" {
            continue;
        }
        if !files::valid_relative(&file.path)
            || file.revision.is_empty()
            || file.revision.len() > 128
            || !file.revision.bytes().all(|b| b.is_ascii_hexdigit())
        {
            return Err(error("仓库文件路径或版本无效"));
        }
        let mut url = reqwest::Url::parse(&format!("{base}/api/v1/models/{repo}/repo"))
            .map_err(|_| error("仓库下载地址无效"))?;
        url.query_pairs_mut()
            .append_pair("FilePath", &file.path)
            .append_pair("Revision", &file.revision);
        files.push(TransferFile {
            path: file.path,
            url: url.to_string(),
            size: file.size,
            sha256: file.sha256,
        });
    }
    if !files.iter().any(|f| f.path == "config.json")
        || !files.iter().any(|f| f.path.ends_with(".mnn"))
    {
        return Err(error("仓库缺少MNN模型或config.json"));
    }
    Ok(TransferSpec {
        owner: format!("mnn:{}", model.name),
        name: model.name.clone(),
        files,
    })
}
async fn fetch(client: &reqwest::Client, url: &str) -> Result<String, CoreError> {
    let mut result = client
        .get(url)
        .send()
        .await
        .map_err(|_| error("模型目录连接失败或超时"))?;
    if result.status() != 200 {
        return Err(error("模型目录服务器拒绝请求"));
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = result
        .chunk()
        .await
        .map_err(|_| error("模型目录连接中断"))?
    {
        if bytes.len() + chunk.len() > 8 * 1024 * 1024 {
            return Err(error("模型目录超过8 MiB限制"));
        }
        bytes.extend_from_slice(&chunk);
    }
    String::from_utf8(bytes).map_err(|_| error("模型目录不是有效UTF-8"))
}
impl Runtime {
    pub fn local_models(&self) -> Result<Vec<LocalModel>, CoreError> {
        self.with_store(|store| {
            let conn = store
                .connection
                .lock()
                .map_err(|_| error("模型目录存储锁不可用"))?;
            let raw = conn
                .query_row(
                    "SELECT content FROM local_model_market WHERE id=1",
                    [],
                    |r| r.get::<_, String>(0),
                )
                .optional()
                .map_err(|_| error("模型目录读取失败"))?;
            raw.map(|s| market(&s))
                .transpose()
                .map(|m| m.unwrap_or_default())
        })
    }
    pub async fn refresh_local_models(&self) -> Result<Vec<LocalModel>, CoreError> {
        self.refresh_local_models_from(MARKET).await
    }
    async fn refresh_local_models_from(&self, url: &str) -> Result<Vec<LocalModel>, CoreError> {
        self.ensure_open()?;
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(Arc::new))
            .clone()?;
        let raw = tokio::select! {biased;_=self.cancellation.cancelled()=>return Err(error("模型目录刷新已取消")),r=tokio::time::timeout(Duration::from_secs(60),fetch(&client,url))=>r.map_err(|_|error("模型目录刷新超时"))??};
        let models = market(&raw)?;
        self.with_store(|store|{store.connection.lock().map_err(|_|error("模型目录存储锁不可用"))?.execute("INSERT INTO local_model_market VALUES(1,?1) ON CONFLICT(id) DO UPDATE SET content=excluded.content",[raw]).map_err(|_|error("模型目录保存失败"))?;Ok(())})?;
        Ok(models)
    }
    pub async fn download_local_model(&self, name: String) -> Result<TransferRun, CoreError> {
        self.download_local_model_from(name, MODELSCOPE).await
    }
    async fn download_local_model_from(
        &self,
        name: String,
        base: &str,
    ) -> Result<TransferRun, CoreError> {
        let store = self.persistent_store()?;
        let existing = store
            .connection
            .lock()
            .map_err(|_| error("下载存储锁不可用"))?
            .query_row(
                "SELECT id FROM transfers WHERE owner=?1",
                [format!("mnn:{name}")],
                |r| r.get::<_, String>(0),
            )
            .optional()
            .map_err(|_| error("下载任务读取失败"))?;
        if let Some(id) = existing {
            return self.start_transfer(id);
        }
        let model = self
            .local_models()?
            .into_iter()
            .find(|m| m.name == name)
            .ok_or_else(|| error("模型不在当前目录，请刷新"))?;
        let repo = model
            .sources
            .get("ModelScope")
            .ok_or_else(|| error("该模型缺少可验证的ModelScope清单"))?;
        repo_id(repo)?;
        let client = self
            .chat_client
            .get_or_init(|| crate::chat::client().map(Arc::new))
            .clone()?;
        let url = format!("{base}/api/v1/models/{repo}/repo/files?Recursive=1");
        let raw = tokio::select! {biased;_=self.cancellation.cancelled()=>return Err(error("模型下载准备已取消")),r=tokio::time::timeout(Duration::from_secs(60),fetch(&client,&url))=>r.map_err(|_|error("模型下载准备超时"))??};
        let id = self.create_transfer(manifest(&raw, &model, repo, base)?)?;
        self.start_transfer(id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn market_and_manifest_keep_identity_version_and_reject_untrusted_paths() {
        let raw = r#"{"models":[{"modelName":"fixture","size_gb":0.1,"sources":{"ModelScope":"MNN/fixture"}}]}"#;
        let model = market(raw).unwrap().remove(0);
        let hash = "a".repeat(64);
        let raw=serde_json::json!({"Code":200,"Success":true,"Data":{"Files":[{"Path":"config.json","Size":0,"Type":"blob","Sha256":hash,"Revision":"abcd"},{"Path":"llm.mnn","Size":0,"Type":"blob","Sha256":hash,"Revision":"ef01"}]}}).to_string();
        let spec = manifest(&raw, &model, "MNN/fixture", MODELSCOPE).unwrap();
        assert_eq!(spec.owner, "mnn:fixture");
        assert!(spec.files[1].url.contains("Revision=ef01"));
        assert!(
            manifest(
                &raw.replace("llm.mnn", "../llm.mnn"),
                &model,
                "MNN/fixture",
                MODELSCOPE
            )
            .is_err()
        );
        assert!(repo_id("../../private").is_err());
        assert!(repo_id("https://host/repo").is_err());
        assert!(market(r#"{"models":[{"modelName":"x","size_gb":-1}]}"#).is_err());
    }

    #[tokio::test]
    async fn market_repository_transfer_and_failed_refresh_keep_one_persisted_owner() {
        use std::{
            io::{Read, Write},
            net::TcpListener,
        };
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let config = b"{}";
        let weight = b"model";
        let hash = |bytes: &[u8]| {
            ring::digest::digest(&ring::digest::SHA256, bytes)
                .as_ref()
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect::<String>()
        };
        let repo=serde_json::json!({"Code":200,"Success":true,"Data":{"Files":[{"Path":"config.json","Size":2,"Type":"blob","Revision":"abcd","Sha256":hash(config)},{"Path":"llm.mnn","Size":5,"Type":"blob","Revision":"abcd","Sha256":hash(weight)}]}}).to_string();
        let bodies=vec![r#"{"models":[{"modelName":"fixture","size_gb":0.1,"sources":{"ModelScope":"MNN/fixture"}}]}"#.to_owned(),repo,"{}".into(),"model".into(),"invalid".into()];
        let worker = std::thread::spawn(move || {
            let mut requests = Vec::new();
            for body in bodies {
                let (mut socket, _) = listener.accept().unwrap();
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
                requests.push(String::from_utf8(request).unwrap());
                write!(
                    socket,
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                )
                .unwrap();
            }
            requests
        });
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("kiyori-market-chain-{unique}"));
        let runtime = Runtime::with_data_dir(&path).unwrap();
        runtime
            .refresh_local_models_from(&format!("{base}/market"))
            .await
            .unwrap();
        let run = runtime
            .download_local_model_from("fixture".into(), &base)
            .await
            .unwrap();
        let mut last = None;
        while let Some(event) = run.next_event().await.unwrap() {
            last = Some(event);
        }
        assert_eq!(last.unwrap().phase, "completed");
        assert!(
            runtime
                .refresh_local_models_from(&format!("{base}/market"))
                .await
                .is_err()
        );
        assert_eq!(runtime.local_models().unwrap()[0].name, "fixture");
        let requests = worker.join().unwrap();
        assert!(requests[1].starts_with("GET /api/v1/models/MNN/fixture/repo/files?Recursive=1 "));
        assert!(requests[2].contains("FilePath=config.json&Revision=abcd"));
        runtime.close();
        let reopened = Runtime::with_data_dir(&path).unwrap();
        assert_eq!(reopened.local_models().unwrap()[0].name, "fixture");
        assert_eq!(reopened.transfers().unwrap()[0].phase, "completed");
        reopened.close();
        std::fs::remove_dir_all(path).unwrap();
    }
}
