import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// ClassicChatInputSection 的单行宿主；复用同一草稿和发送/取消命令。
class ChatClassicInput extends StatelessWidget {
  const ChatClassicInput({
    required this.draft,
    required this.running,
    required this.onExpand,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
    required this.onVoice,
    this.reply,
    this.onClearReply,
    this.attachmentsExpanded = false,
    super.key,
  });
  final TextEditingController draft;
  final bool running;
  final bool attachmentsExpanded;
  final VoidCallback onExpand, onAttach, onSend, onStop, onVoice;
  final String? reply;
  final VoidCallback? onClearReply;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reply != null)
          Container(
            margin: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '回复：$reply',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: '取消回复',
                  onPressed: onClearReply,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(
                      color: colors.outline.withValues(alpha: .3),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    key: const Key('chat-draft'),
                    controller: draft,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 13, height: 16 / 13),
                    decoration: InputDecoration(
                      hintText: '请输入您的问题...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                      suffixIcon: ShellAction(
                        Icons.fullscreen,
                        '全屏输入',
                        size: 40,
                        iconSize: 16,
                        onTap: onExpand,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShellAction(
                Icons.add,
                '添加附件',
                iconSize: 18,
                onTap: onAttach,
                background: attachmentsExpanded
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                color: attachmentsExpanded
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder(
                valueListenable: draft,
                builder: (context, value, _) {
                  final empty = value.text.trim().isEmpty;
                  return ShellAction(
                    running
                        ? Icons.close
                        : empty
                        ? Icons.mic_none
                        : Icons.send_outlined,
                    running
                        ? '停止生成'
                        : empty
                        ? '语音输入'
                        : '发送',
                    iconSize: 18,
                    background: running
                        ? colors.error
                        : empty
                        ? colors.surfaceContainerHighest
                        : colors.primary,
                    color: running
                        ? colors.onError
                        : empty
                        ? colors.onSurfaceVariant
                        : colors.onPrimary,
                    onTap: running
                        ? onStop
                        : empty
                        ? onVoice
                        : onSend,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
