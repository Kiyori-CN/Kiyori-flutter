import 'package:flutter/material.dart';

import 'prompt_presentation.dart';

class GroupCardTile extends StatelessWidget {
  const GroupCardTile({
    required this.group,
    required this.memberNames,
    required this.active,
    required this.onAction,
    super.key,
  });
  final GroupPresentation group;
  final List<String> memberNames;
  final bool active;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final secondary = TextStyle(fontSize: 12, color: colors.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          width: .5,
          color: active
              ? colors.primary.withValues(alpha: .35)
              : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.surfaceContainerHighest,
                  child: group.avatarAsset == null
                      ? Icon(
                          Icons.group,
                          size: 22,
                          color: colors.onSurfaceVariant,
                        )
                      : ClipOval(
                          child: Image.asset(
                            group.avatarAsset!,
                            width: 40,
                            height: 40,
                            cacheWidth: 80,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check,
                                size: 14,
                                color: colors.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '当前激活',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: PopupMenuButton<String>(
                    tooltip: '${group.name}菜单',
                    onSelected: onAction,
                    icon: const Icon(Icons.more_vert, size: 20),
                    constraints: const BoxConstraints(minWidth: 120),
                    itemBuilder: (_) => [
                      for (final entry in [
                        if (!active) ('设为活跃', Icons.check),
                        ('编辑', Icons.edit_outlined),
                        ('复制', Icons.content_copy_outlined),
                        ('删除', Icons.delete_outline),
                      ])
                        PopupMenuItem(
                          value: entry.$1,
                          child: Row(
                            children: [
                              Icon(
                                entry.$2,
                                size: 20,
                                color: entry.$1 == '删除'
                                    ? colors.error
                                    : colors.onSurface,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                entry.$1,
                                style: TextStyle(
                                  color: entry.$1 == '删除'
                                      ? colors.error
                                      : colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (group.description.trim().isNotEmpty)
              Text(
                group.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: secondary,
              ),
            Text('成员：${group.members.length}', style: secondary),
            if (memberNames.isNotEmpty)
              Text(
                memberNames.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: secondary,
              ),
          ],
        ),
      ),
    );
  }
}
