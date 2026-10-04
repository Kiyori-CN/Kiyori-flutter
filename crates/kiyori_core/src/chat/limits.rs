//! 配置级请求队列，复用 Runtime 生命周期。配额按单调时钟计算，取消不占用等待中的槽。
use std::{
    collections::{HashMap, VecDeque},
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
use tokio::sync::Notify;

#[derive(Default)]
pub struct Registry {
    gates: Mutex<HashMap<String, Arc<Gate>>>,
}
#[derive(Default)]
struct State {
    revision: u32,
    per_minute: u32,
    concurrent: u32,
    active: u32,
    times: VecDeque<Instant>,
}
#[derive(Default)]
pub struct Gate {
    state: Mutex<State>,
    changed: Notify,
}
pub struct Permit(Arc<Gate>);
impl Drop for Permit {
    fn drop(&mut self) {
        let mut state = self
            .0
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        state.active = state.active.saturating_sub(1);
        drop(state);
        self.0.changed.notify_waiters();
    }
}
impl Registry {
    pub fn remove(&self, id: &str) {
        self.gates
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .remove(id);
    }
    pub fn configure(
        &self,
        id: &str,
        revision: u32,
        per_minute: u32,
        concurrent: u32,
    ) -> Arc<Gate> {
        let gate = self
            .gates
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .entry(id.to_owned())
            .or_default()
            .clone();
        let mut state = gate
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if revision >= state.revision {
            state.revision = revision;
            state.per_minute = per_minute;
            state.concurrent = concurrent;
        }
        drop(state);
        gate.changed.notify_waiters();
        gate
    }
}
impl Gate {
    pub async fn acquire(self: &Arc<Self>) -> Permit {
        loop {
            let notified = self.changed.notified();
            tokio::pin!(notified);
            // 先登记再检查，释放槽位发生在检查与等待之间时也不会丢失通知。
            notified.as_mut().enable();
            let wait = {
                let now = Instant::now();
                let mut state = self
                    .state
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner);
                while state
                    .times
                    .front()
                    .is_some_and(|time| now.duration_since(*time) >= Duration::from_secs(60))
                {
                    state.times.pop_front();
                }
                let rate = state.per_minute == 0 || state.times.len() < state.per_minute as usize;
                let concurrency = state.concurrent == 0 || state.active < state.concurrent;
                if rate && concurrency {
                    state.active = state.active.saturating_add(1);
                    if state.per_minute > 0 {
                        state.times.push_back(now);
                    }
                    return Permit(self.clone());
                }
                if !rate {
                    state.times.front().map(|time| {
                        Duration::from_secs(60).saturating_sub(now.duration_since(*time))
                    })
                } else {
                    None
                }
            };
            match wait {
                Some(wait) => {
                    tokio::select! { _ = &mut notified => {}, _ = tokio::time::sleep(wait) => {} }
                }
                None => notified.await,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn concurrency_waits_and_drop_releases_without_consuming_rate_for_waiters() {
        let registry = Registry::default();
        let gate = registry.configure("config", 1, 2, 1);
        let permit = gate.acquire().await;
        assert!(
            tokio::time::timeout(Duration::from_millis(20), gate.acquire())
                .await
                .is_err()
        );
        assert_eq!(gate.state.lock().unwrap().times.len(), 1);
        drop(permit);
        let permit = tokio::time::timeout(Duration::from_secs(1), gate.acquire())
            .await
            .unwrap();
        drop(permit);
        assert!(
            tokio::time::timeout(Duration::from_millis(20), gate.acquire())
                .await
                .is_err()
        );
        // 等待中放宽限制唤醒原等待者，不重置实际在途计数。
        let waiting = gate.acquire();
        tokio::pin!(waiting);
        assert!(
            tokio::time::timeout(Duration::from_millis(20), &mut waiting)
                .await
                .is_err()
        );
        registry.configure("config", 2, 0, 0);
        let permit = tokio::time::timeout(Duration::from_secs(1), waiting)
            .await
            .unwrap();
        drop(permit);
        registry.configure("config", 1, 1, 1);
        assert_eq!(gate.state.lock().unwrap().per_minute, 0);
    }
    #[tokio::test]
    async fn separate_configs_do_not_share_slots_and_expired_window_is_reusable() {
        let registry = Registry::default();
        let a = registry.configure("a", 1, 1, 1);
        let b = registry.configure("b", 1, 1, 1);
        let first = a.acquire().await;
        let second = b.acquire().await;
        drop(first);
        drop(second);
        a.state.lock().unwrap().times[0] = Instant::now() - Duration::from_secs(61);
        let permit = tokio::time::timeout(Duration::from_secs(1), a.acquire())
            .await
            .unwrap();
        drop(permit);
        assert_eq!(a.state.lock().unwrap().times.len(), 1);
    }

    #[tokio::test]
    async fn saved_limits_immediately_wake_existing_waiters_without_a_new_request() {
        let path = std::env::temp_dir().join(format!(
            "kiyori-limit-edit-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let runtime = crate::runtime::Runtime::with_data_dir(&path).unwrap();
        let mut config = runtime.model_catalog().unwrap().configs.remove(0);
        config.draft.options.concurrent_limit = 1;
        config.draft.options.request_limit = 1;
        runtime
            .save_model_config(config.id.clone(), config.revision, config.draft, None, None)
            .unwrap();
        let gate = runtime.model_limits.configure("default", 2, 1, 1);
        let permit = gate.acquire().await;
        let waiting = gate.acquire();
        tokio::pin!(waiting);
        assert!(
            tokio::time::timeout(Duration::from_millis(20), &mut waiting)
                .await
                .is_err()
        );
        let mut config = runtime.model_catalog().unwrap().configs.remove(0);
        config.draft.options.concurrent_limit = 0;
        config.draft.options.request_limit = 0;
        runtime
            .save_model_config(config.id, config.revision, config.draft, None, None)
            .unwrap();
        let next = tokio::time::timeout(Duration::from_secs(1), waiting)
            .await
            .unwrap();
        drop(next);
        drop(permit);
        runtime.close();
        std::fs::remove_dir_all(path).unwrap();
    }

    #[tokio::test]
    async fn configured_requests_wait_cancel_without_http_and_release_for_the_next_request() {
        use std::{
            io::{Read, Write},
            net::TcpListener,
            sync::atomic::{AtomicUsize, Ordering},
        };
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let endpoint = format!(
            "http://{}/v1/chat/completions",
            listener.local_addr().unwrap()
        );
        let entered = Arc::new(AtomicUsize::new(0));
        let count = entered.clone();
        let (release, wait) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            for i in 0..2 {
                let (mut socket, _) = listener.accept().unwrap();
                socket
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut header = Vec::new();
                let mut byte = [0; 1];
                while !header.ends_with(b"\r\n\r\n") {
                    socket.read_exact(&mut byte).unwrap();
                    header.push(byte[0]);
                }
                let length = String::from_utf8(header)
                    .unwrap()
                    .lines()
                    .find_map(|line| {
                        line.to_ascii_lowercase()
                            .strip_prefix("content-length: ")
                            .and_then(|n| n.parse::<usize>().ok())
                    })
                    .unwrap();
                socket.read_exact(&mut vec![0; length]).unwrap();
                count.fetch_add(1, Ordering::SeqCst);
                if i == 0 {
                    wait.recv_timeout(Duration::from_secs(5)).unwrap();
                }
                let body = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"ok\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n";
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = socket.write_all(response.as_bytes());
            }
        });
        let path = std::env::temp_dir().join(format!(
            "kiyori-admission-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let runtime = crate::runtime::Runtime::with_data_dir(&path).unwrap();
        let mut config = runtime.model_catalog().unwrap().configs.remove(0);
        config.draft.endpoint = endpoint;
        config.draft.options.concurrent_limit = 1;
        runtime
            .save_model_config(config.id.clone(), config.revision, config.draft, None, None)
            .unwrap();
        let payload = r#"{"version":3,"apiKey":"fixture","headers":{},"usePool":false,"keys":[],"rotation":"ROUND_ROBIN"}"#;
        let first = runtime
            .start_configured_probe("default".into(), 2, payload.into(), "chat".into())
            .unwrap();
        tokio::time::timeout(Duration::from_secs(3), async {
            while entered.load(Ordering::SeqCst) == 0 {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
        })
        .await
        .unwrap();
        let queued = runtime
            .start_configured_probe("default".into(), 2, payload.into(), "chat".into())
            .unwrap();
        tokio::time::sleep(Duration::from_millis(20)).await;
        assert_eq!(entered.load(Ordering::SeqCst), 1);
        queued.cancel_and_wait().await;
        assert_eq!(
            queued.next_event().await.unwrap(),
            Some(super::super::ChatEvent::Cancelled)
        );
        first.cancel_and_wait().await;
        release.send(()).unwrap();
        let third = runtime
            .start_configured_probe("default".into(), 2, payload.into(), "chat".into())
            .unwrap();
        let mut completed = false;
        while let Some(event) = third.next_event().await.unwrap() {
            if matches!(
                event,
                super::super::ChatEvent::Completed {
                    verified: Some(true),
                    ..
                }
            ) {
                completed = true;
            }
        }
        assert!(completed);
        assert_eq!(entered.load(Ordering::SeqCst), 2);
        worker.join().unwrap();
        runtime.close();
        std::fs::remove_dir_all(path).unwrap();
    }
}
