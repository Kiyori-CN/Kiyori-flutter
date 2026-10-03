import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_controller.dart';
import 'profile/profile_markdown_preview.dart';

/// 稳定消息ID与局部流通知；用户上翻后停止自动跟随。
class ChatMessages extends StatefulWidget {
  const ChatMessages({
    required this.controller,
    required this.onAction,
    super.key,
  });
  final ChatController controller;
  final Future<void> Function(ConversationMessage, String) onAction;
  @override
  State<ChatMessages> createState() => _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  final scroll = ScrollController();
  String? conversation;
  bool follow = true, scheduled = false;
  ChatExecution? execution;
  @override
  void initState() {
    super.initState();
    sync();
  }

  @override
  void didUpdateWidget(ChatMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  void sync() {
    final id = widget.controller.snapshot?.conversation.id;
    if (id != conversation) {
      conversation = id;
      follow = true;
    }
    final next = widget.controller.execution;
    if (next != execution) {
      execution?.text.removeListener(tail);
      execution = next;
      execution?.text.addListener(tail);
    }
    tail();
  }

  void tail() {
    if (!follow || scheduled || !mounted) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (mounted &&
          follow &&
          scroll.hasClients &&
          (scroll.position.maxScrollExtent - scroll.offset).abs() > 1) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        // 惰性列表的长消息测量会继续修正末尾估算。
        tail();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    execution?.text.removeListener(tail);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final messages = snapshot?.messages ?? const <ConversationMessage>[];
    if (messages.isEmpty) {
      return const SizedBox.expand(key: Key('empty-conversation'));
    }
    final positions = {
      for (final entry in messages.indexed) entry.$2.id: entry.$1,
    };
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (event is ScrollUpdateNotification && event.dragDetails != null ||
            event is UserScrollNotification) {
          follow = event.metrics.extentAfter < 48;
        }
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          tail();
          return false;
        },
        child: ListView.builder(
          key: ValueKey('messages-${snapshot!.conversation.id}'),
          controller: scroll,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          findChildIndexCallback: (key) =>
              key is ValueKey<String> ? positions[key.value] : null,
          itemBuilder: (context, index) {
            final message = messages[index];
            final operation = execution?.messageId == message.id
                ? execution
                : null;
            return ChatMessageTile(
              key: ValueKey(message.id),
              message: message,
              execution: operation,
              enabled: !widget.controller.busy,
              onAction: (action) => widget.onAction(message, action),
            );
          },
        ),
      ),
    );
  }
}

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    required this.message,
    required this.onAction,
    required this.enabled,
    this.execution,
    super.key,
  });
  final ConversationMessage message;
  final ChatExecution? execution;
  final bool enabled;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = message.role == 'user';
    final body = execution?.active == true
        ? ValueListenableBuilder<String>(
            valueListenable: execution!.text,
            builder: (context, text, _) =>
                // 流中纯文本避免逐token反复解析历史Markdown；终态再一次排版。
                SelectableText(
                  text.isEmpty ? message.content : text,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
          )
        : ProfileMarkdownPreview(text: message.content, embedded: true);
    return Container(
      margin: EdgeInsets.fromLTRB(16, user ? 4 : 2, 16, user ? 4 : 8),
      padding: user ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: user
          ? BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user ? 'Prompt' : message.model,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '消息操作',
                onSelected: onAction,
                icon: const Icon(Icons.more_horiz, size: 18),
                constraints: const BoxConstraints(minWidth: 160),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'copy', child: Text('复制')),
                  if (enabled) ...[
                    PopupMenuItem(
                      value: user ? 'resend' : 'regenerate',
                      child: Text(user ? '编辑并重发' : '重新生成'),
                    ),
                    if (!user)
                      const PopupMenuItem(value: 'edit', child: Text('编辑消息')),
                    if (user)
                      const PopupMenuItem(
                        value: 'rollback',
                        child: Text('回滚到此处'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ],
              ),
            ],
          ),
          body,
          if (message.state != 'completed')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                switch (message.state) {
                  'running' => '正在生成…',
                  'cancelled' => '已停止生成',
                  'interrupted' =>
                    message.error.isEmpty ? '生成已中断' : message.error,
                  _ => message.error.isEmpty ? '生成失败' : message.error,
                },
                style: TextStyle(
                  fontSize: 12,
                  color: message.state == 'failed'
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
