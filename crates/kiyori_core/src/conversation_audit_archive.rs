//! 旧schema1归档的移植投影；不改写已经保存的独立事件链或声称补回未知旧事件。
use super::*;
use base64::{Engine, engine::general_purpose::STANDARD};
use std::collections::{BTreeMap, BTreeSet};

pub(crate) const SCHEMA: &str = "
CREATE TABLE conversation_audit_portable_seals(
 conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 source_sequence INTEGER NOT NULL,chain_head TEXT NOT NULL,seal TEXT NOT NULL,
 PRIMARY KEY(conversation_id,source_sequence,chain_head));
CREATE TRIGGER conversation_audit_portable_seal_no_update BEFORE UPDATE ON conversation_audit_portable_seals BEGIN SELECT RAISE(ABORT,'Audit seals are append only'); END;
PRAGMA user_version=22;";

pub(super) struct Snapshot {
    pub chat: Value,
    pub events: Vec<Value>,
    pub refs: Vec<Value>,
    pub revisions: Vec<Value>,
    pub projections: Vec<Value>,
    pub payloads: BTreeMap<String, Value>,
    pub head: String,
    pub at: i64,
    source_sequence: i64,
    source_head: String,
    locators: BTreeMap<String, i64>,
    occupied_locators: BTreeSet<i64>,
    latest: BTreeMap<(i64, i64), Value>,
}

fn text(value: &Value, field: &str) -> String {
    value
        .get(field)
        .filter(|v| !v.is_null())
        .map_or_else(String::new, |v| {
            v.as_str().map_or_else(|| v.to_string(), str::to_owned)
        })
}
fn field(out: &mut String, value: &str) {
    out.push_str(&format!("{}:{value}\n", value.len()));
}
fn redacted_json(value: &Value) -> Result<Value, CoreError> {
    Ok(match value {
        Value::String(s) => json!(redact(s)),
        Value::Array(values) => json!(
            values
                .iter()
                .map(redacted_json)
                .collect::<Result<Vec<_>, _>>()?
        ),
        Value::Object(values) => {
            let mut output = serde_json::Map::new();
            for (key, value) in values {
                // 先处理每个字符串，避免嵌套消息中的转义JSON绕过文本凭据扫描。
                let wrapped = json!({key:redacted_json(value)?}).to_string();
                let scrubbed = redact(&wrapped);
                let parsed = serde_json::from_str::<Value>(&scrubbed)
                    .map_err(|_| error("归档脱敏正文编码失败"))?;
                output.insert(key.clone(), parsed[key].clone());
            }
            Value::Object(output)
        }
        _ => value.clone(),
    })
}
/// 与旧ConversationAuditHasher逐字段一致：UTF-8字节长度、19字段、排序后的7字段refs。
pub(super) fn event_hash(
    event: &Value,
    refs: &[Value],
    payloads: &BTreeMap<String, Value>,
) -> Result<String, CoreError> {
    let mut canonical = String::new();
    for key in [
        "previousEventSha256",
        "eventId",
        "chatId",
        "sequenceNumber",
        "occurredAt",
        "recordedAt",
        "category",
        "eventType",
        "actor",
        "summary",
        "messageTimestamp",
        "variantIndex",
        "localExecutionId",
        "providerCallId",
        "parentEventId",
        "sourceChatId",
        "sourceEventId",
        "visibility",
        "terminalState",
    ] {
        field(&mut canonical, &text(event, key));
    }
    let mut ordered = refs.to_vec();
    // Kotlin/JVM String排序按UTF-16码元；补充平面字符与BMP私用区不能用UTF-8次序。
    ordered.sort_by(|a, b| {
        a["ordinal"]
            .as_i64()
            .cmp(&b["ordinal"].as_i64())
            .then_with(|| {
                text(a, "label")
                    .encode_utf16()
                    .cmp(text(b, "label").encode_utf16())
            })
            .then_with(|| text(a, "payloadSha256").cmp(&text(b, "payloadSha256")))
    });
    for reference in ordered {
        for key in ["label", "ordinal", "role", "payloadSha256"] {
            field(&mut canonical, &text(&reference, key));
        }
        let payload = payloads
            .get(&text(&reference, "payloadSha256"))
            .ok_or_else(|| error("归档正文引用缺失"))?;
        for key in ["mediaType", "encoding", "plainByteCount"] {
            field(&mut canonical, &text(payload, key));
        }
    }
    Ok(hash(canonical.as_bytes()))
}

