//! 日记阶段和状态只从正文推导，追加必须保留已有正文。
use crate::runtime::{CoreError, ErrorCode};

pub const PHASES: [&str; 8] = [
    "note",
    "plan",
    "progress",
    "decision",
    "evidence",
    "risk",
    "validation",
    "closed",
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiaryEntry {
    pub date: String,
    pub time: String,
    pub phase: String,
    pub raw_phase: Option<String>,
    pub body: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiaryDocument {
    pub preface: String,
    pub entries: Vec<DiaryEntry>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiarySummary {
    pub closed: bool,
    pub entry_count: u32,
    pub first_day: Option<String>,
    pub last_phase: Option<String>,
    pub last_raw_phase: Option<String>,
}

impl DiaryDocument {
    pub fn metadata(&self) -> DiarySummary {
        DiarySummary {
            closed: self.closed(),
            entry_count: self.entries.len() as u32,
            first_day: self.entries.first().map(|e| e.date.clone()),
            last_phase: self.entries.last().map(|e| e.phase.clone()),
            last_raw_phase: self.entries.last().and_then(|e| e.raw_phase.clone()),
        }
    }
    pub fn closed(&self) -> bool {
        self.entries
            .last()
            .is_some_and(|entry| entry.phase == "closed")
    }
    pub fn summary(&self) -> &str {
        self.entries
            .iter()
            .rev()
            .find(|entry| !entry.body.trim().is_empty())
            .map_or(&self.preface, |entry| &entry.body)
    }
}

fn phase(raw: &str) -> String {
    let value = raw.trim().to_ascii_lowercase();
    if PHASES.contains(&value.as_str()) {
        value
    } else {
        "note".into()
    }
}

fn stamp_shape(date: &str, time: &str) -> bool {
    date.len() == 10
        && time.len() == 5
        && date.bytes().enumerate().all(|(i, b)| {
            if i == 4 || i == 7 {
                b == b'-'
            } else {
                b.is_ascii_digit()
            }
        })
        && time.bytes().enumerate().all(|(i, b)| {
            if i == 2 {
                b == b':'
            } else {
                b.is_ascii_digit()
            }
        })
}

fn valid_stamp(date: &str, time: &str) -> bool {
    if !stamp_shape(date, time) {
        return false;
    }
    let number = |text: &str| text.parse::<u32>().unwrap_or(0);
    let year = number(&date[..4]);
    let month = number(&date[5..7]);
    let day = number(&date[8..]);
    let days = match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if year.is_multiple_of(400) || (year.is_multiple_of(4) && !year.is_multiple_of(100)) => {
            29
        }
        2 => 28,
        _ => 0,
    };
    year > 0 && day > 0 && day <= days && number(&time[..2]) < 24 && number(&time[3..]) < 60
}

fn header(line: &str) -> Option<DiaryEntry> {
    let tail = line.strip_prefix("##")?;
    if !tail.starts_with([' ', '\t']) {
        return None;
    }
    let tail = tail.trim_matches([' ', '\t']);
    let date_end = tail.find([' ', '\t'])?;
    let date = &tail[..date_end];
    let rest = tail[date_end..].trim_start_matches([' ', '\t']);
    if rest.len() < 5 || !rest.is_char_boundary(5) {
        return None;
    }
    let time = &rest[..5];
    if !stamp_shape(date, time) {
        return None;
    }
    let suffix = rest[5..].trim_matches([' ', '\t']);
    let raw = if suffix.is_empty() {
        None
    } else {
        let raw = suffix.strip_prefix('·')?.trim_matches([' ', '\t']);
        if raw.is_empty() {
            return None;
        }
        Some(raw.to_owned())
    };
    Some(DiaryEntry {
        date: date.into(),
        time: time.into(),
        phase: phase(raw.as_deref().unwrap_or("note")),
        raw_phase: raw,
        body: String::new(),
    })
}

pub fn parse(content: &str) -> DiaryDocument {
    let normalized = content.replace("\r\n", "\n").replace('\r', "\n");
    let mut result = DiaryDocument {
        preface: String::new(),
        entries: vec![],
    };
    for line in normalized.split('\n') {
        if let Some(entry) = header(line) {
            result.entries.push(entry);
        } else {
            let body = result
                .entries
                .last_mut()
                .map_or(&mut result.preface, |entry| &mut entry.body);
            body.push_str(line);
            body.push('\n');
        }
    }
    result.preface = result.preface.trim().into();
    for entry in &mut result.entries {
        entry.body = entry.body.trim().into();
    }
    result
}

pub fn append(content: &str, body: &str, value: &str, stamp: &str) -> Result<String, CoreError> {
    let invalid = |message: &str| CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    };
    // 本地时间文本由平台时钟提供，保存后不因设备时区变动重解释。
    let (date, time) = stamp
        .split_once(' ')
        .ok_or_else(|| invalid("Invalid diary timestamp."))?;
    // 读取保留旧自由文本格式；新追加拒绝不存在的日期或时间。
    if !valid_stamp(date, time) || !PHASES.contains(&value) {
        return Err(invalid("Invalid diary phase or timestamp."));
    }
    let body = body.replace("\r\n", "\n").replace('\r', "\n");
    let body = body.trim();
    if body.is_empty() && value != "closed" {
        return Err(invalid("Diary entry cannot be blank."));
    }
    // 与旧 Kotlin String.length 一致，按 UTF-16 code unit 计数。
    if body.encode_utf16().count() > 20_000 {
        return Err(invalid("Diary entry exceeds 20000 characters."));
    }
    let mut result = content.trim_end().to_owned();
    if !result.is_empty() {
        result.push_str("\n\n");
    }
    result.push_str(&format!("## {stamp} · {value}"));
    if !body.is_empty() {
        result.push('\n');
        result.push_str(body);
    }
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parser_preserves_preface_unknown_phase_and_mixed_newlines() {
        let diary = parse(
            "开篇\r\n\r\n## 2026-10-03 09:20 · PLAN\r计划\n## 2026-10-03 09:21 · 自定义\n证据\n## 2026-10-03 09:22 · closed\n",
        );
        assert_eq!(diary.preface, "开篇");
        assert_eq!(diary.entries.len(), 3);
        assert_eq!(diary.entries[0].phase, "plan");
        assert_eq!(diary.entries[1].phase, "note");
        assert_eq!(diary.entries[1].raw_phase.as_deref(), Some("自定义"));
        assert!(diary.closed());
        assert_eq!(diary.summary(), "证据");
        let reopened = append(
            "## 2026-10-03 09:22 · closed",
            "继续",
            "progress",
            "2026-10-03 09:23",
        )
        .unwrap();
        assert!(!parse(&reopened).closed());
        assert_eq!(parse(&reopened).summary(), "继续");
    }
    #[test]
    fn append_validates_utf16_length_and_does_not_rewrite_history() {
        let source = "旧正文\r\n保留";
        let result = append(source, "新记录", "evidence", "2026-10-03 09:24").unwrap();
        assert!(result.starts_with(source));
        assert!(append("", "", "progress", "2026-10-03 09:24").is_err());
        assert!(append("", "", "closed", "2026-10-03 09:24").is_ok());
        assert!(append("", &"🐱".repeat(10_001), "note", "2026-10-03 09:24").is_err());
        assert!(append("", "正文", "unknown", "2026-10-03 09:24").is_err());
        for stamp in [
            "2026-02-29 09:24",
            "2026-04-31 09:24",
            "2026-10-03 24:00",
            "2026-10-03 09:60",
        ] {
            assert!(append("", "正文", "note", stamp).is_err());
        }
        assert!(append("", "正文", "note", "2028-02-29 23:59").is_ok());
    }
}
