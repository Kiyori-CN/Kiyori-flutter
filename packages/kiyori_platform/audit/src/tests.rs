#[cfg(windows)]
use super::*;

#[cfg(windows)]
#[test]
fn native_keys_reopen_encrypt_authenticate_and_sign_real_store() {
    use base64::{Engine, engine::general_purpose::STANDARD};
    use ring::signature::{ECDSA_P256_SHA256_ASN1, UnparsedPublicKey};
    use serde_json::Value;
    use std::io::Read;
    let directory = std::env::temp_dir().join(format!(
        "kiyori-audit-native-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let crypto = open(&directory).unwrap();
    let plaintext = b"synthetic audit confidential body";
    let ciphertext = crypto.protect(plaintext).unwrap();
    assert_ne!(crypto.protect(plaintext).unwrap(), ciphertext);
    let signature = crypto.sign(b"hash").unwrap();
    assert_eq!(signature.algorithm, "SHA256withECDSA");
    let public = STANDARD.decode(&signature.public_key).unwrap();
    assert_eq!(public.len(), 91);
    UnparsedPublicKey::new(&ECDSA_P256_SHA256_ASN1, &public[26..])
        .verify(b"hash", &STANDARD.decode(&signature.signature).unwrap())
        .unwrap();
    drop(crypto);
    let reopened = open(&directory).unwrap();
    assert_eq!(reopened.unprotect(&ciphertext).unwrap(), plaintext);
    assert_eq!(
        reopened.sign(b"other hash").unwrap().public_key,
        signature.public_key
    );
    let mut tampered = ciphertext.clone();
    tampered[20] ^= 1;
    assert!(reopened.unprotect(&tampered).is_err());

    // schema20明文审计先用参考运行时建立，平台升级后正文读取和原链保持一致。
    let r = kiyori_core::runtime::Runtime::with_data_dir(&directory).unwrap();
    let id = r.create_conversation().unwrap();
    r.append_conversation_note(id.clone(), "migration-synthetic-secret😀".into())
        .unwrap();
    let initial: Value =
        serde_json::from_str(&r.conversation_audit(id.clone(), 0, String::new()).unwrap()).unwrap();
    r.close();
    {
        let c = rusqlite::Connection::open(directory.join("kiyori.sqlite3")).unwrap();
        c.execute_batch("DROP TABLE conversation_audit_seals; DROP TABLE conversation_audit_security; ALTER TABLE conversation_audit_events DROP COLUMN payload_characters; ALTER TABLE conversation_audit_events DROP COLUMN payload_bytes; ALTER TABLE conversation_audit_events DROP COLUMN run_id; ALTER TABLE conversation_audit_events DROP COLUMN terminal_state; PRAGMA user_version=20;").unwrap();
    }
    struct FailingCrypto(Arc<dyn AuditCrypto>);
    impl AuditCrypto for FailingCrypto {
        fn persistent(&self) -> bool {
            true
        }
        fn protect(&self, _: &[u8]) -> Result<Vec<u8>, CoreError> {
            Err(failure())
        }
        fn unprotect(&self, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
            self.0.unprotect(bytes)
        }
        fn sign(&self, bytes: &[u8]) -> Result<AuditSignature, CoreError> {
            self.0.sign(bytes)
        }
    }
    assert!(
        kiyori_core::runtime::Runtime::with_data_dir_and_audit(
            &directory,
            Arc::new(FailingCrypto(reopened.clone()))
        )
        .is_err()
    );
    {
        let c = rusqlite::Connection::open(directory.join("kiyori.sqlite3")).unwrap();
        assert_eq!(
            c.pragma_query_value(None, "user_version", |r| r.get::<_, i64>(0))
                .unwrap(),
            20
        );
        let original: String = c
            .query_row(
                "SELECT payload FROM conversation_audit_events WHERE sequence=2",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert!(original.contains("migration-synthetic-secret"));
        assert!(
            c.execute("UPDATE conversation_audit_events SET summary='tamper'", [])
                .is_err()
        );
    }
    let r = kiyori_core::runtime::Runtime::with_data_dir_and_audit(&directory, reopened).unwrap();
    let actual: Value = serde_json::from_str(
        &r.conversation_audit(id.clone(), 0, "synthetic-secret".into())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(actual["chainHead"], initial["chainHead"]);
    assert_eq!(actual["events"].as_array().unwrap().len(), 1);
    assert!(
        r.conversation_audit_payload(id.clone(), 2, 0)
            .unwrap()
            .contains("migration-synthetic-secret😀")
    );
    let zip1 = r
        .export_conversation_audit(id.clone(), "zip".into())
        .unwrap();
    let read_signature = |bytes: Vec<u8>| -> Value {
        let mut zip = zip::ZipArchive::new(std::io::Cursor::new(bytes)).unwrap();
        let mut text = String::new();
        zip.by_name("signature.json")
            .unwrap()
            .read_to_string(&mut text)
            .unwrap();
        serde_json::from_str(&text).unwrap()
    };
    let signed = read_signature(zip1);
    assert_eq!(signed["algorithm"], "SHA256withECDSA");
    {
        let c = rusqlite::Connection::open(directory.join("kiyori.sqlite3")).unwrap();
        assert!(
            c.execute("UPDATE conversation_audit_seals SET signature='{}'", [])
                .is_err()
        );
    }
    r.close();
    assert!(kiyori_core::runtime::Runtime::with_data_dir(&directory).is_err());
    let r = kiyori_core::runtime::Runtime::with_data_dir_and_audit(
        &directory,
        open(&directory).unwrap(),
    )
    .unwrap();
    assert_eq!(
        signed,
        read_signature(
            r.export_conversation_audit(id.clone(), "zip".into())
                .unwrap()
        )
    );
    r.close();
    // 损坏持久签名不能绕过真实签名核验；失败不把缓存封印替换为新签名。
    {
        let c = rusqlite::Connection::open(directory.join("kiyori.sqlite3")).unwrap();
        c.execute_batch("DROP TRIGGER conversation_audit_seal_no_update; UPDATE conversation_audit_seals SET signature='{}';").unwrap();
    }
    let r = kiyori_core::runtime::Runtime::with_data_dir_and_audit(
        &directory,
        open(&directory).unwrap(),
    )
    .unwrap();
    assert!(
        r.export_conversation_audit(id.clone(), "zip".into())
            .is_err()
    );
    r.close();
    let database = std::fs::read(directory.join("kiyori.sqlite3")).unwrap();
    assert!(
        !database
            .windows(b"migration-synthetic-secret".len())
            .any(|bytes| bytes == b"migration-synthetic-secret")
    );
    let key_path = directory.join("audit-crypto-v1.dpapi");
    std::fs::write(&key_path, b"corrupted synthetic blob").unwrap();
    assert!(open(&directory).is_err());
    assert_eq!(
        std::fs::read(&key_path).unwrap(),
        b"corrupted synthetic blob"
    );
    std::fs::remove_file(&key_path).unwrap();
    assert!(open(&directory).is_err());
    assert!(!key_path.exists());
    std::fs::remove_dir_all(directory).unwrap();
}
