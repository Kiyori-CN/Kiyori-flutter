import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HapticResult { requested, declined, unsupported, unavailable }

/// 旧Compose的TextHandleMove不是Flutter selectionClick(Android CLOCK_TICK)。
/// 平台拒绝/不支持仅返回事实，不强制打开用户的系统触觉设置。
abstract final class KiyoriHaptics {
  static const _channel = MethodChannel('kiyori/haptics');

  static Future<HapticResult> longPress() async {
    try {
      await HapticFeedback.vibrate();
      return HapticResult.requested;
    } on MissingPluginException {
      return HapticResult.unsupported;
    } on PlatformException {
      return HapticResult.unavailable;
    }
  }

  static Future<HapticResult> textHandleMove() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _channel.invokeMethod<bool>('textHandleMove');
        return result == null
            ? HapticResult.unsupported
            : result
            ? HapticResult.requested
            : HapticResult.declined;
      } on MissingPluginException {
        return HapticResult.unsupported;
      } on PlatformException {
        return HapticResult.unavailable;
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await HapticFeedback.selectionClick();
        return HapticResult.requested;
      } on MissingPluginException {
        return HapticResult.unsupported;
      } on PlatformException {
        return HapticResult.unavailable;
      }
    }
    return HapticResult.unsupported;
  }
}
