//! 首个资源用例是应用私有模型包；用户SAF/bookmark引用仍由平台adapter管理。
use crate::{
    runtime::{CoreError, ErrorCode, Runtime},
    storage::AppStore,
};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResourceRef {
    pub id: String,
    pub workspace: String,
    pub source: String,
    pub name: String,
    pub mime: String,
}
pub(crate) fn error(message: &str) -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: message.into(),
    }
}
pub(crate) fn valid_id(id: &str) -> bool {
    id.len() == 32 && id.bytes().all(|b| b.is_ascii_hexdigit())
}
pub(crate) fn valid_relative(path: &str) -> bool {
    if path.is_empty() || path.len() > 512 || path.split('/').count() > 16 {
        return false;
    }
    path.split('/').all(|part| {
        let stem = part
            .split('.')
            .next()
            .unwrap_or_default()
            .to_ascii_uppercase();
        !part.is_empty()
            && part != "."
            && part != ".."
            && !part.ends_with(['.', ' '])
            && !part
                .chars()
                .any(|c| c.is_control() || "\\:<>\"|?*".contains(c))
            && !["CON", "PRN", "AUX", "NUL", "CLOCK$"].contains(&stem.as_str())
            && !(stem.len() == 4
                && (stem.starts_with("COM") || stem.starts_with("LPT"))
                && matches!(stem.as_bytes()[3], b'1'..=b'9'))
    })
}
pub(crate) fn plain(path: &Path) -> Result<(), CoreError> {
    match std::fs::symlink_metadata(path) {
        Ok(meta) => {
            #[cfg(windows)]
            {
                use std::os::windows::fs::MetadataExt;
                if meta.file_attributes() & 0x400 != 0 {
                    return Err(error("托管资源包含链接，拒绝访问"));
                }
            }
            if meta.file_type().is_symlink() {
                return Err(error("托管资源包含链接，拒绝访问"));
            }
            Ok(())
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(_) => Err(error("无法读取托管资源状态")),
    }
}
impl AppStore {
    pub(crate) fn managed_path(&self, id: &str, relative: &str) -> Result<PathBuf, CoreError> {
        if !valid_id(id) || (!relative.is_empty() && !valid_relative(relative)) {
            return Err(error("托管资源标识或相对路径无效"));
        }
        let base = self.directory.join("resources");
        plain(&base)?;
        let mut path = base.join(id);
        plain(&path)?;
        if !relative.is_empty() {
            for component in relative.split('/') {
                path.push(component);
                plain(&path)?;
            }
        }
        Ok(path)
    }
}
impl Runtime {
    /// 仅完成的Transfer可被推理adapter读取；调用者不能借id访问任意宿主目录。
    pub fn resource_file_path(&self, id: String, relative: String) -> Result<String, CoreError> {
        self.with_store(|store| {
            let connection = store.connection.lock().map_err(|_| error("资源存储锁不可用"))?;
            let exists: bool = connection.query_row("SELECT EXISTS(SELECT 1 FROM transfers t JOIN transfer_files f ON f.transfer_id=t.id WHERE t.id=?1 AND t.phase='completed' AND f.path=?2 AND f.verified=1)",rusqlite::params![id,relative],|r|r.get(0)).map_err(|_|error("资源读取失败"))?;
            if !exists { return Err(error("资源未完成或文件不属于该资源")); }
            let path = store.managed_path(&id, &relative)?;
            if !path.is_file() { return Err(error("资源文件已不可用，请重新下载")); }
            path.to_str().map(str::to_owned).ok_or_else(||error("资源路径无法表示"))
        })
    }
}
