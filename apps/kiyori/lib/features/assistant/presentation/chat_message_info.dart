import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

class ChatMessageInfo extends StatelessWidget {
  const ChatMessageInfo({required this.message, super.key});
  final ConversationMessage message;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    String duration(int? milliseconds) => milliseconds == null
        ? '未记录'
        : milliseconds >= 1000
        ? '${(milliseconds / 1000).toStringAsFixed(2)} s ($milliseconds ms)'
        : '$milliseconds ms';
    String date(int? milliseconds) {
      if (milliseconds == null || milliseconds <= 0) return '未记录';
      final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      String two(int n) => '$n'.padLeft(2, '0');
      return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${value.millisecond.toString().padLeft(3, '0')}';
    }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                message.roleName?.isNotEmpty == true
                    ? message.roleName!
                    : '未记录',
              ),
              row(
                '提供商',
                '未记录',
                '模型',
                message.model.isEmpty ? '未记录' : message.model,
              ),
            ]),
            const SizedBox(height: 12),
            card([
              row('消息时间', '未记录', '发送时间', date(message.sentAt)),
              row(
                '等待耗时',
                duration(message.firstOutputMs),
                '输出耗时',
                // 消息查询已使用 finished_at-first_output_at；统计查询才是总耗时。
                duration(message.durationMs),
              ),
            ]),
            const SizedBox(height: 12),
            card([
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token 统计',
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '↑ ${message.inputTokens ?? '未记录'}  ↓ ${message.outputTokens ?? '未记录'}  缓存 ${message.cacheReadTokens ?? '未记录'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
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
