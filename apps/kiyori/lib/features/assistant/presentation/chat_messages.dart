import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_controller.dart';
import 'chat_markdown.dart';

/// 稳定消息ID与局部流通知；用户上翻后停止自动跟随。
class ChatMessages extends StatefulWidget {
  const ChatMessages({
    required this.controller,
    required this.onAction,
    this.onRoute,
    this.selected,
    this.onSelect,
    super.key,
  });
  final ChatController controller;
  final Future<void> Function(ConversationMessage, String) onAction;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  final Set<String>? selected;
  final ValueChanged<ConversationMessage>? onSelect;
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
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event is ScrollUpdateNotification &&
                      event.dragDetails != null ||
                  event is UserScrollNotification) {
                final next = event.metrics.extentAfter < 48;
                if (next != follow) setState(() => follow = next);
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
                  final tile = ChatMessageTile(
                    key: ValueKey(message.id),
                    message: message,
                    roleName: message.roleName ?? '',
                    bubble:
                        widget.controller.preferences?.messageStyle == 'bubble',
                    disableStream:
                        widget.controller.preferences?.disableStream ?? false,
                    execution: operation,
                    enabled: !widget.controller.busy,
                    onAction: (action) => widget.onAction(message, action),
                    onRoute: widget.onRoute,
                  );
                  if (widget.selected == null) return tile;
                  return Row(
                    key: ValueKey(message.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: widget.selected!.contains(message.id),
                        onChanged: (_) => widget.onSelect?.call(message),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onSelect?.call(message),
                          child: AbsorbPointer(child: tile),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (!follow)
          Positioned(
            bottom: 16,
            right: 16,
            child: IconButton.filledTonal(
              tooltip: '返回最新消息',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .75),
              ),
              onPressed: () {
                setState(() => follow = true);
                tail();
              },
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ),
      ],
    );
  }
}

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    required this.message,
    required this.onAction,
    required this.enabled,
    this.execution,
    this.roleName = '',
    this.disableStream = false,
    this.bubble = false,
    this.onRoute,
    super.key,
  });
  final ConversationMessage message;
  final ChatExecution? execution;
  final String roleName;
  final bool disableStream;
  final bool bubble;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  final bool enabled;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = message.role == 'user';
    final variants = message.variantCount < 2
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '上一个回复',
                visualDensity: VisualDensity.compact,
                onPressed: enabled && message.variant > 0
                    ? () => onAction('variant:${message.variant - 1}')
                    : null,
                constraints: const BoxConstraints.tightFor(
                  width: 16,
                  height: 16,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                '${message.variant + 1}/${message.variantCount}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '下一个回复',
                visualDensity: VisualDensity.compact,
                onPressed: enabled && message.variant + 1 < message.variantCount
                    ? () => onAction('variant:${message.variant + 1}')
                    : null,
                constraints: const BoxConstraints.tightFor(
                  width: 16,
                  height: 16,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_forward, size: 16),
              ),
            ],
          );
    final body = user
        ? Text(
            message.content,
            style: const TextStyle(fontSize: 14, height: 20 / 14),
          )
        : _AssistantBody(message: message, execution: execution);
    Future<void> menu(Offset point) async {
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()!
              as RenderBox;
      final local = overlay.globalToLocal(point);
      final actions = <(String, String, IconData)>[
        ('copy', '复制消息', Icons.content_copy_outlined),
        ('speak', '朗读消息', Icons.volume_up_outlined),
        if (enabled) ...[
          if (user) ...[
            ('resend', '编辑并重发', Icons.edit_outlined),
            ('rollback', '回滚到此处', Icons.delete_sweep_outlined),
          ] else ...[
            ('regenerate', '单条重新生成', Icons.refresh_outlined),
            ('edit', '编辑消息', Icons.auto_fix_high),
            if (message.variantCount > 1)
              ('delete_variant', '删除当前回复版本', Icons.delete_outline),
          ],
          ('delete', '删除', Icons.delete_outline),
          if (!user) ('reply', '回复消息', Icons.reply_outlined),
          ('summary', '插入总结', Icons.summarize_outlined),
          ('branch', '创建分支', Icons.account_tree_outlined),
        ],
        ('info', '信息', Icons.info_outline),
        if (enabled) ('select', '多选', Icons.check_circle_outline),
      ];
      final result = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(local.dx, local.dy, 0, 0),
          Offset.zero & overlay.size,
        ),
        constraints: const BoxConstraints.tightFor(width: 180),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        items: [
          for (final entry in actions)
            _RegisteredMessageMenuItem(
              onRoute: onRoute,
              value: entry.$1,
              height: 40,
              child: Row(
                children: [
                  Icon(entry.$3, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.$2, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      );
      if (context.mounted && result != null) onAction(result);
    }

    final bubbleBody = LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: user
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!user && roleName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  roleName,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            Container(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 40) * .85,
                minHeight: 44,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: user
                    ? colors.primaryContainer
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(user ? 20 : 4),
                  topRight: Radius.circular(user ? 4 : 20),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  body,
                  if (!user) variants,
                  if (message.state != 'completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        message.state == 'running'
                            ? '正在生成…'
                            : message.state == 'cancelled'
                            ? '已停止生成'
                            : message.error,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        final avatar = Icon(
          user ? Icons.person : Icons.assistant,
          size: 32,
          color: user ? colors.primary : colors.secondary,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: user
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!user) ...[avatar, const SizedBox(width: 8)],
              Flexible(child: content),
              if (user) ...[const SizedBox(width: 8), avatar],
            ],
          ),
        );
      },
    );
    return Semantics(
      label: '消息操作',
      onLongPress: () => menu(
        (context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) => menu(details.globalPosition),
        onSecondaryTapDown: (details) => menu(details.globalPosition),
        child: bubble
            ? bubbleBody
            : Container(
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
                            user ? 'Prompt' : 'Response',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!user && roleName.isNotEmpty)
                          Flexible(
                            child: Text(
                              roleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurface.withValues(alpha: .5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    body,
                    if (!user) variants,
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
              ),
      ),
    );
  }
}

// 运行终态只更新参数，保留Markdown State及上一帧AST，避免结束时卸载后闪白。
class _AssistantBody extends StatelessWidget {
  const _AssistantBody({required this.message, this.execution});
  final ConversationMessage message;
  final ChatExecution? execution;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: execution?.text ?? const AlwaysStoppedAnimation<String>(''),
    builder: (context, _) => ChatMarkdown(
      text: execution?.active == true && execution!.text.value.isNotEmpty
          ? execution!.text.value
          : message.content,
      streaming: execution?.active ?? false,
    ),
  );
}

class _RegisteredMessageMenuItem extends PopupMenuItem<String> {
  const _RegisteredMessageMenuItem({
    required this.onRoute,
    required super.value,
    required super.height,
    required super.child,
  });
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  PopupMenuItemState<String, _RegisteredMessageMenuItem> createState() =>
      _RegisteredMessageMenuItemState();
}

class _RegisteredMessageMenuItemState
    extends PopupMenuItemState<String, _RegisteredMessageMenuItem> {
  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) widget.onRoute?.call(route);
    return super.build(context);
  }
}
