import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import '../../../settings/presentation/backup_components.dart';
import 'chat_history_presentation.dart';

part 'chat_history_batch.dart';
part 'chat_history_dialogs.dart';
part 'history_date_dialog.dart';

/// 五张卡片来自旧 ChatHistorySettingsScreen，业务操作保持为空。
class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({
    this.snapshot = const ChatHistoryPresentation(),
    super.key,
  });
  final ChatHistoryPresentation snapshot;
  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '聊天记录管理',
    onBack: () => Navigator.of(context).maybePop(),
    body: Stack(
      children: [
        ListView.separated(
          key: const PageStorageKey('chat-history-management'),
          primary: true,
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) => switch (index) {
            0 => BackupCard(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('聊天记录概览', style: TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    BackupText('当前配置: ${snapshot.profileName}'),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        color: PrimaryColors.of(context).accent,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${snapshot.chats.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const BackupText('聊天记录', small: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            1 => _Statistics(snapshot: snapshot, group: false),
            2 => _Statistics(snapshot: snapshot, group: true),
            3 => _HistoryBatch(snapshot),
            _ => _WorkspaceCard(snapshot.workspaces),
          },
        ),
        if (snapshot.loading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('正在加载数据，请稍候…'),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader(this.title, this.subtitle, this.icon);
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: PrimaryColors.of(context).accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: PrimaryColors.of(context).accent, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            BackupText(subtitle, small: true),
          ],
        ),
      ),
    ],
  );
}

class _Statistics extends StatelessWidget {
  const _Statistics({required this.snapshot, required this.group});
  final ChatHistoryPresentation snapshot;
  final bool group;
  @override
  Widget build(BuildContext context) {
    final identities = group ? snapshot.groups : snapshot.characters;
    final stats = group ? snapshot.groupStats : snapshot.characterStats;
    HistoryIdentity? resolve(HistoryStatistic stat) {
      for (final item in identities) {
        if ((group ? item.id : item.name) == stat.identity) return item;
      }
      return null;
    }

    final sorted = stats.toList()
      ..sort((a, b) {
        if (!group) {
          final empty = (a.identity?.isNotEmpty == true ? 1 : 0).compareTo(
            b.identity?.isNotEmpty == true ? 1 : 0,
          );
          return empty != 0
              ? empty
              : (a.identity ?? '').compareTo(b.identity ?? '');
        }
        final missingA = a.identity?.isNotEmpty == true && resolve(a) == null;
        final missingB = b.identity?.isNotEmpty == true && resolve(b) == null;
        if (missingA != missingB) return missingA ? -1 : 1;
        if ((a.identity?.isEmpty ?? true) != (b.identity?.isEmpty ?? true)) {
          return (a.identity?.isEmpty ?? true) ? 1 : -1;
        }
        return (resolve(a)?.name ?? '').compareTo(resolve(b)?.name ?? '');
      });
    return BackupCard(
      children: [
        _HistoryHeader(
          group ? '角色群聊统计' : '角色卡统计',
          group ? '查看每个角色群聊下的对话与消息数量' : '查看每个角色卡下的对话与消息数量',
          group ? Icons.groups : Icons.assignment_ind,
        ),
        if (snapshot.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  BackupText('正在统计聊天数据…'),
                ],
              ),
            ),
          )
        else if (stats.isEmpty)
          const BackupText('暂无聊天数据可供统计。')
        else
          Column(
            children: [
              for (final stat in sorted)
                _statRow(context, stat, resolve(stat), identities),
            ],
          ),
      ],
    );
  }

  Widget _statRow(
    BuildContext context,
    HistoryStatistic stat,
    HistoryIdentity? identity,
    List<HistoryIdentity> identities,
  ) {
    final missing =
        identity == null && (!group || stat.identity?.isNotEmpty == true);
    final title =
        identity?.name ??
        (group
            ? (stat.identity?.isNotEmpty == true
                  ? '缺失角色群聊（${stat.identity}）'
                  : '未绑定角色群聊')
            : stat.identity ?? '未绑定角色卡');
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: missing
            ? () => _showMissing(context, stat, title, group, identities)
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: identity == null ? 44 : 48,
                height: identity == null ? 44 : 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: identity == null
                      ? (missing
                                ? colors.errorContainer
                                : colors.primaryContainer)
                            .withValues(alpha: .6)
                      : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: identity == null
                    ? Icon(
                        Icons.priority_high,
                        color: missing ? colors.error : colors.primary,
                      )
                    : Text(
                        identity.name.isEmpty
                            ? (group ? '群' : '角')
                            : identity.name.characters.first,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    BackupText(
                      '${stat.chats} 个对话 · ${stat.messages} 条消息',
                      small: true,
                    ),
                    if (missing)
                      Text(
                        group ? '点击处理缺失角色群聊条目' : '点击处理缺失角色卡条目',
                        style: TextStyle(fontSize: 12, color: colors.error),
                      ),
                  ],
                ),
              ),
              if (missing)
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatefulWidget {
  const _WorkspaceCard(this.workspaces);
  final List<HistoryWorkspace> workspaces;
  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final selected = <String>{};
  @override
  void didUpdateWidget(_WorkspaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected.retainAll(widget.workspaces.map((e) => e.path));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BackupCard(
      children: [
        const _HistoryHeader('无绑定工作区', '管理未被任何对话使用的工作区文件夹', Icons.folder_off),
        if (widget.workspaces.isEmpty)
          const BackupText('暂无绑定的工作区文件夹')
        else ...[
          _SelectionBar(
            '已选择 ${selected.length} / ${widget.workspaces.length} 个',
            onAll: () => setState(
              () => selected.addAll(widget.workspaces.map((e) => e.path)),
            ),
            onClear: selected.isEmpty ? null : () => setState(selected.clear),
            clearLabel: '清空',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .3),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                primary: false,
                shrinkWrap: true,
                itemCount: widget.workspaces.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = widget.workspaces[index];
                  void toggle() => setState(
                    () => selected.contains(entry.path)
                        ? selected.remove(entry.path)
                        : selected.add(entry.path),
                  );
                  return InkWell(
                    onTap: toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected.contains(entry.path),
                            onChanged: (_) => toggle(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    Text(
                                      entry.location,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: PrimaryColors.of(context).accent,
                                      ),
                                    ),
                                    const BackupText('• 未被任何对话使用', small: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            entry.location == '内部存储'
                                ? Icons.folder
                                : Icons.folder_open,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _HistoryButton(
            '删除选中的工作区 (${selected.length})',
            Icons.delete_outline,
            destructive: true,
            onPressed: selected.isEmpty
                ? null
                : () => _showDelete(
                    context,
                    '确定要删除选中的 ${selected.length} 个工作区吗？\n\n删除后将无法恢复所有文件和数据。',
                  ),
          ),
        ],
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar(
    this.title, {
    required this.onAll,
    required this.onClear,
    this.clearLabel = '取消',
  });
  final String title, clearLabel;
  final VoidCallback? onAll, onClear;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );
      final actions = Wrap(
        spacing: 8,
        children: [
          TextButton(onPressed: onAll, child: const Text('全选')),
          TextButton(onPressed: onClear, child: Text(clearLabel)),
        ],
      );
      if (constraints.maxWidth < 380 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [text, actions],
        );
      }
      return Row(
        children: [
          Expanded(child: text),
          const SizedBox(width: 8),
          actions,
        ],
      );
    },
  );
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton(
    this.label,
    this.icon, {
    required this.onPressed,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: destructive
            ? Theme.of(context).colorScheme.error
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}