impl Snapshot {
    fn payload(&mut self, value: &str, media: &str, at: i64) -> String {
        // 旧可移植合同要求正文先脱敏再哈希；只处理导出副本，不重写本机源链。
        let value = redact(value);
        let sha = hash(value.as_bytes());
        self.payloads.entry(sha.clone()).or_insert_with(|| json!({"payloadSha256":sha,"plainByteCount":value.len(),"mediaType":media,"encoding":"utf-8","createdAt":at,"bytesBase64":STANDARD.encode(value.as_bytes())}));
        sha
    }
    fn push(
        &mut self,
        mut event: Value,
        payload: &str,
        media: &str,
        role: &str,
    ) -> Result<String, CoreError> {
        let sequence = self.events.len() + 1;
        let id = format!(
            "{}/portable/{sequence}",
            self.chat["id"]
                .as_str()
                .ok_or_else(|| error("归档会话身份缺失"))?
        );
        event["eventId"] = json!(id);
        event["sequenceNumber"] = json!(sequence);
        event["previousEventSha256"] = json!(self.head);
        let sha = self.payload(
            payload,
            media,
            event["recordedAt"].as_i64().unwrap_or(self.at),
        );
        let reference =
            json!({"eventId":id,"payloadSha256":sha,"label":"content","ordinal":0,"role":role});
        self.head = event_hash(&event, std::slice::from_ref(&reference), &self.payloads)?;
        event["eventSha256"] = json!(self.head);
        self.refs.push(reference);
        self.events.push(event);
        Ok(id)
    }
    fn metadata(&self, at: i64, category: &str, kind: &str, summary: &str) -> Value {
        json!({"eventId":"","chatId":self.chat["id"],"sequenceNumber":0,"occurredAt":at,"recordedAt":at,"category":category,"eventType":kind,"actor":if matches!(category,"USER"|"MESSAGE") {"USER"} else {"SYSTEM"},"summary":redact(summary),"messageTimestamp":null,"variantIndex":null,"localExecutionId":null,"providerCallId":null,"parentEventId":null,"sourceChatId":null,"sourceEventId":null,"previousEventSha256":"","eventSha256":"","visibility":"TIMELINE","terminalState":null})
    }
    fn observe(&mut self, messages: &[Value], at: i64) -> Result<(), CoreError> {
        for message in messages {
            let native_id = message["id"]
                .as_str()
                .ok_or_else(|| error("归档消息身份缺失"))?;
            let timestamp = if let Some(existing) = self.locators.get(native_id) {
                *existing
            } else {
                // 新runtime没有旧timestamp。采用首次审计观察时的稳定定位符，并保留native ID；
                // 它是移植身份，不是消息实际发送时间，不能从该值推断网络耗时。
                let mut timestamp = at.max(1);
                while self.occupied_locators.contains(&timestamp) {
                    timestamp = timestamp
                        .checked_add(1)
                        .ok_or_else(|| error("消息定位符超出范围"))?;
                }
                self.locators.insert(native_id.to_owned(), timestamp);
                self.occupied_locators.insert(timestamp);
                timestamp
            };
            let variant = message["variant"].as_i64().unwrap_or(0);
            let content = redact(message["content"].as_str().unwrap_or(""));
            let sha = hash(content.as_bytes());
            let key = (timestamp, variant);
            let previous = self.latest.get(&key).cloned();
            if previous
                .as_ref()
                .is_some_and(|r| r["contentPayloadSha256"] == sha)
            {
                continue;
            }
            let sender = if message["role"] == "assistant" {
                "ai"
            } else {
                message["role"].as_str().unwrap_or("unknown")
            };
            let mut event =
                self.metadata(at, "MESSAGE", "MESSAGE_REVISED", "已观察的消息正文移植投影");
            event["messageTimestamp"] = json!(timestamp);
            event["variantIndex"] = json!(variant);
            event["localExecutionId"] = message["runId"].clone();
            let event_id = self.push(event, &content, "text/plain", sender)?;
            let revision = json!({"revisionId":format!("{event_id}/revision"),"chatId":self.chat["id"],"messageTimestamp":timestamp,"variantIndex":variant,"revisionNumber":previous.as_ref().map_or(0,|r|r["revisionNumber"].as_i64().unwrap_or(0)+1),"sender":sender,"contentPayloadSha256":sha,"previousRevisionId":previous.as_ref().map(|r|r["revisionId"].clone()),"auditEventId":event_id,"source":"NATIVE_AUDIT_PROJECTION","createdAt":at});
            self.latest.insert(key, revision.clone());
            self.revisions.push(revision);
        }
        Ok(())
    }
}

pub(super) fn build(tx: &Connection, id: &str, rows: Vec<Value>) -> Result<Snapshot, CoreError> {
    let (title,created,updated,folder,order,pinned,locked,parent,character):(String,i64,i64,String,i64,bool,bool,Option<String>,String)=tx.query_row("SELECT title,created_at,updated_at,folder,sort_order,pinned,locked,parent_id,character_id FROM conversations WHERE id=?1",[id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?,r.get(4)?,r.get(5)?,r.get(6)?,r.get(7)?,r.get(8)?))).map_err(db)?;
    let source_sequence = rows.len() as i64;
    let source_head = rows
        .last()
        .map_or_else(String::new, |e| text(e, "eventSha256"));
    let at = rows
        .last()
        .and_then(|e| e["recordedAt"].as_i64())
        .unwrap_or(updated);
    let name: Option<String> = tx
        .query_row(
            "SELECT name FROM prompt_characters WHERE id=?1",
            [&character],
            |r| r.get(0),
        )
        .optional()
        .map_err(db)?;
    let group: Option<String> = tx
        .query_row(
            "SELECT id FROM prompt_groups WHERE id=?1",
            [&character],
            |r| r.get(0),
        )
        .optional()
        .map_err(db)?;
    let chat = json!({"id":id,"title":redact(&title),"messages":[],"createdAt":iso(created),"updatedAt":iso(updated),"group":if folder.is_empty(){None}else{Some(folder)},"displayOrder":order,"pinned":pinned,"locked":locked,"parentChatId":parent,"characterCardName":name.map(|s|redact(&s)),"characterGroupId":group,"conversationAudit":null});
    let mut snapshot = Snapshot {
        chat,
        events: Vec::new(),
        refs: Vec::new(),
        revisions: Vec::new(),
        projections: Vec::new(),
        payloads: BTreeMap::new(),
        head: "0".repeat(64),
        at,
        source_sequence,
        source_head,
        locators: BTreeMap::new(),
        occupied_locators: BTreeSet::new(),
        latest: BTreeMap::new(),
    };
    for source in rows {
        let at = source["recordedAt"]
            .as_i64()
            .ok_or_else(|| error("事件时间缺失"))?;
        let data = &source["payload"];
        let mut event = snapshot.metadata(
            at,
            &text(&source, "category"),
            &text(&source, "eventType"),
            &text(&source, "summary"),
        );
        event["localExecutionId"] = data["runId"].clone();
        event["terminalState"] = data["terminalState"].clone();
        if event["terminalState"].is_null() {
            event["terminalState"] = match data["state"].as_str() {
                Some("completed") => json!("COMPLETED"),
                Some("failed") => json!("FAILED"),
                Some("cancelled") => json!("CANCELLED"),
                _ => Value::Null,
            };
        }
        let payload=json!({"nativeEventId":format!("{id}/{}",source["sequence"]),"nativeEventSha256":source["eventSha256"],"observed":redacted_json(data)?,"projection":"BASIC: native message IDs retained; messageTimestamp is first audit observation locator, not send time"}).to_string();
        snapshot.push(event, &payload, "application/json", "metadata")?;
        if let Some(observed) = data["messages"].as_array() {
            snapshot.observe(observed, at)?;
        }
    }
    let current = messages(tx, id, None)?;
    snapshot.observe(current.as_array().ok_or_else(|| error("消息投影无效"))?, at)?;
    // 当前和历史variant分别保留，切换/删除不销毁已观察的正文修订。
    let variants=tx.prepare("SELECT v.message_id,v.variant,v.run_id,v.content,v.state FROM conversation_variants v JOIN conversation_messages m ON m.id=v.message_id WHERE m.conversation_id=?1 AND v.variant<>m.variant ORDER BY m.position,v.variant").map_err(db)?.query_map([id],|r|Ok(json!({"id":r.get::<_,String>(0)?,"variant":r.get::<_,i64>(1)?,"runId":r.get::<_,Option<String>>(2)?,"content":r.get::<_,String>(3)?,"state":r.get::<_,String>(4)?,"role":"assistant"}))).map_err(db)?.collect::<Result<Vec<_>,_>>().map_err(db)?;
    snapshot.observe(&variants, at)?;
    let runs=tx.prepare("SELECT id,model,created_at,finished_at,first_output_at,input_tokens,output_tokens,usage_reported,cache_read_tokens,cache_write_tokens,reasoning_tokens,role_name FROM conversation_runs WHERE conversation_id=?1").map_err(db)?.query_map([id],|r|Ok((r.get::<_,String>(0)?,json!({"modelName":r.get::<_,String>(1)?,"sentAt":r.get::<_,i64>(2)?,"completedAt":r.get::<_,Option<i64>>(3)?,"firstOutputAt":r.get::<_,Option<i64>>(4)?,"inputTokens":r.get::<_,i64>(5)?,"outputTokens":r.get::<_,i64>(6)?,"usageReported":r.get::<_,bool>(7)?,"cacheRead":r.get::<_,Option<i64>>(8)?,"cacheWrite":r.get::<_,Option<i64>>(9)?,"reasoning":r.get::<_,Option<i64>>(10)?,"roleName":r.get::<_,Option<String>>(11)?})))).map_err(db)?.collect::<Result<BTreeMap<_,_>,_>>().map_err(db)?;
    let mut archived = Vec::new();
    for message in current.as_array().ok_or_else(|| error("消息投影无效"))? {
        let native_id = text(message, "id");
        let timestamp = *snapshot
            .locators
            .get(&native_id)
            .ok_or_else(|| error("消息定位缺失"))?;
        let variant = message["variant"].as_i64().unwrap_or(0);
        let mut versions = variants
            .iter()
            .filter(|v| v["id"] == native_id)
            .collect::<Vec<_>>();
        versions.push(message);
        versions.sort_by_key(|v| v["variant"].as_i64().unwrap_or(0));
        let original = versions
            .iter()
            .find(|v| v["variant"] == 0)
            .ok_or_else(|| error("历史基础回复版本缺失，导出已停止"))?;
        let mut base = json!({"sender":if message["role"]=="assistant"{"ai"}else{message["role"].as_str().unwrap_or("unknown")},"content":redact(original["content"].as_str().unwrap_or("")),"timestamp":timestamp,"selectedVariantIndex":variant,"variantCount":versions.len()});
        attach_run(&mut base, original, &runs);
        let previous=versions.into_iter().filter(|v|v["variant"]!=0).map(|v|{let mut projected=json!({"variantIndex":v["variant"],"content":redact(v["content"].as_str().unwrap_or(""))});attach_run(&mut projected,v,&runs);projected}).collect::<Vec<_>>();
        archived.push(json!({"baseMessage":base,"variants":previous}));
        for ((observed, variant), revision) in snapshot
            .latest
            .range((timestamp, i64::MIN)..=(timestamp, i64::MAX))
        {
            if *observed == timestamp {
                snapshot.projections.push(json!({"chatId":id,"messageTimestamp":timestamp,"variantIndex":variant,"currentRevisionId":revision["revisionId"],"estimatedTokenCount":0,"updatedAt":at}));
            }
        }
    }
    snapshot.chat["messages"] = json!(archived);
    Ok(snapshot)
}

