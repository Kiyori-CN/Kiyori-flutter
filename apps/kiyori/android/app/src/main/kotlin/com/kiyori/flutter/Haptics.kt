package com.kiyori.flutter

import android.app.Activity
import android.os.Build
import android.view.HapticFeedbackConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** 只投影旧Compose的触觉类型，遵守系统与View设置，不申请振动权限。 */
class Haptics(activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kiyori/haptics")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "textHandleMove") {
                result.notImplemented()
            } else {
                // 沿AndroidX兼容语义：API<27没有TEXT_HANDLE_MOVE，不替换成时钟滴答。
                result.success(if (Build.VERSION.SDK_INT >= 27)
                    activity.window.decorView.performHapticFeedback(HapticFeedbackConstants.TEXT_HANDLE_MOVE)
                    else null)
            }
        }
    }
    fun close() = channel.setMethodCallHandler(null)
}
