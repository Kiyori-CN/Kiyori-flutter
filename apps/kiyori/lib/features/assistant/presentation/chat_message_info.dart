import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

class ChatMessageInfo extends StatelessWidget {
  const ChatMessageInfo({required this.message, super.key});
  final ConversationMessage message;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget field(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
    Widget row(String left, String a, String right, String b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [field(left, a), const SizedBox(width: 12), field(right, b)],
    );
    Widget card(List<Widget> children) => Card(
      color: c.surfaceContainerHighest.withValues(alpha: .55),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              child,
            ],
          ],
        ),
      ),
    );
    return AlertDialog(
      title: const Text('消息信息'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            card([
              row(
                '发送方',
                message.role == 'user' ? '用户' : 'AI',
                '角色名',
                message.roleName ?? '未提供',
              ),
              row(
                '提供商',
                '未提供',
                '模型名称',
                message.model.isEmpty ? '未提供' : message.model,
              ),
            ]),
            const SizedBox(height: 12),
            card([
              row(
                '消息时间',
                '未提供',
                '发送时间',
                message.sentAt == null
                    ? '未提供'
                    : DateTime.fromMillisecondsSinceEpoch(message.sentAt!)
                          .toString(),
              ),
              row(
                '等待时长',
                message.firstOutputMs == null
                    ? '未提供'
                    : '${message.firstOutputMs} ms',
                '输出时长',
                message.durationMs == null ? '未提供' : '${message.durationMs} ms',
              ),
            ]),
            const SizedBox(height: 12),
            card([
              row(
                '输入 Token',
                message.inputTokens?.toString() ?? '未提供',
                '输出 Token',
                message.outputTokens?.toString() ?? '未提供',
              ),
              row('缓存 Token', '未提供', '状态', message.state),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
