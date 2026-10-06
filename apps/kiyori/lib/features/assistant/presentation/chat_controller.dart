import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'models/model_credentials.dart';
import 'models/model_options_editing.dart';

enum HistoryGroupCreation {
  selected,
  selectionChanged,
  selectionFailed,
  failed,
}

/// 只持有交互与不可变快照；历史、模型解析和终态均由Rust决定。
class ChatController extends ChangeNotifier {
  ChatController(this.connect, this.openSecrets);
  final Future<RuntimeClient> Function() connect;
  final Future<SecretStore> Function() openSecrets;
  ConversationCatalog? catalog;
  ConversationSnapshot? snapshot;
  ConversationStatistics? statistics;
  ModelCatalog? models;
  PromptCatalog? prompts;
  ChatPreferences? preferences;
  KnowledgeSnapshot? knowledge;
  final _replies = <String, ConversationMessage>{};
  final memoryFolderDrafts = <String, List<String>>{};
  List<String> get memoryFolders => memoryFolderDrafts[draftId] ?? const [];
  void attachMemoryFolders(List<String> folders) {
    memoryFolderDrafts[draftId] = folders;
    _notify();
  }

  void clearMemoryFolders() {
    memoryFolderDrafts.remove(draftId);
    _notify();
  }

  ConversationMessage? get replyTo => _replies[draftId];
  void setReply(ConversationMessage message) {
    _replies[draftId] = message;
    _notify();
  }

  void clearReply() {
    _replies.remove(draftId);
    _notify();
  }

  bool savingPreference = false;

  Future<HistoryGroupCreation> createHistoryGroup(
    String name, {
    String? binding,
    required bool includeUnbound,
  }) async {
    final base = preferences;
    if (_disposed || savingPreference || base == null) {
      return HistoryGroupCreation.failed;
    }
    final origin = snapshot?.conversation.id ?? catalog?.activeId;
    final generation = _generation;
    var committed = false;
    savingPreference = true;
    error = null;
    _notify();
    try {
      final runtime = await connect();
      preferences = await runtime.changeChatPreference(
        base.revision,
        'history_group',
        jsonEncode({
          'action': 'create',
          'name': name,
          'binding': binding,
          'include_unbound': includeUnbound,
          'selection': {'origin': origin},
        }),
      );
      // 此后任何读取失败都不能让用户再次创建：短事务已经提交。
      committed = true;
      final directory = await runtime.conversationCatalog();
      final created = directory.conversations
          .where(
            (c) => c.folder == name.trim() && c.characterId == (binding ?? ''),
          )
          .single;
      if (_disposed) return HistoryGroupCreation.selectionFailed;
      if (generation != _generation) {
        // 刷新当前事实而不回填已过期目录；新加载始终跟随SQLite最新active。
        return await load(followActive: true)
            ? HistoryGroupCreation.selectionChanged
            : HistoryGroupCreation.selectionFailed;
      }
      final loaded = await load(
        expectedGeneration: generation,
        followActive: true,
      );
      if (!loaded) {
        return error == null && !_disposed
            ? HistoryGroupCreation.selectionChanged
            : HistoryGroupCreation.selectionFailed;
      }
      return snapshot?.conversation.id == created.id
          ? HistoryGroupCreation.selected
          : HistoryGroupCreation.selectionChanged;
    } catch (failure) {
      error = _error(failure);
      return committed
          ? HistoryGroupCreation.selectionFailed
          : HistoryGroupCreation.failed;
    } finally {
      savingPreference = false;
      _notify();
    }
  }

  Future<bool> setPreference(String key, String value) async {
    final base = preferences;
    if (_disposed || savingPreference || base == null) return false;
    savingPreference = true;
    error = null;
    _notify();
    try {
      preferences = await (await connect()).changeChatPreference(
        base.revision,
        key,
        value,
      );
      if (key.endsWith('_folder') ||
          key == 'history_group' ||
          key == 'history_create') {
        final directory = await (await connect()).conversationCatalog();
        await load(id: directory.activeId);
      }
      return true;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      savingPreference = false;
      _notify();
    }
  }

