//! 审计正文保护和持久签名的窄端口；核心不持有具体平台密钥句柄。
use crate::runtime::{CoreError, ErrorCode};
use base64::{Engine, engine::general_purpose::STANDARD};
use ring::{
    rand::SystemRandom,
    signature::{Ed25519KeyPair, KeyPair},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

pub const ENCRYPTED_PREFIX: &str = "kiyori-audit-encrypted-v1:";
pub const P256_SPKI_PREFIX: &[u8] = &[
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
    0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
];

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditSignature {
    pub algorithm: String,
    pub public_key: String,
    pub signature: String,
}

pub trait AuditCrypto: Send + Sync {
    fn protect(&self, plaintext: &[u8]) -> Result<Vec<u8>, CoreError>;
    fn unprotect(&self, ciphertext: &[u8]) -> Result<Vec<u8>, CoreError>;
    fn sign(&self, value: &[u8]) -> Result<AuditSignature, CoreError>;
    fn persistent(&self) -> bool;
}
pub fn verify(value: &[u8], signature: &AuditSignature) -> Result<(), CoreError> {
    use ring::signature::{ECDSA_P256_SHA256_ASN1, ED25519, UnparsedPublicKey};
    let public = STANDARD
        .decode(&signature.public_key)
        .map_err(|_| failure())?;
    let signature_bytes = STANDARD
        .decode(&signature.signature)
        .map_err(|_| failure())?;
    match signature.algorithm.as_str() {
        "SHA256withECDSA" if public.len() == 91 && public.starts_with(P256_SPKI_PREFIX) => {
            UnparsedPublicKey::new(&ECDSA_P256_SHA256_ASN1, &public[26..])
                .verify(value, &signature_bytes)
                .map_err(|_| failure())
        }
        "Ed25519" => UnparsedPublicKey::new(&ED25519, public)
            .verify(value, &signature_bytes)
            .map_err(|_| failure()),
        _ => Err(failure()),
    }
}

pub fn failure() -> CoreError {
    CoreError {
        code: ErrorCode::Storage,
        message: "审计安全存储或签名不可用；原始记录未覆盖".into(),
    }
}

/// Rust参考运行时保留历史测试合同；产品FFI必须显式装配平台实现，不在平台失败时回退。
pub(crate) struct ReferenceAuditCrypto;
impl AuditCrypto for ReferenceAuditCrypto {
    fn protect(&self, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
        Ok(bytes.to_vec())
    }
    fn unprotect(&self, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
        Ok(bytes.to_vec())
    }
    fn sign(&self, value: &[u8]) -> Result<AuditSignature, CoreError> {
        let key = Ed25519KeyPair::generate_pkcs8(&SystemRandom::new()).map_err(|_| failure())?;
        let key = Ed25519KeyPair::from_pkcs8(key.as_ref()).map_err(|_| failure())?;
        Ok(AuditSignature {
            algorithm: "Ed25519".into(),
            public_key: STANDARD.encode(key.public_key().as_ref()),
            signature: STANDARD.encode(key.sign(value).as_ref()),
        })
    }
    fn persistent(&self) -> bool {
        false
    }
}

pub(crate) fn register(
    connection: &rusqlite::Connection,
    crypto: Arc<dyn AuditCrypto>,
) -> Result<(), CoreError> {
    use rusqlite::functions::FunctionFlags;
    let protector = crypto.clone();
    connection
        .create_scalar_function(
            "kiyori_audit_protect",
            1,
            FunctionFlags::SQLITE_UTF8 | FunctionFlags::SQLITE_DIRECTONLY,
            move |ctx| {
                let text: String = ctx.get(0)?;
                let bytes = protector
                    .protect(text.as_bytes())
                    .map_err(|e| rusqlite::Error::UserFunctionError(Box::new(e)))?;
                if !protector.persistent() {
                    return String::from_utf8(bytes)
                        .map_err(|e| rusqlite::Error::UserFunctionError(Box::new(e)));
                }
                Ok(format!("{ENCRYPTED_PREFIX}{}", STANDARD.encode(bytes)))
            },
        )
        .map_err(|_| failure())?;
    connection
        .create_scalar_function(
            "kiyori_audit_unprotect",
            1,
            FunctionFlags::SQLITE_UTF8 | FunctionFlags::SQLITE_DIRECTONLY,
            move |ctx| {
                let text: String = ctx.get(0)?;
                let Some(encoded) = text.strip_prefix(ENCRYPTED_PREFIX) else {
                    return Ok(text);
                };
                let bytes = STANDARD
                    .decode(encoded)
                    .map_err(|e| rusqlite::Error::UserFunctionError(Box::new(e)))?;
                let plain = crypto
                    .unprotect(&bytes)
                    .map_err(|e| rusqlite::Error::UserFunctionError(Box::new(e)))?;
                String::from_utf8(plain)
                    .map_err(|e| rusqlite::Error::UserFunctionError(Box::new(e)))
            },
        )
        .map_err(|_| failure())
}
