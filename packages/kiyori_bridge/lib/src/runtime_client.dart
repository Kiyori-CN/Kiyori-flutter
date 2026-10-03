import 'dart:async';

import 'generated/api.dart' as api;
import 'generated/frb_generated.dart';

/// Presentation-facing contract; the native runtime remains the state owner.
abstract interface class RuntimeClient {
  Future<api.RuntimeInfo> info();
  Future<DiagnosticRun> startDiagnostic({int steps = 20, int intervalMs = 100});
  Future<void> close();
  Future<api.KnowledgeSnapshot> knowledgeSnapshot();
  Future<api.KnowledgeSnapshot> queryKnowledge(api.MemoryQuery query);
  Future<api.MemoryRecord?> getMemory(String space, String id);
  Future<String> saveKnowledgeSpace(String? id, String name);
  Future<void> selectKnowledgeSpace(String id);
  Future<bool> deleteKnowledgeSpace(String id);
  Future<void> createKnowledgeFolder(String space, String path);
  Future<void> renameKnowledgeFolder(String space, String old, String path);
  Future<void> deleteKnowledgeFolder(String space, String path);
  Future<String> saveMemory(String space, String? id, api.MemoryDraft draft);
  Future<void> archiveMemory(String space, String id, bool archived);
  Future<bool> deleteMemory(String space, String id);
  Future<List<api.WorkflowRecord>> listWorkflows();
  Future<api.WorkflowRecord> createWorkflow(String name, String description);
  Future<bool> deleteWorkflow(String id);
  Future<int> deleteWorkflows(List<String> ids);
  Future<api.WorkflowRecord> updateWorkflow({
    required String id,
    required String name,
    required String description,
    required bool enabled,
  });
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

  static Future<NativeRuntimeClient> open({String? dataDirectory}) async {
    await (_initialization ??= RustLib.init());
    final handle = dataDirectory == null
        ? await api.createRuntime()
        : await api.createRuntimeWithDataDir(dataDir: dataDirectory);
    return NativeRuntimeClient._(handle);
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
  Future<api.KnowledgeSnapshot> knowledgeSnapshot() {
    _ensureOpen();
    return _handle.knowledgeSnapshot();
  }

  @override
  Future<api.KnowledgeSnapshot> queryKnowledge(api.MemoryQuery query) {
    _ensureOpen();
    return _handle.queryKnowledge(query: query);
  }

  @override
  Future<api.MemoryRecord?> getMemory(String space, String id) {
    _ensureOpen();
    return _handle.getMemory(space: space, id: id);
  }

  @override
  Future<void> renameKnowledgeFolder(String space, String old, String path) {
    _ensureOpen();
    return _handle.renameKnowledgeFolder(space: space, old: old, new_: path);
  }

  @override
  Future<void> deleteKnowledgeFolder(String space, String path) {
    _ensureOpen();
    return _handle.deleteKnowledgeFolder(space: space, path: path);
  }

  @override
  Future<String> saveKnowledgeSpace(String? id, String name) {
    _ensureOpen();
    return _handle.saveKnowledgeSpace(id: id, name: name);
  }

  @override
  Future<void> selectKnowledgeSpace(String id) {
    _ensureOpen();
    return _handle.selectKnowledgeSpace(id: id);
  }

  @override
  Future<bool> deleteKnowledgeSpace(String id) {
    _ensureOpen();
    return _handle.deleteKnowledgeSpace(id: id);
  }

  @override
  Future<void> createKnowledgeFolder(String space, String path) {
    _ensureOpen();
    return _handle.createKnowledgeFolder(space: space, path: path);
  }

  @override
  Future<String> saveMemory(String space, String? id, api.MemoryDraft draft) {
    _ensureOpen();
    return _handle.saveMemory(space: space, id: id, draft: draft);
  }

  @override
  Future<void> archiveMemory(String space, String id, bool archived) {
    _ensureOpen();
    return _handle.archiveMemory(space: space, id: id, archived: archived);
  }

  @override
  Future<bool> deleteMemory(String space, String id) {
    _ensureOpen();
    return _handle.deleteMemory(space: space, id: id);
  }

  @override
  Future<List<api.WorkflowRecord>> listWorkflows() async {
    _ensureOpen();
    return _handle.listWorkflows();
  }

  @override
  Future<api.WorkflowRecord> createWorkflow(
    String name,
    String description,
  ) async {
    _ensureOpen();
    return _handle.createWorkflow(name: name, description: description);
  }

  @override
  Future<bool> deleteWorkflow(String id) async {
    _ensureOpen();
    return _handle.deleteWorkflow(id: id);
  }

  @override
  Future<int> deleteWorkflows(List<String> ids) async {
    _ensureOpen();
    return _handle.deleteWorkflows(ids: ids);
  }

  @override
  Future<api.WorkflowRecord> updateWorkflow({
    required String id,
    required String name,
    required String description,
    required bool enabled,
  }) async {
    _ensureOpen();
    return _handle.updateWorkflow(
      id: id,
      name: name,
      description: description,
      enabled: enabled,
    );
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
