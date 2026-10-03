import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  test('mobile uses isolated storage without destructive recovery and redacts native errors', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'containsKey') return false;
          if (call.method == 'write') return null;
          throw PlatformException(
            code: 'native',
            message: 'private-fixture-content',
          );
        });
    try {
      final store = MobileSecretStore();
      const reference = '0123456789abcdef0123456789abcdef';
      await store.writeNew(reference, 'fixture');
      final options = (calls.last.arguments as Map)['options'] as Map;
      expect(options['resetOnError'], 'false');
      expect(options['storageNamespace'], 'kiyori_secrets_v1');
      expect(options['migrateWithBackup'], 'true');
      await expectLater(
        store.read(reference),
        throwsA(
          isA<SecretStoreException>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('private-fixture-content')),
          ),
        ),
      );
      expect(
        calls.any((c) => c.method == 'deleteAll' || c.method == 'delete'),
        isFalse,
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
