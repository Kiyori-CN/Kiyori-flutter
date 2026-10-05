//! 会话审计和消息修订归SQLite；事件链只追加，旧数据明确标记为基础快照。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use base64::{Engine, engine::general_purpose::STANDARD};
use ring::{
    digest::{SHA256, digest},
    rand::SystemRandom,
    signature::{Ed25519KeyPair, KeyPair},
};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use serde_json::{Value, json};
use std::io::{Cursor, Write};

pub(crate) const SCHEMA: &str = "
ALTER TABLE conversations ADD COLUMN parent_id TEXT REFERENCES conversations(id) ON DELETE SET NULL;
CREATE TABLE conversation_audit_events(
 conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 sequence INTEGER NOT NULL, event_id TEXT NOT NULL UNIQUE, recorded_at INTEGER NOT NULL,
 category TEXT NOT NULL,event_type TEXT NOT NULL,summary TEXT NOT NULL,
 payload TEXT NOT NULL,previous_hash TEXT NOT NULL,event_hash TEXT NOT NULL,
 PRIMARY KEY(conversation_id,sequence));
CREATE TRIGGER conversation_audit_no_update BEFORE UPDATE ON conversation_audit_events
 BEGIN SELECT RAISE(ABORT,'Audit events are append only'); END;
PRAGMA user_version=20;";
const MAX_EXPORT: usize = 64 * 1024 * 1024;
#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(c: &Connection) {
    c.execute_batch("DROP TABLE IF EXISTS conversation_audit_events; DROP TABLE IF EXISTS conversation_audit_key;").unwrap();
    let has_parent = c
        .prepare("PRAGMA table_info(conversations)")
        .unwrap()
        .query_map([], |r| r.get::<_, String>(1))
        .unwrap()
        .any(|r| r.unwrap() == "parent_id");
    if has_parent {
        c.execute_batch("ALTER TABLE conversations DROP COLUMN parent_id;")
            .unwrap();
    }
}
fn error(text: &str) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: text.into(),
    }
}
fn db(_: rusqlite::Error) -> CoreError {
    error("会话审计存储失败")
}
fn time() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
pub(crate) fn hash(bytes: &[u8]) -> String {
    digest(&SHA256, bytes)
        .as_ref()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}
