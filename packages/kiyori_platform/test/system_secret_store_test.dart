import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    test(
      '$platform retains system storage isolation and never overwrites existing secrets',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'containsKey') return true;
          if (call.method == 'read') return 'fixture';
          return null;
        });
        try {
          final store = SystemSecretStore();
          const reference = '0123456789abcdef0123456789abcdef';
          expect(await store.read(reference), 'fixture');
          final arguments = calls.single.arguments as Map;
          expect(arguments['key'], 'kiyori_secret_$reference');
          final options = arguments['options'] as Map;
          if (platform != TargetPlatform.linux) {
            expect(options['accountName'], 'com.kiyori.secrets.v1');
            expect(options['synchronizable'], 'false');
          }
          if (platform == TargetPlatform.macOS) {
            expect(options['usesDataProtectionKeychain'], 'false');
          }
          await expectLater(
            store.writeNew(reference, 'replacement'),
            throwsA(
              isA<SecretStoreException>().having(
                (e) => e.code,
                'code',
                'already_exists',
              ),
            ),
          );
          expect(calls.any((call) => call.method == 'write'), isFalse);
          final count = calls.length;
          await expectLater(
            store.writeNew(reference, '界' * 400000),
            throwsA(
              isA<SecretStoreException>().having(
                (e) => e.code,
                'code',
                'too_large',
              ),
            ),
          );
          expect(calls.length, count);
        } finally {
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
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
      final store = SystemSecretStore();
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
