package com.kiyori.flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import java.io.Closeable

/** 单次SAF读写；不保留URI授权、不复制到缓存、不将内容写入日志。 */
class TextExchange(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kiyori/text_exchange")
    // 第二个线程仅用于关闭正在等待provider的I/O，避免清理排在阻塞读取后面。
    private val worker = Executors.newFixedThreadPool(2)
    private val activeIo = AtomicReference<Closeable?>()
    private var signal = CancellationSignal()
    private var pending: MethodChannel.Result? = null
    private var export: ByteArray? = null
    @Volatile private var detached = false

    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in listOf("importText", "exportText", "exportAudit")) { result.notImplemented(); return }
        if (detached) { result.error("detached", null, null); return }
        if (pending != null) { result.error("busy", null, null); return }
        val audit = call.method == "exportAudit"
        val save = call.method != "importText"
        val name = call.argument<String>("suggestedName") ?: "text.txt"
        if (save && (name.isEmpty() || name.any { it in "/\\:\u0000" })) {
            result.error("invalid_name", null, null); return
        }
        val mime = if (audit) call.argument<String>("mime") else "text/plain"
        if (audit && mime !in listOf("application/zip", "text/markdown")) {
            result.error("invalid_name", null, null); return
        }
        val bytes = if (audit) call.argument<ByteArray>("bytes") else if (save) call.argument<String>("text")?.toByteArray(Charsets.UTF_8) else null
        if (save && bytes == null) { result.error("io_failed", null, null); return }
        if (bytes != null && bytes.size > if (audit) 64 * LIMIT else LIMIT) { bytes.fill(0); result.error("too_large", null, null); return }
        pending = result
        signal = CancellationSignal()
        export = bytes
        val intent = Intent(if (save) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (save) mime else "text/*"
            if (save) putExtra(Intent.EXTRA_TITLE, name)
        }
        try { activity.startActivityForResult(intent, if (save) SAVE else OPEN) }
        catch (_: Exception) { finish(error = "unavailable") }
    }

    fun onResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != OPEN && request != SAVE) return false
        if (pending == null) return true
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) {
            finish(value = if (request == SAVE) false else null)
            return true
        }
        val bytes = export
        export = null
        worker.execute {
            var value: Any? = null
            var error: String? = null
            try {
                if (detached) throw ExchangeFailure("detached")
                if (request == OPEN) value = read(uri)
                else {
                    requireNotNull(bytes)
                    activity.contentResolver.openAssetFileDescriptor(uri, "wt", signal).use { descriptor ->
                        requireNotNull(descriptor).createOutputStream().use { stream ->
                            activeIo.set(stream)
                            if (detached) throw ExchangeFailure("detached")
                            stream.write(bytes)
                            stream.flush()
                        }
                    }
                    value = true
                }
            } catch (e: ExchangeFailure) { error = e.reason }
            catch (_: Exception) { error = "io_failed" }
            finally { activeIo.set(null); bytes?.fill(0) }
            activity.runOnUiThread { if (!detached) finish(value, error) }
        }
        return true
    }

    private fun read(uri: Uri): String {
        return activity.contentResolver.openAssetFileDescriptor(uri, "r", signal).use { descriptor ->
          requireNotNull(descriptor).createInputStream().use { stream ->
            activeIo.set(stream)
            val bytes = ByteArray(LIMIT + 1)
            try {
                var size = 0
                while (true) {
                    if (detached) throw ExchangeFailure("detached")
                    val count = stream.read(bytes, size, minOf(8192, bytes.size - size))
                    if (count < 0) break
                    size += count
                    if (size > LIMIT) throw ExchangeFailure("too_large")
                }
                try {
                    Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes, 0, size)).toString()
                } catch (_: java.nio.charset.CharacterCodingException) { throw ExchangeFailure("invalid_utf8") }
            } finally { bytes.fill(0) }
          }
        }
    }
    private fun finish(value: Any? = null, error: String? = null) {
        val result = pending
        pending = null
        export?.fill(0)
        export = null
        if (error == null) result?.success(value) else result?.error(error, null, null)
    }
    fun close() {
        detached = true
        channel.setMethodCallHandler(null)
        finish(error = "detached")
        worker.execute {
            try { signal.cancel() } catch (_: Exception) { /* 原异常可能含URI，禁止输出。 */ }
            try { activeIo.getAndSet(null)?.close() } catch (_: Exception) { /* 尽力释放，结果已是detached。 */ }
        }
        worker.shutdown()
    }
    private class ExchangeFailure(val reason: String) : Exception()
    private companion object { const val OPEN = 42031; const val SAVE = 42032; const val LIMIT = 1048576 }
}