fn encoded(fields: [&str; 8]) -> String {
    // 带UTF-8字节长度的字段消除拼接歧义。格式独立版本化，不冒充旧Android事件编码。
    let mut out = String::from("kiyori-audit-v1\n");
    for value in fields {
        out.push_str(&format!("{}:{value}\n", value.len()));
    }
    out
}
pub(crate) fn append(
    tx: &Connection,
    id: &str,
    category: &str,
    kind: &str,
    summary: &str,
    payload: Value,
) -> Result<(), CoreError> {
    let (seq,previous)=tx.query_row("SELECT sequence,event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence DESC LIMIT 1",[id],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,String>(1)?))).optional().map_err(db)?.unwrap_or((0,String::new()));
    let seq = seq + 1;
    let at = time();
    let payload = payload.to_string();
    let event = hash(
        encoded([
            id,
            &seq.to_string(),
            &at.to_string(),
            category,
            kind,
            summary,
            &payload,
            &previous,
        ])
        .as_bytes(),
    );
    let event_id = format!("{id}/{seq}");
    tx.execute(
        "INSERT INTO conversation_audit_events VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)",
        params![
            id, seq, event_id, at, category, kind, summary, payload, previous, event
        ],
    )
    .map_err(db)?;
    Ok(())
}
pub(crate) fn messages(tx: &Connection, id: &str, run: Option<&str>) -> Result<Value, CoreError> {
    let values=tx.prepare("SELECT id,role,content,state,variant,run_id,position FROM conversation_messages WHERE conversation_id=?1 AND (?2 IS NULL OR run_id=?2) ORDER BY position").map_err(db)?.query_map(params![id,run],|r|Ok(json!({"id":r.get::<_,String>(0)?,"role":r.get::<_,String>(1)?,"content":r.get::<_,String>(2)?,"state":r.get::<_,String>(3)?,"variant":r.get::<_,i64>(4)?,"runId":r.get::<_,Option<String>>(5)?,"position":r.get::<_,i64>(6)?}))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
    Ok(json!(values))
}
pub(crate) fn changed_messages(
    tx: &Connection,
    id: &str,
    message: &str,
    action: &str,
    text: &str,
) -> Result<Value, CoreError> {
    let selected = if action == "delete_selected" {
        text
    } else {
        "[]"
    };
    let values=tx.prepare("SELECT m.id,m.role,m.content,m.state,m.variant,m.run_id,m.position FROM conversation_messages m WHERE m.conversation_id=?1 AND (m.id=?2 OR (?3='deleteFrom' AND m.position>=(SELECT position FROM conversation_messages WHERE id=?2)) OR (?3='delete_selected' AND m.id IN (SELECT value FROM json_each(?4)))) ORDER BY m.position").map_err(db)?.query_map(params![id,message,action,selected],|r|Ok(json!({"id":r.get::<_,String>(0)?,"role":r.get::<_,String>(1)?,"content":r.get::<_,String>(2)?,"state":r.get::<_,String>(3)?,"variant":r.get::<_,i64>(4)?,"runId":r.get::<_,Option<String>>(5)?,"position":r.get::<_,i64>(6)?}))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
    Ok(json!(values))
}
pub(crate) fn initialize(tx: &Connection, id: &str) -> Result<(), CoreError> {
    if !tx
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM conversation_audit_events WHERE conversation_id=?1)",
            [id],
            |r| r.get::<_, bool>(0),
        )
        .map_err(db)?
    {
        append(
            tx,
            id,
            "HISTORY",
            "BASIC_SNAPSHOT",
            "基础历史快照",
            json!({"messages":messages(tx,id,None)?,"coverage":"既有消息的当前快照；迁移前的修订与供应商事件未知"}),
        )?;
    }
    Ok(())
}

