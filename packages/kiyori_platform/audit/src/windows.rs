use super::*;
use base64::{Engine, engine::general_purpose::STANDARD};
use ring::{
    aead,
    rand::{SecureRandom, SystemRandom},
    signature::{ECDSA_P256_SHA256_ASN1_SIGNING, EcdsaKeyPair, KeyPair},
};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    ptr,
};
use windows_sys::Win32::{
    Foundation::LocalFree,
    Security::Cryptography::{
        CRYPT_INTEGER_BLOB, CRYPTPROTECT_UI_FORBIDDEN, CryptProtectData, CryptUnprotectData,
    },
};

pub(super) struct WindowsAuditCrypto {
    key: aead::LessSafeKey,
    signer: EcdsaKeyPair,
}

fn transform(bytes: &[u8], protect: bool) -> Result<Vec<u8>, CoreError> {
    if bytes.len() > 1024 * 1024 {
        return Err(failure());
    }
    let input = CRYPT_INTEGER_BLOB {
        cbData: bytes.len() as u32,
        pbData: bytes.as_ptr().cast_mut(),
    };
    let mut output = CRYPT_INTEGER_BLOB {
        cbData: 0,
        pbData: ptr::null_mut(),
    };
    // Windows分配output，复制后用LocalFree释放；不使用机器级保护或交互式提示。
    unsafe {
        let ok = if protect {
            CryptProtectData(
                &input,
                ptr::null(),
                ptr::null(),
                ptr::null(),
                ptr::null(),
                CRYPTPROTECT_UI_FORBIDDEN,
                &mut output,
            )
        } else {
            CryptUnprotectData(
                &input,
                ptr::null_mut(),
                ptr::null(),
                ptr::null(),
                ptr::null(),
                CRYPTPROTECT_UI_FORBIDDEN,
                &mut output,
            )
        };
        if ok == 0 || output.pbData.is_null() {
            return Err(failure());
        }
        let memory = std::slice::from_raw_parts_mut(output.pbData, output.cbData as usize);
        let result = memory.to_vec();
        memory.fill(0);
        LocalFree(output.pbData.cast());
        Ok(result)
    }
}

impl WindowsAuditCrypto {
    pub(super) fn open(directory: &Path) -> Result<Self, CoreError> {
        std::fs::create_dir_all(directory).map_err(|_| failure())?;
        let lock = OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .read(true)
            .open(directory.join("audit-crypto.lock"))
            .map_err(|_| failure())?;
        lock.lock().map_err(|_| failure())?;
        let path = directory.join("audit-crypto-v1.dpapi");
        let rng = SystemRandom::new();
        let mut plain = match File::open(&path) {
            Ok(file) => {
                let mut bytes = Vec::new();
                file.take(65537)
                    .read_to_end(&mut bytes)
                    .map_err(|_| failure())?;
                if bytes.len() > 65536 {
                    return Err(failure());
                }
                transform(&bytes, false)?
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                if directory.join("audit-crypto-v1.initialized").exists() {
                    return Err(failure());
                }
                // 固定私钥从不明文落盘；损坏或解密失败不能新建替换原身份。
                let pkcs8 = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &rng)
                    .map_err(|_| failure())?;
                let mut plain = vec![0u8; 32];
                rng.fill(&mut plain).map_err(|_| failure())?;
                plain.extend_from_slice(pkcs8.as_ref());
                let encrypted = transform(&plain, true)?;
                // 同目录临时文件+rename避免写入中断把最终密钥变成半文件。
                let temp = directory.join("audit-crypto-v1.pending");
                let mut output = OpenOptions::new()
                    .create(true)
                    .truncate(true)
                    .write(true)
                    .open(&temp)
                    .map_err(|_| failure())?;
                output.write_all(&encrypted).map_err(|_| failure())?;
                output.sync_all().map_err(|_| failure())?;
                drop(output);
                std::fs::rename(temp, path).map_err(|_| failure())?;
                plain
            }
            Err(_) => return Err(failure()),
        };
        let result = (|| {
            if plain.len() < 33 {
                return Err(failure());
            }
            let key =
                aead::UnboundKey::new(&aead::AES_256_GCM, &plain[..32]).map_err(|_| failure())?;
            let signer =
                EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &plain[32..], &rng)
                    .map_err(|_| failure())?;
            Ok(Self {
                key: aead::LessSafeKey::new(key),
                signer,
            })
        })();
        plain.fill(0);
        result
    }
}
impl AuditCrypto for WindowsAuditCrypto {
    fn persistent(&self) -> bool {
        true
    }
    fn protect(&self, plaintext: &[u8]) -> Result<Vec<u8>, CoreError> {
        let mut nonce = [0u8; 12];
        SystemRandom::new()
            .fill(&mut nonce)
            .map_err(|_| failure())?;
        let mut bytes = plaintext.to_vec();
        self.key
            .seal_in_place_append_tag(
                aead::Nonce::assume_unique_for_key(nonce),
                aead::Aad::empty(),
                &mut bytes,
            )
            .map_err(|_| failure())?;
        let mut result = nonce.to_vec();
        result.extend_from_slice(&bytes);
        Ok(result)
    }
    fn unprotect(&self, ciphertext: &[u8]) -> Result<Vec<u8>, CoreError> {
        if ciphertext.len() < 28 {
            return Err(failure());
        }
        let nonce: [u8; 12] = ciphertext[..12].try_into().map_err(|_| failure())?;
        let mut bytes = ciphertext[12..].to_vec();
        let plain = self
            .key
            .open_in_place(
                aead::Nonce::assume_unique_for_key(nonce),
                aead::Aad::empty(),
                &mut bytes,
            )
            .map_err(|_| failure())?;
        let result = plain.to_vec();
        bytes.fill(0);
        Ok(result)
    }
    fn sign(&self, value: &[u8]) -> Result<AuditSignature, CoreError> {
        let signature = self
            .signer
            .sign(&SystemRandom::new(), value)
            .map_err(|_| failure())?;
        // P-256未压缩点转X.509 SubjectPublicKeyInfo，匹配Android publicKey.encoded。
        let mut key = vec![
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06,
            0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
        ];
        key.extend_from_slice(self.signer.public_key().as_ref());
        Ok(AuditSignature {
            algorithm: "SHA256withECDSA".into(),
            public_key: STANDARD.encode(key),
            signature: STANDARD.encode(signature.as_ref()),
        })
    }
}
