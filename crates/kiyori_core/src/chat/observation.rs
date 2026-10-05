//! 请求内观测：不入库，不从历史耗时反推速度；与旧GenerationSpeedTracker同一生命周期。
use super::{ChatEvent, ChatMessage};
use std::time::Instant;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Observation {
    pub context_tokens: i64,
    pub context_limit: i64,
    pub tokens_per_second: Option<f64>,
    pub estimated: bool,
    pub first_output_ms: Option<i64>,
    pub duration_ms: Option<i64>,
    pub model: String,
    pub input_tokens: Option<i64>,
    pub output_tokens: Option<i64>,
    pub cache_read_tokens: Option<i64>,
    pub cache_write_tokens: Option<i64>,
    pub reasoning_tokens: Option<i64>,
    pub finished: bool,
}

// Kotlin String.length按UTF-16计数；每条消息/分片分别截去小数，不将累计正文重新估算。
pub(crate) fn estimate(text: &str) -> i64 {
    let (mut chinese, mut other) = (0i64, 0i64);
    for c in text.chars() {
        if ('\u{4e00}'..='\u{9fff}').contains(&c) {
            chinese += 1;
        } else {
            other += c.len_utf16() as i64;
        }
    }
    (chinese * 6 + other) / 4
}

pub(crate) struct Tracker {
    started: Instant,
    streaming: bool,
    first: Option<i64>,
    chunks: u8,
    estimated_tokens: i64,
    provider: Option<ChatEvent>,
    model: String,
    snapshot: Observation,
}

impl Tracker {
    pub fn new(streaming: bool, model: String, messages: &[ChatMessage], limit: i64) -> Self {
        Self {
            started: Instant::now(),
            streaming,
            first: None,
            chunks: 0,
            estimated_tokens: 0,
            provider: None,
            model,
            snapshot: Observation {
                context_tokens: messages
                    .iter()
                    .map(|m| estimate(&m.content))
                    .fold(0i64, i64::saturating_add),
                context_limit: limit,
                estimated: true,
                ..Observation::default()
            },
        }
    }

    pub fn snapshot(&self) -> Observation {
        self.snapshot.clone()
    }
    pub fn rebase_context(&mut self, messages: &[ChatMessage]) {
        // 总结仍属于本次等待时间；只替换实际聊天请求的上下文估算，不能重启计时。
        self.snapshot.context_tokens = messages
            .iter()
            .map(|m| estimate(&m.content))
            .fold(0i64, i64::saturating_add);
    }
    pub fn set_context_tokens(&mut self, tokens: i64) {
        // 提供方的输入窗口估计独立于Usage，不据此伪造实际用量或输出速度。
        self.snapshot.context_tokens = tokens;
    }

    pub fn observe(&mut self, event: &ChatEvent) {
        self.observe_at(
            event,
            self.started.elapsed().as_millis().min(i64::MAX as u128) as i64,
        );
    }