fn attach_run(projected: &mut Value, message: &Value, runs: &BTreeMap<String, Value>) {
    if message["role"] != "assistant" {
        return;
    }
    let Some(run) = runs.get(&text(message, "runId")) else {
        return;
    };
    for key in [
        "modelName",
        "sentAt",
        "inputTokens",
        "outputTokens",
        "roleName",
    ] {
        if !run[key].is_null() {
            projected[key] = run[key].clone();
        }
    }
    let reported = run["usageReported"].as_bool().unwrap_or(false);
    projected["providerRequestCount"] = json!(1);
    projected["providerUsageRequestCount"] = json!(i64::from(reported));
    if reported {
        projected["providerTotalInputTokens"] = run["inputTokens"].clone();
        projected["providerOutputTokens"] = run["outputTokens"].clone();
    }
    if let (Some(sent), Some(done)) = (run["sentAt"].as_i64(), run["completedAt"].as_i64()) {
        projected["completedAt"] = json!(done);
        if let Some(first) = run["firstOutputAt"].as_i64() {
            let first = first.clamp(sent, done.max(sent));
            projected["waitDurationMs"] = json!((first - sent).max(0));
            projected["outputDurationMs"] = json!((done - first).max(0));
        }
    }
    if let Some(read) = run["cacheRead"].as_i64() {
        projected["cachedInputTokens"] = json!(read);
        projected["providerCacheReadTokens"] = json!(read);
    }
    if let Some(write) = run["cacheWrite"].as_i64() {
        projected["providerCacheWriteTokens"] = json!(write);
    }
    let measured = !run["cacheRead"].is_null() || !run["cacheWrite"].is_null();
    projected["providerCacheMetricRequestCount"] = json!(i64::from(reported && measured));
    if reported && measured {
        projected["providerCacheMetricPromptTokens"] = run["inputTokens"].clone();
    }
    if let Some(reasoning) = run["reasoning"].as_i64() {
        projected["providerReasoningTokens"] = json!(reasoning);
    }
}

fn iso(millis: i64) -> String {
    // 公历转换，无时区依赖；旧LocalDateTime字段固定UTC投影，manifest明确epoch。
    let seconds = millis.div_euclid(1000);
    let z = seconds.div_euclid(86400) + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let mut year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = mp + if mp < 10 { 3 } else { -9 };
    year += i64::from(month <= 2);
    let tod = seconds.rem_euclid(86400);
    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}.{:03}",
        tod / 3600,
        tod / 60 % 60,
        tod % 60,
        millis.rem_euclid(1000)
    )
}

