import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'secret_contract.dart';

// Windows SDK dpapi.h: CRYPTPROTECT_UI_FORBIDDEN，绑定包未导出该常量。
const _uiForbidden = 0x1;

/// 每个不可变引用独立保护；损坏不删除，错误不包含路径或明文。
class WindowsSecretStore implements SecretStore {
  WindowsSecretStore(this.directory);
  final Directory directory;
  String _path(String reference) {
    validateSecretReference(reference);
    return '${directory.path}/$reference.dpapi';
  }

  @override
  Future<void> writeNew(String reference, String value) async {
    final path = _path(reference);
    if (utf8.encode(value).length > 1048576) {
      throw const SecretStoreException('too_large');
    }
    await Isolate.run(() {
      try {
        final encrypted = _transform(utf8.encode(value), protect: true);
        final file = File(path);
        file.parent.createSync(recursive: true);
        file.createSync(exclusive: true);
        file.writeAsBytesSync(encrypted, flush: true);
      } on SecretStoreException {
        rethrow;
      } catch (_) {
        throw const SecretStoreException('write_failed');
      }
    });
  }

  @override
  Future<String?> read(String reference) async {
    final path = _path(reference);
    return Isolate.run(() {
      try {
        final file = File(path);
        if (!file.existsSync()) return null;
        if (file.lengthSync() > 2097152) {
          throw const SecretStoreException('too_large');
        }
        final plain = _transform(file.readAsBytesSync(), protect: false);
        try {
          return utf8.decode(plain);
        } finally {
          plain.fillRange(0, plain.length, 0);
        }
      } on SecretStoreException {
        rethrow;
      } catch (_) {
        throw const SecretStoreException('read_failed');
      }
    });
  }

  @override
  Future<void> delete(String reference) async {
    final path = _path(reference);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      throw const SecretStoreException('delete_failed');
    }
  }
}

Uint8List _transform(Uint8List bytes, {required bool protect}) {
  if (!Platform.isWindows) {
    throw const SecretStoreException('unsupported_platform');
  }
  return using((arena) {
    final input = arena<CRYPT_INTEGER_BLOB>();
    input.ref.cbData = bytes.length;
    input.ref.pbData = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    input.ref.pbData.asTypedList(bytes.length).setAll(0, bytes);
    final output = arena<CRYPT_INTEGER_BLOB>();
    try {
      final result = protect
          ? CryptProtectData(input, null, null, null, _uiForbidden, output)
          : CryptUnprotectData(input, null, null, null, _uiForbidden, output);
      if (!result.value || output.ref.pbData.address == 0) {
        throw const SecretStoreException('protection_failed');
      }
      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      input.ref.pbData.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      if (protect) bytes.fillRange(0, bytes.length, 0);
      if (output.ref.pbData.address != 0) {
        output.ref.pbData
            .asTypedList(output.ref.cbData)
            .fillRange(0, output.ref.cbData, 0);
        LocalFree(HLOCAL(output.ref.pbData.cast()));
      }
    }
  });
}
