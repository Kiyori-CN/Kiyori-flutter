//! 会话审计和消息修订归SQLite；事件链只追加，旧数据明确标记为基础快照。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use ring::digest::{SHA256, digest};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use serde_json::{Value, json};
use std::io::{Cursor, Write};

#[path = "conversation_audit_archive.rs"]
pub(crate) mod archive;
#[path = "conversation_audit_search.rs"]
mod search;

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
pub(crate) const SECURE_SCHEMA: &str = "
ALTER TABLE conversation_audit_events ADD COLUMN payload_characters INTEGER NOT NULL DEFAULT 0;
ALTER TABLE conversation_audit_events ADD COLUMN payload_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE conversation_audit_events ADD COLUMN run_id TEXT;
ALTER TABLE conversation_audit_events ADD COLUMN terminal_state TEXT;
DROP TRIGGER conversation_audit_no_update;
UPDATE conversation_audit_events SET payload_characters=length(payload),payload_bytes=length(CAST(payload AS BLOB)),run_id=json_extract(payload,'$.runId'),terminal_state=coalesce(json_extract(payload,'$.terminalState'),CASE json_extract(payload,'$.state') WHEN 'completed' THEN 'COMPLETED' WHEN 'failed' THEN 'FAILED' WHEN 'cancelled' THEN 'CANCELLED' END);
CREATE TRIGGER conversation_audit_no_update BEFORE UPDATE ON conversation_audit_events BEGIN SELECT RAISE(ABORT,'Audit events are append only'); END;
CREATE TABLE conversation_audit_seals(conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,sequence INTEGER NOT NULL,seal TEXT NOT NULL,signature TEXT NOT NULL,PRIMARY KEY(conversation_id,sequence));
CREATE TRIGGER conversation_audit_seal_no_update BEFORE UPDATE ON conversation_audit_seals BEGIN SELECT RAISE(ABORT,'Audit seals are append only'); END;
CREATE TABLE conversation_audit_security(id INTEGER PRIMARY KEY CHECK(id=1),public_key TEXT NOT NULL);
PRAGMA user_version=21;";
const MAX_EXPORT: usize = 64 * 1024 * 1024;
#[cfg(test)]
pub(crate) fn remove_schema_for_fixture(c: &Connection) {
    c.execute_batch("DROP TABLE IF EXISTS conversation_title_requests;")
        .unwrap();
    let has_title_revision = c
        .prepare("PRAGMA table_info(conversations)")
        .unwrap()
        .query_map([], |r| r.get::<_, String>(1))
        .unwrap()
        .any(|r| r.unwrap() == "title_revision");
    if has_title_revision {
        c.execute_batch("ALTER TABLE conversations DROP COLUMN title_revision;")
            .unwrap();
    }
    c.execute_batch("DROP TABLE IF EXISTS conversation_message_metadata;")
        .unwrap();
    c.execute_batch("DROP TABLE IF EXISTS conversation_audit_portable_seals; DROP TABLE IF EXISTS conversation_audit_security; DROP TABLE IF EXISTS conversation_audit_seals; DROP TABLE IF EXISTS conversation_audit_events; DROP TABLE IF EXISTS conversation_audit_key;").unwrap();
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
fn events_count(c: &Connection, id: &str) -> Result<i64, CoreError> {
    c.query_row(
        "SELECT count(*) FROM conversation_audit_events WHERE conversation_id=?1",
        [id],
        |r| r.get(0),
    )
    .map_err(db)
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
    let run = payload
        .get("runId")
        .and_then(Value::as_str)
        .map(str::to_owned);
    let terminal = payload
        .get("terminalState")
        .and_then(Value::as_str)
        .map(str::to_owned)
        .or_else(|| match payload.get("state").and_then(Value::as_str) {
            Some("completed") => Some("COMPLETED".into()),
            Some("failed") => Some("FAILED".into()),
            Some("cancelled") => Some("CANCELLED".into()),
            _ => None,
        });
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
        "INSERT INTO conversation_audit_events(conversation_id,sequence,event_id,recorded_at,category,event_type,summary,payload,previous_hash,event_hash,payload_characters,payload_bytes,run_id,terminal_state) VALUES(?1,?2,?3,?4,?5,?6,?7,kiyori_audit_protect(?8),?9,?10,?11,?12,?13,?14)",
        params![
            id, seq, event_id, at, category, kind, summary, payload, previous, event,payload.chars().count() as i64,payload.len() as i64,run,terminal
        ],
    )
    .map_err(db)?;
    Ok(())
}
pub(crate) fn messages(tx: &Connection, id: &str, run: Option<&str>) -> Result<Value, CoreError> {
    let values=tx.prepare("SELECT m.id,m.role,m.content,m.state,m.variant,m.run_id,m.position,d.role_id,d.role_name,d.created_at FROM conversation_messages m LEFT JOIN conversation_message_metadata d ON d.message_id=m.id WHERE m.conversation_id=?1 AND (?2 IS NULL OR m.run_id=?2) ORDER BY m.position").map_err(db)?.query_map(params![id,run],|r|Ok(json!({"id":r.get::<_,String>(0)?,"role":r.get::<_,String>(1)?,"content":r.get::<_,String>(2)?,"state":r.get::<_,String>(3)?,"variant":r.get::<_,i64>(4)?,"runId":r.get::<_,Option<String>>(5)?,"position":r.get::<_,i64>(6)?,"roleId":r.get::<_,Option<String>>(7)?,"roleName":r.get::<_,Option<String>>(8)?,"createdAt":r.get::<_,Option<i64>>(9)?}))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
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
        let (total,bytes,head):(i64,i64,String)=tx.query_row("SELECT count(*),coalesce(sum(payload_bytes),0),coalesce((SELECT event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence DESC LIMIT 1),'') FROM conversation_audit_events WHERE conversation_id=?1",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?))).map_err(db)?;
        let searching = !query.trim().is_empty();
        let matcher = search::Query::new(query);
        let sql = format!(
            "SELECT sequence,event_id,recorded_at,category,event_type,summary,previous_hash,event_hash,payload_characters,payload_bytes,run_id,terminal_state,{} FROM conversation_audit_events WHERE conversation_id=?1 AND (?2=0 OR sequence<?2) ORDER BY sequence DESC LIMIT {}",
            if searching {
                "kiyori_audit_unprotect(payload)"
            } else {
                "NULL"
            },
            if searching { 100 } else { 101 },
        );
        let mut statement = tx.prepare(&sql).map_err(db)?;
        let mut rows = statement.query(params![id, before]).map_err(db)?;
        let mut events = Vec::new();
        let mut scanned = 0;
        let mut cursor = None;
        // 搜索每批扫描100条未过滤事件；逐行释放解密正文，稀疏命中也能推进游标。
        while let Some(r) = rows.next().map_err(db)? {
            let category = r.get::<_, String>(3).map_err(db)?;
            let actor = if matches!(category.as_str(), "USER" | "MESSAGE") {
                "USER"
            } else {
                "SYSTEM"
            };
            let sequence = r.get::<_, i64>(0).map_err(db)?;
            let mut event = json!({"sequence":sequence,"eventId":r.get::<_,String>(1).map_err(db)?,"recordedAt":r.get::<_,i64>(2).map_err(db)?,"category":category,"eventType":r.get::<_,String>(4).map_err(db)?,"summary":r.get::<_,String>(5).map_err(db)?,"previousEventSha256":r.get::<_,String>(6).map_err(db)?,"eventSha256":r.get::<_,String>(7).map_err(db)?,"characters":r.get::<_,i64>(8).map_err(db)?,"bytes":r.get::<_,i64>(9).map_err(db)?,"localExecutionId":r.get::<_,Option<String>>(10).map_err(db)?,"terminalState":r.get::<_,Option<String>>(11).map_err(db)?,"actor":actor});
            scanned += 1;
            cursor = (sequence > 1).then_some(sequence);
            if searching {
                let payload = r.get::<_, String>(12).map_err(db)?;
                if let Some(excerpt) = matcher.excerpt(&event, &payload) {
                    event["searchExcerpt"] = excerpt.into();
                    events.push(event);
                }
            } else {
                events.push(event);
            }
        }
        drop(rows);
        drop(statement);
        let more = if searching {
            cursor.is_some()
        } else {
            events.len() > 100
        };
        events.truncate(100);
        if !searching {
            scanned = events.len();
            cursor = if more {
                events.last().and_then(|e| e["sequence"].as_i64())
            } else {
                None
            };
        }
        events.reverse();
        let runtime:Option<String>=tx.query_row("SELECT model FROM conversation_runs WHERE conversation_id=?1 ORDER BY created_at DESC LIMIT 1",[id],|r|r.get(0)).optional().map_err(db)?;
        let running=tx.query_row("SELECT EXISTS(SELECT 1 FROM conversation_runs WHERE conversation_id=?1 AND state='running' UNION ALL SELECT 1 FROM conversation_title_requests WHERE conversation_id=?1 AND state='running')",[id],|r|r.get::<_,bool>(0)).map_err(db)?;
        let result=json!({"events":events,"hasOlder":more,"scannedCount":scanned,"nextBeforeSequence":cursor,"eventCount":total,"payloadBytes":bytes,"chainHead":head,"runtime":runtime,"status":if running {"IN_PROGRESS"} else {"BASIC"}}).to_string();
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
        c.query_row("SELECT substr(kiyori_audit_unprotect(payload),?3,8192) FROM conversation_audit_events WHERE conversation_id=?1 AND sequence=?2",params![id,sequence,i64::from(page)*8192+1],|r|r.get(0)).map_err(db)
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
        let size:i64=tx.query_row("SELECT (SELECT coalesce(sum(payload_bytes),0) FROM conversation_audit_events WHERE conversation_id=?1)+(SELECT coalesce(sum(length(CAST(content AS BLOB))),0) FROM conversation_messages WHERE conversation_id=?1)+(SELECT coalesce(sum(length(CAST(v.content AS BLOB))),0) FROM conversation_variants v JOIN conversation_messages m ON m.id=v.message_id WHERE m.conversation_id=?1)",[id],|r|r.get(0)).map_err(db)?;
        if size > (MAX_EXPORT / 2) as i64 {
            return Err(error("审计导出超过64 MiB边界；原始记录未截断"));
        }
        let mut events = Vec::new();
        let mut previous = String::new();
        let rows=tx.prepare("SELECT sequence,recorded_at,category,event_type,summary,kiyori_audit_unprotect(payload),previous_hash,event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence").map_err(db)?.query_map([id],|r|Ok((r.get::<_,i64>(0)?,r.get::<_,i64>(1)?,r.get::<_,String>(2)?,r.get::<_,String>(3)?,r.get::<_,String>(4)?,r.get::<_,String>(5)?,r.get::<_,String>(6)?,r.get::<_,String>(7)?))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
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
            events.push(json!({"conversationId":id,"sequence":seq,"recordedAt":at,"category":category,"eventType":kind,"summary":summary,"payload":data,"previousEventSha256":prev,"eventSha256":event}));
        }
        let result = if self.audit_crypto.persistent() {
            let snapshot = archive::build(&tx, id, events)?;
            if format == "markdown" {
                archive::seal_snapshot(&tx, &*self.audit_crypto, &snapshot)?;
                archive::markdown(&snapshot, true)?.into_bytes()
            } else {
                archive::package(&tx, &*self.audit_crypto, &snapshot)?
            }
        } else if format == "markdown" {
            // 参考运行时也使用相同阅读投影；旧四文件包只保留纯核心签名夹具兼容。
            archive::markdown(&archive::build(&tx, id, events)?, true)?.into_bytes()
        } else {
            let events = serde_json::to_vec(&events).map_err(|_| error("无法编码事件包"))?;
            let messages = serde_json::to_vec(&messages(&tx, id, None)?)
                .map_err(|_| error("无法编码消息包"))?;
            let seal=json!({"format":"kiyori-audit-v1","conversationId":id,"chainHead":previous,"coverage":"BASIC","eventsSha256":hash(&events),"messagesSha256":hash(&messages)}).to_string();
            let sequence = events_count(&tx, id)?;
            let saved: Option<(String,String)> = tx.query_row("SELECT seal,signature FROM conversation_audit_seals WHERE conversation_id=?1 AND sequence=?2",params![id,sequence],|r|Ok((r.get(0)?,r.get(1)?))).optional().map_err(db)?;
            let signature = match saved {
                Some((old, signature)) if old == seal => signature,
                Some(_) => return Err(error("已有封印与当前投影不一致，导出已停止")),
                None => {
                    let signature =
                        serde_json::to_string(&self.audit_crypto.sign(seal.as_bytes())?)
                            .map_err(|_| error("无法编码封印"))?;
                    tx.execute(
                        "INSERT INTO conversation_audit_seals VALUES(?1,?2,?3,?4)",
                        params![id, sequence, seal, signature],
                    )
                    .map_err(db)?;
                    signature
                }
            };
            let stored_signature: crate::audit_crypto::AuditSignature =
                serde_json::from_str(&signature).map_err(|_| error("封印签名损坏"))?;
            if self.audit_crypto.persistent() && stored_signature.algorithm != "SHA256withECDSA" {
                return Err(error("封印签名算法与当前安全端口不一致"));
            }
            crate::audit_crypto::verify(seal.as_bytes(), &stored_signature)?;
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
