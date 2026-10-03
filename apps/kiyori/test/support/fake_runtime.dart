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
  final searchSettings = <String, MemorySearchSettings>{};
  @override
  Future<MemorySearchSettings> memorySearchSettings(String space) async =>
      searchSettings[space] ??
      const MemorySearchSettings(
        graphVisible: false,
        scoreMode: 'balanced',
        keywordWeight: 10,
        tagWeight: 0,
        vectorWeight: 0,
        edgeWeight: .4,
        autoInterval: 5,
        extractionRules: '',
      );
  @override
  Future<void> saveMemorySearchSettings(
    String space,
    MemorySearchSettings value,
  ) async {
    searchSettings[space] = value;
  }

  @override
  Future<void> setMemoryGraphVisible(String space, bool visible) async {
    final old = await memorySearchSettings(space);
    searchSettings[space] = MemorySearchSettings(
      graphVisible: visible,
      scoreMode: old.scoreMode,
      keywordWeight: old.keywordWeight,
      tagWeight: old.tagWeight,
      vectorWeight: old.vectorWeight,
      edgeWeight: old.edgeWeight,
      autoInterval: old.autoInterval,
      extractionRules: old.extractionRules,
    );
  }

  @override
  Future<MemorySearchReport> simulateMemorySearch(
    String space,
    MemoryQuery query,
  ) => throw UnimplementedError();
  @override
  Future<MemoryGraph> memoryGraph(MemoryQuery query) =>
      throw UnimplementedError();
  @override
  Future<String> saveMemoryLink(
    String space,
    String? id,
    MemoryLinkDraft draft,
  ) => throw UnimplementedError();
  @override
  Future<bool> deleteMemoryLink(String space, String id) =>
      throw UnimplementedError();
  @override
  Future<int> deleteMemories(String space, List<String> ids) =>
      throw UnimplementedError();
  @override
  Future<DiaryDocument> parseDiary(String content) =>
      throw UnimplementedError();
  @override
  Future<String> createDiary(
    String space,
    MemoryDraft draft,
    String phase,
    String stamp,
  ) => throw UnimplementedError();
  @override
  Future<void> appendDiary(
    String space,
    String id,
    String body,
    String phase,
    String stamp,
  ) => throw UnimplementedError();
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
