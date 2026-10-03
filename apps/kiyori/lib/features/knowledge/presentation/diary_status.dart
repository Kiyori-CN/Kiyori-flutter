import 'package:flutter/material.dart';

/// 详情和列表共用旧日记状态徽章；窄屏允许文字换行但不挤压标题到逐字排列。
class DiaryStatus extends StatelessWidget {
  const DiaryStatus({required this.closed, super.key});
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = closed
        ? colors.onSurfaceVariant
        : colors.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: closed
            ? colors.surfaceContainerHighest
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              closed ? Icons.check_circle_outline : Icons.pending_actions,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                closed ? '已完结' : '进行中',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