  bool loading = false, changing = false, _disposed = false;
  String? error;
  int _generation = 0;
  final drafts = <String, String>{};
  final historyCollapsed = <String>{};
  final executions = <String, ChatExecution>{};
  String get draftId => snapshot?.conversation.id ?? 'new';
  ChatExecution? get execution => executions[snapshot?.conversation.id];
  bool get busy => changing || (execution?.active ?? false);
  PromptCharacter? get character => prompts?.characters
      .where((c) => c.id == prompts?.activeCharacter)
      .firstOrNull;
  String get modelName =>
      character?.draft.modelName ??
      models?.functions
          .where((f) => f.function == 'chat')
          .firstOrNull
          ?.modelName ??
      '未选择';
  String? get modelConfigId =>
      character?.draft.modelConfig ??
      models?.functions
          .where((f) => f.function == 'chat')
          .firstOrNull
          ?.configId;
  ModelConfig? get modelConfig =>
      models?.configs.where((config) => config.id == modelConfigId).firstOrNull;
  int? get contextLimit {
    final options = modelConfig?.draft.options;
    if (options == null) return null;
    return (options.maxContextMode
                ? options.maxContextLength
                : options.contextLength)
            .toInt() *
        1024;
  }

  Future<void> setMaxContext(bool enabled) async {
    final config = modelConfig;
    if (changing || _disposed || config == null) return;
    changing = true;
    error = null;
    _notify();
    try {
      final d = config.draft;
      await (await connect()).saveModelConfig(
        config.id,
        config.revision,
        ModelConfigDraft(
          name: d.name,
          provider: d.provider,
          protocol: d.protocol,
          endpoint: d.endpoint,
          models: d.models,
          options: d.options.copyWith(maxContextMode: enabled),
        ),
        config.secretReference,
        null,
      );
      await load();
    } catch (failure) {
      error = _error(failure);
    } finally {
      changing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void dismissError() {
    error = null;
    _notify();
  }

  String _error(Object value) =>
      value is BridgeError ? value.message : '聊天操作失败，请保留输入并重试';

  Future<bool> load({
    String? id,
    int? expectedGeneration,
    bool followActive = false,
  }) async {
    if (_disposed ||
        (expectedGeneration != null && expectedGeneration != _generation)) {
      return false;
    }
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final runtime = await connect();
      final directory = await runtime.conversationCatalog();
      final modelDirectory = await runtime.modelCatalog();
      final promptDirectory = await runtime.promptCatalog();
      final chatPreferences = await runtime.chatPreferences();
      final knowledgeDirectory = await runtime.knowledgeSnapshot();
      final previous = followActive
          ? directory.activeId
          : id ?? snapshot?.conversation.id;
      final selected = directory.conversations.any((c) => c.id == previous)
          ? previous
          : directory.activeId;
      final exists = directory.conversations.any((c) => c.id == selected);
      final value = exists ? await runtime.conversation(selected!) : null;
      final stats = exists
          ? await runtime.conversationStatistics(selected!)
          : null;
      if (_disposed || generation != _generation) return false;
      catalog = directory;
      snapshot = value;
      statistics = stats;
      final reply = _replies[selected];
      if (reply != null &&
          value?.messages.any((m) => m.id == reply.id) != true) {
        _replies.remove(selected);
      }
      models = modelDirectory;
      prompts = promptDirectory;
      preferences = chatPreferences;
      knowledge = knowledgeDirectory;
      return true;
    } catch (failure) {
      if (!_disposed && generation == _generation) error = _error(failure);
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> chooseModel(String config, String model) async {
    if (changing || _disposed) return;
    changing = true;
    error = null;
    _notify();
    final card = character;
    try {
      final runtime = await connect();
      if (card?.draft.modelConfig != null) {
        final d = card!.draft;
        await runtime.saveCharacter(
          card.id,
          card.revision,
          CharacterDraft(
            name: d.name,
            description: d.description,
            setting: d.setting,
            opening: d.opening,
            chat: d.chat,
            voice: d.voice,
            custom: d.custom,
            marks: d.marks,
            tagIds: d.tagIds,
            modelConfig: config,
            modelName: model,
            memorySpace: d.memorySpace,
            toolsEnabled: d.toolsEnabled,
            tools: d.tools,
          ),
        );
      } else {
        await runtime.selectFunctionModel('chat', config, model);
      }
      await load();
    } catch (failure) {
      error = _error(failure);
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<void> chooseCharacter(String id) async {
    if (busy || _disposed) return;
    changing = true;
    error = null;
    _notify();
    try {
      final runtime = await connect();
      await runtime.selectChatCharacter(id);
      final directory = await runtime.conversationCatalog();
      await load(id: directory.activeId);
    } catch (failure) {
      error = _error(failure);
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<bool> chooseMemory(String id) async {
    if (changing || _disposed) return false;
    changing = true;
    error = null;
    _notify();
    try {
      final runtime = await connect();
      final card = character;
      if (card?.draft.memorySpace != null) {
        final d = card!.draft;
        await runtime.saveCharacter(
          card.id,
          card.revision,
          CharacterDraft(
            name: d.name,
            description: d.description,
            setting: d.setting,
            opening: d.opening,
            chat: d.chat,
            voice: d.voice,
            custom: d.custom,
            marks: d.marks,
            tagIds: d.tagIds,
            modelConfig: d.modelConfig,
            modelName: d.modelName,
            memorySpace: id,
            toolsEnabled: d.toolsEnabled,
            tools: d.tools,
          ),
        );
      } else {
        await runtime.selectKnowledgeSpace(id);
      }
      await load();
      return error == null;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<bool> select(String id) async {
    if (changing || _disposed) return false;
    changing = true;
    _notify();
    try {
      final runtime = await connect();
      await runtime.selectConversation(id);
      await load(id: id);
      return error == null;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<bool> create() async {
    if (changing || _disposed) return false;
    changing = true;
    _notify();
    try {
      final id = await (await connect()).createConversation();
      await load(id: id);
      return error == null;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<bool> change(Conversation item, String action, String value) async {
    if (changing || _disposed) return false;
    changing = true;
    error = null;
    _notify();
    try {
      await (await connect()).changeConversation(
        item.id,
        item.revision,
        action,
        value,
      );
      if (action == 'delete') {
        drafts.remove(item.id);
        if (snapshot?.conversation.id == item.id) snapshot = null;
      }
      await load();
      return error == null;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<bool> changeMessage(
    Conversation item,
    ConversationMessage message,
    String action,
    String text,
  ) async {
    if (changing || _disposed) return false;
    changing = true;
    error = null;
    _notify();
    try {
      await (await connect()).changeMessage(
        item.id,
        item.revision,
        message.id,
        action,
        text,
      );
      if (action == 'branch') {
        final directory = await (await connect()).conversationCatalog();
        await load(id: directory.activeId);
      } else {
        await load();
      }
      return error == null;
    } catch (failure) {
      error = _error(failure);
      return false;
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<void> send(
    String text, {
    void Function()? accepted,
    String? replaceFrom,
    int? revision,
  }) async {
    if (busy || loading || _disposed || text.trim().isEmpty) return;
    if (memoryFolders.isNotEmpty) {
      error = '记忆文件夹附件需要记忆查询工具，当前尚未接入。请移除附件后发送文字。';
      _notify();
      return;
    }
    final reply = replyTo;
    if (snapshot == null && !await create()) return;
    if (_disposed) return;
    final id = snapshot!.conversation.id;
    executions.remove(id)?.dispose();
    final operation = ChatExecution();
    executions[id] = operation;
    error = null;
    _notify();
    operation.done = _send(
      id,
      text,
      operation,
      accepted,
      replaceFrom,
      revision,
      reply?.id,
    );
    await operation.done;
  }

  Future<void> _send(
    String id,
    String text,
    ChatExecution operation,
    void Function()? accepted,
    String? replaceFrom,
    int? revision,
    String? replyId, {
    String? summaryBoundary,
  }) async {
    PreparedConversation? prepared;
    try {
      final runtime = await connect();
      final target =
          replaceFrom != null &&
              snapshot?.messages.any(
                    (m) => m.id == replaceFrom && m.role == 'assistant',
                  ) ==
                  true
          ? replaceFrom
          : null;
      prepared = summaryBoundary == null
          ? await runtime.prepareConversation(id, target: target)
          : await runtime.prepareSummary(id, summaryBoundary, revision!);
      if (_disposed || operation.stopping) return;
      final reference = await prepared.secretReference();
      // 仅此作用域持有明文；句柄中的短lease覆盖native读取及Rust最终配置复核。
      final raw = reference == null
          ? null
          : await (await openSecrets()).read(reference);
      if (reference != null && raw == null) {
        throw const SecretStoreException('missing');
      }
      if (_disposed || operation.stopping) return;
      final payload = raw == null
          ? const ModelCredentials().encode()
          : ModelCredentials.decode(raw).encode();
      final summaryReference = summaryBoundary == null
          ? await prepared.summarySecretReference()
          : null;
      final summaryRaw =
          summaryReference == null || summaryReference == reference
          ? null
          : await (await openSecrets()).read(summaryReference);
      if (_disposed || operation.stopping) return;
      final run = summaryBoundary != null
          ? await prepared.startSummary(payload)
          : await prepared.start(
              text,
              payload,
              summaryPayload:
                  summaryReference != null && summaryReference == reference
                  ? payload
                  : summaryReference == null
                  ? const ModelCredentials().encode()
                  : summaryRaw == null
                  ? null
                  : ModelCredentials.decode(summaryRaw).encode(),
              replaceFrom: replaceFrom,
              revision: revision,
              replyTo: replyId,
            );
      operation.run = run;
      if (summaryBoundary == null) {
        if (_replies[id]?.id == replyId) _replies.remove(id);
        if (drafts[id] == text) drafts.remove(id);
        if (drafts['new'] == text) drafts.remove('new');
      }
      if (!_disposed && snapshot?.conversation.id == id) accepted?.call();
      await prepared.close();
      prepared = null;
      if (_disposed || operation.stopping) {
        await run.cancel();
        return;
      }
      // 网络可能先于FFI快照返回；流正文从空串累积，禁止把DB快照与重放delta相加。
      final started = await runtime.conversation(id);
      final startedStatistics = await runtime.conversationStatistics(id);
      operation.messageId = started.messages
          .where((m) => m.state == 'running')
          .firstOrNull
          ?.id;
      if (!_disposed && snapshot?.conversation.id == id) {
        snapshot = started;
        statistics = startedStatistics;
        _notify();
      }
      await for (final event in run.events) {
        if (_disposed) {
          await run.cancel();
          break;
        }
        if (event.phase == ChatPhase.text) operation.append(event.text);
        if (event.phase == ChatPhase.failed &&
            snapshot?.conversation.id == id) {
          error = event.errorMessage;
        }
      }
    } catch (failure) {
      if (!_disposed && snapshot?.conversation.id == id) {
        error = _error(failure);
      }
      await operation.run?.cancel();
    } finally {
      await prepared?.close();
      if (!_disposed) {
        try {
          final runtime = await connect();
          final finalSnapshot = await runtime.conversation(id);
          final finalStatistics = await runtime.conversationStatistics(id);
          final directory = await runtime.conversationCatalog();
          if (!_disposed) {
            if (snapshot?.conversation.id == id) {
              snapshot = finalSnapshot;
              statistics = finalStatistics;
            }
            catalog = directory;
          }
        } catch (_) {
          if (!_disposed && snapshot?.conversation.id == id) {
            error ??= '生成已结束，但历史读取失败，请重新载入';
          }
        }
      }
      operation.finish();
      _notify();
    }
  }

  Future<void> stop() async {
    final operation = execution;
    if (operation == null || !operation.active) return;
    operation.stopping = true;
    _notify();
    await operation.run?.cancel();
    await operation.done;
  }

  Future<void> insertSummary(ConversationMessage boundary) async {
    final item = snapshot?.conversation;
    if (item == null || busy || loading || _disposed) return;
    executions.remove(item.id)?.dispose();
    final operation = ChatExecution();
    executions[item.id] = operation;
    error = null;
    _notify();
    operation.done = _send(
      item.id,
      '',
      operation,
      null,
      null,
      item.revision,
      null,
      summaryBoundary: boundary.id,
    );
    await operation.done;
  }

  Future<void> shutdown() async {
    final pending = executions.values.where((e) => e.active).toList();
    for (final operation in pending) {
      operation.stopping = true;
      await operation.run?.cancel();
    }
    await Future.wait(pending.map((e) => e.done ?? Future<void>.value()));
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final operation in executions.values) {
      operation.stopping = true;
      unawaited(operation.run?.cancel().catchError((Object _) {}));
      operation.dispose();
    }
    super.dispose();
  }
}

class ChatExecution {
  ChatRun? run;
  Future<void>? done;
  String? messageId;
  bool active = true, stopping = false, _disposed = false;
  final text = ValueNotifier<String>('');
  final _pending = StringBuffer();
  Timer? _timer;
  void append(String delta) {
    _pending.write(delta);
    _timer ??= Timer(const Duration(milliseconds: 32), flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed && _pending.isNotEmpty) {
      text.value += _pending.toString();
      _pending.clear();
    }
  }

  void finish() {
    flush();
    active = false;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    text.dispose();
  }
}
