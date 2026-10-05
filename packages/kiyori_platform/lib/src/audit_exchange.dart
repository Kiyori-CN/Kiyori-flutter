import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'text_exchange_contract.dart';
import 'windows_text_exchange.dart';

/// 用户选择目标后的单次二进制导出；不保存路径或持久权限。
abstract interface class AuditExchange {
  Future<bool> save(
    Uint8List bytes, {
    required String name,
    required String mime,
  });
}

class PlatformAuditExchange implements AuditExchange {
  PlatformAuditExchange({
    Future<String?> Function(String name, String mime)? select,
    bool? windows,
  }) : _select = select ?? _choose,
       _windows = windows ?? Platform.isWindows;
  final Future<String?> Function(String name, String mime) _select;
  final bool _windows;
  static Future<String?> _choose(String name, String mime) {
    final zip = mime == 'application/zip';
    return selectWindowsFile(
      true,
      name,
      label: zip ? 'ZIP审计包' : 'Markdown诊断',
      pattern: zip ? '*.zip' : '*.md',
      extension: zip ? 'zip' : 'md',
    );
  }

  static bool _busy = false;
  @override
  Future<bool> save(
    Uint8List bytes, {
    required String name,
    required String mime,
  }) async {
    if (_busy) throw const TextExchangeException('busy');
    if (name.isEmpty ||
        name.contains(RegExp(r'[\\/:\x00]')) ||
        !{'application/zip', 'text/markdown'}.contains(mime)) {
      throw const TextExchangeException('invalid_name');
    }
    if (bytes.length > 64 * 1024 * 1024) {
      throw const TextExchangeException('too_large');
    }
    _busy = true;
    try {
      if (_windows) {
        final path = await _select(name, mime);
        if (path == null) return false;
        await Isolate.run(
          () => File(path).writeAsBytesSync(bytes, flush: true),
        );
        return true;
      }
      return await const MethodChannel('kiyori/text_exchange')
              .invokeMethod<bool>('exportAudit', {
                'bytes': bytes,
                'suggestedName': name,
                'mime': mime,
              }) ??
          false;
    } on MissingPluginException {
      throw const TextExchangeException('unsupported');
    } on PlatformException catch (error) {
      const known = {
        'busy',
        'detached',
        'cancelled',
        'too_large',
        'invalid_name',
        'unsupported',
      };
      throw TextExchangeException(
        known.contains(error.code) ? error.code : 'io_failed',
      );
    } on TextExchangeException {
      rethrow;
    } catch (_) {
      throw const TextExchangeException('io_failed');
    } finally {
      _busy = false;
    }
  }
}
