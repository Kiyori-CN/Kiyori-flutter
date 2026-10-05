//! serde-hjson 1.1.0缺单引号；仅转换完整引号token，保持无引号正文、注释与多行文字。
use super::{CoreError, error};

fn invalid() -> CoreError {
    error("扩展HJSON字符串无效")
}
fn primitive(text: &str) -> bool {
    matches!(
        serde_json::from_str::<serde_json::Value>(text.trim()),
        Ok(serde_json::Value::Null | serde_json::Value::Bool(_) | serde_json::Value::Number(_))
    )
}
fn quoted(text: &str, start: usize) -> Result<(String, usize), CoreError> {
    let bytes = text.as_bytes();
    let delimiter = bytes[start];
    let mut json = String::from("\"");
    let mut index = start + 1;
    loop {
        let ch = *bytes.get(index).ok_or_else(invalid)?;
        if ch == delimiter {
            json.push('"');
            return Ok((json, index + 1));
        }
        if ch < 32 {
            return Err(invalid());
        }
        if ch == b'\\' {
            index += 1;
            match *bytes.get(index).ok_or_else(invalid)? {
                b'\'' => json.push('\''),
                escaped @ (b'"' | b'/' | b'\\' | b'b' | b'f' | b'n' | b'r' | b't' | b'u') => {
                    json.push('\\');
                    json.push(escaped as char);
                }
                _ => return Err(invalid()),
            }
            index += 1;
        } else {
            let ch = text[index..].chars().next().ok_or_else(invalid)?;
            if ch == '"' {
                json.push('\\');
            }
            json.push(ch);
            index += ch.len_utf8();
        }
    }
}
fn multiline(text: &str, start: usize) -> Result<(String, usize), CoreError> {
    let bytes = text.as_bytes();
    let line_start = text[..start].rfind('\n').map_or(0, |offset| offset + 1);
    let indent = text[line_start..start].encode_utf16().count();
    let mut index = start + 3;
    while matches!(bytes.get(index), Some(b' ' | b'\t' | b'\r')) {
        index += 1;
    }
    let mut value = String::new();
    let mut new_line = bytes.get(index) == Some(&b'\n');
    if new_line {
        index += 1;
    }
    while index < bytes.len() {
        if new_line {
            for _ in 0..indent {
                if matches!(bytes.get(index), Some(b' ' | b'\t' | b'\r')) {
                    index += 1;
                } else {
                    break;
                }
            }
        }
        if bytes[index..].starts_with(b"'''") {
            if value.ends_with('\n') {
                value.pop();
            }
            return Ok((
                serde_json::to_string(&value).map_err(|_| invalid())?,
                index + 3,
            ));
        }
        let ch = text[index..].chars().next().ok_or_else(invalid)?;
        if ch != '\r' {
            value.push(ch);
        }
        new_line = ch == '\n';
        index += ch.len_utf8();
    }
    Err(invalid())
}
pub(super) fn normalize(text: &str) -> Result<String, CoreError> {
    let bytes = text.as_bytes();
    let mut output = String::with_capacity(text.len());
    let mut index = 0;
    let mut objects = vec![true];
    let mut key = true;
    let mut waiting = true;
    let mut bare: Option<usize> = None;
    let mut can_be_primitive = true;
    while index < bytes.len() {
        let ch = bytes[index];
        if bare.is_none() && (ch == b'#' || bytes[index..].starts_with(b"//")) {
            let end = bytes[index..]
                .iter()
                .position(|&b| b == b'\n')
                .map_or(bytes.len(), |length| index + length);
            output.push_str(&text[index..end]);
            index = end;
            continue;
        }
        if bare.is_none() && bytes[index..].starts_with(b"/*") {
            let end = text[index + 2..].find("*/").ok_or_else(invalid)? + index + 4;
            output.push_str(&text[index..end]);
            index = end;
            continue;
        }
        if bare.is_none() && waiting && matches!(ch, b'\'' | b'"') {
            if !key && bytes[index..].starts_with(b"'''") {
                let (json, end) = multiline(text, index)?;
                output.push_str(&json);
                index = end;
            } else {
                let (json, end) = quoted(text, index)?;
                output.push_str(&json);
                index = end;
            }
            waiting = false;
            continue;
        }
        if matches!(ch, b'\n' | b'\r') {
            if bare.is_some() || !waiting {
                key = *objects.last().ok_or_else(invalid)?;
                waiting = true;
            }
            bare = None;
        } else if key && ch == b':' {
            key = false;
            waiting = true;
            bare = None;
        } else if bare.is_none()
            || (can_be_primitive
                && matches!(ch, b',' | b']' | b'}' | b'#' | b'/')
                && bare.is_some_and(|start| {
                    let result = primitive(&text[start..index]);
                    can_be_primitive = result;
                    result
                }))
        {
            match ch {
                b'{' | b'[' if waiting => {
                    if objects.len() >= 32 {
                        return Err(invalid());
                    }
                    objects.push(ch == b'{');
                    key = ch == b'{';
                    bare = None;
                }
                b'}' | b']' => {
                    if objects.len() > 1 {
                        objects.pop();
                    }
                    key = false;
                    waiting = false;
                    bare = None;
                }
                b',' => {
                    key = *objects.last().ok_or_else(invalid)?;
                    waiting = true;
                    bare = None;
                }
                b'#' | b'/'
                    if bare.is_some()
                        && (ch == b'#'
                            || bytes[index..].starts_with(b"//")
                            || bytes[index..].starts_with(b"/*")) =>
                {
                    // 数字/布尔/null之后的注释属于分隔符，无引号字符串内部同字符保留。
                    bare = None;
                    waiting = false;
                    continue;
                }
                b' ' | b'\t' => {}
                _ if waiting => {
                    bare = Some(index);
                    can_be_primitive = true;
                    waiting = false;
                }
                _ => {}
            }
        }
        let character = text[index..].chars().next().ok_or_else(invalid)?;
        output.push(character);
        index += character.len_utf8();
    }
    Ok(output)
}