pub(super) fn seal_snapshot(
    tx: &Connection,
    crypto: &dyn crate::audit_crypto::AuditCrypto,
    snapshot: &Snapshot,
) -> Result<Value, CoreError> {
    // 流式生成尚未结束时，同源事件游标可能有不同当前投影；每个不同链头独立封印。
    let saved:Option<(String,String)>=tx.query_row("SELECT chain_head,seal FROM conversation_audit_portable_seals WHERE conversation_id=?1 AND source_sequence=?2 AND chain_head=?3",params![snapshot.chat["id"].as_str(),snapshot.source_sequence,snapshot.head],|r|Ok((r.get(0)?,r.get(1)?))).optional().map_err(db)?;
    let seal = if let Some((head, seal)) = saved {
        if head != snapshot.head {
            return Err(error("移植封印与当前快照不一致，导出已停止"));
        }
        serde_json::from_str::<Value>(&seal).map_err(|_| error("移植封印损坏"))?
    } else {
        let signed = crypto.sign(snapshot.head.as_bytes())?;
        let seal = json!({"sealId":format!("{}/portable-seal/{}/{}",snapshot.chat["id"].as_str().unwrap_or(""),snapshot.source_sequence,snapshot.head),"chatId":snapshot.chat["id"],"sequenceNumber":snapshot.events.len(),"rootSha256":snapshot.head,"signatureAlgorithm":signed.algorithm,"signatureBase64":signed.signature,"publicKeyBase64":signed.public_key,"reason":"EXPORT_SNAPSHOT","createdAt":snapshot.at});
        tx.execute(
            "INSERT INTO conversation_audit_portable_seals VALUES(?1,?2,?3,?4)",
            params![
                snapshot.chat["id"].as_str(),
                snapshot.source_sequence,
                snapshot.head,
                seal.to_string()
            ],
        )
        .map_err(db)?;
        seal
    };
    let signature = crate::audit_crypto::AuditSignature {
        algorithm: text(&seal, "signatureAlgorithm"),
        public_key: text(&seal, "publicKeyBase64"),
        signature: text(&seal, "signatureBase64"),
    };
    if crypto.persistent() && signature.algorithm != "SHA256withECDSA" {
        return Err(error("移植封印算法不一致"));
    }
    if crypto.persistent() {
        let pinned: String = tx
            .query_row(
                "SELECT public_key FROM conversation_audit_security WHERE id=1",
                [],
                |r| r.get(0),
            )
            .map_err(db)?;
        if signature.public_key != pinned {
            return Err(error("移植封印签名身份与本机安全存储不一致"));
        }
    }
    crate::audit_crypto::verify(snapshot.head.as_bytes(), &signature)?;
    Ok(seal)
}

pub(super) fn package(
    tx: &Connection,
    crypto: &dyn crate::audit_crypto::AuditCrypto,
    snapshot: &Snapshot,
) -> Result<Vec<u8>, CoreError> {
    let seal = seal_snapshot(tx, crypto, snapshot)?;
    let root = json!({"chatId":snapshot.chat["id"],"schemaVersion":1,"completenessStatus":"BASIC","eventCount":snapshot.events.len(),"lastSequenceNumber":snapshot.events.len(),"chainHeadSha256":snapshot.head,"latestSealSequenceNumber":snapshot.events.len(),"createdAt":snapshot.events.first().map_or(snapshot.at,|e|e["recordedAt"].as_i64().unwrap_or(snapshot.at)),"updatedAt":snapshot.at,"lastFailureCode":null,"legacyReconstructionLevel":"BASIC"});
    let archive = json!({"schemaVersion":1,"audit":root,"events":snapshot.events,"eventPayloads":snapshot.refs,"revisions":snapshot.revisions,"projections":snapshot.projections,"seals":[seal],"payloads":snapshot.payloads.values().collect::<Vec<_>>()});
    validate(&archive)?;
    let payload_index=snapshot.payloads.values().map(|p|json!({"payloadSha256":p["payloadSha256"],"path":format!("payloads/{}.txt",text(p,"payloadSha256")),"mediaType":p["mediaType"],"encoding":p["encoding"],"plainByteCount":p["plainByteCount"]})).collect::<Vec<_>>();
    let manifest = json!({"archiveType":"kiyori_conversation_audit","formatVersion":1,"chatId":snapshot.chat["id"],"title":snapshot.chat["title"],"exportedAt":time(),"cutoffEventId":snapshot.events.last().map(|e|e["eventId"].clone()),"cutoffSequenceNumber":snapshot.events.len(),"completenessStatus":"BASIC","executionState":"TERMINAL_UNKNOWN","eventCount":snapshot.events.len(),"revisionCount":snapshot.revisions.len(),"sealCount":1,"payloads":payload_index,"nativeSourceChainHead":snapshot.source_head,"projection":"BASIC native audit projection; messageTimestamp is an observation locator; dates are UTC; unknown provider/tool facts are not reconstructed"});
    let integrity = json!({"chainHeadSha256":snapshot.head,"lastSequenceNumber":snapshot.events.len(),"latestSealSequenceNumber":snapshot.events.len(),"seals":[seal]});
    let report = json!({"policyVersion":1,"credentialsPersisted":false,"alwaysRedacted":["Authorization","Cookie","password","private key","access token","request signature","credential URL parameter"],"note":"Native source chain is preserved locally; the portable chain binds credential-redacted export projections. This ZIP is plaintext.","aiReviewMarkdown":"Additional pseudonymization of private paths and identity fields; plaintext UTF-8."});
    let entries = [
        ("manifest.json", manifest.to_string()),
        ("chat.json", snapshot.chat.to_string()),
        ("audit.json", archive.to_string()),
        ("timeline.md", markdown(snapshot, false)?),
        ("events.jsonl", event_jsonl(snapshot)),
        ("revisions.jsonl", jsonl(&snapshot.revisions)),
        ("projections.jsonl", jsonl(&snapshot.projections)),
        ("integrity.json", integrity.to_string()),
        ("redaction-report.json", report.to_string()),
    ];
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    for (name, content) in entries {
        write_entry(&mut zip, name, content.as_bytes())?;
    }
    for (sha, payload) in &snapshot.payloads {
        let bytes = STANDARD
            .decode(text(payload, "bytesBase64"))
            .map_err(|_| error("归档正文编码无效"))?;
        write_entry(&mut zip, &format!("payloads/{sha}.txt"), &bytes)?;
    }
    Ok(zip
        .finish()
        .map_err(|_| error("无法完成审计包"))?
        .into_inner())
}
fn write_entry(
    zip: &mut zip::ZipWriter<Cursor<Vec<u8>>>,
    name: &str,
    bytes: &[u8],
) -> Result<(), CoreError> {
    zip.start_file(
        name,
        zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated),
    )
    .map_err(|_| error("无法创建审计包"))?;
    zip.write_all(bytes).map_err(|_| error("无法写入审计包"))
}
fn jsonl(values: &[Value]) -> String {
    values.iter().map(|v| v.to_string() + "\n").collect()
}
fn event_jsonl(snapshot: &Snapshot) -> String {
    let mut refs_by_event: BTreeMap<String, Vec<Value>> = BTreeMap::new();
    for r in &snapshot.refs {
        refs_by_event.entry(text(r,"eventId")).or_default().push(json!({"payloadSha256":r["payloadSha256"],"label":r["label"],"ordinal":r["ordinal"],"role":r["role"]}));
    }
    snapshot
        .events
        .iter()
        .map(|event| {
            let mut projected = event.clone();
            projected["payloadRefs"] = json!(
                refs_by_event
                    .get(&text(event, "eventId"))
                    .cloned()
                    .unwrap_or_default()
            );
            projected.to_string() + "\n"
        })
        .collect()
}

