import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(TransientNotice.channel, null);
  });

  test('Android uses exact system long Toast request and exposes unavailable status', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TransientNotice.channel, (call) async {
      calls.add(call);
      return calls.length == 1 ? 'requested' : 'unavailable';
    });
    const message = '分组已创建。当前聊天已从其他入口切换，已保留你的新选择。';
    expect(
      (await TransientNotice.showLong(message)).status,
      TransientNoticeStatus.requested,
    );
    expect(calls.single.method, 'showLong');
    expect(calls.single.arguments, message);
    final unavailable = await TransientNotice.showLong(message);
    expect(unavailable.status, TransientNoticeStatus.unavailable);
    expect(unavailable.reason, isNotEmpty);
  });

  test(
    'desktop does not invoke Android and missing adapter is observable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      var invoked = false;
      messenger.setMockMethodCallHandler(TransientNotice.channel, (call) async {
        invoked = true;
        throw PlatformException(code: 'unavailable');
      });
      expect(
        (await TransientNotice.showLong('提示')).status,
        TransientNoticeStatus.unsupported,
      );
      expect(invoked, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect((await TransientNotice.showLong('提示')).reason, '系统提示请求失败');
      messenger.setMockMethodCallHandler(TransientNotice.channel, null);
      expect((await TransientNotice.showLong('提示')).reason, '系统提示适配器未接入');
    },
  );
}
