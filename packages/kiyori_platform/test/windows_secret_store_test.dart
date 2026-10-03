import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';

void main() {
  test('DPAPI protects each reference, reopens, rejects overwrite and preserves corruption', () async {
    final dir = await Directory.systemTemp.createTemp('kiyori-vault-test-');
    const reference = '0123456789abcdef0123456789abcdef';
    const other = 'fedcba9876543210fedcba9876543210';
    const value = '仅测试的中文值-kiyori-native-fixture';
    final store = WindowsSecretStore(dir);
    try {
      await store.writeNew(reference, value);
      final file = File('${dir.path}/$reference.dpapi');
      final cipher = await file.readAsBytes();
      expect(utf8.decode(cipher, allowMalformed: true), isNot(contains(value)));
      expect(await WindowsSecretStore(dir).read(reference), value);
      await expectLater(
        store.writeNew(reference, 'overwrite'),
        throwsA(isA<SecretStoreException>()),
      );
      expect(await store.read(reference), value);
      await store.writeNew(other, '另一个测试值');
      await file.writeAsBytes([1, 2, 3, 4], flush: true);
      await expectLater(
        store.read(reference),
        throwsA(isA<SecretStoreException>()),
      );
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      expect(await store.read(other), '另一个测试值');
      await expectLater(
        store.read('../escape'),
        throwsA(isA<SecretStoreException>()),
      );
      await store.delete(other);
      expect(await store.read(other), isNull);
      await store.delete(reference);
    } finally {
      await dir.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