pub(super) fn validate(archive: &Value) -> Result<(), CoreError> {
    let fail = || error("旧格式审计包完整性校验失败");
    let root = &archive["audit"];
    let id = &root["chatId"];
    if archive["schemaVersion"] != 1 || root["schemaVersion"] != 1 {
        return Err(fail());
    }
    let mut payloads = BTreeMap::new();
    for p in archive["payloads"].as_array().ok_or_else(fail)? {
        let sha = text(p, "payloadSha256");
        let bytes = STANDARD
            .decode(text(p, "bytesBase64"))
            .map_err(|_| fail())?;
        if bytes.len() as u64 != p["plainByteCount"].as_u64().ok_or_else(fail)?
            || hash(&bytes) != sha
            || payloads.insert(sha, p.clone()).is_some()
        {
            return Err(fail());
        }
        if text(p, "encoding").eq_ignore_ascii_case("utf-8") {
            let value = std::str::from_utf8(&bytes).map_err(|_| fail())?;
            if redact(value) != value {
                return Err(fail());
            }
        }
    }
    let events = archive["events"].as_array().ok_or_else(fail)?;
    let refs = archive["eventPayloads"].as_array().ok_or_else(fail)?;
    let mut refs_by_event: BTreeMap<String, Vec<Value>> = BTreeMap::new();
    for reference in refs {
        refs_by_event
            .entry(text(reference, "eventId"))
            .or_default()
            .push(reference.clone());
    }
    let events_by_id = events
        .iter()
        .map(|e| (text(e, "eventId"), e))
        .collect::<BTreeMap<_, _>>();
    let mut previous = "0".repeat(64);
    let mut seen = BTreeSet::new();
    let mut used = BTreeSet::new();
    for (index, event) in events.iter().enumerate() {
        let eid = text(event, "eventId");
        if &event["chatId"] != id
            || event["sequenceNumber"] != (index + 1)
            || event["previousEventSha256"] != previous
            || seen.contains(&eid)
        {
            return Err(fail());
        }
        if !event["parentEventId"].is_null() && !seen.contains(&text(event, "parentEventId")) {
            return Err(fail());
        }
        let mut event_refs = refs_by_event.get(&eid).cloned().unwrap_or_default();
        event_refs.sort_by_key(|r| r["ordinal"].as_i64().unwrap_or(-1));
        for (ordinal, reference) in event_refs.iter().enumerate() {
            if reference["ordinal"] != ordinal
                || !payloads.contains_key(&text(reference, "payloadSha256"))
            {
                return Err(fail());
            }
            used.insert(text(reference, "payloadSha256"));
        }
        if event_hash(event, &event_refs, &payloads)? != text(event, "eventSha256") {
            return Err(fail());
        }
        previous = text(event, "eventSha256");
        seen.insert(eid);
    }
    if refs.iter().any(|r| !seen.contains(&text(r, "eventId")))
        || root["eventCount"] != events.len()
        || root["lastSequenceNumber"] != events.len()
        || root["chainHeadSha256"] != previous
    {
        return Err(fail());
    }
    let mut revisions = BTreeMap::new();
    let mut latest: BTreeMap<(i64, i64), &Value> = BTreeMap::new();
    for r in archive["revisions"].as_array().ok_or_else(fail)? {
        let key = (
            r["messageTimestamp"].as_i64().ok_or_else(fail)?,
            r["variantIndex"].as_i64().ok_or_else(fail)?,
        );
        let old = latest.get(&key);
        let event = events_by_id
            .get(&text(r, "auditEventId"))
            .ok_or_else(fail)?;
        if &r["chatId"] != id
            || r["revisionNumber"]
                != old.map_or(0, |r| r["revisionNumber"].as_i64().unwrap_or(-1) + 1)
            || r["previousRevisionId"] != old.map_or(Value::Null, |r| r["revisionId"].clone())
            || event["eventType"] != "MESSAGE_REVISED"
            || event["messageTimestamp"] != r["messageTimestamp"]
            || event["variantIndex"] != r["variantIndex"]
            || !refs_by_event
                .get(&text(r, "auditEventId"))
                .is_some_and(|refs| {
                    refs.iter().any(|p| {
                        p["eventId"] == r["auditEventId"]
                            && p["payloadSha256"] == r["contentPayloadSha256"]
                            && p["role"] == r["sender"]
                    })
                })
            || revisions.insert(text(r, "revisionId"), r).is_some()
        {
            return Err(fail());
        }
        used.insert(text(r, "contentPayloadSha256"));
        latest.insert(key, r);
    }
    let mut projected = BTreeSet::new();
    for p in archive["projections"].as_array().ok_or_else(fail)? {
        let key = (
            p["messageTimestamp"].as_i64().ok_or_else(fail)?,
            p["variantIndex"].as_i64().ok_or_else(fail)?,
        );
        if &p["chatId"] != id
            || !projected.insert(key)
            || latest
                .get(&key)
                .is_none_or(|r| r["revisionId"] != p["currentRevisionId"])
        {
            return Err(fail());
        }
    }
    if used != payloads.keys().cloned().collect() {
        return Err(fail());
    }
    let seals = archive["seals"].as_array().ok_or_else(fail)?;
    let mut sealed = BTreeSet::new();
    let mut seal_ids = BTreeSet::new();
    let mut latest_seal = 0;
    for seal in seals {
        let sequence = seal["sequenceNumber"].as_u64().ok_or_else(fail)? as usize;
        if &seal["chatId"] != id
            || sequence == 0
            || !sealed.insert(sequence)
            || !seal_ids.insert(text(seal, "sealId"))
            || events
                .get(sequence - 1)
                .is_none_or(|e| e["eventSha256"] != seal["rootSha256"])
        {
            return Err(fail());
        }
        crate::audit_crypto::verify(
            text(seal, "rootSha256").as_bytes(),
            &crate::audit_crypto::AuditSignature {
                algorithm: text(seal, "signatureAlgorithm"),
                public_key: text(seal, "publicKeyBase64"),
                signature: text(seal, "signatureBase64"),
            },
        )?;
        latest_seal = latest_seal.max(sequence);
    }
    if seals.is_empty() || root["latestSealSequenceNumber"] != latest_seal {
        return Err(fail());
    }
    Ok(())
}

