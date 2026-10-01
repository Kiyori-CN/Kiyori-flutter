import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

class RuntimeController extends ChangeNotifier {
  RuntimeController(this._connect);
  final Future<RuntimeClient> Function() _connect;
  RuntimeClient? _client;
  RuntimeInfo? info;
  String? error;
  bool starting = true;
  bool checking = false;
  bool cancelling = false;
  TaskEvent? lastEvent;
  DiagnosticRun? _run;
  bool _disposed = false;
  Future<void>? _shutdown;

  Future<void> initialize() async {
    try {
      final client = await _connect();
      if (_disposed) {
        await client.close();
        return;
      }
      _client = client;
      final result = await client.info();
      if (!_disposed) info = result;
    } catch (failure, stack) {
      _recordError(failure, stack);
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> runCheck() async {
    final client = _client;
    if (_disposed || client == null || checking) return;
    checking = true;
    cancelling = false;
    error = null;
    lastEvent = null;
    _notify();
    try {
      final run = await client.startDiagnostic();
      _run = run;
      if (_disposed) {
        await run.cancel();
        return;
      }
      if (cancelling) await run.cancel();
      await for (final event in run.events) {
        if (!_disposed) {
          lastEvent = event;
          _notify();
        }
      }
    } catch (failure, stack) {
      _recordError(failure, stack);
    } finally {
      _run = null;
      checking = false;
      cancelling = false;
      _notify();
    }
  }

  Future<void> cancelCheck() async {
    if (!checking || cancelling) return;
    cancelling = true;
    _notify();
    try {
      await _run?.cancel();
    } catch (failure, stack) {
      _recordError(failure, stack);
      _notify();
    }
  }

  void _recordError(Object failure, StackTrace stack) {
    if (!_disposed) {
      error = switch (failure) {
        BridgeError(code: ErrorCode.invalidInput) => '检查参数无效。',
        BridgeError(code: ErrorCode.runtimeClosed) => '工作空间已关闭，请重新打开应用。',
        BridgeError(code: ErrorCode.concurrentRead) => '检查正在运行，请等待它结束。',
        _ => '无法连接应用核心，请查看本地诊断记录。',
      };
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('Kiyori runtime failure: ${failure.runtimeType}'),
        stack: stack,
        library: 'kiyori',
      ),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> shutdown() => _shutdown ??= _close();
  Future<void> _close() async {
    await _client?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      shutdown().catchError((Object failure, StackTrace stack) {
        _recordError(failure, stack);
      }),
    );
    super.dispose();
  }
}
