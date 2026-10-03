import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart' as bridge;

import 'prompt_presentation.dart';
import '../models/function_model_presentation.dart';

/// 仅持有 Rust 目录投影；编辑 revision 固定在打开表单时。
class PromptsController extends ChangeNotifier {
  PromptsController(this._connect);
  final Future<bridge.RuntimeClient> Function() _connect;
  PromptsPresentation snapshot = const PromptsPresentation(
    cards: [],
    activeCardId: null,
  );
  bool loading = false, saving = false, _disposed = false;
  String? error;
  int _generation = 0;

  Future<void> _read(bridge.RuntimeClient client) async {
    final value = await client.promptCatalog();
    final knowledge = await client.knowledgeSnapshot();
    final models = await client.modelCatalog();
    if (_disposed) return;
    snapshot = PromptsPresentation(
      activeCardId: value.activeCharacter,
      activeGroupId: value.activeGroup,
      models: [
        for (final config in models.configs)
          ModelConfigPresentation(
            id: config.id,
            name: config.draft.name,
            models: config.draft.models,
            image: config.draft.options.image,
            audio: config.draft.options.audio,
            video: config.draft.options.video,
          ),
      ],
      memories: [
        for (final space in knowledge.spaces)
          PromptOption(space.id, space.name),
      ],
      cards: [
        for (final card in value.characters)
          CharacterPresentation(
            id: card.id,
            revision: card.revision,
            updatedAt: card.updatedAt.toInt(),
            name: card.draft.name,
            description: card.draft.description,
            setting: card.draft.setting,
            opening: card.draft.opening,
            chat: card.draft.chat,
            voice: card.draft.voice,
            custom: card.draft.custom,
            marks: card.draft.marks,
            tagIds: card.draft.tagIds,
            isDefault: card.id == 'default_character',
            avatarAsset: card.id == 'default_character'
                ? 'assets/branding/kiyori-app-icon.png'
                : null,
            fixedModel: card.draft.modelConfig != null,
            modelConfigId: card.draft.modelConfig,
            modelName: card.draft.modelName,
            fixedMemory: card.draft.memorySpace != null,
            memoryId: card.draft.memorySpace,
            toolAccess: CharacterToolAccess(
              enabled: card.draft.toolsEnabled,
              allowed: {
                for (final kind in CharacterToolKind.values)
                  kind: {
                    for (final tool in card.draft.tools)
                      if (tool.kind == kind.name) tool.name,
                  },
              },
            ),
          ),
      ],
      tags: [
        for (final tag in value.tags)
          PromptTagPresentation(
            id: tag.id,
            revision: tag.revision,
            name: tag.draft.name,
            description: tag.draft.description,
            content: tag.draft.content,
          ),
      ],
      groups: [
        for (final group in value.groups)
          GroupPresentation(
            id: group.id,
            revision: group.revision,
            updatedAt: group.updatedAt.toInt(),
            name: group.draft.name,
            description: group.draft.description,
            members: [
              for (final entry in group.draft.members.indexed)
                GroupMemberPresentation(entry.$2, orderIndex: entry.$1),
            ],
          ),
      ],
    );
  }

  Future<void> load() async {
    if (_disposed || saving || loading) return;
    loading = true;
    error = null;
    final generation = ++_generation;
    notifyListeners();
    try {
      final client = await _connect();
      if (_disposed || generation != _generation) return;
      await _read(client);
    } catch (_) {
      if (!_disposed) error = '无法读取角色和提示词，请重试。';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _write(
    Future<Object?> Function(bridge.RuntimeClient) operation,
  ) async {
    if (_disposed || saving || loading) throw StateError('正在处理，请稍后重试。');
    saving = true;
    error = null;
    notifyListeners();
    try {
      final client = await _connect();
      if (_disposed) throw StateError('页面已关闭。');
      await operation(client);
      // 已提交不能作为保存失败重试，尤其是创建和复制。
      try {
        await _read(client);
      } catch (_) {
        if (!_disposed) error = '已保存，但目录刷新失败，请重新加载。';
      }
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveCharacter(CharacterPresentation value) => _write(
    (client) => client.saveCharacter(
      value.id.isEmpty ? null : value.id,
      value.id.isEmpty ? null : value.revision,
      bridge.CharacterDraft(
        name: value.name,
        description: value.description,
        setting: value.setting,
        opening: value.opening,
        chat: value.chat,
        voice: value.voice,
        custom: value.custom,
        marks: value.marks,
        tagIds: value.tagIds,
        modelConfig: value.fixedModel ? value.modelConfigId : null,
        modelName: value.fixedModel ? value.modelName : null,
        memorySpace: value.fixedMemory ? value.memoryId : null,
        toolsEnabled: value.toolAccess.enabled,
        tools: [
          for (final entry in value.toolAccess.allowed.entries)
            for (final name in entry.value)
              bridge.PromptTool(kind: entry.key.name, name: name),
        ],
      ),
    ),
  );
  Future<void> saveTag(PromptTagPresentation value) => _write(
    (client) => client.savePromptTag(
      value.id.isEmpty ? null : value.id,
      value.id.isEmpty ? null : value.revision,
      bridge.TagDraft(
        name: value.name,
        description: value.description,
        content: value.content,
      ),
    ),
  );
  Future<void> saveGroup(GroupPresentation value) => _write(
    (client) => client.savePromptGroup(
      value.id.isEmpty ? null : value.id,
      value.id.isEmpty ? null : value.revision,
      bridge.GroupDraft(
        name: value.name,
        description: value.description,
        members: value.members.map((member) => member.characterId).toList(),
      ),
    ),
  );
  Future<void> activate(String kind, String id) =>
      _write((client) => client.activatePrompt(kind, id));
  Future<void> delete(String kind, String id, int revision) =>
      _write((client) => client.deletePrompt(kind, id, revision));
  Future<void> duplicate(String kind, String id, int revision) =>
      _write((client) => client.duplicatePrompt(kind, id, revision));
  Future<void> reset(int revision) =>
      _write((client) => client.resetDefaultCharacter(revision));

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
