import '../models/function_model_presentation.dart';
import 'character_defaults.dart';

/// 只读展示输入。默认项是旧首次初始化外观，不表示已经建立角色数据库。
class PromptsPresentation {
  const PromptsPresentation({
    this.cards = const [CharacterPresentation.defaultCard],
    this.tags = const [],
    this.groups = const [],
    this.models = const [],
    this.memories = const [],
    this.tools = const [],
    this.activeCardId = 'default_character',
    this.activeGroupId,
    this.tagsImporting = false,
    this.tagsExporting = false,
  });
  final List<CharacterPresentation> cards;
  final List<PromptTagPresentation> tags;
  final List<GroupPresentation> groups;
  final List<ModelConfigPresentation> models;
  final List<PromptOption> memories;
  final List<CharacterToolOption> tools;
  final String? activeCardId;
  final String? activeGroupId;
  final bool tagsImporting, tagsExporting;

  CharacterPresentation? card(String id) =>
      cards.where((e) => e.id == id).firstOrNull;

  GroupPresentation? group(String id) =>
      groups.where((e) => e.id == id).firstOrNull;
}

/// 旧群组没有默认标记或规划参数，模型/记忆/工具绑定仍属于成员角色。
class GroupPresentation {
  const GroupPresentation({
    required this.id,
    required this.name,
    this.description = '',
    this.members = const [],
    this.updatedAt = 0,
    this.avatarAsset,
  });
  final String id, name, description;
  final List<GroupMemberPresentation> members;
  final int updatedAt;
  final String? avatarAsset;
}

class GroupMemberPresentation {
  const GroupMemberPresentation(this.characterId, {this.orderIndex = 0});
  final String characterId;
  final int orderIndex;
}

class CharacterPresentation {
  const CharacterPresentation({
    required this.id,
    required this.name,
    this.description = '',
    this.setting = '',
    this.opening = '',
    this.chat = '',
    this.voice = '',
    this.custom = '',
    this.marks = '',
    this.tagIds = const [],
    this.isDefault = false,
    this.avatarAsset,
    this.updatedAt = 0,
    this.fixedModel = false,
    this.modelConfigId,
    this.modelName,
    this.fixedMemory = false,
    this.memoryId,
    this.toolAccess = const CharacterToolAccess(),
  });
  static const defaultCard = CharacterPresentation(
    id: 'default_character',
    name: 'Kiyori',
    isDefault: true,
    description: '系统默认的角色卡配置',
    setting: CharacterDefaults.settingZh,
    chat: CharacterDefaults.chatZh,
    voice: CharacterDefaults.voiceZh,
    avatarAsset: 'assets/branding/kiyori-app-icon.png',
  );
  static const newDraft = CharacterPresentation(
    id: '',
    name: '',
    setting: CharacterDefaults.settingZh,
    chat: CharacterDefaults.chatZh,
  );
  final String id,
      name,
      description,
      setting,
      opening,
      chat,
      voice,
      custom,
      marks;
  final List<String> tagIds;
  final bool isDefault, fixedModel, fixedMemory;
  final String? avatarAsset, modelConfigId, modelName, memoryId;
  final int updatedAt;
  final CharacterToolAccess toolAccess;
}

class PromptTagPresentation {
  const PromptTagPresentation({
    required this.id,
    required this.name,
    this.description = '',
    this.content = '',
  });
  final String id, name, description, content;
}

class PromptOption {
  const PromptOption(this.id, this.name, [this.description = '']);
  final String id, name, description;
}

enum CharacterToolKind {
  builtin('内建工具', '当前没有可配置的内建工具'),
  package('包', '当前没有全局可用的包'),
  skill('Skill', '当前没有对 AI 可见的 Skill'),
  mcp('MCP', '当前没有已启用的 MCP 服务器');

  const CharacterToolKind(this.label, this.empty);
  final String label, empty;
}

class CharacterToolOption extends PromptOption {
  const CharacterToolOption(
    super.id,
    super.name,
    this.kind, [
    super.description,
  ]);
  final CharacterToolKind kind;
}

class CharacterToolAccess {
  const CharacterToolAccess({this.enabled = false, this.allowed = const {}});
  final bool enabled;
  final Map<CharacterToolKind, Set<String>> allowed;
  String get summary {
    if (!enabled) return '当前跟随全局配置';
    if (allowed.values.every((e) => e.isEmpty)) {
      return '当前未允许任何内建工具或外部来源';
    }
    return CharacterToolKind.values
        .map((e) => '${e.label} ${allowed[e]?.length ?? 0}')
        .join(' · ');
  }
}
