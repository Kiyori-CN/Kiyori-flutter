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
  Future<List<String>> searchConversations(String query) async => [];
  @override
  Future<ChatPreferences> chatPreferences() async => const ChatPreferences(
    revision: 1,
    historyMode: 'folder',
    autoCharacter: false,
    autoChat: false,
    thinking: false,
    thinkingQuality: 2,
    messageStyle: 'cursor',
    inputStyle: 'agent',
    memoryAuto: true,
    toolsEnabled: true,
    permission: 'ask',
    disableStream: false,
    autoRead: false,
    disablePreferences: false,
    folders: [],
  );
  @override
  Future<ChatPreferences> changeChatPreference(
    int revision,
    String key,
    String value,
  ) async => throw UnimplementedError();
  @override
  Future<ConversationStatistics> conversationStatistics(String id) async =>
      const ConversationStatistics(
        cacheReportedRequests: 0,
        speedEstimated: true,
        requests: 0,
        reportedRequests: 0,
        recentModel: '',
      );
  @override
  Future<ConversationCatalog> conversationCatalog() async =>
      const ConversationCatalog(activeId: null, conversations: []);
  @override
  Future<ConversationSnapshot> conversation(String id) async =>
      throw UnimplementedError();
  @override
  Future<String> createConversation() async => throw UnimplementedError();
  @override
  Future<void> selectConversation(String id) async =>
      throw UnimplementedError();
  @override
  Future<void> selectChatCharacter(String id) async =>
      throw UnimplementedError();
  @override
  Future<void> changeConversation(
    String id,
    int revision,
    String action,
    String value,
  ) async => throw UnimplementedError();
  @override
  Future<void> changeMessage(
    String id,
    int revision,
    String message,
    String action,
    String text,
  ) async => throw UnimplementedError();
  @override
  Future<PreparedConversation> prepareConversation(
    String id, {
    String? target,
  }) async => throw UnimplementedError();
  @override
  Future<ChatRun> startConfiguredProbe(
    String id,
    int revision,
    String payload,
    String kind,
  ) async => throw UnimplementedError('Use real configured probe runtime.');
  @override
  Future<ChatRun> startPoolTest(
    ModelConfigDraft draft,
    List<PoolKey> keys,
    List<ChatHeader> headers,
    int concurrency,
  ) async => throw UnimplementedError('Use real pool runtime.');
  @override
  Future<ChatRun> startModelProbe(
    ModelConfigDraft draft,
    String apiKey,
    List<ChatHeader> headers,
    String kind,
  ) async =>
      throw UnimplementedError('Use loopback with real request runtime.');
  @override
  Future<ChatRun> startChat(ChatRequest request) async =>
      throw UnimplementedError('Use loopback with real request runtime.');
  @override
  Future<ContextSettings> contextSettings() async =>
      throw UnimplementedError('Use real context runtime.');
  @override
  Future<ContextSettings> saveContextSettings(
    String id,
    int revision,
    ContextOptions options,
    HistoryRetention history,
  ) async => throw UnimplementedError('Use real context runtime.');
  @override
  Future<void> resetFunctionModels() async =>
      throw UnimplementedError('Use real model runtime.');
  @override
  Future<ModelCatalog> modelCatalog() async => throw UnimplementedError(
    'Use a real runtime for model persistence tests.',
  );
  @override
  Future<String> createModelConfig(String name) async =>
      throw UnimplementedError(
        'Use a real runtime for model persistence tests.',
      );
  @override
  Future<void> saveModelConfig(
    String id,
    int revision,
    ModelConfigDraft draft,
    String? secretReference,
    String? replacement,
  ) async => throw UnimplementedError(
    'Use a real runtime for model persistence tests.',
  );
  @override
  Future<ModelSecretsWrite> beginModelSecrets() async =>
      throw UnimplementedError(
        'Use a real runtime for model persistence tests.',
      );
  @override
  Future<void> retireModelSecret(String reference) async =>
      throw UnimplementedError(
        'Use a real runtime for model persistence tests.',
      );
  @override
  Future<List<String>> retiredModelSecrets() async => throw UnimplementedError(
    'Use a real runtime for model persistence tests.',
  );
  @override
  Future<void> forgetRetiredModelSecret(String reference) async =>
      throw UnimplementedError(
        'Use a real runtime for model persistence tests.',
      );
  @override
  Future<void> selectFunctionModel(
    String function,
    String config,
    String model,
  ) async => throw UnimplementedError(
    'Use a real runtime for model persistence tests.',
  );
  @override
  Future<void> deleteModelConfig(
    String id,
    int revision,
    String? replacementConfig,
    String? replacementModel,
  ) async => throw UnimplementedError(
    'Use a real runtime for model persistence tests.',
  );
  @override
  Future<PromptCatalog> promptCatalog() async => throw UnimplementedError(
    'Use a real runtime for prompt persistence tests.',
  );
  @override
  Future<String> saveCharacter(
    String? id,
    int? revision,
    CharacterDraft draft,
  ) async => throw UnimplementedError(
    'Use a real runtime for prompt persistence tests.',
  );
  @override
  Future<String> savePromptTag(
    String? id,
    int? revision,
    TagDraft draft,
  ) async => throw UnimplementedError(
    'Use a real runtime for prompt persistence tests.',
  );
  @override
  Future<String> savePromptGroup(
    String? id,
    int? revision,
    GroupDraft draft,
  ) async => throw UnimplementedError(
    'Use a real runtime for prompt persistence tests.',
  );
  @override
  Future<void> activatePrompt(String kind, String id) async =>
      throw UnimplementedError(
        'Use a real runtime for prompt persistence tests.',
      );
  @override
  Future<void> deletePrompt(String kind, String id, int revision) async =>
      throw UnimplementedError(
        'Use a real runtime for prompt persistence tests.',
      );
  @override
  Future<String> duplicatePrompt(String kind, String id, int revision) async =>
      throw UnimplementedError(
        'Use a real runtime for prompt persistence tests.',
      );
  @override
  Future<void> resetDefaultCharacter(int revision) async =>
      throw UnimplementedError(
        'Use a real runtime for prompt persistence tests.',
      );
  @override
  Future<String> composeCharacterPrompt(String id, bool voice) async =>
      throw UnimplementedError(
        'Use a real runtime for prompt persistence tests.',
      );
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
