package com.kiyori

import android.app.Activity
import android.widget.Toast
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** 复用Android系统Toast，不仿造系统位置或在Activity退出后继续持有提示。 */
class TransientNotice(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kiyori/transient_notice")
    private var toast: Toast? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "showLong") {
                result.notImplemented()
            } else {
                val message = call.arguments as? String
                if (message.isNullOrBlank() || message.length > 2048) {
                    result.error("invalid", "提示文字无效", null)
                } else if (activity.isFinishing || activity.isDestroyed) {
                    result.success("unavailable")
                } else {
                    toast?.cancel()
                    toast = Toast.makeText(activity, message, Toast.LENGTH_LONG).also { it.show() }
                    result.success("requested")
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        toast?.cancel()
        toast = null
    }
}