    fn observe_at(&mut self, event: &ChatEvent, elapsed: i64) {
        if self.snapshot.finished {
            return;
        }
        match event {
            ChatEvent::Text(text) if !text.is_empty() => {
                self.first.get_or_insert(elapsed);
                self.chunks = (self.chunks + 1).min(2);
                self.estimated_tokens = self.estimated_tokens.saturating_add(estimate(text));
            }
            ChatEvent::Usage { output, .. } => {
                self.provider = Some(event.clone());
                self.estimated_tokens = (*output).min(i64::MAX as u64) as i64;
            }
            ChatEvent::Failed(_) | ChatEvent::Cancelled => {
                self.snapshot = Observation {
                    context_tokens: self.snapshot.context_tokens,
                    context_limit: self.snapshot.context_limit,
                    finished: true,
                    estimated: true,
                    ..Observation::default()
                };
                return;
            }
            ChatEvent::Completed { .. } => {
                self.snapshot.finished = true;
                self.snapshot.model = self.model.clone();
                self.snapshot.first_output_ms = self.first;
                self.snapshot.duration_ms = Some(elapsed);
                if let Some(ChatEvent::Usage {
                    input,
                    output,
                    output_reported,
                    cache_read,
                    cache_write,
                    reasoning,
                    ..
                }) = &self.provider
                {
                    self.snapshot.input_tokens = Some(*input as i64);
                    self.snapshot.output_tokens = output_reported.then_some(*output as i64);
                    self.snapshot.cache_write_tokens = cache_write.map(|v| v as i64);
                    self.snapshot.reasoning_tokens = reasoning.map(|v| v as i64);
                    self.snapshot.cache_read_tokens = if *output_reported {
                        cache_read.map(|v| v as i64)
                    } else {
                        None
                    };
                    self.estimated_tokens = if *output_reported { *output as i64 } else { 0 };
                    self.snapshot.estimated = false;
                } else {
                    // 旧UNAVAILABLE样本没有最终供应商输出，不能把本地估算当完成速度。
                    self.estimated_tokens = 0;
                }
            }
            _ => {}
        }
        self.snapshot.tokens_per_second = self.first.and_then(|first| {
            let duration = elapsed - first;
            (self.streaming && self.chunks >= 2 && duration > 0 && self.estimated_tokens > 0)
                .then(|| self.estimated_tokens as f64 * 1000. / duration as f64)
        });
        if !self.snapshot.finished && self.snapshot.tokens_per_second.is_some() {
            self.snapshot.first_output_ms = self.first;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn cancelled_failed_and_unreported_runs_do_not_publish_final_speed() {
        for terminal in [
            ChatEvent::Cancelled,
            ChatEvent::Failed(super::super::ChatFailure::protocol()),
            ChatEvent::Completed {
                reason: "stop".into(),
                verified: None,
            },
        ] {
            let mut tracker = Tracker::new(true, "m".into(), &[], 100);
            tracker.observe_at(&ChatEvent::Text("abcd".into()), 100);
            tracker.observe_at(&ChatEvent::Text("abcd".into()), 200);
            assert!(tracker.snapshot().tokens_per_second.is_some());
            tracker.observe_at(&terminal, 300);
            let s = tracker.snapshot();
            assert_eq!(s.tokens_per_second, None);
            assert_eq!(s.context_limit, 100);
            if !matches!(terminal, ChatEvent::Completed { .. }) {
                assert!(s.model.is_empty());
                assert_eq!(s.first_output_ms, None);
            }
        }
    }
    #[test]
    fn estimate_matches_utf16_and_per_message_rounding() {
        assert_eq!(estimate("中A😀"), 2);
        let tracker = Tracker::new(
            true,
            "m".into(),
            &[
                ChatMessage {
                    role: "user".into(),
                    content: "abc".into(),
                },
                ChatMessage {
                    role: "assistant".into(),
                    content: "abc".into(),
                },
            ],
            100,
        );
        assert_eq!(tracker.snapshot().context_tokens, 0);
    }
    #[test]
    fn summary_projection_rebases_context_without_resetting_wait_or_samples() {
        let mut tracker = Tracker::new(true, "model".into(), &[], 100);
        let started = tracker.started;
        tracker.rebase_context(&[ChatMessage {
            role: "user".into(),
            content: "中中".into(),
        }]);
        assert_eq!(tracker.started, started);
        assert_eq!(tracker.snapshot().context_tokens, 3);
        tracker.observe_at(&ChatEvent::Text("abcd".into()), 2000);
        tracker.observe_at(&ChatEvent::Text("abcd".into()), 2500);
        assert_eq!(tracker.snapshot().first_output_ms, Some(2000));
        assert_eq!(tracker.snapshot().tokens_per_second, Some(4.));
    }
    #[test]
    fn timing_excludes_wait_and_requires_observable_stream() {
        for streaming in [true, false] {
            let mut tracker = Tracker::new(streaming, "m".into(), &[], 100);
            tracker.observe_at(&ChatEvent::Text("abcd".into()), 1000);
            assert_eq!(tracker.snapshot().tokens_per_second, None);
            tracker.observe_at(&ChatEvent::Text("abcd".into()), 1500);
            assert_eq!(
                tracker.snapshot().tokens_per_second,
                streaming.then_some(4.)
            );
            assert_eq!(tracker.snapshot().input_tokens, None);
            tracker.observe_at(
                &ChatEvent::Usage {
                    input: 10,
                    output: 20,
                    output_reported: true,
                    total: 30,
                    cache_read: Some(0),
                    cache_write: None,
                    reasoning: None,
                },
                1800,
            );
            tracker.observe_at(
                &ChatEvent::Completed {
                    reason: "stop".into(),
                    verified: None,
                },
                2000,
            );
            let s = tracker.snapshot();
            assert_eq!(s.tokens_per_second, streaming.then_some(20.));
            assert_eq!(s.first_output_ms, Some(1000));
            assert_eq!(s.duration_ms, Some(2000));
            assert_eq!(s.output_tokens, Some(20));
            assert!(!s.estimated);
            tracker.observe_at(&ChatEvent::Cancelled, 4000);
            assert_eq!(tracker.snapshot(), s);
        }
    }
}
