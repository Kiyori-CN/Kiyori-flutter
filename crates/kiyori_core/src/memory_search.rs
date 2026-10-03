//! 检索偏好与本地评分；完整正文逐条扫描，Dart只接收有界解释结果。
use crate::{
    knowledge::{MemoryQuery, folder_path, require_space},
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use std::{collections::HashMap, sync::OnceLock};

#[cfg(test)]
#[path = "memory_search_tests.rs"]
mod tests;

#[derive(Clone, Debug, PartialEq)]
pub struct MemorySearchSettings {
    pub graph_visible: bool,
    pub score_mode: String,
    pub keyword_weight: f64,
    pub tag_weight: f64,
    pub vector_weight: f64,
    pub edge_weight: f64,
    pub auto_interval: u32,
    pub extraction_rules: String,
}
impl Default for MemorySearchSettings {
    fn default() -> Self {
        Self {
            graph_visible: false,
            score_mode: "balanced".into(),
            keyword_weight: 10.0,
            tag_weight: 0.0,
            vector_weight: 0.0,
            edge_weight: 0.4,
            auto_interval: 5,
            extraction_rules: String::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct MemorySearchCandidate {
    pub id: String,
    pub title: String,
    pub folder: String,
    pub matched_tokens: u32,
    pub keyword_score: f64,
    pub tag_score: f64,
    pub reverse_score: f64,
    pub edge_score: f64,
    pub total_score: f64,
    pub passed: bool,
}
#[derive(Clone, Debug)]
pub struct MemorySearchReport {
    pub space_id: String,
    pub tokens: Vec<String>,
    pub scope_count: u32,
    pub keyword_matches: u32,
    pub tag_matches: u32,
    pub reverse_matches: u32,
    pub edges_traversed: u32,
    pub passed_count: u32,
    pub keyword_weight: f64,
    pub tag_weight: f64,
    pub edge_weight: f64,
    pub vector_unavailable: bool,
    pub has_more: bool,
    pub candidates: Vec<MemorySearchCandidate>,
}
fn invalid(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::InvalidInput,
        message: message.into(),
    }
}
fn storage(_: rusqlite::Error) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: "Memory search storage failed.".into(),
    }
}
pub(crate) fn settings_in(
    connection: &Connection,
    space: &str,
) -> Result<MemorySearchSettings, CoreError> {
    require_space(connection, space)?;
    Ok(connection.query_row(
        "SELECT graph_visible,score_mode,keyword_weight,tag_weight,vector_weight,edge_weight,auto_interval,extraction_rules FROM memory_search_settings WHERE space_id=?1",
        [space], |r| Ok(MemorySearchSettings { graph_visible:r.get(0)?,score_mode:r.get(1)?,keyword_weight:r.get(2)?,tag_weight:r.get(3)?,vector_weight:r.get(4)?,edge_weight:r.get(5)?,auto_interval:r.get(6)?,extraction_rules:r.get(7)? }))
        .optional().map_err(storage)?.unwrap_or_default())
}
impl Runtime {
    pub fn memory_search_settings(&self, space: String) -> Result<MemorySearchSettings, CoreError> {
        self.with_store(|s| s.memory_search_settings(space))
    }
    pub fn save_memory_search_settings(
        &self,
        space: String,
        value: MemorySearchSettings,
    ) -> Result<(), CoreError> {
        self.with_store(|s| s.save_memory_search_settings(space, value))
    }
    pub fn set_memory_graph_visible(&self, space: String, visible: bool) -> Result<(), CoreError> {
        self.with_store(|s| s.set_memory_graph_visible(space, visible))
    }
    pub fn simulate_memory_search(
        &self,
        space: String,
        query: MemoryQuery,
    ) -> Result<MemorySearchReport, CoreError> {
        self.with_store(|s| s.simulate_memory_search(space, query))
    }
}
impl AppStore {
    pub fn memory_search_settings(&self, space: String) -> Result<MemorySearchSettings, CoreError> {
        let connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        settings_in(&connection, &space)
    }
    pub fn save_memory_search_settings(
        &self,
        space: String,
        mut value: MemorySearchSettings,
    ) -> Result<(), CoreError> {
        if !matches!(
            value.score_mode.as_str(),
            "balanced" | "keyword_first" | "semantic_first"
        ) || [
            value.keyword_weight,
            value.tag_weight,
            value.vector_weight,
            value.edge_weight,
        ]
        .iter()
        .any(|v| !v.is_finite())
            || value.extraction_rules.encode_utf16().count() > 20000
        {
            return Err(invalid("Invalid memory search settings."));
        }
        value.keyword_weight = value.keyword_weight.clamp(0.0, 20.0);
        value.tag_weight = value.tag_weight.clamp(0.0, 20.0);
        value.vector_weight = value.vector_weight.clamp(0.0, 2.0);
        value.edge_weight = value.edge_weight.clamp(0.0, 2.0);
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&tx, &space)?;
        // 图谱偏好独立更新，过期设置草稿不能覆盖另一窗口的显示选择。
        tx.execute("INSERT INTO memory_search_settings(space_id,score_mode,keyword_weight,tag_weight,vector_weight,edge_weight,auto_interval,extraction_rules) VALUES (?1,?2,?3,?4,?5,?6,?7,?8) ON CONFLICT(space_id) DO UPDATE SET score_mode=excluded.score_mode,keyword_weight=excluded.keyword_weight,tag_weight=excluded.tag_weight,vector_weight=excluded.vector_weight,edge_weight=excluded.edge_weight,auto_interval=excluded.auto_interval,extraction_rules=excluded.extraction_rules",
            params![space,value.score_mode,value.keyword_weight,value.tag_weight,value.vector_weight,value.edge_weight,value.auto_interval.clamp(1,30),value.extraction_rules]).map_err(storage)?;
        tx.commit().map_err(storage)
    }
    pub fn set_memory_graph_visible(&self, space: String, visible: bool) -> Result<(), CoreError> {
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage)?;
        require_space(&tx, &space)?;
        tx.execute("INSERT INTO memory_search_settings(space_id,graph_visible) VALUES (?1,?2) ON CONFLICT(space_id) DO UPDATE SET graph_visible=excluded.graph_visible", params![space,visible]).map_err(storage)?;
        tx.commit().map_err(storage)
    }
}

