import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_character_avatar.dart';
import 'chat_history_management.dart';
import 'chat_history_swipe.dart';
import 'chat_history_widgets.dart';

typedef _Row = ({
  String key,
  String label,
  String? folder,
  String? binding,
  int depth,
  Conversation? item,
});

/// 目录/折叠为UI投影；拖排只在松手时提交，持久顺序仍来自唯一Rust owner。
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
  Set<String> get collapsed => widget.owner.historyCollapsed;
  final rows = <_Row>[];
  final scroll = ScrollController();
  Timer? clock;
  bool committing = false;
  @override
  void initState() {
    super.initState();
    rebuildRows();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatHistoryList old) {
    super.didUpdateWidget(old);
    // 提交开始的busy通知仍带旧目录，不能把已经让位的拖排草稿跳回原位。
    if (!committing) rebuildRows();
  }

  void rebuildRows() {
    rows.clear();
    final mode = widget.owner.preferences?.historyMode ?? 'folder';
    void folders(
      List<Conversation> items,
      String prefix,
      int depth,
      String? binding,
    ) {
      final names = <String>{for (final c in items) c.folder};
      if (!widget.searching && mode == 'folder') {
        names.addAll(widget.owner.preferences?.folders ?? []);
      }
      for (final folder in names) {
        final key = jsonEncode(['folder', prefix, folder]);
        rows.add((
          key: key,
          label: folder.isEmpty ? '未分组' : folder,
          folder: folder.isEmpty ? null : folder,
          binding: binding,
          depth: depth,
          item: null,
        ));
        if (!widget.searching && collapsed.contains(key)) {
          continue;
        }
        for (final c in items.where((c) => c.folder == folder)) {
          rows.add((
            key: c.id,
            label: c.title,
            folder: null,
            binding: binding,
            depth: depth,
            item: c,
          ));
        }
      }
    }

    if (mode == 'character') {
      for (final id in {for (final c in widget.items) c.characterId}) {
        final members = widget.items.where((c) => c.characterId == id).toList();
        final key = jsonEncode(['character', id]);
        final group = widget.owner.prompts?.groups
            .where((g) => g.id == id)
            .firstOrNull;
        rows.add((
          key: key,
          label: group == null
              ? members.first.characterName
              : '群聊: ${group.draft.name}',
          folder: null,
          binding: id,
          depth: 0,
          item: null,
        ));
        if (!widget.searching && collapsed.contains(key)) continue;
        folders(members, key, 1, id);
      }
    } else {
      folders(
        widget.items,
        mode,
        0,
        mode == 'current' ? historyBinding(widget.owner) : null,
      );
    }
  }

  Widget rail(double height) => SizedBox(
    width: 22,
    child: Padding(
      padding: const EdgeInsets.only(left: 10, right: 8),
      child: Center(
        child: Container(
          width: 2,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: .7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    ),
  );
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (widget.searching ||
        widget.owner.changing ||
        oldIndex < 0 ||
        oldIndex >= rows.length) {
      return;
    }
    final original = rows[oldIndex].item;
    if (original == null) return;
    final proposed = List<_Row>.from(rows);
    final moving = proposed.removeAt(oldIndex);
    proposed.insert(newIndex, moving);
    String? folder, binding;
    bool foundHeader = false;
    for (var i = 0; i <= newIndex; i++) {
      final row = proposed[i];
      if (row.item == null) {
        if (row.key.startsWith('["folder"')) {
          folder = row.folder ?? '';
          binding = row.binding;
          foundHeader = true;
        } else {
          foundHeader = false;
        }
      }
    }
    if (!foundHeader) return;
    final mode = widget.owner.preferences?.historyMode ?? 'folder';
    final targetBinding = mode == 'character'
        ? binding ?? ''
        : original.characterId;
    final candidates = <Conversation>[];
    String currentFolder = '', currentBinding = '';
    for (final row in proposed) {
      if (row.item == null) {
        if (row.key.startsWith('["folder"')) {
          currentFolder = row.folder ?? '';
          currentBinding = row.binding ?? '';
        }
      } else if (currentFolder == folder &&
          (mode != 'character' || currentBinding == targetBinding)) {
        candidates.add(row.item!);
      }
    }
    bool seenNormal = false;
    for (final item in candidates) {
      if (!item.pinned) {
        seenNormal = true;
      } else if (seenNormal) {
        return;
      }
    }
    final bucket = candidates
        .where((c) => c.pinned == original.pinned)
        .toList();
    final index = bucket.indexWhere((c) => c.id == original.id);
    final next = index >= 0 && index + 1 < bucket.length
        ? bucket[index + 1]
        : null;
    final previous = index > 0 ? bucket[index - 1] : null;
    final anchor = next ?? previous;
    setState(() {
      committing = true;
      rows
        ..clear()
        ..addAll(proposed);
    });
    await widget.owner.change(
      original,
      'move',
      jsonEncode({
        'folder': folder,
        'character': targetBinding,
        'anchor': anchor?.id,
        'anchor_revision': anchor?.revision,
        'before': next != null,
      }),
    );
    if (mounted) {
      setState(() {
        committing = false;
        rebuildRows();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ReorderableListView.builder(
        scrollController: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        buildDefaultDragHandles: false,
        itemCount: rows.length,
        onReorderItem: reorder,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 6,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        itemBuilder: (context, index) {
          final row = rows[index];
          return Padding(
            key: ValueKey(row.key),
            padding: const EdgeInsets.only(bottom: 2),
            child: row.item == null ? header(row) : entry(row, index),
          );
        },
      ),
      Positioned(
        right: 0,
        top: 12,
        bottom: 12,
        width: 16,
        child: _HistoryQuickScroll(controller: scroll),
      ),
    ],
  );
  Widget header(_Row row) {
    final colors = Theme.of(context).colorScheme;
    final expanded = widget.searching || !collapsed.contains(row.key);
    final character = row.key.startsWith('["character"');
    void toggle() {
      if (widget.searching) return;
      setState(() {
        if (!collapsed.remove(row.key)) collapsed.add(row.key);
        rebuildRows();
      });
    }

    void manage() => showHistoryFolderManagement(
      context,
      widget.owner,
      row.folder!,
      binding: row.binding,
      onRoute: widget.onRoute,
    );
    Widget semanticButton(Widget child, {bool manageable = false}) => Semantics(
      label: '${row.label}, ${expanded ? '已展开' : '已收起'}',
      button: true,
      enabled: !widget.searching,
      excludeSemantics: true,
      onTap: widget.searching ? null : toggle,
      onLongPress: manageable && !widget.searching ? manage : null,
      child: child,
    );
    if (character) {
      final group = widget.owner.prompts?.groups
          .where((g) => g.id == row.binding)
          .firstOrNull;
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: semanticButton(
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.searching ? null : toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (group == null)
                    ChatCharacterAvatar(
                      characterId: row.binding,
                      size: 24,
                      background: colors.primaryContainer,
                      foreground: colors.onPrimaryContainer,
                    )
                  else
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.groups,
                        size: 15,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (row.depth > 0) rail(36),
          Expanded(
            child: Material(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Expanded(
                    child: semanticButton(
                      InkWell(
                        onTap: widget.searching ? null : toggle,
                        onLongPress: row.folder == null || widget.searching
                            ? null
                            : manage,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 18,
                                  color: historyTone(context, IconTone.folder),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    row.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 20 / 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  expanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      manageable: row.folder != null,
                    ),
                  ),
                  if (row.folder != null)
                    IconButton(
                      tooltip: '管理分组',
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: manage,
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget entry(_Row row, int index) {
    final item = row.item!;
    final colors = Theme.of(context).colorScheme;
    final selected = widget.owner.snapshot?.conversation.id == item.id;
    final enabled = !widget.owner.changing;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final meta = selected
        ? colors.onSecondaryContainer.withValues(alpha: .78)
        : colors.onSurfaceVariant;
    final streaming = widget.owner.executions[item.id]?.active == true;
    final relativeTime = historyTime(item.updatedAt);
    final rowDescription = [
      item.title,
      relativeTime,
      item.folder.isEmpty ? '未分组' : item.folder,
      if (selected) '当前对话',
      if (item.pinned) '已置顶',
      if (item.locked) '已锁定',
      if (streaming) '正在生成',
    ].join(', ');
    void manage() => showHistoryManagement(
      context,
      widget.owner,
      item,
      onRoute: widget.onRoute,
      visible: widget.items,
    );
    Future<void> select() async {
      final route = ModalRoute.of(context);
      if (await widget.owner.select(item.id) && route?.isActive == true) {
        route!.navigator?.removeRoute(route);
      }
    }

    Widget button(Widget icon, String tip, VoidCallback tap) => IconButton(
      tooltip: tip,
      onPressed: enabled ? tap : null,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: icon,
    );
    return Row(
      children: [
        if (row.depth > 0) rail(52),
        Expanded(
          child: HistorySwipe(
            key: ValueKey('swipe-${item.id}'),
            edit: enabled
                ? () => showHistoryMetadata(
                    context,
                    widget.owner,
                    item,
                    onRoute: widget.onRoute,
                  )
                : null,
            delete: enabled && !item.locked
                ? () => showHistoryDelete(
                    context,
                    widget.owner,
                    item,
                    onRoute: widget.onRoute,
                  )
                : null,
            child: Material(
              color: selected
                  ? colors.secondaryContainer
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        enabled: enabled && !widget.searching,
                        child: button(
                          Icon(
                            Icons.drag_handle,
                            size: 16,
                            color: meta.withValues(alpha: .6),
                          ),
                          '拖动项目 ${item.title}',
                          manage,
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: rowDescription,
                          selected: selected,
                          button: true,
                          enabled: enabled,
                          excludeSemantics: true,
                          onTap: enabled ? select : null,
                          onLongPress: enabled ? manage : null,
                          child: InkWell(
                            onLongPress: enabled ? manage : null,
                            onTap: enabled ? select : null,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 20 / 14,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: foreground,
                                            ),
                                          ),
                                        ),
                                        if (streaming) ...[
                                          const SizedBox(width: 4),
                                          const SizedBox.square(
                                            dimension: 11,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                            ),
                                          ),
                                        ],
                                        if (item.pinned) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.push_pin,
                                            size: 13,
                                            color: meta,
                                          ),
                                        ],
                                        if (item.locked) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.lock,
                                            size: 13,
                                            color: meta,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (item.parentTitle != null) ...[
                                          Icon(
                                            Icons.account_tree,
                                            size: 11,
                                            color: meta,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            item.parentTitle == null
                                                ? relativeTime
                                                : '$relativeTime · ${item.parentTitle}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 16 / 11,
                                              color: meta,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      button(
                        Icon(Icons.more_vert, size: 18, color: meta),
                        '管理对话 ${item.title}',
                        manage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryQuickScroll extends StatefulWidget {
  const _HistoryQuickScroll({required this.controller});
  final ScrollController controller;
  @override
  State<_HistoryQuickScroll> createState() => _HistoryQuickScrollState();
}

class _HistoryQuickScrollState extends State<_HistoryQuickScroll> {
  bool handling = false;
  ScrollPosition? observed;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => changed());
  }

  void changed() {
    if (widget.controller.hasClients &&
        observed != widget.controller.position) {
      observed?.isScrollingNotifier.removeListener(changed);
      observed = widget.controller.position;
      observed!.isScrollingNotifier.addListener(changed);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    observed?.isScrollingNotifier.removeListener(changed);
    widget.controller.removeListener(changed);
    super.dispose();
  }

  Future<void> go(double target) async {
    final c = widget.controller;
    final end = target > 0;
    await c.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
    // 惰性列表第一次extent是估算；末行布局后继续校准，不留下尚未显示的尾部。
    for (var i = 0; end && i < 8 && mounted && c.hasClients; i++) {
      WidgetsBinding.instance.ensureVisualUpdate();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          !c.hasClients ||
          c.position.maxScrollExtent - c.offset < 1) {
        break;
      }
      c.jumpTo(c.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final c = widget.controller;
      if (!c.hasClients ||
          !c.position.hasContentDimensions ||
          c.position.maxScrollExtent <= 0) {
        return const SizedBox.shrink();
      }
      final colors = Theme.of(context).colorScheme;
      final p = c.position;
      final max = p.maxScrollExtent;
      // 极短横屏视口仍保留上下入口；只在放不下旧48dp按钮时按可见高度约束。
      final buttonHeight = ((bounds.maxHeight - 16) / 2).clamp(0.0, 48.0);
      Widget button(bool enabled, IconData icon, String label, double target) =>
          SizedBox(
            width: 16,
            height: buttonHeight,
            child: Material(
              color: enabled
                  ? colors.surfaceContainerHighest.withValues(alpha: .62)
                  : Colors.transparent,
              shape: const StadiumBorder(),
              elevation: enabled ? 1 : 0,
              child: InkWell(
                onTap: enabled ? () => go(target) : null,
                child: Icon(
                  icon,
                  size: 14,
                  color: colors.onSurfaceVariant.withValues(
                    alpha: enabled ? 1 : .22,
                  ),
                ),
              ),
            ),
          );
      return Opacity(
        opacity: (handling || p.isScrollingNotifier.value) ? .9 : .5,
        child: Column(
          children: [
            Semantics(
              label: '滚动到顶部',
              button: true,
              child: button(
                p.extentBefore > 0,
                Icons.keyboard_arrow_up,
                '滚动到顶部',
                0,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final fraction =
                        (p.viewportDimension / (p.viewportDimension + max))
                            .clamp(.12, 1.0);
                    final thumb = (bounds.maxHeight * fraction).clamp(
                      bounds.maxHeight < 36 ? bounds.maxHeight : 36.0,
                      bounds.maxHeight,
                    );
                    final travel = (bounds.maxHeight - thumb).clamp(
                      1.0,
                      double.infinity,
                    );
                    void jump(double y) =>
                        c.jumpTo(((y - thumb / 2) / travel).clamp(0, 1) * max);
                    return Semantics(
                      label: '历史记录快速滚动',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => jump(d.localPosition.dy),
                        onVerticalDragStart: (d) {
                          setState(() => handling = true);
                          jump(d.localPosition.dy);
                        },
                        onVerticalDragUpdate: (d) => c.jumpTo(
                          (c.offset + d.delta.dy * max / travel).clamp(0, max),
                        ),
                        onVerticalDragEnd: (_) =>
                            setState(() => handling = false),
                        onVerticalDragCancel: () =>
                            setState(() => handling = false),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 2,
                              height: bounds.maxHeight,
                              decoration: BoxDecoration(
                                color: colors.outlineVariant.withValues(
                                  alpha: .35,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            Positioned(
                              top: (c.offset / max).clamp(0, 1) * travel,
                              child: Container(
                                width: 8,
                                height: thumb,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              label: '滚动到底部',
              button: true,
              child: button(
                p.extentAfter > 0,
                Icons.keyboard_arrow_down,
                '滚动到底部',
                max,
              ),
            ),
          ],
        ),
      );
    },
  );
}
