import 'dart:async';

import 'generated/api.dart' as api;
import 'generated/frb_generated.dart';

/// Presentation-facing contract; the native runtime remains the state owner.
abstract interface class RuntimeClient {
  Future<api.ConversationCatalog> conversationCatalog();
  Future<List<String>> searchConversations(String query);
  Future<api.ConversationStatistics> conversationStatistics(String id);
  Future<api.ChatPreferences> chatPreferences();
  Future<api.ChatPreferences> changeChatPreference(
    int revision,
    String key,
    String value,
  );
  Future<api.ConversationSnapshot> conversation(String id);
  Future<String> createConversation();
  Future<void> selectConversation(String id);
  Future<void> selectChatCharacter(String id);
  Future<void> changeConversation(
    String id,
    int revision,
    String action,
    String value,
  );
  Future<void> changeMessage(
    String id,
    int revision,
    String message,
    String action,
    String text,
  );
  Future<PreparedConversation> prepareConversation(String id, {String? target});
  Future<ChatRun> startConfiguredProbe(
    String id,
    int revision,
    String payload,
    String kind,
  );
  Future<ChatRun> startPoolTest(
    api.ModelConfigDraft draft,
    List<api.PoolKey> keys,
    List<api.ChatHeader> headers,
    int concurrency,
  );
  Future<ChatRun> startChat(api.ChatRequest request);
  Future<ChatRun> startModelProbe(
    api.ModelConfigDraft draft,
    String apiKey,
    List<api.ChatHeader> headers,
    String kind,
  );
  Future<api.ContextSettings> contextSettings();
  Future<api.ContextSettings> saveContextSettings(
    String id,
    int revision,
    api.ContextOptions options,
    api.HistoryRetention history,
  );
  Future<void> resetFunctionModels();
  Future<api.ModelCatalog> modelCatalog();
  Future<String> createModelConfig(String name);
  Future<void> saveModelConfig(
    String id,
    int revision,
    api.ModelConfigDraft draft,
    String? secretReference,
    String? replacement,
  );
  Future<ModelSecretsWrite> beginModelSecrets();
  Future<void> retireModelSecret(String reference);
  Future<List<String>> retiredModelSecrets();
  Future<void> forgetRetiredModelSecret(String reference);
  Future<void> selectFunctionModel(
    String function,
    String config,
    String model,
  );
  Future<void> deleteModelConfig(
    String id,
    int revision,
    String? replacementConfig,
    String? replacementModel,
  );
  Future<api.PromptCatalog> promptCatalog();
  Future<String> saveCharacter(
    String? id,
    int? revision,
    api.CharacterDraft draft,
  );
  Future<String> savePromptTag(String? id, int? revision, api.TagDraft draft);
  Future<String> savePromptGroup(
    String? id,
    int? revision,
    api.GroupDraft draft,
  );
  Future<void> activatePrompt(String kind, String id);
  Future<void> deletePrompt(String kind, String id, int revision);
  Future<String> duplicatePrompt(String kind, String id, int revision);
  Future<void> resetDefaultCharacter(int revision);
  Future<String> composeCharacterPrompt(String id, bool voice);
  Future<api.MemorySearchSettings> memorySearchSettings(String space);
  Future<void> saveMemorySearchSettings(
    String space,
    api.MemorySearchSettings value,
  );
  Future<void> setMemoryGraphVisible(String space, bool visible);
  Future<api.MemorySearchReport> simulateMemorySearch(
    String space,
    api.MemoryQuery query,
  );
  Future<api.RuntimeInfo> info();
  Future<DiagnosticRun> startDiagnostic({int steps = 20, int intervalMs = 100});
  Future<void> close();
  Future<api.KnowledgeSnapshot> knowledgeSnapshot();
  Future<api.KnowledgeSnapshot> queryKnowledge(api.MemoryQuery query);
  Future<api.MemoryRecord?> getMemory(String space, String id);
  Future<api.MemoryGraph> memoryGraph(api.MemoryQuery query);
  Future<String> saveMemoryLink(
    String space,
    String? id,
    api.MemoryLinkDraft draft,
  );
  Future<bool> deleteMemoryLink(String space, String id);
  Future<int> deleteMemories(String space, List<String> ids);
  Future<api.DiaryDocument> parseDiary(String content);
  Future<String> createDiary(
    String space,
    api.MemoryDraft draft,
    String phase,
    String stamp,
  );
  Future<void> appendDiary(
    String space,
    String id,
    String body,
    String phase,
    String stamp,
  );
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

abstract interface class ChatRun {
  Stream<api.ChatEvent> get events;
  Future<void> cancel();
}

abstract interface class PreparedConversation {
  Future<String?> secretReference();
  Future<ChatRun> start(
    String text,
    String payload, {
    String? replaceFrom,
    int? revision,
    String? replyTo,
  });
  Future<void> close();
}

final class _NativePreparedConversation implements PreparedConversation {
  _NativePreparedConversation(this.handle, this.owner);
  final api.ConversationPreparation handle;
  final NativeRuntimeClient owner;
  bool closed = false;
  @override
  Future<String?> secretReference() => handle.secretReference();
  @override
  Future<ChatRun> start(
    String text,
    String payload, {
    String? replaceFrom,
    int? revision,
    String? replyTo,
  }) async {
    owner._ensureOpen();
    return owner._trackChat(
      await handle.start(
        text: text,
        payload: payload,
        replaceFrom: replaceFrom,
        revision: revision,
        replyTo: replyTo,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await handle.close();
    handle.dispose();
    owner._preparations.remove(this);
  }
}

abstract interface class ModelSecretsWrite {
  Future<String> reserve(String id, int revision);
  Future<void> close();
}

final class _NativeModelSecretsWrite implements ModelSecretsWrite {
  _NativeModelSecretsWrite(this.handle);
  final api.ModelSecretsHandle handle;
  @override
  Future<String> reserve(String id, int revision) =>
      handle.reserve(id: id, revision: revision);
  @override
  Future<void> close() => handle.close();
}

final class NativeRuntimeClient implements RuntimeClient {
  final _preparations = <_NativePreparedConversation>{};
  @override
  Future<List<String>> searchConversations(String query) {
    _ensureOpen();
    return _handle.searchConversations(query: query);
  }

  @override
  Future<api.ConversationStatistics> conversationStatistics(String id) {
    _ensureOpen();
    return _handle.conversationStatistics(id: id);
  }

  @override
  Future<api.ChatPreferences> chatPreferences() {
    _ensureOpen();
    return _handle.chatPreferences();
  }

  @override
  Future<api.ChatPreferences> changeChatPreference(
    int revision,
    String key,
    String value,
  ) {
    _ensureOpen();
    return _handle.changeChatPreference(
      revision: revision,
      key: key,
      value: value,
    );
  }

  @override
  Future<api.ConversationCatalog> conversationCatalog() {
    _ensureOpen();
    return _handle.conversationCatalog();
  }

  @override
  Future<api.ConversationSnapshot> conversation(String id) {
    _ensureOpen();
    return _handle.conversation(id: id);
  }

  @override
  Future<String> createConversation() {
    _ensureOpen();
    return _handle.createConversation();
  }

  @override
  Future<void> selectConversation(String id) {
    _ensureOpen();
    return _handle.selectConversation(id: id);
  }

  @override
  Future<void> selectChatCharacter(String id) {
    _ensureOpen();
    return _handle.selectChatCharacter(id: id);
  }

  @override
  Future<void> changeConversation(
    String id,
    int revision,
    String action,
    String value,
  ) {
    _ensureOpen();
    return _handle.changeConversation(
      id: id,
      revision: revision,
      action: action,
      value: value,
    );
  }

  @override
  Future<void> changeMessage(
    String id,
    int revision,
    String message,
    String action,
    String text,
  ) {
    _ensureOpen();
    return _handle.changeMessage(
      id: id,
      revision: revision,
      message: message,
      action: action,
      text: text,
    );
  }

  @override
  Future<PreparedConversation> prepareConversation(
    String id, {
    String? target,
  }) async {
    _ensureOpen();
    final handle = await _handle.prepareConversation(id: id, target: target);
    if (_closing != null) {
      await handle.close();
      handle.dispose();
      _ensureOpen();
    }
    final preparation = _NativePreparedConversation(handle, this);
    _preparations.add(preparation);
    return preparation;
  }

  @override
  Future<void> resetFunctionModels() {
    _ensureOpen();
    return _handle.resetFunctionModels();
  }

  @override
  Future<api.ModelCatalog> modelCatalog() {
    _ensureOpen();
    return _handle.modelCatalog();
  }

  @override
  Future<String> createModelConfig(String name) {
    _ensureOpen();
    return _handle.createModelConfig(name: name);
  }

  @override
  Future<void> saveModelConfig(
    String id,
    int revision,
    api.ModelConfigDraft draft,
    String? secretReference,
    String? replacement,
  ) {
    _ensureOpen();
    return _handle.saveModelConfig(
      id: id,
      revision: revision,
      draft: draft,
      secretReference: secretReference,
      replacement: replacement,
    );
  }

  @override
  Future<ModelSecretsWrite> beginModelSecrets() async {
    _ensureOpen();
    return _NativeModelSecretsWrite(await _handle.beginModelSecrets());
  }

  @override
  Future<api.ContextSettings> contextSettings() {
    _ensureOpen();
    return _handle.contextSettings();
  }

  @override
  Future<api.ContextSettings> saveContextSettings(
    String id,
    int revision,
    api.ContextOptions options,
    api.HistoryRetention history,
  ) {
    _ensureOpen();
    return _handle.saveContextSettings(
      id: id,
      revision: revision,
      options: options,
      history: history,
    );
  }

  @override
  Future<void> retireModelSecret(String reference) {
    _ensureOpen();
    return _handle.retireModelSecret(reference: reference);
  }

  @override
  Future<List<String>> retiredModelSecrets() {
    _ensureOpen();
    return _handle.retiredModelSecrets();
  }

  @override
  Future<void> forgetRetiredModelSecret(String reference) {
    _ensureOpen();
    return _handle.forgetRetiredModelSecret(reference: reference);
  }

  @override
  Future<void> selectFunctionModel(
    String function,
    String config,
    String model,
  ) {
    _ensureOpen();
    return _handle.selectFunctionModel(
      function: function,
      config: config,
      model: model,
    );
  }

  @override
  Future<void> deleteModelConfig(
    String id,
    int revision,
    String? replacementConfig,
    String? replacementModel,
  ) {
    _ensureOpen();
    return _handle.deleteModelConfig(
      id: id,
      revision: revision,
      replacementConfig: replacementConfig,
      replacementModel: replacementModel,
    );
  }

  @override
  Future<api.PromptCatalog> promptCatalog() {
    _ensureOpen();
    return _handle.promptCatalog();
  }

  @override
  Future<String> saveCharacter(
    String? id,
    int? revision,
    api.CharacterDraft draft,
  ) {
    _ensureOpen();
    return _handle.saveCharacter(id: id, revision: revision, draft: draft);
  }

  @override
  Future<String> savePromptTag(String? id, int? revision, api.TagDraft draft) {
    _ensureOpen();
    return _handle.savePromptTag(id: id, revision: revision, draft: draft);
  }

  @override
  Future<String> savePromptGroup(
    String? id,
    int? revision,
    api.GroupDraft draft,
  ) {
    _ensureOpen();
    return _handle.savePromptGroup(id: id, revision: revision, draft: draft);
  }

  @override
  Future<void> activatePrompt(String kind, String id) {
    _ensureOpen();
    return _handle.activatePrompt(kind: kind, id: id);
  }

  @override
  Future<void> deletePrompt(String kind, String id, int revision) {
    _ensureOpen();
    return _handle.deletePrompt(kind: kind, id: id, revision: revision);
  }

  @override
  Future<String> duplicatePrompt(String kind, String id, int revision) {
    _ensureOpen();
    return _handle.duplicatePrompt(kind: kind, id: id, revision: revision);
  }

  @override
  Future<void> resetDefaultCharacter(int revision) {
    _ensureOpen();
    return _handle.resetDefaultCharacter(revision: revision);
  }

  @override
  Future<String> composeCharacterPrompt(String id, bool voice) {
    _ensureOpen();
    return _handle.composeCharacterPrompt(id: id, voice: voice);
  }

  @override
  Future<api.MemorySearchSettings> memorySearchSettings(String space) {
    _ensureOpen();
    return _handle.memorySearchSettings(space: space);
  }

  @override
  Future<void> saveMemorySearchSettings(
    String space,
    api.MemorySearchSettings value,
  ) {
    _ensureOpen();
    return _handle.saveMemorySearchSettings(space: space, value: value);
  }

  @override
  Future<void> setMemoryGraphVisible(String space, bool visible) {
    _ensureOpen();
    return _handle.setMemoryGraphVisible(space: space, visible: visible);
  }

  @override
  Future<api.MemorySearchReport> simulateMemorySearch(
    String space,
    api.MemoryQuery query,
  ) {
    _ensureOpen();
    return _handle.simulateMemorySearch(space: space, query: query);
  }

  @override
  Future<api.MemoryGraph> memoryGraph(api.MemoryQuery query) {
    _ensureOpen();
    return _handle.memoryGraph(query: query);
  }

  @override
  Future<String> saveMemoryLink(
    String space,
    String? id,
    api.MemoryLinkDraft draft,
  ) {
    _ensureOpen();
    return _handle.saveMemoryLink(space: space, id: id, draft: draft);
  }

  @override
  Future<bool> deleteMemoryLink(String space, String id) {
    _ensureOpen();
    return _handle.deleteMemoryLink(space: space, id: id);
  }

  @override
  Future<int> deleteMemories(String space, List<String> ids) {
    _ensureOpen();
    return _handle.deleteMemories(space: space, ids: ids);
  }

  NativeRuntimeClient._(this._handle);

  static Future<void>? _initialization;
  final api.RuntimeHandle _handle;
  final Set<_NativeDiagnosticRun> _runs = {};
  final Set<_NativeChatRun> _chatRuns = {};
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
  Future<api.DiaryDocument> parseDiary(String content) {
    _ensureOpen();
    return api.parseDiary(content: content);
  }

  @override
  Future<String> createDiary(
    String space,
    api.MemoryDraft draft,
    String phase,
    String stamp,
  ) {
    _ensureOpen();
    return _handle.createDiary(
      space: space,
      draft: draft,
      phase: phase,
      stamp: stamp,
    );
  }

  @override
  Future<void> appendDiary(
    String space,
    String id,
    String body,
    String phase,
    String stamp,
  ) {
    _ensureOpen();
    return _handle.appendDiary(
      space: space,
      id: id,
      body: body,
      phase: phase,
      stamp: stamp,
    );
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
    await Future.wait(_preparations.toList().map((item) => item.close()));
    await Future.wait(_chatRuns.toList().map((run) => run.stop()));
    await Future.wait(_runs.toList().map((run) => run.stop()));
    _handle.dispose();
  }

  @override
  Future<ChatRun> startChat(api.ChatRequest request) async {
    _ensureOpen();
    final handle = await _handle.startChat(request: request);
    return _trackChat(handle);
  }

  @override
  Future<ChatRun> startConfiguredProbe(
    String id,
    int revision,
    String payload,
    String kind,
  ) async {
    _ensureOpen();
    return _trackChat(
      await _handle.startConfiguredProbe(
        id: id,
        revision: revision,
        payload: payload,
        kind: kind,
      ),
    );
  }

  @override
  Future<ChatRun> startModelProbe(
    api.ModelConfigDraft draft,
    String apiKey,
    List<api.ChatHeader> headers,
    String kind,
  ) async {
    _ensureOpen();
    return _trackChat(
      await _handle.startModelProbe(
        draft: draft,
        apiKey: apiKey,
        headers: headers,
        kind: kind,
      ),
    );
  }

  Future<ChatRun> _trackChat(api.ChatHandle handle) async {
    if (_closing != null) {
      await handle.cancel();
      handle.dispose();
      _ensureOpen();
    }
    late final _NativeChatRun run;
    run = _NativeChatRun(handle, () => _chatRuns.remove(run));
    _chatRuns.add(run);
    return run;
  }

  @override
  Future<ChatRun> startPoolTest(
    api.ModelConfigDraft draft,
    List<api.PoolKey> keys,
    List<api.ChatHeader> headers,
    int concurrency,
  ) async {
    _ensureOpen();
    return _trackChat(
      await _handle.startPoolTest(
        draft: draft,
        keys: keys,
        headers: headers,
        concurrency: concurrency,
      ),
    );
  }
}

final class _NativeChatRun implements ChatRun {
  _NativeChatRun(this.handle, this.onDone) {
    controller = StreamController<api.ChatEvent>(
      onListen: () => pumping = pump(),
      onPause: () => resume ??= Completer<void>(),
      onResume: wake,
      onCancel: stop,
    );
  }
  final api.ChatHandle handle;
  final void Function() onDone;
  late final StreamController<api.ChatEvent> controller;
  Future<void>? pumping, cancellation;
  Completer<void>? resume;
  bool stopped = false, disposed = false;
  @override
  Stream<api.ChatEvent> get events => controller.stream;
  void wake() {
    resume?.complete();
    resume = null;
  }

  @override
  Future<void> cancel() async {
    if (disposed) return;
    await (cancellation ??= handle.cancel());
    wake();
  }

  Future<void> stop() async {
    stopped = true;
    await cancel();
    wake();
    if (pumping == null) unawaited(controller.close());
    await pumping;
    dispose();
  }

  Future<void> pump() async {
    try {
      while (!stopped) {
        if (resume case final waiting?) await waiting.future;
        if (stopped) break;
        final event = await handle.nextEvent();
        if (event == null || stopped) break;
        controller.add(event);
        if (event.phase == api.ChatPhase.completed ||
            event.phase == api.ChatPhase.failed ||
            event.phase == api.ChatPhase.cancelled) {
          break;
        }
      }
    } catch (error, stack) {
      if (!stopped) controller.addError(error, stack);
    } finally {
      unawaited(controller.close());
      await cancellation;
      dispose();
    }
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    handle.dispose();
    onDone();
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