fn searchable(token: &str) -> bool {
    let body: String = token.split('*').map(str::trim).collect();
    (2..=24).contains(&body.encode_utf16().count()) && body.chars().any(char::is_alphanumeric)
}
fn tokens(query: &str) -> Vec<String> {
    static SEGMENTER: OnceLock<jieba_rs::Jieba> = OnceLock::new();
    let fragments: Vec<_> = if query.contains('|') {
        query.split('|').collect()
    } else {
        query.split_whitespace().collect()
    };
    let mut result = vec![];
    for fragment in fragments {
        let fragment = fragment.trim().to_lowercase();
        if searchable(&fragment) {
            result.push(fragment.clone());
        }
        if !fragment.contains('*') {
            for word in SEGMENTER
                .get_or_init(jieba_rs::Jieba::new)
                .cut_for_search(&fragment, true)
            {
                if searchable(word.word) {
                    result.push(word.word.to_owned());
                }
            }
        }
    }
    result.sort_by(|a, b| {
        b.encode_utf16()
            .count()
            .cmp(&a.encode_utf16().count())
            .then(a.cmp(b))
    });
    result.dedup();
    result.truncate(32);
    result
}
// 有序字面片段匹配，不把a*b误写为ab，也不把用户输入解释为正则。
fn matches(text: &str, token: &str) -> bool {
    if token.trim().is_empty() || token.split('*').all(|p| p.trim().is_empty()) {
        return false;
    }
    let mut remaining = text;
    for part in token.split('*').map(str::trim).filter(|p| !p.is_empty()) {
        let Some(offset) = remaining.find(part) else {
            return false;
        };
        remaining = &remaining[offset + part.len()..];
    }
    true
}
struct Scored {
    row: MemorySearchCandidate,
    importance: f64,
    updated: i64,
    keyword_hits: u32,
    tag_hits: u32,
    reverse: bool,
}
impl AppStore {
    pub fn simulate_memory_search(
        &self,
        space: String,
        query: MemoryQuery,
    ) -> Result<MemorySearchReport, CoreError> {
        if query.text.encode_utf16().count() > 2048 {
            return Err(invalid("Search query exceeds 2048 characters."));
        }
        let query_text = query.text.trim().to_lowercase();
        let tokens = tokens(&query_text);
        let all = query_text.is_empty() || query_text == "*";
        let folder = folder_path(&query.folder)?;
        let mut connection = self
            .connection
            .lock()
            .map_err(|_| invalid("Storage lock failed."))?;
        let tx = connection.transaction().map_err(storage)?;
        let config = settings_in(&tx, &space)?;
        let (lexical, edge) = match config.score_mode.as_str() {
            "keyword_first" => (1.3, 0.9),
            "semantic_first" => (0.8, 1.1),
            _ => (1.0, 1.0),
        };
        let mut report = MemorySearchReport {
            space_id: space.clone(),
            tokens: tokens.clone(),
            scope_count: 0,
            keyword_matches: 0,
            tag_matches: 0,
            reverse_matches: 0,
            edges_traversed: 0,
            passed_count: 0,
            keyword_weight: config.keyword_weight * lexical,
            tag_weight: config.tag_weight * lexical,
            edge_weight: config.edge_weight * edge,
            vector_unavailable: config.vector_weight > 0.0,
            has_more: false,
            candidates: vec![],
        };
        let mut rows = Vec::<Scored>::new();
        let mut statement = tx.prepare("SELECT id,title,content,folder,importance,updated_at,kind FROM memories WHERE space_id=?1 AND (?2 IS NULL OR kind=?2) AND archived=?3 AND (?4='' OR folder=?4 OR substr(folder,1,length(?4)+1)=?4||'/') AND (?5 IS NULL OR category=?5) AND (?6 IS NULL OR EXISTS(SELECT 1 FROM memory_tags WHERE memory_id=memories.id AND name=?6)) ORDER BY updated_at DESC,id DESC").map_err(storage)?;
        let mut cursor = statement
            .query(params![
                space,
                query.kind,
                query.archived,
                folder,
                query.category,
                query.tag
            ])
            .map_err(storage)?;
        let mut tags_query = tx
            .prepare("SELECT name FROM memory_tags WHERE memory_id=?1")
            .map_err(storage)?;
        while let Some(record) = cursor.next().map_err(storage)? {
            let content: String = record.get(2).map_err(storage)?;
            let kind: String = record.get(6).map_err(storage)?;
            if kind == "diary"
                && query.diary_closed.is_some_and(|v| {
                    crate::diary::parse(&content)
                        .entries
                        .last()
                        .is_some_and(|e| e.phase == "closed")
                        != v
                })
            {
                continue;
            }
            let id: String = record.get(0).map_err(storage)?;
            let title: String = record.get(1).map_err(storage)?;
            let tags = tags_query
                .query_map([&id], |r| r.get::<_, String>(0))
                .map_err(storage)?
                .collect::<Result<Vec<_>, _>>()
                .map_err(storage)?;
            let tags: Vec<_> = tags.iter().map(|t| t.to_lowercase()).collect();
            let title_lower = title.to_lowercase();
            let body = content.to_lowercase();
            let keyword_hits = tokens
                .iter()
                .filter(|t| {
                    matches(&title_lower, t)
                        || matches(&body, t)
                        || tags.iter().any(|tag| matches(tag, t))
                })
                .count() as u32;
            let tag_hits = tokens
                .iter()
                .filter(|t| tags.iter().any(|tag| matches(tag, t)))
                .count() as u32;
            let reverse = !tokens.is_empty() && matches(&query_text, &title_lower);
            report.scope_count += 1;
            rows.push(Scored {
                row: MemorySearchCandidate {
                    id,
                    title,
                    folder: record.get(3).map_err(storage)?,
                    matched_tokens: keyword_hits,
                    keyword_score: 0.0,
                    tag_score: 0.0,
                    reverse_score: 0.0,
                    edge_score: 0.0,
                    total_score: 0.0,
                    passed: all,
                },
                importance: record.get(4).map_err(storage)?,
                updated: record.get(5).map_err(storage)?,
                keyword_hits,
                tag_hits,
                reverse,
            });
        }
        drop(cursor);
        drop(statement);
        drop(tags_query);
        if !all {
            for (tag, weight) in [(false, report.keyword_weight), (true, report.tag_weight)] {
                let hits = |v: &Scored| if tag { v.tag_hits } else { v.keyword_hits };
                let mut order: Vec<_> = (0..rows.len()).filter(|i| hits(&rows[*i]) > 0).collect();
                order.sort_by(|a, b| {
                    hits(&rows[*b])
                        .cmp(&hits(&rows[*a]))
                        .then(rows[*b].importance.total_cmp(&rows[*a].importance))
                        .then(rows[*b].updated.cmp(&rows[*a].updated))
                        .then(rows[*a].row.id.cmp(&rows[*b].row.id))
                });
                if tag {
                    report.tag_matches = order.len() as u32;
                } else {
                    report.keyword_matches = order.len() as u32;
                }
                for (rank, i) in order.into_iter().enumerate() {
                    let score = weight * rows[i].importance / (61.0 + rank as f64)
                        * (1.0 + 0.6 * hits(&rows[i]) as f64 / tokens.len() as f64);
                    if tag {
                        rows[i].row.tag_score = score;
                    } else {
                        rows[i].row.keyword_score = score;
                    }
                }
            }
            for row in rows.iter_mut().filter(|r| r.reverse) {
                report.reverse_matches += 1;
                row.row.reverse_score =
                    report.keyword_weight * row.importance / (60.0 + report.reverse_matches as f64);
            }
            for row in &mut rows {
                row.row.total_score =
                    row.row.keyword_score + row.row.tag_score + row.row.reverse_score;
            }
            if report.edge_weight > 0.0 {
                let indices: HashMap<_, _> = rows
                    .iter()
                    .enumerate()
                    .map(|(i, r)| (r.row.id.clone(), i))
                    .collect();
                let mut seeds: Vec<_> = rows
                    .iter()
                    .filter(|r| r.row.total_score > 0.0)
                    .map(|r| (r.row.id.clone(), r.row.total_score))
                    .collect();
                seeds.sort_by(|a, b| b.1.total_cmp(&a.1).then(a.0.cmp(&b.0)));
                seeds.truncate(10);
                let mut links = tx.prepare("SELECT source_id,target_id,weight FROM memory_links WHERE space_id=?1 AND (source_id=?2 OR target_id=?2) ORDER BY id").map_err(storage)?;
                // 固定种子原始分数，避免遍历顺序让本轮传播分数再次传播。
                for (id, score) in seeds {
                    let edges = links
                        .query_map(params![space, id], |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, f64>(2)?,
                            ))
                        })
                        .map_err(storage)?;
                    for edge in edges {
                        let (a, b, weight) = edge.map_err(storage)?;
                        let target = if a == id { b } else { a };
                        if let Some(i) = indices.get(&target) {
                            rows[*i].row.edge_score += (score * weight + 0.03) * report.edge_weight;
                            report.edges_traversed += 1;
                        }
                    }
                }
            }
            for row in &mut rows {
                row.row.total_score += row.row.edge_score;
                row.row.passed = row.row.total_score >= 0.025;
            }
            rows.retain(|r| r.row.total_score > 0.0);
            rows.sort_by(|a, b| {
                b.row
                    .total_score
                    .total_cmp(&a.row.total_score)
                    .then(b.updated.cmp(&a.updated))
                    .then(a.row.id.cmp(&b.row.id))
            });
        }
        report.passed_count = rows.iter().filter(|r| r.row.passed).count() as u32;
        report.has_more = rows.len() > 100;
        report.candidates = rows.into_iter().take(100).map(|r| r.row).collect();
        tx.commit().map_err(storage)?;
        Ok(report)
    }
}
