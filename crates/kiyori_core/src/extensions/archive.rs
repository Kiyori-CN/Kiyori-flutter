//! 不直接extract；先用流式读取限制实际条目，再用正式目录验证CRC与数据重叠。
use super::*;
use std::{
    collections::BTreeMap,
    io::{Read, Seek},
};
use zip::{
    CompressionMethod, ZipArchive,
    read::{ZipFile, read_zipfile_from_stream},
};

const MAX_ENTRIES: usize = 1024;
const MAX_EXPANDED: u64 = 16 * 1024 * 1024;
const MAX_FILE: u64 = 4 * 1024 * 1024;

#[derive(Clone, Deserialize, Serialize)]
pub(super) struct Manifest {
    pub schema_version: u32,
    pub toolpkg_id: String,
    pub version: String,
    pub main: String,
    #[serde(default)]
    pub display_name: Value,
    #[serde(default)]
    pub description: Value,
    #[serde(default = "enabled_default")]
    pub enabled_by_default: bool,
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}
fn enabled_default() -> bool {
    true
}
pub(super) fn label(value: &Value) -> Result<String, CoreError> {
    let text = match value {
        Value::Null => "",
        Value::String(text) => text,
        Value::Object(values) => {
            if values.values().any(|v| {
                !v.is_string()
                    || v.as_str()
                        .is_some_and(|s| s.len() > 4096 || s.contains('\0'))
            }) {
                return Err(error("扩展本地化文字无效"));
            }
            values
                .get("zh")
                .or_else(|| values.get("en"))
                .or_else(|| values.values().next())
                .and_then(Value::as_str)
                .unwrap_or_default()
        }
        _ => return Err(error("扩展文字无效")),
    };
    if text.len() > 4096 || text.contains('\0') {
        return Err(error("扩展文字超过限制"));
    }
    Ok(text.to_owned())
}
impl Manifest {
    pub(super) fn validate(&self) -> Result<(), CoreError> {
        let version = self.version.split('.').collect::<Vec<_>>();
        if self.schema_version != 1
            || !crate::scripts::valid_id(&self.toolpkg_id)
            || version.len() != 3
            || version.iter().any(|p| {
                p.is_empty() || !p.bytes().all(|b| b.is_ascii_digit()) || p.parse::<u32>().is_err()
            })
            || !files::valid_relative(&self.main)
            || !self.main.ends_with(".js")
        {
            return Err(error("扩展manifest身份、版本或入口不受支持"));
        }
        label(&self.display_name)?;
        label(&self.description)?;
        for (name, value) in &self.extra {
            let allowed = match name.as_str() {
                "author" | "category" | "logo" => true,
                "api_version" => value.as_str().is_some_and(|v| v == "1" || v == "1.0"),
                "requires"
                | "environment"
                | "subpackages"
                | "resources"
                | "wasm_modules"
                | "workflow_templates"
                | "workspace_templates" => value.as_array().is_some_and(Vec::is_empty),
                _ => false,
            };
            if !allowed {
                return Err(error("此扩展声明了尚未接入的包能力"));
            }
        }
        Ok(())
    }
}
pub(super) struct CheckedArchive {
    pub manifest: Manifest,
    pub source: String,
}
struct Preflight {
    entries: BTreeMap<String, (u64, u32)>,
    central: BTreeMap<String, (u64, u32)>,
    count: usize,
    expanded: u64,
}
fn invalid_zip() -> zip::result::ZipError {
    zip::result::ZipError::InvalidArchive("Invalid bounded package".into())
}
fn name(raw: &str, directory: bool) -> bool {
    let path = if directory {
        raw.strip_suffix('/').unwrap_or(raw)
    } else {
        raw
    };
    files::valid_relative(path)
        && !path.split('/').any(|p| p.starts_with('.'))
        && ![
            ".exe",
            ".dll",
            ".so",
            ".dylib",
            ".wasm",
            ".qjsc",
            ".bin",
            ".pem",
            ".key",
            ".p12",
            ".jks",
            ".keystore",
        ]
        .iter()
        .any(|suffix| path.to_ascii_lowercase().ends_with(suffix))
}
fn supported(method: CompressionMethod) -> bool {
    matches!(
        method,
        CompressionMethod::Stored | CompressionMethod::Deflated
    )
}
impl Preflight {
    fn visit_file<R: Read>(&mut self, file: &mut ZipFile<'_, R>) -> zip::result::ZipResult<()> {
        self.count += 1;
        let lower = file.name().to_ascii_lowercase();
        if self.count > MAX_ENTRIES
            || !name(file.name(), file.is_dir())
            || file.name().as_bytes() != file.name_raw()
            || file.encrypted()
            || !supported(file.compression())
            || file.size() > MAX_FILE
            || file.size() > file.compressed_size().max(1).saturating_mul(200)
            || self.entries.contains_key(&lower)
        {
            return Err(invalid_zip());
        }
        self.expanded = self
            .expanded
            .checked_add(file.size())
            .ok_or_else(invalid_zip)?;
        if self.expanded > MAX_EXPANDED {
            return Err(invalid_zip());
        }
        self.entries.insert(lower, (file.size(), file.crc32()));
        // 实际读取不能超过声明；读到EOF才触发CRC校验，不能只相信中央目录size。
        let expected = file.size();
        let read = std::io::copy(&mut file.take(expected + 1), &mut std::io::sink())?;
        if read != expected {
            return Err(invalid_zip());
        }
        Ok(())
    }
    fn visit_additional_metadata<R: Read>(
        &mut self,
        file: &ZipFile<'_, R>,
    ) -> zip::result::ZipResult<()> {
        let key = file.name().to_ascii_lowercase();
        let mode = file.unix_mode().unwrap_or(0) & 0o170000;
        if !name(file.name(), file.is_dir())
            || file.name().as_bytes() != file.name_raw()
            || file.is_symlink()
            || !matches!(mode, 0 | 0o100000 | 0o040000)
            || self.central.len() >= MAX_ENTRIES
            || self
                .central
                .insert(key, (file.size(), file.crc32()))
                .is_some()
        {
            return Err(invalid_zip());
        }
        Ok(())
    }
}
pub(super) fn read(file: &mut File) -> Result<CheckedArchive, CoreError> {
    file.rewind().map_err(|_| error("扩展包不可读"))?;
    let mut visitor = Preflight {
        entries: Default::default(),
        central: Default::default(),
        count: 0,
        expanded: 0,
    };
    loop {
        let entry = read_zipfile_from_stream(&mut *file).map_err(|_| error("扩展ZIP文件头无效"))?;
        let Some(mut entry) = entry else {
            break;
        };
        visitor
            .visit_file(&mut entry)
            .map_err(|_| error("扩展ZIP路径、数量、大小、压缩或CRC无效"))?;
    }
    if visitor.entries.is_empty() {
        return Err(error("扩展ZIP没有文件"));
    }
    file.rewind().map_err(|_| error("扩展包不可读"))?;
    let mut archive = ZipArchive::new(file).map_err(|_| error("扩展ZIP终态无效"))?;
    if archive.len() != visitor.count
        || archive.offset() != 0
        || archive
            .has_overlapping_files()
            .map_err(|_| error("扩展ZIP布局无效"))?
    {
        return Err(error("扩展ZIP重复、前缀或数据重叠"));
    }
    for index in 0..archive.len() {
        let entry = archive
            .by_index_raw(index)
            .map_err(|_| error("扩展ZIP目录不可读"))?;
        visitor
            .visit_additional_metadata(&entry)
            .map_err(|_| error("扩展ZIP目录或链接无效"))?;
    }
    if visitor.central != visitor.entries {
        return Err(error("扩展ZIP目录与文件不一致"));
    }
    let manifest_text = read_entry(&mut archive, "manifest.json", 64 * 1024)?;
    let manifest: Manifest =
        serde_json::from_slice(&manifest_text).map_err(|_| error("扩展manifest不是有效JSON"))?;
    manifest.validate()?;
    let source = String::from_utf8(read_entry(&mut archive, &manifest.main, 2 * 1024 * 1024)?)
        .map_err(|_| error("扩展入口必须为UTF-8 JavaScript"))?;
    if source.is_empty() || source.contains('\0') {
        return Err(error("扩展入口无效"));
    }
    Ok(CheckedArchive { manifest, source })
}
fn read_entry<R: Read + Seek>(
    archive: &mut ZipArchive<R>,
    name: &str,
    limit: u64,
) -> Result<Vec<u8>, CoreError> {
    let file = archive
        .by_name(name)
        .map_err(|_| error("扩展缺少manifest或入口"))?;
    if !file.is_file()
        || file.is_symlink()
        || file.encrypted()
        || !supported(file.compression())
        || file.size() > limit
    {
        return Err(error("扩展文件超过限制或不是普通文件"));
    }
    let expected = file.size();
    let mut bytes = Vec::new();
    file.take(limit + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| error("扩展文件CRC或读取失败"))?;
    if bytes.len() as u64 != expected {
        return Err(error("扩展文件大小不一致"));
    }
    Ok(bytes)
}
