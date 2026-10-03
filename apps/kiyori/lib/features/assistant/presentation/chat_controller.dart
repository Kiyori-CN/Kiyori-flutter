import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'models/model_credentials.dart';

/// 只持有交互与不可变快照；历史、模型解析和终态均由Rust决定。
class ChatController extends ChangeNotifier {
  ChatController(this.connect, this.openSecrets);
  final Future<RuntimeClient> Function() connect;
  final Future<SecretStore> Function() openSecrets;
  ConversationCatalog? catalog;
  ConversationSnapshot? snapshot;
  ModelCatalog? models;
  PromptCatalog? prompts;
  bool loading = false, changing = false, _disposed = false;
  String? error;
  int _generation = 0;
  final drafts = <String, String>{};
  final executions = <String, ChatExecution>{};
  String get draftId => snapshot?.conversation.id ?? 'new';
  ChatExecution? get execution => executions[snapshot?.conversation.id];
  bool get busy => changing || (execution?.active ?? false);
  PromptCharacter? get character => prompts?.characters
      .where(
        (c) =>
            c.id ==
            (snapshot?.conversation.characterId ?? prompts?.activeCharacter),
      )
      .firstOrNull;
  String get modelName =>
      character?.draft.modelName ??
      models?.functions
          .where((f) => f.function == 'chat')
          .firstOrNull
          ?.modelName ??
      '未选择';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _error(Object value) =>
      value is BridgeError ? value.message : '聊天操作失败，请保留输入并重试';

  Future<void> load({String? id}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final runtime = await connect();
      final directory = await runtime.conversationCatalog();
      final modelDirectory = await runtime.modelCatalog();
      final promptDirectory = await runtime.promptCatalog();
      final selected = id ?? snapshot?.conversation.id ?? directory.activeId;
      final exists = directory.conversations.any((c) => c.id == selected);
      final value = exists ? await runtime.conversation(selected!) : null;
      if (_disposed || generation != _generation) return;
      catalog = directory;
      snapshot = value;
      models = modelDirectory;
      prompts = promptDirectory;
    } catch (failure) {
      if (!_disposed && generation == _generation) error = _error(failure);
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
    final item = snapshot?.conversation;
    if (item != null) {
      await change(item, 'character', id);
      return;
    }
    changing = true;
    _notify();
    try {
      await (await connect()).activatePrompt('character', id);
      await load();
    } catch (failure) {
      error = _error(failure);
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
      await (await connect()).selectConversation(id);
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

  Future<void> send(
    String text, {
    void Function()? accepted,
    String? replaceFrom,
    int? revision,
  }) async {
    if (busy || loading || _disposed || text.trim().isEmpty) return;
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
  ) async {
    PreparedConversation? prepared;
    try {
      final runtime = await connect();
      prepared = await runtime.prepareConversation(id);
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
      final run = await prepared.start(
        text,
        payload,
        replaceFrom: replaceFrom,
        revision: revision,
      );
      operation.run = run;
      if (drafts[id] == text) drafts.remove(id);
      if (drafts['new'] == text) drafts.remove('new');
      if (!_disposed && snapshot?.conversation.id == id) accepted?.call();
      await prepared.close();
      prepared = null;
      if (_disposed || operation.stopping) {
        await run.cancel();
        return;
      }
      // 网络可能先于FFI快照返回；流正文从空串累积，禁止把DB快照与重放delta相加。
      final started = await runtime.conversation(id);
      operation.messageId = started.messages.last.id;
      if (!_disposed && snapshot?.conversation.id == id) {
        snapshot = started;
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
          final directory = await runtime.conversationCatalog();
          if (!_disposed) {
            if (snapshot?.conversation.id == id) snapshot = finalSnapshot;
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
