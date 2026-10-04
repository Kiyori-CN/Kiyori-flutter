import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'model_credentials.dart';

/// 只投影完整成功目录。刷新失败保留旧目录，输入变化与退出撤销迟到结果。
class ModelDirectoryController extends ChangeNotifier {
  ModelDirectoryController(this.connect);
  final Future<RuntimeClient> Function() connect;
  ChatRun? _run;
  bool loading = false, _disposed = false;
  int _generation = 0;
  String? error;
  List<ModelEntry> models = const [];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> cancel() async {
    _generation++;
    loading = false;
    final run = _run;
    _run = null;
    _notify();
    await run?.cancel();
  }

  Future<bool> refresh(
    ModelConfigDraft draft,
    ModelCredentials credentials, {
    ModelConfig? config,
  }) async {
    if (loading || _disposed) return false;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    ChatRun? run;
    try {
      final runtime = await connect();
      if (_disposed || generation != _generation) return false;
      run = config != null
          ? await runtime.startConfiguredModelDirectory(
              config.id,
              config.revision,
              credentials.encode(),
            )
          : await runtime.startModelDirectory(draft, credentials.apiKey, [
              for (final h in credentials.headers.entries)
                ChatHeader(name: h.key, value: h.value),
            ]);
      if (_disposed || generation != _generation) {
        await run.cancel();
        await run.events.drain<void>();
        return false;
      }
      _run = run;
      List<ModelEntry>? received;
      var completed = false;
      await for (final event in run.events) {
        if (_disposed || generation != _generation) continue;
        if (event.phase == ChatPhase.models) received = event.models;
        if (event.phase == ChatPhase.failed) error = event.errorMessage;
        if (event.phase == ChatPhase.completed) completed = true;
      }
      if (_disposed || generation != _generation) return false;
      if (completed && received != null) {
        models = List.unmodifiable(received);
        return true;
      }
      error ??= '获取模型目录未完成，请重试';
      return false;
    } catch (_) {
      if (!_disposed && generation == _generation) error = '获取模型目录失败，请检查配置后重试';
      return false;
    } finally {
      if (identical(_run, run)) _run = null;
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    models = const [];
    super.dispose();
  }
}