pub(super) fn markdown(snapshot: &Snapshot, external: bool) -> Result<String, CoreError> {
    let mut refs_by_event: BTreeMap<String, Vec<&Value>> = BTreeMap::new();
    for reference in &snapshot.refs {
        refs_by_event
            .entry(text(reference, "eventId"))
            .or_default()
            .push(reference);
    }
    let mut output = format!(
        "# Kiyori AI 对话审计\n\n- Chat ID: `{}`\n- 标题: {}\n- 完整性: `BASIC`\n- 事件数: {}\n- 链头: `{}`\n\n> 仅包含实际持久化事实。messageTimestamp 是首次审计观察的移植定位符，未知供应商、工具事实及迁移前修订不补造。\n\n",
        snapshot.chat["id"].as_str().unwrap_or(""),
        snapshot.chat["title"].as_str().unwrap_or(""),
        snapshot.events.len(),
        snapshot.head
    );
    if external {
        output.push_str("- 导出格式: 明文 UTF-8 Markdown（未加密）\n- payload 每项最多 64 KiB、合计最多 8 MiB，失败证据优先；相同正文仅展开一次。消息首尾各 32 Ki UTF-16 单元。完整正文保留在 `.kiyori-audit`。\n\n");
    }
    output.push_str("## 当前对话\n\n");
    for (index, message) in snapshot.chat["messages"]
        .as_array()
        .ok_or_else(|| error("归档消息无效"))?
        .iter()
        .enumerate()
    {
        let base = &message["baseMessage"];
        output.push_str(&format!(
            "### {}. {} · timestamp={}\n\n",
            index + 1,
            text(base, "sender"),
            text(base, "timestamp")
        ));
        let selected = base["selectedVariantIndex"].as_i64().unwrap_or(0);
        let content = if selected == 0 {
            text(base, "content")
        } else {
            text(
                message["variants"]
                    .as_array()
                    .and_then(|variants| variants.iter().find(|v| v["variantIndex"] == selected))
                    .ok_or_else(|| error("当前回复版本缺失"))?,
                "content",
            )
        };
        let displayed = if selected == 0 {
            base
        } else {
            message["variants"]
                .as_array()
                .and_then(|v| v.iter().find(|v| v["variantIndex"] == selected))
                .ok_or_else(|| error("当前回复版本缺失"))?
        };
        output.push_str(&format!("- model: {}\n- provider: not_recorded\n- sentAt: {}\n- provider usage coverage: {}/{}\n",displayed["modelName"].as_str().unwrap_or("not_recorded"),if displayed["sentAt"].is_null(){"not_recorded".into()}else{text(displayed,"sentAt")},text(displayed,"providerUsageRequestCount"),text(displayed,"providerRequestCount")));
        if displayed["providerUsageRequestCount"].as_i64().unwrap_or(0) > 0 {
            output.push_str(&format!(
                "- provider tokens: input={}, output={}\n",
                text(displayed, "providerTotalInputTokens"),
                text(displayed, "providerOutputTokens")
            ));
        } else {
            output.push_str("- provider tokens: not_reported\n");
        }
        output.push('\n');
        let content = if external {
            bound_message(&content)
        } else {
            content
        };
        fenced(&mut output, &content);
        if let Some(variants) = message["variants"].as_array() {
            for variant in variants.iter().filter(|v| v["variantIndex"] != selected) {
                let content = text(variant, "content");
                output.push_str(&format!(
                    "- 历史 AI variant {}\n\n",
                    text(variant, "variantIndex")
                ));
                fenced(
                    &mut output,
                    &if external {
                        bound_message(&content)
                    } else {
                        content
                    },
                );
            }
            if selected != 0 {
                output.push_str("- 历史 AI variant 0\n\n");
                let content = text(base, "content");
                fenced(
                    &mut output,
                    &if external {
                        bound_message(&content)
                    } else {
                        content
                    },
                );
            }
        }
    }
    let mut budget = 8 * 1024 * 1024usize;
    let mut included = BTreeSet::new();
    if external {
        let mut priority = snapshot.events.iter().collect::<Vec<_>>();
        priority.sort_by_key(|e| {
            (
                !matches!(e["terminalState"].as_str(), Some("FAILED" | "CANCELLED")),
                e["sequenceNumber"].as_i64().unwrap_or(0),
            )
        });
        for event in priority {
            for reference in refs_by_event
                .get(&text(event, "eventId"))
                .into_iter()
                .flatten()
            {
                let sha = text(reference, "payloadSha256");
                let size = snapshot.payloads[&sha]["plainByteCount"]
                    .as_u64()
                    .unwrap_or(u64::MAX) as usize;
                if !included.contains(&sha) && size <= 65536 && size <= budget {
                    included.insert(sha);
                    budget -= size;
                }
            }
        }
    }
    output.push_str("## 修订与当前投影\n\n");
    for revision in &snapshot.revisions {
        output.push_str(&format!(
            "- revision={}, timestamp={}, variant={}, source={}, payload={}\n",
            text(revision, "revisionId"),
            text(revision, "messageTimestamp"),
            text(revision, "variantIndex"),
            text(revision, "source"),
            text(revision, "contentPayloadSha256")
        ));
    }
    for projection in &snapshot.projections {
        output.push_str(&format!(
            "- current projection: timestamp={}, variant={}, revision={}\n",
            text(projection, "messageTimestamp"),
            text(projection, "variantIndex"),
            text(projection, "currentRevisionId")
        ));
    }
    output.push_str("\n## 审计事件时间线\n\n");
    let mut emitted = BTreeSet::new();
    for event in &snapshot.events {
        output.push_str(&format!("### {}. {} / {}\n\n- eventId: `{}`\n- recordedAt: {}\n- 摘要: {}\n- eventSha256: `{}`\n\n",text(event,"sequenceNumber"),text(event,"category"),text(event,"eventType"),text(event,"eventId"),text(event,"recordedAt"),text(event,"summary"),text(event,"eventSha256")));
        for reference in refs_by_event
            .get(&text(event, "eventId"))
            .into_iter()
            .flatten()
        {
            let sha = text(reference, "payloadSha256");
            let payload = &snapshot.payloads[&sha];
            output.push_str(&format!(
                "- SHA-256: `{sha}`；字节数: {}\n",
                text(payload, "plainByteCount")
            ));
            if !external {
                output.push_str(&format!("- 路径: `payloads/{sha}.txt`\n\n"));
                continue;
            }
            if !emitted.insert(sha.clone()) {
                output.push_str(&format!(
                    "- 正文与此前相同：[查看首次正文](#payload-{sha})\n\n"
                ));
                continue;
            }
            output.push_str(&format!("\n##### payload-{sha}\n\n"));
            if included.contains(&sha) {
                let bytes = STANDARD
                    .decode(text(payload, "bytesBase64"))
                    .map_err(|_| error("正文编码无效"))?;
                fenced(
                    &mut output,
                    std::str::from_utf8(&bytes).map_err(|_| error("正文UTF-8无效"))?,
                );
            } else {
                output.push_str("- 大型正文未展开或达到总预算（每项 64 KiB、合计 8 MiB）；原文请另行导出 `.kiyori-audit`。\n\n");
            }
        }
    }
    output.push_str("## 机器可读事件 JSONL\n\n```jsonl\n");
    output.push_str(&event_jsonl(snapshot));
    output.push_str("```\n");
    Ok(if external {
        share_redact(&output)
    } else {
        redact(&output)
    })
}
fn fenced(out: &mut String, value: &str) {
    let longest = value.split(|c| c != '`').map(str::len).max().unwrap_or(0);
    let fence = "`".repeat(longest.max(2) + 1);
    out.push_str(&format!("{fence}text\n{value}\n{fence}\n\n"));
}
fn bound_message(value: &str) -> String {
    let units = value.encode_utf16().count();
    if units <= 65536 {
        return value.to_owned();
    }
    let mut head = 0;
    let mut tail = value.len();
    let mut used = 0;
    for (i, c) in value.char_indices() {
        if used + c.len_utf16() > 32768 {
            break;
        }
        used += c.len_utf16();
        head = i + c.len_utf8();
    }
    used = 0;
    for (i, c) in value.char_indices().rev() {
        if used + c.len_utf16() > 32768 {
            break;
        }
        used += c.len_utf16();
        tail = i;
    }
    format!(
        "{}\n\n[中间正文未展开；完整原文见 .kiyori-audit]\n\n{}",
        &value[..head],
        &value[tail..]
    )
}

