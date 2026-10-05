//! 旧审计字面量多词 AND 匹配；不建立明文索引或改写事件链。
use serde_json::Value;

fn fold(text: &str) -> String {
    text.chars()
        .map(|ch| {
            // Kotlin/Java Char大小写是单字符映射，ß不能扩为SS。
            let mut upper = ch.to_uppercase();
            let first = upper.next().unwrap_or(ch);
            let upper = if upper.next().is_none() { first } else { ch };
            upper.to_lowercase().next().unwrap_or(upper)
        })
        .collect()
}

pub(super) struct Query {
    terms: Vec<String>,
}

impl Query {
    pub(super) fn new(query: &str) -> Self {
        let mut terms = Vec::new();
        for term in query.split_whitespace() {
            let term = fold(term);
            if !terms.contains(&term) {
                terms.push(term);
            }
        }
        Self { terms }
    }

    pub(super) fn excerpt(&self, event: &Value, payload: &str) -> Option<String> {
        let mut fields = [
            "sequence",
            "eventId",
            "category",
            "eventType",
            "actor",
            "summary",
            "localExecutionId",
            "providerCallId",
            "parentEventId",
            "terminalState",
            "visibility",
            "messageTimestamp",
            "variantIndex",
            "sourceChatId",
            "sourceEventId",
            "eventSha256",
            "previousEventSha256",
        ]
        .into_iter()
        .filter_map(|key| match &event[key] {
            Value::String(value) => Some(value.clone()),
            Value::Number(value) => Some(value.to_string()),
            _ => None,
        })
        .collect::<Vec<_>>();
        // 当前事件的唯一JSON正文附件；未知工具/来源字段不从正文猜测重建。
        fields.extend(["正文".into(), "body".into(), payload.into()]);
        let folded: Vec<_> = fields.iter().map(|value| fold(value)).collect();
        if self.terms.is_empty()
            || !self
                .terms
                .iter()
                .all(|term| folded.iter().any(|field| field.contains(term)))
        {
            return None;
        }
        let index = folded
            .iter()
            .rposition(|field| self.terms.iter().any(|term| field.contains(term)))?;
        let position = self
            .terms
            .iter()
            .filter_map(|term| folded[index].find(term))
            .min()
            .unwrap_or(0);
        // fold可能改变UTF-8字节宽度，先还原字符位置，再按旧UTF-16窗口取摘录。
        let characters = folded[index][..position].chars().count();
        let position: usize = fields[index]
            .chars()
            .take(characters)
            .map(char::len_utf16)
            .sum();
        let units: Vec<_> = fields[index].encode_utf16().collect();
        let start = position.saturating_sub(60);
        let end = (start + 240).min(units.len());
        let mut excerpt = String::new();
        let mut space = false;
        for ch in String::from_utf16_lossy(&units[start..end]).chars() {
            if ch.is_whitespace() {
                if !space {
                    excerpt.push(' ');
                }
                space = true;
            } else {
                excerpt.push(ch);
                space = false;
            }
        }
        Some(format!(
            "{}{}{}",
            if start > 0 { "…" } else { "" },
            excerpt,
            if end < units.len() { "…" } else { "" }
        ))
    }
}
