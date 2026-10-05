use super::*;
use base64::{Engine, engine::general_purpose::STANDARD};
use jni::{
    EnvUnowned, JavaVM, jni_sig,
    objects::{JByteArray, JClass, JValue},
    refs::Global,
};
use std::sync::OnceLock;

static CLASS: OnceLock<Global<JClass<'static>>> = OnceLock::new();

pub fn bind<'local>(mut unowned: EnvUnowned<'local>, class: JClass<'local>) {
    unowned
        .with_env(|env| -> jni::errors::Result<()> {
            let global = env.new_global_ref(class)?;
            let _ = CLASS.set(global);
            Ok(())
        })
        .resolve::<jni::errors::ThrowRuntimeExAndDefault>();
}
pub(super) fn open(require_existing: bool) -> Result<Arc<dyn AuditCrypto>, CoreError> {
    if CLASS.get().is_none() {
        return Err(failure());
    }
    call("initializeKeys", &[u8::from(require_existing)])?;
    Ok(Arc::new(AndroidAuditCrypto))
}
struct AndroidAuditCrypto;
fn call(method: &str, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
    let class = CLASS.get().ok_or_else(failure)?;
    JavaVM::singleton()
        .map_err(|_| failure())?
        .attach_current_thread(|env| -> jni::errors::Result<Vec<u8>> {
            let result = (|| {
                let input = env.byte_array_from_slice(bytes)?;
                let object = env
                    .call_static_method(
                        &**class,
                        jni::strings::JNIString::from(method),
                        jni_sig!("([B)[B"),
                        &[JValue::Object(input.as_ref())],
                    )?
                    .l()?;
                let array = JByteArray::cast_local(env, object)?;
                env.convert_byte_array(&array)
            })();
            // 清除本次Java异常，不回显平台日志/密钥信息，也不毒化下一个worker调用。
            if result.is_err() {
                env.exception_clear();
            }
            result
        })
        .map_err(|_| failure())
}
impl AuditCrypto for AndroidAuditCrypto {
    fn persistent(&self) -> bool {
        true
    }
    fn protect(&self, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
        call("protect", bytes)
    }
    fn unprotect(&self, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
        call("unprotect", bytes)
    }
    fn sign(&self, value: &[u8]) -> Result<AuditSignature, CoreError> {
        let signature = call("sign", value)?;
        let public = call("publicKey", &[])?;
        Ok(AuditSignature {
            algorithm: "SHA256withECDSA".into(),
            public_key: STANDARD.encode(public),
            signature: STANDARD.encode(signature),
        })
    }
}
