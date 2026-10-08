package com.kiyori.flutter

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** 只持有Android系统密钥；事件、正文和所有业务事务仍归Rust。 */
object AuditCrypto {
    private const val payloadAlias = "kiyori_conversation_audit_payload_v1"
    private const val signingAlias = "kiyori_conversation_audit_signing_v1"
    private const val storeName = "AndroidKeyStore"
    private fun store() = KeyStore.getInstance(storeName).apply { load(null) }
    @JvmStatic private external fun bind()
    fun initialize() {
        System.loadLibrary("kiyori_ffi")
        bind()
    }
    @Synchronized private fun payload(create: Boolean): SecretKey {
        val existing = store().getKey(payloadAlias, null)
        if (existing != null) return existing as SecretKey
        check(create) { "Audit payload key unavailable" }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, storeName)
        generator.init(KeyGenParameterSpec.Builder(payloadAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true).setKeySize(256).build())
        return generator.generateKey()
    }
    @Synchronized private fun signing(create: Boolean = false): KeyStore.PrivateKeyEntry {
        (store().getEntry(signingAlias, null) as? KeyStore.PrivateKeyEntry)?.let { return it }
        check(create) { "Audit signing key unavailable" }
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, storeName)
        generator.initialize(KeyGenParameterSpec.Builder(signingAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1")).setDigests(KeyProperties.DIGEST_SHA256).build())
        generator.generateKeyPair()
        return store().getEntry(signingAlias, null) as KeyStore.PrivateKeyEntry
    }
    @JvmStatic @Synchronized fun initializeKeys(flags: ByteArray): ByteArray {
        val create = flags.single().toInt() == 0
        payload(create)
        signing(create)
        return byteArrayOf()
    }
    @JvmStatic fun protect(bytes: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, payload(false))
        check(cipher.iv.size == 12)
        return cipher.iv + cipher.doFinal(bytes)
    }
    @JvmStatic fun unprotect(bytes: ByteArray): ByteArray {
        require(bytes.size >= 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, payload(false), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return cipher.doFinal(bytes, 12, bytes.size - 12)
    }
    @JvmStatic fun sign(bytes: ByteArray): ByteArray = Signature.getInstance("SHA256withECDSA").run {
        initSign(signing().privateKey)
        update(bytes)
        sign()
    }
    @JvmStatic fun publicKey(unused: ByteArray): ByteArray = signing().certificate.publicKey.encoded
}
