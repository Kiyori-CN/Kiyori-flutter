import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'model_credentials.dart';

class ModelPoolTestController extends ChangeNotifier {
  ModelPoolTestController(this.connect);
  final Future<RuntimeClient> Function() connect;
  ChatRun? _run;
  Future<void>? _flight;
  bool running = false, _disposed = false;
  int _generation = 0;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> pause() async {
    _generation++;
    await _run?.cancel();
    await _flight;
    running = false;
    _notify();
  }

  Future<void> start(
    ModelConfigDraft draft,
    ModelCredentials credentials,
    Future<void> Function(ModelPoolKey original, String availability) save,
  ) async {
    if (_disposed || running) return;
    final generation = ++_generation;
    running = true;
    error = null;
    _notify();
    final operation = _execute(generation, draft, credentials, save);
    _flight = operation;
    try {
      await operation;
    } finally {
      if (identical(_flight, operation)) _flight = null;
      if (!_disposed && generation == _generation) {
        running = false;
        _notify();
      }
    }
  }

  Future<void> _execute(
    int generation,
    ModelConfigDraft draft,
    ModelCredentials credentials,
    Future<void> Function(ModelPoolKey original, String availability) save,
  ) async {
    ChatRun? run;
    try {
      final runtime = await connect();
      if (_disposed || generation != _generation) return;
      run = await runtime.startPoolTest(
        draft,
        [
          for (final key in credentials.keys)
            PoolKey(
              id: key.id,
              key: key.key,
              enabled: key.enabled,
              availability: key.availability,
            ),
        ],
        [
          for (final h in credentials.headers.entries)
            ChatHeader(name: h.key, value: h.value),
        ],
        5,
      );
      if (_disposed || generation != _generation) {
        await run.cancel();
        await run.events.drain<void>();
        return;
      }
      _run = run;
      final originals = {for (final key in credentials.keys) key.id: key};
      await for (final event in run.events) {
        if (_disposed || generation != _generation) break;
        if (event.phase == ChatPhase.poolResult) {
          final original = originals[event.keyId];
          if (original != null) {
            await save(
              original,
              event.verified == true ? 'AVAILABLE' : 'UNAVAILABLE',
            );
          }
        } else if (event.phase == ChatPhase.failed) {
          error = event.errorMessage;
        }
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = '密钥池测试或保存失败，请检查配置后重试';
      }
    } finally {
      await run?.cancel();
      if (identical(_run, run)) _run = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_run?.cancel());
    super.dispose();
  }
}
