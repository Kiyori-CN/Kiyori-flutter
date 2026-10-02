/// 旧 ChatHistorySettingsScreen 的只读展示输入；不读取聊天库或工作区目录。
class ChatHistoryPresentation {
  const ChatHistoryPresentation({
    this.profileName = '默认配置',
    this.loading = false,
    this.chats = const [],
    this.characters = const [],
    this.groups = const [],
    this.characterStats = const [],
    this.groupStats = const [],
    this.workspaces = const [],
  });
  final String profileName;
  final bool loading;
  final List<ChatHistoryItem> chats;
  final List<HistoryIdentity> characters, groups;
  final List<HistoryStatistic> characterStats, groupStats;
  final List<HistoryWorkspace> workspaces;
}

class ChatHistoryItem {
  const ChatHistoryItem({
    required this.id,
    required this.title,
    this.character,
    this.characterGroupId,
    this.group,
    this.updatedAt = 0,
  });
  final String id, title;
  final String? character, characterGroupId, group;
  final int updatedAt;
}

class HistoryIdentity {
  const HistoryIdentity(this.id, this.name);
  final String id, name;
}

class HistoryStatistic {
  const HistoryStatistic(this.identity, this.chats, this.messages);

  /// 角色按名称、群聊按 ID 对应原统计键，null 为未绑定。
  final String? identity;
  final int chats, messages;
}

class HistoryWorkspace {
  const HistoryWorkspace(this.path, this.name, this.location);
  final String path, name, location;
}
