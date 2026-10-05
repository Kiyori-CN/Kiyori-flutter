//! 审计安全端口：Android持有Keystore句柄，Windows使用当前用户DPAPI保护独立密钥。
use kiyori_core::{
    audit_crypto::{AuditCrypto, AuditSignature, failure},
    runtime::CoreError,
};
use std::{path::Path, sync::Arc};

#[cfg(target_os = "android")]
mod android;
#[cfg(windows)]
mod windows;

pub fn open(directory: &Path) -> Result<Arc<dyn AuditCrypto>, CoreError> {
    if !directory.is_absolute() {
        return Err(failure());
    }
    #[cfg(windows)]
    {
        let crypto = windows::WindowsAuditCrypto::open(directory)?;
        mark_initialized(directory)?;
        Ok(Arc::new(crypto))
    }
    #[cfg(target_os = "android")]
    {
        let crypto = android::open(directory.join("audit-crypto-v1.initialized").exists())?;
        mark_initialized(directory)?;
        Ok(crypto)
    }
    #[cfg(not(any(windows, target_os = "android")))]
    {
        let _ = directory;
        Ok(Arc::new(UnsupportedAuditCrypto))
    }
}
#[cfg(any(windows, target_os = "android"))]
fn mark_initialized(directory: &Path) -> Result<(), CoreError> {
    std::fs::create_dir_all(directory).map_err(|_| failure())?;
    let marker = directory.join("audit-crypto-v1.initialized");
    match std::fs::OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(marker)
    {
        Ok(file) => file.sync_all().map_err(|_| failure()),
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => Ok(()),
        Err(_) => Err(failure()),
    }
}
#[cfg(not(any(windows, target_os = "android")))]
struct UnsupportedAuditCrypto;
#[cfg(not(any(windows, target_os = "android")))]
impl AuditCrypto for UnsupportedAuditCrypto {
    fn persistent(&self) -> bool {
        false
    }
    fn protect(&self, _: &[u8]) -> Result<Vec<u8>, CoreError> {
        Err(failure())
    }
    fn unprotect(&self, _: &[u8]) -> Result<Vec<u8>, CoreError> {
        Err(failure())
    }
    fn sign(&self, _: &[u8]) -> Result<AuditSignature, CoreError> {
        Err(failure())
    }
}

/// Android宿主需要在创建Runtime前绑定已加载的类，避免worker的系统ClassLoader找不到app类。
#[cfg(target_os = "android")]
pub use android::bind;

#[cfg(test)]
mod tests;
