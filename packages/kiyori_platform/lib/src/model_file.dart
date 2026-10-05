import 'dart:io';

import 'package:flutter/services.dart';

import 'windows_model_file.dart';

const modelFileChunkBytes = 1024 * 1024;

/// 用户单次选择的文件句柄，不将路径/URI交给UI或Rust，不保留SAF权限。
abstract interface class ModelFilePicker {
  Future<ModelFileSource?> select();
}

abstract interface class ModelFileSource {
  String get name;
  Future<Uint8List> read();
  Future<void> close();
}

class ModelFileException implements Exception {
  const ModelFileException(this.code);
  final String code;
  @override
  String toString() => 'ModelFileException($code)';
}

ModelFilePicker createModelFilePicker() => Platform.isWindows
    ? WindowsModelFilePicker()
    : const ChannelModelFilePicker();

class ChannelModelFilePicker implements ModelFilePicker {
  const ChannelModelFilePicker();
  static const channel = MethodChannel('kiyori/model_file');
  @override
  Future<ModelFileSource?> select() async {
    final result = await _call<Map<Object?, Object?>>('select');
    if (result == null) return null;
    final name = result['name'], token = result['token'];
    if (name is! String || token is! String) {
      throw const ModelFileException('io_failed');
    }
    return _ChannelModelFile(name, token);
  }
}

Future<T?> _call<T>(String method, [Map<String, Object>? args]) async {
  try {
    return await ChannelModelFilePicker.channel.invokeMethod<T>(method, args);
  } on MissingPluginException {
    throw const ModelFileException('unsupported');
  } on PlatformException catch (error) {
    const known = {
      'busy',
      'detached',
      'cancelled',
      'unsupported',
      'invalid_name',
    };
    throw ModelFileException(
      known.contains(error.code) ? error.code : 'io_failed',
    );
  } catch (_) {
    throw const ModelFileException('io_failed');
  }
}

class _ChannelModelFile implements ModelFileSource {
  _ChannelModelFile(this.name, this.token);
  @override
  final String name;
  final String token;
  bool closed = false;
  Future<void>? closing;
  @override
  Future<Uint8List> read() async {
    if (closed) throw const ModelFileException('cancelled');
    final bytes = await _call<Uint8List>('read', {'token': token});
    if (closed) throw const ModelFileException('cancelled');
    if (bytes == null || bytes.length > modelFileChunkBytes) {
      throw const ModelFileException('io_failed');
    }
    return bytes;
  }

  @override
  Future<void> close() => closing ??= _close();
  Future<void> _close() async {
    closed = true;
    await _call<void>('close', {'token': token});
  }
}