impl AppStore {
    pub fn conversation_audit(
        &self,
        id: &str,
        before: i64,
        query: &str,
    ) -> Result<String, CoreError> {
        if query.len() > 4096 || before < 0 {
            return Err(error("审计查询参数无效"));
        }
        let mut c = self
            .connection
            .lock()
            .map_err(|_| error("审计存储锁不可用"))?;
        let tx = c
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db)?;
        let exists = tx
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM conversations WHERE id=?1)",
                [id],
                |r| r.get::<_, bool>(0),
            )
            .map_err(db)?;
        if !exists {
            return Err(error("对话已不存在"));
        }
        initialize(&tx, id)?;
        let (total,bytes,head):(i64,i64,String)=tx.query_row("SELECT count(*),coalesce(sum(length(CAST(payload AS BLOB))),0),coalesce((SELECT event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence DESC LIMIT 1),'') FROM conversation_audit_events WHERE conversation_id=?1",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(db)?;
        let terms: Vec<String> = query.split_whitespace().map(str::to_lowercase).collect();
        let filter=terms.iter().enumerate().map(|(i,_)|format!(" AND instr(lower(event_id||' '||category||' '||event_type||' '||summary||' '||payload),?{})>0",i+3)).collect::<String>();
        let sql = format!(
            "SELECT sequence,event_id,recorded_at,category,event_type,summary,previous_hash,event_hash,length(payload),length(CAST(payload AS BLOB)) FROM conversation_audit_events WHERE conversation_id=?1 AND (?2=0 OR sequence<?2){filter} ORDER BY sequence DESC LIMIT 101"
        );
        let mut args: Vec<rusqlite::types::Value> = vec![id.to_owned().into(), before.into()];
        args.extend(terms.into_iter().map(Into::into));
        let mut events=tx.prepare(&sql).map_err(db)?.query_map(rusqlite::params_from_iter(args),|r|Ok(json!({"sequence":r.get::<_,i64>(0)?,"eventId":r.get::<_,String>(1)?,"recordedAt":r.get::<_,i64>(2)?,"category":r.get::<_,String>(3)?,"eventType":r.get::<_,String>(4)?,"summary":r.get::<_,String>(5)?,"previousEventSha256":r.get::<_,String>(6)?,"eventSha256":r.get::<_,String>(7)?,"characters":r.get::<_,i64>(8)?,"bytes":r.get::<_,i64>(9)?}))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
        let more = events.len() > 100;
        events.truncate(100);
        events.reverse();
        let runtime:Option<String>=tx.query_row("SELECT model FROM conversation_runs WHERE conversation_id=?1 ORDER BY created_at DESC LIMIT 1",[id],|r|r.get(0)).optional().map_err(db)?;
        let running=tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE conversation_id=?1 AND state='running')",[id],|r|r.get::<_,bool>(0)).map_err(db)?;
        let result=json!({"events":events,"hasOlder":more,"eventCount":total,"payloadBytes":bytes,"chainHead":head,"runtime":runtime,"status":if running {"IN_PROGRESS"} else {"BASIC"}}).to_string();
        tx.commit().map_err(db)?;
        Ok(result)
    }
    pub fn conversation_audit_payload(
        &self,
        id: &str,
        sequence: i64,
        page: u32,
    ) -> Result<String, CoreError> {
        let c = self
            .connection
            .lock()
            .map_err(|_| error("审计存储锁不可用"))?;
        c.query_row("SELECT substr(payload,?3,8192) FROM conversation_audit_events WHERE conversation_id=?1 AND sequence=?2",params![id,sequence,i64::from(page)*8192+1],|r|r.get(0)).map_err(db)
    }
    pub fn append_conversation_note(&self, id: &str, note: &str) -> Result<(), CoreError> {
        if note.trim().is_empty() || note.len() > 65536 {
            return Err(error("注释为空或超过64 KiB限制"));
        }
        let mut c = self
            .connection
            .lock()
            .map_err(|_| error("审计存储锁不可用"))?;
        let tx = c
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db)?;
        initialize(&tx, id)?;
        append(
            &tx,
            id,
            "USER",
            "DIAGNOSTIC_NOTE",
            "已添加审计注释",
            json!({"note":note}),
        )?;
        tx.commit().map_err(db)
    }
    pub fn export_conversation_audit(&self, id: &str, format: &str) -> Result<Vec<u8>, CoreError> {
        if !matches!(format, "markdown" | "zip") {
            return Err(error("导出格式无效"));
        }
        let mut c = self
            .connection
            .lock()
            .map_err(|_| error("审计存储锁不可用"))?;
        let tx = c
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(db)?;
        initialize(&tx, id)?;
        let size:i64=tx.query_row("SELECT coalesce(sum(length(CAST(payload AS BLOB))),0) FROM conversation_audit_events WHERE conversation_id=?1",[id],|r|r.get(0)).map_err(db)?;
        if size > (MAX_EXPORT / 2) as i64 {
            return Err(error("审计导出超过64 MiB边界；原始记录未截断"));
        }
        let mut events = Vec::new();
        let mut previous = String::new();
        let rows=tx.prepare("SELECT sequence,recorded_at,category,event_type,summary,payload,previous_hash,event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence").map_err(db)?.query_map([id],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,i64>(1)?,r.get::<_,String>(2)?,r.get::<_,String>(3)?,r.get::<_,String>(4)?,r.get::<_,String>(5)?,r.get::<_,String>(6)?,r.get::<_,String>(7)?))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
        let mut markdown = String::from(
            "# Kiyori 对话诊断\n\n记录范围：基础事件和消息修订。迁移前历史、未接入的工具事件未知。\n\n",
        );
        for (seq, at, category, kind, summary, payload, prev, event) in rows {
            if prev != previous
                || hash(
                    encoded([
                        id,
                        &seq.to_string(),
                        &at.to_string(),
                        &category,
                        &kind,
                        &summary,
                        &payload,
                        &prev,
                    ])
                    .as_bytes(),
                ) != event
            {
                return Err(error("审计事件链损坏，导出已停止"));
            }
            previous = event.clone();
            let data: Value = serde_json::from_str(&payload).map_err(|_| error("审计正文损坏"))?;
            markdown.push_str(&format!(
                "## {seq} · {summary}\n\n{category} / {kind} · {at}\n\n```json\n{}\n```\n\n",
                serde_json::to_string_pretty(&data).map_err(|_| error("无法编码审计正文"))?
            ));
            events.push(json!({"conversationId":id,"sequence":seq,"recordedAt":at,"category":category,"eventType":kind,"summary":summary,"payload":data,"previousEventSha256":prev,"eventSha256":event}));
        }
        let result = if format == "markdown" {
            redact(&markdown).into_bytes()
        } else {
            let events = serde_json::to_vec(&events).map_err(|_| error("无法编码事件包"))?;
            let messages = serde_json::to_vec(&messages(&tx, id, None)?)
                .map_err(|_| error("无法编码消息包"))?;
            let seal=json!({"format":"kiyori-audit-v1","conversationId":id,"chainHead":previous,"coverage":"BASIC","eventsSha256":hash(&events),"messagesSha256":hash(&messages)}).to_string();
            // 自包含签名证明封印完整性，不宣称设备/作者身份；私钥仅随本次导出存活。
            let key = Ed25519KeyPair::generate_pkcs8(&SystemRandom::new())
                .map_err(|_| error("签名密钥不可用"))?;
            let signer =
                Ed25519KeyPair::from_pkcs8(key.as_ref()).map_err(|_| error("签名密钥不可用"))?;
            let signature=json!({"algorithm":"Ed25519","publicKey":STANDARD.encode(signer.public_key().as_ref()),"signature":STANDARD.encode(signer.sign(seal.as_bytes()).as_ref())}).to_string();
            let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
            for (name, bytes) in [
                ("events.json", events.as_slice()),
                ("messages.json", messages.as_slice()),
                ("seal.json", seal.as_bytes()),
                ("signature.json", signature.as_bytes()),
            ] {
                zip.start_file(
                    name,
                    zip::write::SimpleFileOptions::default()
                        .compression_method(zip::CompressionMethod::Deflated),
                )
                .map_err(|_| error("无法创建审计包"))?;
                zip.write_all(bytes).map_err(|_| error("无法写入审计包"))?;
            }
            zip.finish()
                .map_err(|_| error("无法完成审计包"))?
                .into_inner()
        };
        if result.len() > MAX_EXPORT {
            return Err(error("导出超过64 MiB边界"));
        }
        tx.commit().map_err(db)?;
        Ok(result)
    }
}
/// 常见凭据遮蔽只用于分享诊断；签名包保留原文以验证链，不宣称加密。
pub(crate) fn redact(text: &str) -> String {
    // 使用字符边界扫描赋值/认证/URL；无空格JSON也必须遮蔽，不能误删下一段正文。
    let lower = text.to_ascii_lowercase();
    let bytes = lower.as_bytes();
    let mut ranges = Vec::new();
    for (start, _) in lower.char_indices() {
        if start > 0 && (bytes[start - 1].is_ascii_alphanumeric() || bytes[start - 1] == b'_') {
            continue;
        }
        let tail = &lower[start..];
        for key in [
            "authorization",
            "proxy-authorization",
            "cookie",
            "set-cookie",
            "password",
            "passwd",
            "api_key",
            "api-key",
            "apikey",
            "access_token",
            "access-token",
            "accesstoken",
            "refresh_token",
            "refresh-token",
            "refreshtoken",
            "auth_token",
            "auth-token",
            "authtoken",
            "client_secret",
            "client-secret",
            "clientsecret",
            "private_key",
            "private-key",
            "privatekey",
            "request_signature",
            "request-signature",
            "signature",
            "token",
        ] {
            if !tail.starts_with(key) {
                continue;
            }
            let mut offset = start + key.len();
            if bytes
                .get(offset)
                .is_some_and(|c| matches!(c, b'\"' | b'\''))
            {
                offset += 1;
            }
            while bytes.get(offset).is_some_and(u8::is_ascii_whitespace) {
                offset += 1;
            }
            if !bytes.get(offset).is_some_and(|c| matches!(c, b':' | b'=')) {
                continue;
            }
            offset += 1;
            while bytes.get(offset).is_some_and(u8::is_ascii_whitespace) {
                offset += 1;
            }
            let quote = bytes
                .get(offset)
                .copied()
                .filter(|c| matches!(c, b'\"' | b'\''));
            if quote.is_some() {
                offset += 1;
            }
            let mut end = offset;
            let mut escaped = false;
            for (index, ch) in text[offset..].char_indices() {
                if let Some(quote) = quote {
                    if !escaped && ch as u32 == u32::from(quote) {
                        break;
                    }
                    escaped = !escaped && ch == '\\';
                } else if ch.is_whitespace()
                    || matches!(ch, ',' | ';' | '"' | '\'' | '}' | '&' | '#')
                {
                    break;
                }
                end = offset + index + ch.len_utf8();
            }
            if end > offset && !text[offset..end].starts_with("[REDACTED") {
                ranges.push((offset, end));
            }
        }
        for scheme in ["bearer", "basic"] {
            if tail.starts_with(scheme)
                && bytes
                    .get(start + scheme.len())
                    .is_some_and(u8::is_ascii_whitespace)
            {
                let offset = start + scheme.len();
                let value = offset + text[offset..].len() - text[offset..].trim_start().len();
                let end = text[value..]
                    .char_indices()
                    .find(|(_, c)| {
                        c.is_whitespace() || matches!(c, ',' | ';' | '"' | '\'' | '}' | '&')
                    })
                    .map_or(text.len(), |(i, _)| value + i);
                if end > value && !text[value..end].starts_with("[REDACTED") {
                    ranges.push((value, end));
                }
            }
        }
        if tail.starts_with("http://") || tail.starts_with("https://") {
            let value = start + if tail.starts_with("https://") { 8 } else { 7 };
            if let Some(at) = text[value..].find('@') {
                let auth = &text[value..value + at];
                if auth.contains(':')
                    && !auth.contains(['/', ' ', '\n', '\r', '\t'])
                    && !auth.starts_with("[REDACTED")
                {
                    ranges.push((value, value + at));
                }
            }
        }
        if tail.starts_with("-----begin")
            && let Some(label) = tail.find("private key-----")
        {
            let after = start + label + "private key-----".len();
            if let Some(end_marker) = lower[after..].find("-----end")
                && let Some(end_label) = lower[after + end_marker..].find("private key-----")
            {
                ranges.push((
                    start,
                    after + end_marker + end_label + "private key-----".len(),
                ));
            }
        }
        if tail.starts_with("sk-") {
            let end = text[start..]
                .char_indices()
                .find(|(_, c)| c.is_whitespace() || matches!(c, ',' | '"' | '\'' | '}'))
                .map_or(text.len(), |(i, _)| start + i);
            ranges.push((start, end));
        }
    }
    ranges.sort_unstable();
    let mut output = String::with_capacity(text.len());
    let mut cursor = 0;
    for (start, end) in ranges {
        if start < cursor {
            continue;
        }
        output.push_str(&text[cursor..start]);
        output.push_str("[REDACTED:credential]");
        cursor = end;
    }
    output.push_str(&text[cursor..]);
    output
}
impl Runtime {
    pub fn conversation_audit(
        &self,
        id: String,
        before: i64,
        query: String,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.conversation_audit(&id, before, &query))
    }
    pub fn conversation_audit_payload(
        &self,
        id: String,
        sequence: i64,
        page: u32,
    ) -> Result<String, CoreError> {
        self.with_store(|s| s.conversation_audit_payload(&id, sequence, page))
    }
    pub fn append_conversation_note(&self, id: String, note: String) -> Result<(), CoreError> {
        self.with_store(|s| s.append_conversation_note(&id, &note))
    }
    pub fn export_conversation_audit(
        &self,
        id: String,
        format: String,
    ) -> Result<Vec<u8>, CoreError> {
        self.with_store(|s| s.export_conversation_audit(&id, &format))
    }
}
