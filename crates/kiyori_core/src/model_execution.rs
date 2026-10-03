//! 凭据只在本次调用内解析；候选规则和持久游标属于共享核心，不推进编辑revision。
use crate::{
    chat, models,
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{OptionalExtension, TransactionBehavior, params};
use serde::Deserialize;
use std::collections::{HashMap, HashSet};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Credentials {
    version: u32,
    api_key: String,
    headers: HashMap<String, String>,
    use_pool: bool,
    keys: Vec<Key>,
    rotation: String,
}
#[derive(Deserialize)]
struct Key {
    id: String,
    key: String,
    enabled: bool,
    availability: String,
}
fn invalid(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    }
}
fn storage(_: rusqlite::Error) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: "模型轮换存储失败".into(),
    }
}

fn credentials(payload: &str) -> Result<Credentials, CoreError> {
    if payload.len() > 1024 * 1024 {
        return Err(invalid("安全凭据超过限制"));
    }
    let result: Credentials =
        serde_json::from_str(payload).map_err(|_| invalid("安全凭据格式无效"))?;
    let mut ids = HashSet::new();
    if result.version != 3
        || result.keys.len() > 20_000
        || result.headers.len() > 100
        || !matches!(result.rotation.as_str(), "ROUND_ROBIN" | "RANDOM")
        || result.keys.iter().any(|k| {
            k.id.is_empty()
                || !ids.insert(&k.id)
                || k.key.trim().is_empty()
                || !matches!(
                    k.availability.as_str(),
                    "UNTESTED" | "AVAILABLE" | "UNAVAILABLE"
                )
        })
    {
        return Err(invalid("安全凭据格式无效"));
    }
    Ok(result)
}

fn random_index(count: usize) -> Result<usize, CoreError> {
    // 拒绝采样，避免取模使随机候选概率偏斜；只支持非空有界候选。
    let bound = count as u64;
    let limit = u64::MAX - (u64::MAX % bound);
    loop {
        let mut bytes = [0; 8];
        rustls::crypto::ring::default_provider()
            .secure_random
            .fill(&mut bytes)
            .map_err(|_| invalid("无法生成密钥池随机索引"))?;
        let value = u64::from_le_bytes(bytes);
        if value < limit {
            return Ok((value % bound) as usize);
        }
    }
}

impl AppStore {
    pub(crate) fn prepare_configured_probe(
        &self,
        id: &str,
        revision: u32,
        payload: &str,
        kind: &str,
    ) -> Result<chat::ChatRequest, CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("模型存储锁不可用"))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        let config = models::read_config(&tx, id)?;
        if config.revision != revision {
            return Err(invalid("模型配置已变化，请重新载入后测试"));
        }
        if !matches!(config.draft.protocol.as_str(), "chat" | "responses") {
            return Err(invalid("该模型协议的请求执行尚未接入"));
        }
        let (key, headers) = select_credentials(&tx, id, payload)?;
        let request = chat::probe::prepare(config.draft, key, headers, kind)?;
        tx.commit().map_err(storage)?;
        Ok(request)
    }
}

/// 调用方事务同时冻结配置、消息和游标；失败回滚，不在网络失败时重放候选。
pub(crate) fn select_credentials(
    tx: &rusqlite::Transaction<'_>,
    id: &str,
    payload: &str,
) -> Result<(String, Vec<(String, String)>), CoreError> {
    let credentials = credentials(payload)?;
    let mut next_index = None;
    let key = if !credentials.use_pool {
        &credentials.api_key
    } else {
        let enabled: Vec<_> = credentials.keys.iter().filter(|k| k.enabled).collect();
        let marked = enabled.iter().any(|k| k.availability != "UNTESTED");
        let candidates: Vec<_> = enabled
            .into_iter()
            .filter(|k| !marked || k.availability == "AVAILABLE")
            .collect();
        if candidates.is_empty() {
            if marked {
                return Err(invalid("密钥池没有可用密钥，请重新测试或清除标记"));
            }
            if credentials.api_key.trim().is_empty() {
                return Err(invalid("密钥池为空或全部停用，且未配置备用密钥"));
            }
            &credentials.api_key
        } else {
            let index = if credentials.rotation == "RANDOM" {
                random_index(candidates.len())?
            } else {
                let cursor: Option<u32> = tx
                    .query_row(
                        "SELECT next_index FROM model_key_cursors WHERE config_id=?1",
                        [id],
                        |r| r.get(0),
                    )
                    .optional()
                    .map_err(storage)?;
                let index = cursor.unwrap_or(0) as usize % candidates.len();
                next_index = Some((index + 1) % candidates.len());
                index
            };
            &candidates[index].key
        }
    };
    let key = key.clone();
    if let Some(next) = next_index {
        tx.execute("INSERT INTO model_key_cursors VALUES(?1,?2) ON CONFLICT(config_id) DO UPDATE SET next_index=excluded.next_index",params![id,next as u32]).map_err(storage)?;
    }
    Ok((key, credentials.headers.into_iter().collect()))
}

impl Runtime {
    pub fn start_configured_probe(
        &self,
        id: String,
        revision: u32,
        payload: String,
        kind: String,
    ) -> Result<chat::ChatRun, CoreError> {
        let request =
            self.with_store(|s| s.prepare_configured_probe(&id, revision, &payload, &kind))?;
        self.start_chat(request)
    }
}

#[cfg(test)]
#[path = "model_execution_tests.rs"]
mod tests;
