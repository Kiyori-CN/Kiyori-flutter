import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'windows_secret_store.dart';
import 'secret_contract.dart';

Future<SecretStore> openNativeSecretStore() async {
  if (Platform.isWindows) {
    final support = await getApplicationSupportDirectory();
    return WindowsSecretStore(Directory('${support.path}/kiyori-secrets-v1'));
  }
  if (Platform.isAndroid || Platform.isIOS) return MobileSecretStore();
  throw const SecretStoreException('unsupported_platform');
}

class MobileSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'kiyori_secrets_v1',
      resetOnError: false,
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accountName: 'com.kiyori.secrets.v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  String _key(String reference) {
    validateSecretReference(reference);
    return 'kiyori_secret_$reference';
  }

  @override
  Future<void> writeNew(String reference, String value) async {
    final key = _key(reference);
    if (value.length > 1048576) throw const SecretStoreException('too_large');
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
