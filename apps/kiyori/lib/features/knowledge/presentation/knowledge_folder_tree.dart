import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 目录事实来自 Rust；这里只保存每个空间的展开投影。
class KnowledgeFolderTree extends StatelessWidget {
  const KnowledgeFolderTree({
    required this.paths,
    required this.expanded,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onChoose,
    required this.onMenu,
    super.key,
  });
  final List<String> paths;
  final Set<String> expanded;
  final String selected;
  final bool busy;
  final ValueChanged<String> onToggle, onChoose;
  final void Function(BuildContext, String) onMenu;

  @override
  Widget build(BuildContext context) {
    final children = <String, List<String>>{};
    for (final path in paths) {
      final slash = path.lastIndexOf('/');
      final parent = slash < 0 ? '' : path.substring(0, slash);
      (children[parent] ??= []).add(path);
    }
    for (final list in children.values) {
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    final visible = <(String, int)>[('', 0)];
    // 显式栈防止极深逻辑目录消耗递归栈；缩进与旧源一样最多五级。
    final pending = [
      for (final path in (children[''] ?? []).reversed) (path, 0),
    ];
    while (pending.isNotEmpty) {
      final row = pending.removeLast();
      visible.add(row);
      if (expanded.contains(row.$1)) {
        for (final child in (children[row.$1] ?? []).reversed) {
          pending.add((child, row.$2 + 1));
        }
      }
    }
    return SliverList.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final (path, level) = visible[index];
        final root = path.isEmpty;
        final name = root ? '根目录' : path.split('/').last;
        final hasChildren = !root && (children[path]?.isNotEmpty ?? false);
        final isExpanded = expanded.contains(path);
        final chosen = selected == path;
        final colors = Theme.of(context).colorScheme;
        return Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Semantics(
              selected: chosen,
              child: Material(
                color: chosen
                    ? colors.primaryContainer.withValues(alpha: .8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : () => onChoose(path),
                  onLongPress: busy || root
                      ? null
                      : () => onMenu(context, path),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16 + math.min(level, 5) * 12,
                        right: 4,
                      ),
                      child: Row(
                        children: [
                          if (hasChildren) ...[
                            IconButton(
                              tooltip: '${isExpanded ? '折叠' : '展开'} $name',
                              onPressed: busy ? null : () => onToggle(path),
                              icon: AnimatedRotation(
                                turns: isExpanded ? .25 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Icon(
                            hasChildren && isExpanded
                                ? Icons.folder_open
                                : Icons.folder,
                            size: 20,
                            color: chosen
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: chosen
                                        ? colors.primary
                                        : colors.onSurface,
                                    fontWeight: chosen
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                          ),
                          if (!root)
                            IconButton(
                              tooltip: '$path 的文件夹操作',
                              onPressed: busy
                                  ? null
                                  : () => onMenu(context, path),
                              icon: const Icon(Icons.more_vert, size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
