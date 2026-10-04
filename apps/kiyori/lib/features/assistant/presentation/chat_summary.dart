import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 对应旧SummaryMessageComposable；摘要全文只在用户展开时构建。
class ChatSummary extends StatelessWidget {
  const ChatSummary({
    required this.message,
    required this.enabled,
    required this.onAction,
    this.onRoute,
    super.key,
  });
  final ConversationMessage message;
  final bool enabled;
  final ValueChanged<String> onAction;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        key: ValueKey('summary-${message.id}'),
        onTap: () async {
          final action = await showDialog<String>(
            context: context,
            builder: (context) {
              onRoute?.call(ModalRoute.of(context)!);
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: c.surface,
                surfaceTintColor: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '摘要',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: c.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: c.primary.withValues(alpha: .2),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: SingleChildScrollView(
                              child: Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        if (message.state == 'invalidated') ...[
                          const SizedBox(height: 8),
                          Text(
                            '较早的历史已修改，此摘要暂不用于后续请求。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              if (enabled)
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, 'edit'),
                                  child: const Text('编辑'),
                                ),
                              if (enabled)
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, 'delete'),
                                  child: Text(
                                    '删除',
                                    style: TextStyle(color: c.error),
                                  ),
                                ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('关闭'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
          if (context.mounted && action != null) onAction(action);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.primary.withValues(alpha: .5),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info, size: 14, color: c.primary),
                      const SizedBox(width: 4),
                      Text(
                        '摘要',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: c.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: c.primary.withValues(alpha: .5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
