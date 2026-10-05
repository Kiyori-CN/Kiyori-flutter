package com.kiyori

import android.app.Activity
import android.content.Intent
import android.os.CancellationSignal
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

/** 仅用户本次SAF授权，分片读取；Rust拥有校验/持久化，不保存URI权限或返回路径。 */
class ModelFile(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kiyori/model_file")
    private val worker = Executors.newFixedThreadPool(2)
    private val stream = AtomicReference<InputStream?>()
    private var signal = CancellationSignal()
    private var pending: MethodChannel.Result? = null
    @Volatile private var token: String? = null
    @Volatile private var detached = false
    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (detached) { result.error("detached", null, null); return }
        when (call.method) {
            "select" -> {
                if (pending != null || token != null) { result.error("busy", null, null); return }
                pending = result
                signal = CancellationSignal()
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }, OPEN)
                } catch (_: Exception) { complete(error = "unsupported") }
            }
            "read" -> {
                val id = call.argument<String>("token")
                if (id == null || id != token) { result.error("cancelled", null, null); return }
                if (pending != null) { result.error("busy", null, null); return }
                pending = result
                val source = stream.get()
                worker.execute {
                    var value: ByteArray? = null
                    var error: String? = null
                    try {
                        val bytes = ByteArray(LIMIT)
                        val size = requireNotNull(source).read(bytes)
                        value = if (size < 0) ByteArray(0) else bytes.copyOf(size)
                    } catch (_: Exception) { error = "io_failed" }
                    activity.runOnUiThread {
                        if (!detached && token == id) complete(value, error)
                    }
                }
            }
            "close" -> {
                if (call.argument<String>("token") == token) release {
                    activity.runOnUiThread { result.success(null) }
                } else result.success(null)
            }
            else -> result.notImplemented()
        }
    }
    fun onResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != OPEN) return false
        if (pending == null) return true
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) { complete(); return true }
        val id = UUID.randomUUID().toString()
        token = id
        val selectionSignal = signal
        worker.execute {
            var value: Any? = null
            var error: String? = null
            try {
                val name = activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null, selectionSignal).use { cursor ->
                    if (cursor != null && cursor.moveToFirst()) cursor.getString(0) else null
                }
                if (name == null || !name.lowercase().endsWith(".gguf") || name.any { it in "/\\:\u0000" }) {
                    error = "invalid_name"
                } else {
                    val descriptor = activity.contentResolver.openAssetFileDescriptor(uri, "r", selectionSignal)
                    val source = try { requireNotNull(descriptor).createInputStream() }
                    catch (failure: Exception) { descriptor?.close(); throw failure }
                    if (detached || selectionSignal.isCanceled || token != id) source.close()
                    else {
                        if (!stream.compareAndSet(null, source)) source.close()
                        else if (detached || selectionSignal.isCanceled || token != id) {
                            if (stream.compareAndSet(source, null)) source.close()
                        } else value = mapOf("name" to name, "token" to id)
                    }
                }
            } catch (_: Exception) { error = "io_failed" }
            activity.runOnUiThread {
                if (!detached && token == id) {
                    if (error != null || value == null) token = null
                    complete(value, error ?: if (value == null) "cancelled" else null)
                }
            }
        }
        return true
    }
    private fun complete(value: Any? = null, error: String? = null) {
        val result = pending
        pending = null
        if (error == null) result?.success(value) else result?.error(error, null, null)
    }
    private fun release(after: () -> Unit = {}) {
        token = null
        complete(error = "cancelled")
        val oldSignal = signal
        val oldStream = stream.getAndSet(null)
        worker.execute {
            try { oldSignal.cancel() } catch (_: Exception) { /* 不输出URI。 */ }
            try { oldStream?.close() } catch (_: Exception) { /* 结果已标记取消。 */ }
            after()
        }
    }
    fun close() {
        detached = true
        channel.setMethodCallHandler(null)
        release()
        worker.shutdown()
    }
    private companion object { const val OPEN = 42033; const val LIMIT = 1048576 }
}
