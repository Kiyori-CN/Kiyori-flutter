import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum TransientNoticeStatus { requested, unsupported, unavailable }

class TransientNoticeResult {
  const TransientNoticeResult(this.status, {this.reason});
  final TransientNoticeStatus status;
  final String? reason;
}

/// Android系统拥有Toast位置/样式与生命周期；requested不表示用户已看到。
class TransientNotice {
  static const channel = MethodChannel('kiyori/transient_notice');

  static Future<TransientNoticeResult> showLong(String message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const TransientNoticeResult(
        TransientNoticeStatus.unsupported,
        reason: '此平台没有Android系统Toast',
      );
    }
    try {
      final status = await channel.invokeMethod<String>('showLong', message);
      return status == 'requested'
          ? const TransientNoticeResult(TransientNoticeStatus.requested)
          : const TransientNoticeResult(
              TransientNoticeStatus.unavailable,
              reason: '系统提示宿主不可用',
            );
    } on MissingPluginException {
      return const TransientNoticeResult(
        TransientNoticeStatus.unavailable,
        reason: '系统提示适配器未接入',
      );
    } on PlatformException {
      return const TransientNoticeResult(
        TransientNoticeStatus.unavailable,
        reason: '系统提示请求失败',
      );
    }
  }
}
