import 'dart:async';

import 'generated/api.dart' as api;
import 'generated/frb_generated.dart';

/// Presentation-facing contract; the native runtime remains the state owner.
abstract interface class RuntimeClient {
  Future<api.RuntimeInfo> info();
  Future<DiagnosticRun> startDiagnostic({int steps = 20, int intervalMs = 100});
  Future<void> close();
}

abstract interface class DiagnosticRun {
  Stream<api.TaskEvent> get events;
  Future<void> cancel();
}

final class NativeRuntimeClient implements RuntimeClient {
  NativeRuntimeClient._(this._handle);

  static Future<void>? _initialization;
  final api.RuntimeHandle _handle;
  final Set<_NativeDiagnosticRun> _runs = {};
  Future<void>? _closing;

  static Future<NativeRuntimeClient> open() async {
    await (_initialization ??= RustLib.init());
    return NativeRuntimeClient._(await api.createRuntime());
  }

  void _ensureOpen() {
    if (_closing != null) {
      throw const api.BridgeError(
        code: api.ErrorCode.runtimeClosed,
        message: 'The runtime has been closed.',
      );
    }
  }

  @override
  Future<api.RuntimeInfo> info() {
    _ensureOpen();
    return _handle.info();
  }

  @override
  Future<DiagnosticRun> startDiagnostic({
    int steps = 20,
    int intervalMs = 100,
  }) async {
    _ensureOpen();
    final handle = await _handle.startDiagnostic(
      steps: steps,
      intervalMs: intervalMs,
    );
    // close() can race the FFI result; never expose an orphaned task to the UI.
    if (_closing != null) {
      await handle.cancel();
      handle.dispose();
      _ensureOpen();
    }
    late final _NativeDiagnosticRun run;
    run = _NativeDiagnosticRun(handle, () => _runs.remove(run));
    _runs.add(run);
    return run;
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    await _handle.close();
    await Future.wait(_runs.toList().map((run) => run.stop()));
    _handle.dispose();
  }
}

final class _NativeDiagnosticRun implements DiagnosticRun {
  _NativeDiagnosticRun(this._handle, this._onDone) {
    _controller = StreamController<api.TaskEvent>(
      onListen: () {
        _pumping = _pump();
      },
      onPause: () {
        _resume ??= Completer<void>();
      },
      onResume: _wake,
      onCancel: stop,
    );
  }

  final api.TaskHandle _handle;
  final void Function() _onDone;
  late final StreamController<api.TaskEvent> _controller;
  Completer<void>? _resume;
  Future<void>? _pumping;
  Future<void>? _cancellation;
  bool _stopped = false;
  bool _disposed = false;

  @override
  Stream<api.TaskEvent> get events => _controller.stream;

  void _wake() {
    _resume?.complete();
    _resume = null;
  }

  @override
  Future<void> cancel() async {
    if (_disposed) return;
    await (_cancellation ??= _handle.cancel());
    _wake();
  }

  Future<void> stop() async {
    _stopped = true;
    await cancel();
    _wake();
    if (_pumping == null) {
      unawaited(_controller.close());
    }
    await _pumping;
    _dispose();
  }

  Future<void> _pump() async {
    try {
      while (!_stopped) {
        if (_resume case final resume?) await resume.future;
        if (_stopped) {
          break;
        }
        final event = await _handle.nextEvent();
        if (event == null || _stopped) break;
        _controller.add(event);
        if (event.phase == api.TaskPhase.completed ||
            event.phase == api.TaskPhase.cancelled) {
          break;
        }
      }
    } catch (error, stack) {
      if (!_stopped) _controller.addError(error, stack);
    } finally {
      // Do not await close: stream cancellation may itself be awaiting this pump.
      unawaited(_controller.close());
      await _cancellation;
      _dispose();
    }
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _handle.dispose();
    _onDone();
  }
}
