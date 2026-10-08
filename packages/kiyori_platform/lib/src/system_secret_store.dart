import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_contract.dart';

/// 系统钥匙环不可用时明确报错，不回退到明文或销毁原凭据。
class SystemSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'kiyori_flutter_secrets_v1',
      resetOnError: false,
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accountName: 'com.kiyori.flutter.secrets.v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accountName: 'com.kiyori.flutter.secrets.v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
      // 不共享凭据，避免 Keychain Sharing 引入 provisioning 依赖。
      usesDataProtectionKeychain: false,
    ),
  );
  String _key(String reference) {
    validateSecretReference(reference);
    return 'kiyori_secret_$reference';
  }

  @override
  Future<void> writeNew(String reference, String value) async {
    final key = _key(reference);
    if (utf8.encode(value).length > 1048576) {
      throw const SecretStoreException('too_large');
    }
    try {
      if (await _storage.containsKey(key: key)) {
        throw const SecretStoreException('already_exists');
      }
      await _storage.write(key: key, value: value);
    } on SecretStoreException {
      rethrow;
    } catch (_) {
      throw const SecretStoreException('write_failed');
    }
  }

  @override
  Future<String?> read(String reference) async {
    final key = _key(reference);
    try {
      return await _storage.read(key: key);
    } catch (_) {
      throw const SecretStoreException('read_failed');
    }
  }

  @override
  Future<void> delete(String reference) async {
    final key = _key(reference);
    try {
      await _storage.delete(key: key);
    } catch (_) {
      throw const SecretStoreException('delete_failed');
    }
  }
}
