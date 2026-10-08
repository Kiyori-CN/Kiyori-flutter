pub mod api;
mod frb_generated;

// 在最终cdylib保留JNI入口；实现由平台crate拥有，FFI仅转交宿主绑定。
#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub extern "system" fn Java_com_kiyori_flutter_AuditCrypto_bind<'local>(
    env: jni::EnvUnowned<'local>,
    class: jni::objects::JClass<'local>,
) {
    kiyori_audit_crypto::bind(env, class);
}
