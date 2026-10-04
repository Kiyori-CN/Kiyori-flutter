use super::{ChatFailure, ChatFailureKind};

const MAX_EVENT: usize = 1024 * 1024;

/// 按字节保留跨网络块的UTF-8，支持CR、LF、CRLF以及多行data。
/// 只保留当前事件，不把整段回复累积到解析器。
#[derive(Default)]
pub(super) struct Sse {
    line: Vec<u8>,
    data: Vec<u8>,
    cr: bool,
    first: bool,
}

impl Sse {
    pub fn new() -> Self {
        Self {
            first: true,
            ..Self::default()
        }
    }

    pub fn push(&mut self, byte: u8) -> Result<Option<String>, ChatFailure> {
        if self.cr {
            self.cr = false;
            if byte == b'\n' {
                return Ok(None);
            }
        }
        if byte == b'\r' || byte == b'\n' {
            self.cr = byte == b'\r';
            return self.end_line();
        }
        if self.line.len() + self.data.len() >= MAX_EVENT {
            return Err(ChatFailure::new(
                ChatFailureKind::Protocol,
                "流式事件超过1 MiB限制",
            ));
        }
        self.line.push(byte);
        Ok(None)
    }

    pub fn at_boundary(&self) -> bool {
        self.data.is_empty() && (self.line.is_empty() || self.line.first() == Some(&b':'))
    }

    fn end_line(&mut self) -> Result<Option<String>, ChatFailure> {
        let bytes = std::mem::take(&mut self.line);
        let mut line = std::str::from_utf8(&bytes).map_err(|_| ChatFailure::protocol())?;
        if self.first {
            line = line.trim_start_matches('\u{feff}');
            self.first = false;
        }
        if line.is_empty() {
            if self.data.is_empty() {
                return Ok(None);
            }
            self.data.pop();
            return String::from_utf8(std::mem::take(&mut self.data))
                .map(Some)
                .map_err(|_| ChatFailure::protocol());
        }
        let (field, value) = line.split_once(':').unwrap_or((line, ""));
        if field == "data" {
            self.data
                .extend_from_slice(value.strip_prefix(' ').unwrap_or(value).as_bytes());
            self.data.push(b'\n');
        }
        Ok(None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn utf8_multiline_and_all_line_endings() {
        let mut sse = Sse::new();
        let events = "\u{feff}:ping\r\ndata: 你\rdata: 好\n\rdata: [DONE]\n\n"
            .as_bytes()
            .iter()
            .filter_map(|b| sse.push(*b).unwrap())
            .collect::<Vec<_>>();
        assert_eq!(events, ["你\n好", "[DONE]"]);
    }
    #[test]
    fn invalid_utf8_and_oversize_are_errors() {
        let mut sse = Sse::new();
        sse.push(255).unwrap();
        assert!(sse.push(b'\n').is_err());
        let mut sse = Sse::new();
        for _ in 0..MAX_EVENT {
            sse.push(b'x').unwrap();
        }
        assert!(sse.push(b'x').is_err());
    }
}