/// 旧外部审阅规则的扫描实现，无新增正则依赖；假名按原值SHA256保持稳定。
fn share_redact(value: &str) -> String {
    let value = redact(value);
    let lowercase = value.to_ascii_lowercase();
    let mut output = String::new();
    let mut cursor = 0;
    for (start, c) in value.char_indices() {
        if start < cursor {
            continue;
        }
        let tail = &value[start..];
        let lower = &lowercase[start..];
        let path = lower.starts_with("/home/")
            || lower.starts_with("/users/")
            || lower.starts_with("/data/data/")
            || lower.starts_with("/data/user/")
            || lower.starts_with("/storage/emulated/") && lower.contains("/android/")
            || c.is_ascii_alphabetic()
                && lower.get(1..3) == Some(":\\")
                && (lower[3..].trim_start_matches('\\').starts_with("users\\")
                    || lower[3..]
                        .trim_start_matches('\\')
                        .starts_with("documents and settings\\"));
        if path {
            let end = tail
                .char_indices()
                .find(|(_, c)| c.is_whitespace() || matches!(c, '"' | '\'' | '<' | '>' | '`'))
                .map_or(value.len(), |(i, _)| start + i);
            output.push_str(&value[cursor..start]);
            output.push_str(&format!(
                "[PRIVATE_PATH:{}]",
                &hash(&value.as_bytes()[start..end])[..12]
            ));
            cursor = end;
            continue;
        }
        if c == '@' {
            let begin = value[..start]
                .char_indices()
                .rev()
                .take_while(|(_, c)| {
                    c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '%' | '+' | '-')
                })
                .last()
                .map(|(i, _)| i);
            let end = tail[1..]
                .char_indices()
                .take_while(|(_, c)| c.is_ascii_alphanumeric() || matches!(c, '.' | '-'))
                .last()
                .map(|(i, c)| start + 1 + i + c.len_utf8());
            if let (Some(begin), Some(end)) = (begin, end)
                && begin >= cursor
                && value[start + 1..end].contains('.')
            {
                output.push_str(&value[cursor..begin]);
                output.push_str(&format!(
                    "[ACCOUNT:{}]",
                    &hash(&value.as_bytes()[begin..end])[..12]
                ));
                cursor = end;
            }
        }
        if start > 0 && value.as_bytes()[start - 1].is_ascii_alphanumeric() {
            continue;
        }
        for key in [
            "username",
            "user_name",
            "userid",
            "user_id",
            "accountid",
            "account_id",
            "deviceid",
            "device_id",
            "deviceserial",
            "device_serial",
        ] {
            if !lower.starts_with(key) {
                continue;
            }
            let after = start + key.len();
            let rest = value[after..].trim_start_matches(['"', '\'', ' ', '\t']);
            if !rest.starts_with([':', '=']) {
                continue;
            }
            let rest = rest[1..].trim_start();
            let Some(quote) = rest.chars().next().filter(|c| matches!(c, '"' | '\'')) else {
                continue;
            };
            let begin = value.len() - rest.len() + 1;
            if let Some(length) = value[begin..].find(quote) {
                let end = begin + length;
                if begin >= cursor && !value[begin..end].starts_with("[IDENTITY:") {
                    output.push_str(&value[cursor..begin]);
                    output.push_str(&format!(
                        "[IDENTITY:{}]",
                        &hash(&value.as_bytes()[begin..end])[..12]
                    ));
                    cursor = end;
                }
            }
        }
    }
    output.push_str(&value[cursor..]);
    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audit_crypto::ReferenceAuditCrypto;
    use std::io::Read;

    #[test]
    fn legacy_utf8_event_hash_matches_independent_node_vector() {
        let event = json!({"previousEventSha256":"0".repeat(64),"eventId":"event-1","chatId":"chat-1","sequenceNumber":1,"occurredAt":100,"recordedAt":101,"category":"USER","eventType":"USER_INPUT_SUBMITTED","actor":"USER","summary":"提交😀","messageTimestamp":100,"variantIndex":0,"localExecutionId":null,"providerCallId":null,"parentEventId":null,"sourceChatId":null,"sourceEventId":null,"visibility":"TIMELINE","terminalState":null});
        let sha = "1".repeat(64);
        let refs = vec![json!({"label":"input","ordinal":0,"role":"user","payloadSha256":sha})];
        let payloads = BTreeMap::from([(
            sha,
            json!({"mediaType":"text/plain","encoding":"utf-8","plainByteCount":5}),
        )]);
        assert_eq!(
            event_hash(&event, &refs, &payloads).unwrap(),
            "de21c29b11ad0bcc959b35d4ff39d704de063761ae9141cd9182a7cecb76e933"
        );
        let mut changed = event;
        changed["terminalState"] = json!("FAILED");
        assert_ne!(
            event_hash(&changed, &refs, &payloads).unwrap(),
            "de21c29b11ad0bcc959b35d4ff39d704de063761ae9141cd9182a7cecb76e933"
        );
    }

    #[test]
    fn portable_revisions_validate_and_tampered_relationships_are_rejected() {
        let dir =
            std::env::temp_dir().join(format!("kiyori-portable-{}-{}", std::process::id(), time()));
        let runtime = Runtime::with_data_dir(&dir).unwrap();
        let id = runtime.create_conversation().unwrap();
        runtime.with_store(|s|{s.connection.lock().unwrap().execute("INSERT INTO conversation_messages(id,conversation_id,position,role,content,state,variant) VALUES('synthetic-message',?1,0,'assistant','原文😀','completed',0)",[&id]).unwrap();Ok(())}).unwrap();
        runtime
            .conversation_audit(id.clone(), 0, String::new())
            .unwrap();
        let revision = runtime
            .conversation(id.clone())
            .unwrap()
            .conversation
            .revision;
        runtime
            .change_message(
                id.clone(),
                revision,
                "synthetic-message".into(),
                "edit".into(),
                "修订😀```围栏".into(),
            )
            .unwrap();
        runtime.with_store(|s|{
            let c=s.connection.lock().unwrap();
            // 保存旧variant 0，当前消息编辑仍须使用新内容，不能被历史副本回填。
            c.execute("INSERT INTO conversation_variants VALUES('synthetic-message',0,NULL,'过期正文','completed')",[]).unwrap();
            let rows=c.prepare("SELECT sequence,recorded_at,category,event_type,summary,payload,event_hash FROM conversation_audit_events WHERE conversation_id=?1 ORDER BY sequence").unwrap().query_map([&id],|r|{let payload:String=r.get(5)?;Ok(json!({"sequence":r.get::<_,i64>(0)?,"recordedAt":r.get::<_,i64>(1)?,"category":r.get::<_,String>(2)?,"eventType":r.get::<_,String>(3)?,"summary":r.get::<_,String>(4)?,"payload":serde_json::from_str::<Value>(&payload).unwrap(),"eventSha256":r.get::<_,String>(6)?}))}).unwrap().collect::<Result<Vec<_>,_>>().unwrap();
            let snapshot=build(&c,&id,rows).unwrap();
            assert_eq!(snapshot.revisions.len(),2);
            assert_eq!(snapshot.projections.len(),1);
            assert_eq!(snapshot.chat["messages"][0]["baseMessage"]["content"],"修订😀```围栏");
            let bytes=package(&c,&ReferenceAuditCrypto,&snapshot).unwrap();
            let mut zip=zip::ZipArchive::new(Cursor::new(bytes)).unwrap();
            for name in ["manifest.json","chat.json","audit.json","timeline.md","events.jsonl","revisions.jsonl","projections.jsonl","integrity.json","redaction-report.json"]{assert!(zip.by_name(name).is_ok(),"{name}");}
            let mut text=String::new();zip.by_name("audit.json").unwrap().read_to_string(&mut text).unwrap();
            let archive:Value=serde_json::from_str(&text).unwrap();validate(&archive).unwrap();
            for mutation in 0..5 {
                let mut bad=archive.clone();
                match mutation{
                    0=>bad["events"][0]["summary"]=json!("篡改"),
                    1=>bad["revisions"][1]["previousRevisionId"]=Value::Null,
                    2=>bad["projections"][0]["currentRevisionId"]=bad["revisions"][0]["revisionId"].clone(),
                    3=>bad["payloads"][0]["bytesBase64"]=json!(STANDARD.encode("篡改")),
                    _=>bad["seals"][0]["rootSha256"]=json!("0".repeat(64)),
                }
                assert!(validate(&bad).is_err(),"mutation {mutation}");
            }
            let markdown=markdown(&snapshot,true).unwrap();
            assert!(markdown.contains("原文😀"));assert!(markdown.contains("修订😀```围栏"));
            assert!(markdown.contains("````text"));
            Ok(())
        }).unwrap();
        runtime.close();
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn diagnostics_pseudonymize_deduplicate_bound_and_keep_source_bytes() {
        let nested = json!({"messages":[{"content":"嵌套😀 {\"password\":\"synthetic-nested-secret\"}","apiKey":"synthetic-object-secret"}],"ordinary":"保留"});
        let scrubbed = redacted_json(&nested).unwrap();
        assert!(!scrubbed.to_string().contains("synthetic-nested-secret"));
        assert!(!scrubbed.to_string().contains("synthetic-object-secret"));
        assert!(scrubbed.to_string().contains("嵌套😀"));
        assert_eq!(scrubbed["ordinary"], "保留");
        let private = r#"正文😀 C:\Users\fixture\private.txt /home/fixture/private.txt /data/user/0/com.fixture/db user@example.test {"userId":"fixture-identity","password":"synthetic-secret"} /srv/public.txt"#;
        let shared = share_redact(private);
        for raw in [
            r"C:\Users\fixture",
            "/home/fixture",
            "/data/user/0/com.fixture",
            "user@example.test",
            "fixture-identity",
            "synthetic-secret",
        ] {
            assert!(!shared.contains(raw), "{shared}");
        }
        for retained in [
            "正文😀",
            "[PRIVATE_PATH:",
            "[ACCOUNT:",
            "[IDENTITY:",
            "/srv/public.txt",
        ] {
            assert!(shared.contains(retained), "{shared}");
        }
        assert_eq!(share_redact(&shared), shared);
        let long = format!("BEGIN😀{}😀END", "中".repeat(70000));
        let bounded = bound_message(&long);
        assert!(bounded.starts_with("BEGIN😀"));
        assert!(bounded.ends_with("😀END"));
        assert!(bounded.contains("中间正文未展开"));
        assert!(bounded.len() < long.len());
        assert_eq!(iso(0), "1970-01-01T00:00:00.000");
        assert_eq!(iso(1709164800123), "2024-02-29T00:00:00.123");
        let mut snapshot = Snapshot {
            chat: json!({"id":"fixture","title":"fixture","messages":[]}),
            events: vec![],
            refs: vec![],
            revisions: vec![],
            projections: vec![],
            payloads: BTreeMap::new(),
            head: "0".repeat(64),
            at: 1,
            source_sequence: 0,
            source_head: String::new(),
            locators: BTreeMap::new(),
            occupied_locators: BTreeSet::new(),
            latest: BTreeMap::new(),
        };
        for at in 1..=2 {
            let event = snapshot.metadata(at, "USER", "DIAGNOSTIC_NOTE", "备注");
            snapshot
                .push(event, private, "text/plain", "metadata")
                .unwrap();
        }
        let huge = "大".repeat(30000);
        let event = snapshot.metadata(3, "USER", "DIAGNOSTIC_NOTE", "大正文");
        snapshot
            .push(event, &huge, "text/plain", "metadata")
            .unwrap();
        assert_eq!(snapshot.payloads.len(), 2);
        let md = markdown(&snapshot, true).unwrap();
        assert_eq!(md.matches("正文😀").count(), 1);
        assert!(md.contains("查看首次正文"));
        assert!(md.contains("大型正文未展开"));
        assert!(!md.contains("user@example.test"));
        assert!(
            snapshot
                .payloads
                .values()
                .any(|p| STANDARD.decode(text(p, "bytesBase64")).unwrap() == huge.as_bytes())
        );
    }
}
