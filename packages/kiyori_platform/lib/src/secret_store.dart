import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'windows_secret_store.dart';
import 'secret_contract.dart';
import 'system_secret_store.dart';
export 'system_secret_store.dart';

Future<SecretStore> openNativeSecretStore() async {
  if (Platform.isWindows) {
    final support = await getApplicationSupportDirectory();
    return WindowsSecretStore(Directory('${support.path}/kiyori-secrets-v1'));
  }
  if (Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux) {
    return SystemSecretStore();
  }
  throw const SecretStoreException('unsupported_platform');
}
