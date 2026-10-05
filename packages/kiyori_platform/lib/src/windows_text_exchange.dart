import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'text_exchange_contract.dart';

/// COM对话框和文件I/O在独立isolate执行，UI不读取路径；不生成中间明文文件。
class WindowsTextExchange implements TextExchange {
  WindowsTextExchange({
    Future<String?> Function(bool save, String name)? select,
  }) : _select = select ?? ((save, name) => selectWindowsFile(save, name));
  final Future<String?> Function(bool save, String name) _select;
  static bool _busy = false;
  Future<T> _run<T>(Future<T> Function() action) async {
    if (_busy) throw const TextExchangeException('busy');
    _busy = true;
    try {
      return await action();
    } on TextExchangeException {
      rethrow;
    } catch (_) {
      throw const TextExchangeException('io_failed');
    } finally {
      _busy = false;
    }
  }

  @override
  Future<String?> importText() => _run(() async {
    final path = await _select(false, '');
    if (path == null) return null;
    return Isolate.run(() {
      try {
        final file = File(path).openSync();
        try {
          final bytes = file.readSync(maxTextExchangeBytes + 1);
          try {
            if (bytes.length > maxTextExchangeBytes) {
              throw const TextExchangeException('too_large');
            }
            return utf8.decode(bytes);
          } on FormatException {
            throw const TextExchangeException('invalid_utf8');
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
        } finally {
          file.closeSync();
        }
      } on TextExchangeException {
        rethrow;
      } catch (_) {
        throw const TextExchangeException('io_failed');
      }
    });
  });
  @override
  Future<bool> exportText(String text, {required String suggestedName}) =>
      _run(() async {
        validateTextExport(text, suggestedName);
        final path = await _select(true, suggestedName);
        if (path == null) return false;
        await Isolate.run(() {
          final bytes = utf8.encode(text);
          try {
            File(path).writeAsBytesSync(bytes, flush: true);
          } catch (_) {
            throw const TextExchangeException('io_failed');
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
        });
        return true;
      });
}

Future<String?> selectWindowsFile(
  bool save,
  String name, {
  String label = '文本文件',
  String pattern = '*.txt',
  String extension = 'txt',
}) {
  // 只将本应用窗口作为owner，不能把其它前台应用错误地设为模态父窗口。
  final owner = using((arena) {
    final hwnd = GetForegroundWindow();
    final process = arena<Uint32>();
    GetWindowThreadProcessId(hwnd, process);
    return process.value == GetCurrentProcessId() ? hwnd.address : 0;
  });
  return Isolate.run(() {
    final initialized = CoInitializeEx(COINIT_APARTMENTTHREADED);
    if (initialized.isError) throw const TextExchangeException('unavailable');
    try {
      return using((arena) {
        final IFileDialog dialog = save
            ? arena.com<IFileSaveDialog>(FileSaveDialog)
            : arena.com<IFileOpenDialog>(FileOpenDialog);
        dialog.setOptions(
          dialog.getOptions() |
              FOS_FORCEFILESYSTEM |
              FOS_NOCHANGEDIR |
              FOS_DONTADDTORECENT |
              (save ? FOS_OVERWRITEPROMPT : FOS_FILEMUSTEXIST),
        );
        final filter = arena<COMDLG_FILTERSPEC>();
        filter.ref.pszName = arena.pwstr(label);
        filter.ref.pszSpec = arena.pwstr(pattern);
        dialog.setFileTypes(1, filter);
        dialog.setDefaultExtension(arena.pcwstr(extension));
        if (save) dialog.setFileName(arena.pcwstr(name));
        try {
          dialog.show(owner == 0 ? null : HWND(Pointer.fromAddress(owner)));
        } on WindowsException catch (error) {
          if (error.hr.code == -2147023673) {
            return null; // HRESULT_FROM_WIN32(ERROR_CANCELLED)
          }
          throw const TextExchangeException('io_failed');
        }
        final result = dialog.getResult();
        if (result == null) throw const TextExchangeException('io_failed');
        arena.adopt(result);
        final path = result.getDisplayName(SIGDN_FILESYSPATH);
        try {
          return path.toDartString();
        } finally {
          CoTaskMemFree(path);
        }
      });
    } on TextExchangeException {
      rethrow;
    } catch (_) {
      throw const TextExchangeException('io_failed');
    } finally {
      CoUninitialize();
    }
  });
}
