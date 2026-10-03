import 'dart:async';

import 'package:kiyori_bridge/kiyori_bridge.dart';

class FakeRun implements DiagnosticRun {
  final controller = StreamController<TaskEvent>();
  bool cancelled = false;
  @override
  Stream<TaskEvent> get events => controller.stream;
  @override
  Future<void> cancel() async {
    if (cancelled) return;
    cancelled = true;
    controller.add(
      const TaskEvent(
        revision: 1,
        phase: TaskPhase.cancelled,
        completedSteps: 0,
        totalSteps: 20,
      ),
    );
    unawaited(controller.close());
  }
}

class FakeClient implements RuntimeClient {
  @override
  Future<KnowledgeSnapshot> queryKnowledge(MemoryQuery query) =>
      knowledgeSnapshot();
  @override
  Future<MemoryRecord?> getMemory(String space, String id) async =>
      (await knowledgeSnapshot()).records
          .where((r) => r.id == id && r.spaceId == space)
          .firstOrNull;
  @override
  Future<void> renameKnowledgeFolder(String space, String old, String path) =>
      throw UnimplementedError();
  @override
  Future<void> deleteKnowledgeFolder(String space, String path) =>
      throw UnimplementedError();
  @override
  Future<KnowledgeSnapshot> knowledgeSnapshot() => throw UnimplementedError();
  @override
  Future<String> saveKnowledgeSpace(String? id, String name) =>
      throw UnimplementedError();
  @override
  Future<void> selectKnowledgeSpace(String id) => throw UnimplementedError();
  @override
  Future<bool> deleteKnowledgeSpace(String id) => throw UnimplementedError();
  @override
  Future<void> createKnowledgeFolder(String space, String path) =>
      throw UnimplementedError();
  @override
  Future<String> saveMemory(String space, String? id, MemoryDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> archiveMemory(String space, String id, bool archived) =>
      throw UnimplementedError();
  @override
  Future<bool> deleteMemory(String space, String id) =>
      throw UnimplementedError();
  bool closed = false;
  int starts = 0;
  FakeRun? run;
  Completer<DiagnosticRun>? pendingStart;
  @override
  Future<RuntimeInfo> info() async => const RuntimeInfo(
    coreVersion: '0.1.0',
    hostPlatform: 'windows',
    capabilities: [
      Capability(id: 'kiyori.runtime.diagnostics', available: true, reason: ''),
      Capability(
        id: 'kiyori.browser',
        available: false,
        reason: 'not_implemented',
      ),
    ],
  );
  @override
  Future<DiagnosticRun> startDiagnostic({
    int steps = 20,
    int intervalMs = 100,
  }) async {
    starts++;
    if (pendingStart case final pending?) return pending.future;
    return run = FakeRun();
  }

  @override
  Future<void> close() async {
    closed = true;
    await run?.cancel();
  }

  @override
  Future<List<WorkflowRecord>> listWorkflows() async => const [];

  @override
  Future<WorkflowRecord> createWorkflow(String name, String description) {
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteWorkflow(String id) async => false;
  @override
  Future<int> deleteWorkflows(List<String> ids) async => 0;

  @override
  Future<WorkflowRecord> updateWorkflow({
    required String id,
    required String name,
    required String description,
    required bool enabled,
  }) => throw UnimplementedError();
}
