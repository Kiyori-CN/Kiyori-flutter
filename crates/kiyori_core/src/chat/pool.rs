use super::*;
use crate::models::ModelConfigDraft;
use std::collections::{HashSet, VecDeque};
use tokio::task::JoinSet;

pub struct PoolKey {
    pub id: String,
    pub key: String,
    pub enabled: bool,
    pub availability: String,
}

pub(crate) fn start_pool(
    client: Arc<Client>,
    draft: ModelConfigDraft,
    keys: Vec<PoolKey>,
    headers: Vec<(String, String)>,
    concurrency: u32,
    cancellation: CancellationToken,
) -> Result<ChatRun, CoreError> {
    let invalid = || CoreError {
        code: ErrorCode::InvalidInput,
        message: "密钥池测试参数无效".into(),
    };
    if keys.len() > 20_000
        || concurrency > 32
        || !matches!(draft.protocol.as_str(), "chat" | "responses")
        || endpoint(&draft.endpoint, &draft.protocol).is_err()
    {
        return Err(invalid());
    }
    let mut ids = HashSet::new();
    for key in &keys {
        if key.id.is_empty()
            || !ids.insert(&key.id)
            || key.key.trim().is_empty()
            || !matches!(
                key.availability.as_str(),
                "UNTESTED" | "AVAILABLE" | "UNAVAILABLE"
            )
        {
            return Err(invalid());
        }
    }
    probe::prepare(draft.clone(), String::new(), headers.clone(), "chat")?;
    let mut pending = VecDeque::new();
    for key in keys
        .into_iter()
        .filter(|k| k.enabled && k.availability == "UNTESTED")
    {
        pending.push_back(key);
    }
    let (sender, receiver) = mpsc::channel(8);
    let finished = CancellationToken::new();
    let guard = finished.clone().drop_guard();
    let cancel = cancellation.clone();
    tokio::spawn(async move {
        let _guard = guard;
        let mut workers = JoinSet::new();
        let work = async {
            let _ = sender.send(ChatEvent::Started).await;
            loop {
                while workers.len() < concurrency.max(1) as usize {
                    let Some(key) = pending.pop_front() else {
                        break;
                    };
                    let draft = draft.clone();
                    let headers = headers.clone();
                    let client = client.clone();
                    workers.spawn(async move {
                        let id = key.id;
                        let Ok(request) = probe::prepare(draft, key.key, headers, "chat") else {
                            return Err(ChatFailure::new(
                                ChatFailureKind::InvalidInput,
                                "密钥池测试配置无效",
                            ));
                        };
                        // 单key探测复用同一execute；collector只保留终态，不累计事件。
                        let (tx, mut rx) = mpsc::channel(8);
                        let send = async {
                            let result = execute(&client, request, &tx).await;
                            drop(tx);
                            result
                        };
                        let collect = async {
                            let mut available = false;
                            while let Some(event) = rx.recv().await {
                                if matches!(
                                    event,
                                    ChatEvent::Completed {
                                        verified: Some(true),
                                        ..
                                    }
                                ) {
                                    available = true;
                                }
                            }
                            available
                        };
                        let (result, available) = tokio::join!(send, collect);
                        if let Err(error) = &result
                            && matches!(
                                error.kind,
                                ChatFailureKind::InvalidInput | ChatFailureKind::Unsupported
                            )
                        {
                            return Err(error.clone());
                        }
                        Ok((id, result.is_ok() && available))
                    });
                }
                let Some(result) = workers.join_next().await else {
                    break;
                };
                match result {
                    Ok(Ok((id, available))) => {
                        if sender
                            .send(ChatEvent::PoolResult { id, available })
                            .await
                            .is_err()
                        {
                            break;
                        }
                    }
                    Ok(Err(error)) => {
                        let _ = sender.send(ChatEvent::Failed(error)).await;
                        return;
                    }
                    Err(_) => {
                        let _ = sender
                            .send(ChatEvent::Failed(ChatFailure::new(
                                ChatFailureKind::Interrupted,
                                "密钥池测试任务意外结束",
                            )))
                            .await;
                        return;
                    }
                }
            }
            let _ = sender
                .send(ChatEvent::Completed {
                    reason: "pool".into(),
                    verified: None,
                })
                .await;
        };
        tokio::select! { biased; _ = cancel.cancelled() => {}, _ = work => {} }
        // 暂停完成前等待所有worker被中止，不能把取消伪装成不可用。
        workers.abort_all();
        while workers.join_next().await.is_some() {}
    });
    Ok(ChatRun {
        cancellation,
        finished,
        state: Mutex::new(RunState {
            receiver,
            terminal: false,
        }),
    })
}
