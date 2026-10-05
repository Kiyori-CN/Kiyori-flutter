import 'dart:io';
import 'dart:typed_data';

import 'model_file.dart';
import 'windows_text_exchange.dart';

class WindowsModelFilePicker implements ModelFilePicker {
  WindowsModelFilePicker({Future<String?> Function()? select})
    : _select =
          select ??
          (() => selectWindowsFile(
            false,
            '',
            label: 'GGUF 模型',
            pattern: '*.gguf',
            extension: 'gguf',
          ));
  final Future<String?> Function() _select;
  static bool busy = false;
  @override
  Future<ModelFileSource?> select() async {
    if (busy) throw const ModelFileException('busy');
    busy = true;
    try {
      final path = await _select();
      if (path == null) {
        busy = false;
        return null;
      }
      final name = path.replaceAll('\\', '/').split('/').last;
      if (!name.toLowerCase().endsWith('.gguf')) {
        throw const ModelFileException('invalid_name');
      }
      final source = _WindowsModelFile(name, await File(path).open());
      source.onClose = () => busy = false;
      return source;
    } on ModelFileException {
      busy = false;
      rethrow;
    } catch (_) {
      busy = false;
      throw const ModelFileException('io_failed');
    }
  }
}

class _WindowsModelFile implements ModelFileSource {
  _WindowsModelFile(this.name, this.file);
  @override
  final String name;
  final RandomAccessFile file;
  void Function()? onClose;
  bool closed = false, reading = false;
  Future<Uint8List>? flight;
  Future<void>? closing;
  @override
  Future<Uint8List> read() async {
    if (closed) throw const ModelFileException('cancelled');
    if (reading) throw const ModelFileException('busy');
    reading = true;
    try {
      flight = file.read(modelFileChunkBytes);
      final bytes = await flight!;
      if (closed) throw const ModelFileException('cancelled');
      return bytes;
    } on ModelFileException {
      rethrow;
    } catch (_) {
      throw const ModelFileException('io_failed');
    } finally {
      reading = false;
      flight = null;
    }
  }

  @override
  Future<void> close() => closing ??= _close();
  Future<void> _close() async {
    closed = true;
    try {
      // Windows普通文件异步读取先结算再释放；不会复制整个模型到内存。
      try {
        await flight;
      } catch (_) {
        /* 原读取错误由read报告。 */
      }
      await file.close();
    } catch (_) {
      throw const ModelFileException('io_failed');
    } finally {
      onClose?.call();
    }
  }
}
