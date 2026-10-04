//! 上游目录是请求运行时的只读操作，不创建另一个网络或模型配置所有者。
use super::*;
use crate::models::ModelConfigDraft;
use std::collections::HashSet;

#[cfg(test)]
#[path = "directory_tests.rs"]
mod tests;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelEntry {
    pub id: String,
    pub name: String,
}

pub(crate) fn start(
    client: Arc<Client>,
    draft: ModelConfigDraft,
    key: String,
    custom_headers: Vec<(String, String)>,
    cancellation: CancellationToken,
) -> ChatRun {
    let (sender, receiver) = mpsc::channel(8);
    let finished = CancellationToken::new();
    let guard = finished.clone().drop_guard();
    let cancel = cancellation.clone();
    tokio::spawn(async move {
        let _guard = guard;
        let work = async {
            let _ = sender.send(ChatEvent::Started).await;
            let result = tokio::time::timeout(
                Duration::from_secs(60),
                fetch(&client, &draft, &key, custom_headers),
            )
            .await;
            match result {
                Ok(Ok(models)) => {
                    if sender.send(ChatEvent::Models(models)).await.is_ok() {
                        let _ = sender
                            .send(ChatEvent::Completed {
                                reason: "models".into(),
                                verified: None,
                            })
                            .await;
                    }
                }
                Ok(Err(error)) => {
                    let _ = sender.send(ChatEvent::Failed(error)).await;
                }
                Err(_) => {
                    let _ = sender
                        .send(ChatEvent::Failed(ChatFailure::new(
                            ChatFailureKind::Timeout,
                            "获取模型目录超时，请重试",
                        )))
                        .await;
                }
            }
        };
        tokio::select! { biased; _ = cancel.cancelled() => {}, _ = work => {} }
    });
    ChatRun {
        cancellation,
        finished,
        state: Mutex::new(RunState {
            receiver,
            terminal: false,
        }),
    }
}

fn invalid(message: &str) -> ChatFailure {
    ChatFailure::new(ChatFailureKind::InvalidInput, message)
}

pub(crate) fn url(draft: &ModelConfigDraft) -> Result<Url, ChatFailure> {
    if matches!(draft.provider.as_str(), "MNN" | "LLAMA_CPP") {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "本地模型目录需要原生模型资源服务，当前平台尚未接入",
        ));
    }
    if !matches!(
        draft.protocol.as_str(),
        "chat" | "responses" | "messages" | "native"
    ) {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "该提供方的模型目录尚未接入",
        ));
    }
    // '#'只表示生成端点精确输入；目录路径仍从同一主机派生，不发送到提供方默认主机。
    let raw = draft.endpoint.trim().trim_end_matches('#');
    let mut url = super::endpoint(&format!("{raw}#"), "chat")?;
    let path = url.path().trim_end_matches('/').to_owned();
    let root = path
        .split_once("/models/")
        .map(|(root, _)| root)
        .or_else(|| path.strip_suffix("/chat/completions"))
        .or_else(|| path.strip_suffix("/responses"))
        .or_else(|| path.strip_suffix("/messages"))
        .or_else(|| path.strip_suffix("/models"))
        .unwrap_or(&path);
    let version = root.split('/').any(|part| {
        part.strip_prefix('v').is_some_and(|suffix| {
            let number = suffix.trim_end_matches("beta").trim_end_matches("alpha");
            !number.is_empty() && number.chars().all(|c| c.is_ascii_digit())
        })
    });
    // 兼容端点可能在版本后还有openai等路径；只移除已知操作，保留整个代理前缀。
    let base = if version {
        root.to_owned()
    } else {
        format!(
            "{root}/{}",
            if draft.protocol == "native" {
                "v1beta"
            } else {
                "v1"
            }
        )
    };
    url.set_path(&format!("{base}/models"));
    // 仅匹配旧版官方端点。自定义主机不能借厂商选择把凭据转发到默认服务器。
    if draft.protocol == "messages"
        && url.scheme() == "https"
        && url.port_or_known_default() == Some(443)
    {
        let route = match (draft.provider.as_str(), url.host_str(), path.as_str()) {
            ("DEEPSEEK", Some("api.deepseek.com"), "/anthropic/v1/messages") => Some("/v1/models"),
            ("ZHIPU", Some("open.bigmodel.cn"), "/api/anthropic/v1/messages") => {
                Some("/api/paas/v4/models")
            }
            ("MIMO", Some("api.xiaomimimo.com"), "/anthropic/v1/messages") => Some("/v1/models"),
            ("NOVITA", Some("api.novita.ai"), "/anthropic/v1/messages") => {
                Some("/openai/v1/models")
            }
            _ => None,
        };
        if let Some(route) = route {
            url.set_path(route);
        }
    }
    Ok(url)
}

