import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_controller.dart';
import 'chat_history_management.dart';
import 'chat_dialogs.dart';

/// 原历史目录的角色/文件夹层级。折叠只影响投影，搜索始终展开匹配路径。
class ChatHistoryList extends StatefulWidget {
  const ChatHistoryList({
    required this.owner,
    required this.items,
    required this.searching,
    this.onRoute,
    super.key,
  });
  final ChatController owner;
  final List<Conversation> items;
  final bool searching;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<ChatHistoryList> createState() => _ChatHistoryListState();
}

class _ChatHistoryListState extends State<ChatHistoryList> {
  final collapsed = <String>{};
  final rows =
      <
        ({
          String key,
          String label,
          String? folder,
          int depth,
          Conversation? item,
        })
      >[];
  @override
  void initState() {
    super.initState();
    rebuildRows();
  }

  @override
  void didUpdateWidget(ChatHistoryList old) {
    super.didUpdateWidget(old);
    rebuildRows();
  }

  void rebuildRows() {
    rows.clear();
    final mode = widget.owner.preferences?.historyMode ?? 'folder';
    void folders(List<Conversation> items, String prefix, int depth) {
      final names = <String>{for (final c in items) c.folder};
      if (!widget.searching && mode == 'folder') {
        names.addAll(widget.owner.preferences?.folders ?? []);
      }
      for (final folder in names) {
        final key = '$prefix/folder/$folder';
        final members = items.where((c) => c.folder == folder).toList();
        rows.add((
          key: key,
          label: '${folder.isEmpty ? '未分组' : folder} (${members.length})',
          folder: folder.isEmpty ? null : folder,
          depth: depth,
          item: null,
        ));
        if (!widget.searching && collapsed.contains(key)) continue;
        for (final c in members) {
          rows.add((
            key: c.id,
            label: c.title,
            folder: null,
            depth: depth,
            item: c,
          ));
        }
      }
    }

    if (mode == 'character') {
      for (final id in {for (final c in widget.items) c.characterId}) {
        final members = widget.items.where((c) => c.characterId == id).toList();
        final key = 'character/$id';
        rows.add((
          key: key,
          label: '${members.first.characterName} (${members.length})',
          folder: null,
          depth: 0,
          item: null,
        ));
        if (!widget.searching && collapsed.contains(key)) continue;
        folders(members, key, 1);
      }
    } else {
      folders(widget.items, mode, 0);
    }
  }

  String relativeTime(int time) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - time.toInt();
    if (elapsed < 60000) return '刚刚';
    if (elapsed < 3600000) return '${elapsed ~/ 60000} 分钟前';
    if (elapsed < 86400000) return '${elapsed ~/ 3600000} 小时前';
    return '${elapsed ~/ 86400000} 天前';
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    itemCount: rows.length,
    findChildIndexCallback: (key) {
      final index = rows.indexWhere((row) => ValueKey(row.key) == key);
      return index < 0 ? null : index;
    },
    itemBuilder: (context, index) {
      final row = rows[index];
      final item = row.item;
      final colors = Theme.of(context).colorScheme;
      if (item == null) {
        return Padding(
          key: ValueKey(row.key),
          padding: EdgeInsets.only(left: row.depth * 12, top: 4, bottom: 2),
          child: Material(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.searching
                        ? null
                        : () => setState(() {
                            if (!collapsed.remove(row.key)) {
                              collapsed.add(row.key);
                            }
                            rebuildRows();
                          }),
                    onLongPress: row.folder == null
                        ? null
                        : () => showHistoryFolderManagement(
                            context,
                            widget.owner,
                            row.folder!,
                            onRoute: widget.onRoute,
                          ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              row.key.startsWith('character/') && row.depth == 0
                                  ? Icons.person_outline
                                  : Icons.folder_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.label,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              !widget.searching && collapsed.contains(row.key)
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (row.folder != null)
                  IconButton(
                    tooltip: '管理文件夹',
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onPressed: () => showHistoryFolderManagement(
                      context,
                      widget.owner,
                      row.folder!,
                      onRoute: widget.onRoute,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      final selected = widget.owner.snapshot?.conversation.id == item.id;
      void manage() => showHistoryManagement(
        context,
        widget.owner,
        item,
        onRoute: widget.onRoute,
      );
      return Padding(
        key: ValueKey(item.id),
        padding: EdgeInsets.only(left: row.depth * 12, bottom: 2),
        child: gestures(
          item,
          Material(
            color: selected
                ? colors.secondaryContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                LongPressDraggable<Conversation>(
                  data: item,
                  maxSimultaneousDrags:
                      widget.searching || widget.owner.changing ? 0 : 1,
                  feedback: Material(
                    elevation: 6,
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 240,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  child: IconButton(
                    onPressed: manage,
                    tooltip: '移动对话',
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 48,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.drag_handle, size: 16),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onLongPress: manage,
                    onTap: () async {
                      final route = ModalRoute.of(context);
                      if (await widget.owner.select(item.id) &&
                          route?.isActive == true) {
                        route!.navigator?.removeRoute(route);
                      }
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (item.pinned)
                                  const Icon(Icons.push_pin, size: 13),
                                if (item.locked)
                                  const Icon(Icons.lock, size: 13),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              relativeTime(item.updatedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '会话操作',
                  onPressed: manage,
                  icon: const Icon(Icons.more_vert, size: 18),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget gestures(Conversation item, Widget child) => DragTarget<Conversation>(
    onWillAcceptWithDetails: (d) =>
        !widget.searching &&
        !widget.owner.changing &&
        d.data.id != item.id &&
        d.data.folder == item.folder &&
        d.data.pinned == item.pinned &&
        (widget.owner.preferences?.historyMode == 'folder' ||
            d.data.characterId == item.characterId),
    onAcceptWithDetails: (d) => widget.owner.change(d.data, 'before', item.id),
    builder: (context, candidates, rejected) => Dismissible(
      key: ValueKey('swipe-${item.id}'),
      direction: widget.owner.changing
          ? DismissDirection.none
          : item.locked
          ? DismissDirection.startToEnd
          : DismissDirection.horizontal,
      dismissThresholds: {
        DismissDirection.startToEnd: .4,
        DismissDirection.endToStart: .4,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await showHistoryMetadata(
            context,
            widget.owner,
            item,
            onRoute: widget.onRoute,
          );
        } else if (await confirmChatAction(
              context,
              '删除对话？',
              '确定删除“${item.title}”及其全部消息？',
              onRoute: widget.onRoute,
            ) &&
            context.mounted) {
          await widget.owner.change(item, 'delete', '');
        }
        // 正式目录刷新移除行，动画不作为业务成功的事实来源。
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.edit_outlined),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
        ),
        child: child,
      ),
    ),
  );
}
