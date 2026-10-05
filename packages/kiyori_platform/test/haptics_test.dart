import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('kiyori/haptics');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'Android handle move preserves native outcome without clock tick fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Object? outcome = true;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'textHandleMove');
        expect(call.arguments, isNull);
        calls++;
        if (outcome is PlatformException) throw outcome;
        return outcome;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        fail('Android TextHandleMove must not use Flutter CLOCK_TICK');
      });
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.requested);
      outcome = false;
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.declined);
      outcome = null; // Android API <27
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.unsupported);
      outcome = PlatformException(code: 'unavailable');
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.unavailable);
      expect(calls, 4);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.unsupported);
    },
  );

  test(
    'long press and iOS handle move use their standard platform feedback',
    () async {
      final calls = <Object?>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        expect(call.method, 'HapticFeedback.vibrate');
        calls.add(call.arguments);
        return null;
      });
      expect(await KiyoriHaptics.longPress(), HapticResult.requested);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.requested);
      expect(calls, [null, 'HapticFeedbackType.selectionClick']);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(await KiyoriHaptics.textHandleMove(), HapticResult.unsupported);
      expect(calls, hasLength(2));
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(await KiyoriHaptics.longPress(), HapticResult.unavailable);
    },
  );
}