async fn fetch(
    client: &Client,
    draft: &ModelConfigDraft,
    key: &str,
    custom_headers: Vec<(String, String)>,
) -> Result<Vec<ModelEntry>, ChatFailure> {
    let mut url = url(draft)?;
    if draft.provider == "MOONSHOT"
        && url.host_str() == Some("api.kimi.com")
        && url.scheme() == "https"
        && url.port_or_known_default() == Some(443)
        && url.path() == "/coding/v1/models"
    {
        return Ok(vec![ModelEntry {
            id: "kimi-for-coding".into(),
            name: "kimi-for-coding".into(),
        }]);
    }
    let google = draft.protocol == "native";
    if google && draft.provider != "GOOGLE" {
        return Err(ChatFailure::new(
            ChatFailureKind::Unsupported,
            "该原生协议的模型目录尚未接入",
        ));
    }
    let mut headers = HeaderMap::new();
    let auth_name = if google {
        "x-goog-api-key"
    } else if draft.protocol == "messages"
        && !matches!(
            draft.provider.as_str(),
            "DEEPSEEK"
                | "ZHIPU"
                | "MIMO"
                | "NOVITA"
                | "SILICONFLOW"
                | "INFINIAI"
                | "LMSTUDIO"
                | "OLLAMA"
                | "MOONSHOT"
        )
    {
        "x-api-key"
    } else {
        "authorization"
    };
    if !key.trim().is_empty() {
        let raw = if auth_name == "authorization" {
            format!("Bearer {}", key.trim())
        } else {
            key.trim().into()
        };
        let mut value = HeaderValue::from_str(&raw).map_err(|_| invalid("认证信息格式无效"))?;
        value.set_sensitive(true);
        headers.insert(HeaderName::from_static(auth_name), value);
    }
    if draft.protocol == "messages" {
        headers.insert("anthropic-version", HeaderValue::from_static("2023-06-01"));
    }
    if draft.provider == "MIMO" && !key.trim().is_empty() {
        let mut value =
            HeaderValue::from_str(key.trim()).map_err(|_| invalid("认证信息格式无效"))?;
        value.set_sensitive(true);
        headers.insert("api-key", value);
    }
    if custom_headers.len() > 100 {
        return Err(invalid("请求头数量过多"));
    }
    for (name, value) in custom_headers {
        let name = HeaderName::from_bytes(name.trim().as_bytes())
            .map_err(|_| invalid("请求头名称无效"))?;
        if matches!(
            name.as_str(),
            "host"
                | "content-length"
                | "transfer-encoding"
                | "connection"
                | "content-type"
                | "accept"
                | "upgrade"
                | "proxy-authorization"
                | "cookie"
        ) {
            return Err(invalid("自定义请求头不能覆盖传输控制字段"));
        }
        let mut value = HeaderValue::from_str(&value).map_err(|_| invalid("请求头内容无效"))?;
        value.set_sensitive(true);
        headers.insert(name, value);
    }
    let mut models = Vec::new();
    let mut seen = HashSet::new();
    let mut cursors = HashSet::new();
    let mut total_bytes = 0;
    for _ in 0..100 {
        let mut response = client
            .get(url.clone())
            .headers(headers.clone())
            .header("Accept", "application/json")
            .send()
            .await
            .map_err(super::transport)?;
        if !response.status().is_success() {
            let status = response.status().as_u16();
            return Err(ChatFailure {
                kind: ChatFailureKind::Http,
                message: format!("模型目录服务返回HTTP {status}"),
                http_status: Some(status),
            });
        }
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(super::transport)? {
            total_bytes += chunk.len();
            if total_bytes > 8 * 1024 * 1024 {
                return Err(ChatFailure::new(
                    ChatFailureKind::Protocol,
                    "模型目录超过8 MiB限制",
                ));
            }
            body.extend_from_slice(&chunk);
        }
        let value: Value = serde_json::from_slice(&body).map_err(|_| ChatFailure::protocol())?;
        let entries = value
            .get(if google { "models" } else { "data" })
            .and_then(Value::as_array)
            .ok_or_else(ChatFailure::protocol)?;
        for entry in entries {
            let id = entry
                .get(if google { "name" } else { "id" })
                .and_then(Value::as_str)
                .ok_or_else(ChatFailure::protocol)?;
            let id = if google {
                id.strip_prefix("models/").unwrap_or(id)
            } else {
                id
            };
            if id.trim().is_empty() || id.len() > 512 || id.chars().any(char::is_control) {
                return Err(ChatFailure::protocol());
            }
            let name = entry
                .get("display_name")
                .or_else(|| entry.get("displayName"))
                .or_else(|| entry.get("name").filter(|_| !google))
                .and_then(Value::as_str)
                .unwrap_or(id);
            if name.len() > 2048 || name.chars().any(char::is_control) {
                return Err(ChatFailure::protocol());
            }
            if seen.insert(id.to_owned()) {
                models.push(ModelEntry {
                    id: id.into(),
                    name: name.into(),
                });
                if models.len() > 20_000 {
                    return Err(ChatFailure::new(
                        ChatFailureKind::Protocol,
                        "模型目录超过20000项限制",
                    ));
                }
            }
        }
        let cursor = if google {
            value
                .get("nextPageToken")
                .and_then(Value::as_str)
                .filter(|s| !s.is_empty())
        } else if value.get("has_more") == Some(&Value::Bool(true)) {
            Some(
                value
                    .get("last_id")
                    .and_then(Value::as_str)
                    .filter(|s| !s.is_empty())
                    .ok_or_else(ChatFailure::protocol)?,
            )
        } else {
            None
        };
        let Some(cursor) = cursor else {
            return Ok(models);
        };
        if cursor.len() > 2048 || !cursors.insert(cursor.to_owned()) {
            return Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "模型目录分页游标无效",
            ));
        }
        url.set_query(None);
        url.query_pairs_mut()
            .append_pair(if google { "pageToken" } else { "after_id" }, cursor);
    }
    Err(ChatFailure::new(
        ChatFailureKind::Protocol,
        "模型目录超过100页限制",
    ))
}
