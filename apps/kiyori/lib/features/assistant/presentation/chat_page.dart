import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_messages.dart';
import 'chat_dialogs.dart';

/// 原聊天宿主；运行与持久化由注入的共享controller连接Rust。
class ChatPage extends StatefulWidget {
  const ChatPage({
    this.onOpenDrawer = emptyAction,
    this.onOpenModels = emptyAction,
    this.controller,
    super.key,
  });
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenModels;
  final ChatController? controller;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin {
  final draft = TextEditingController();
  String draftId = 'new';
  ChatController? get chat => widget.controller;
  @override
  void initState() {
    super.initState();
    chat?.addListener(changed);
    draft.addListener(saveDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(chat?.load());
    });
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != chat) {
      oldWidget.controller?.removeListener(changed);
      chat?.addListener(changed);
      changed();
    }
  }

  void saveDraft() {
    chat?.drafts[draftId] = draft.text;
  }

  void changed() {
    if (!mounted) return;
    final next = chat?.draftId ?? 'new';
    if (next != draftId) {
      final previous = draft.text;
      final wasNew = draftId == 'new';
      draftId = next;
      draft.text =
          chat?.drafts[next] ??
          (wasNew && next != 'new' && chat?.snapshot?.messages.isEmpty == true
              ? previous
              : '');
    }
    setState(() {});
  }

  void send() {
    final value = draft.text;
    unawaited(
      chat?.send(
        value,
        accepted: () {
          if (mounted && draft.text == value) draft.clear();
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    chat?.removeListener(changed);
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 4),
                ShellAction(
                  Icons.menu,
                  '菜单',
                  onTap: widget.onOpenDrawer,
                  size: 48,
                  iconSize: 21,
                ),
                Expanded(
                  child: Text(
                    chat?.snapshot?.conversation.title ?? 'AI 对话',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const ShellAction(
                  Icons.language,
                  '浏览器',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF2584E9),
                ),
                const ShellAction(
                  Icons.folder_outlined,
                  '文件管理器',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFFB07C07),
                ),
                const ShellAction(
                  Icons.terminal,
                  'AI 电脑',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF657CA8),
                ),
                const ShellAction(
                  Icons.article_outlined,
                  '对话详情',
                  size: 48,
                  iconSize: 21,
                  color: Color(0xFF427FEB),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(height: .5, thickness: .5, color: c.outlineVariant),
          ColoredBox(
            color: c.surfaceContainerHighest.withValues(alpha: .2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  ShellAction(
                    Icons.history,
                    '显示历史',
                    size: 32,
                    color: Color(0xFF2584E9),
                    onTap: () {
                      if (chat != null) showChatHistory(context, chat!);
                    },
                  ),
                  const SizedBox(width: 8),
                  const ShellAction(
                    Icons.picture_in_picture_alt_rounded,
                    '打开悬浮窗',
                    size: 32,
                    color: Color(0xFF607080),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () {
                          if (chat != null) showChatCharacters(context, chat!);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEDF6EF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 16,
                                  color: Color(0xFF34974E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  chat?.character?.draft.name ?? 'Kiyori',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '对话统计',
                    child: SizedBox.square(
                      dimension: 36,
                      child: InkWell(
                        onTap: emptyAction,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: 0,
                                  strokeWidth: 2.5,
                                  backgroundColor: c.surfaceContainerHighest,
                                ),
                                Icon(
                                  Icons.bar_chart_outlined,
                                  size: 15,
                                  color: c.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: chat == null
                ? const SizedBox.expand(key: Key('empty-conversation'))
                : ChatMessages(controller: chat!, onAction: messageAction),
          ),
          if (chat?.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(chat!.error!, style: TextStyle(color: c.error)),
                  ),
                  IconButton(
                    tooltip: '重新载入',
                    onPressed: () => chat!.load(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('chat-draft'),
                  controller: draft,
                  style: const TextStyle(fontSize: 14, height: 20 / 14),
                  minLines: 1,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '请输入您的问题...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: c.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: ShellAction(
                      Icons.fullscreen,
                      '全屏输入',
                      size: 48,
                      iconSize: 24,
                      onTap: () async {
                        final value = await editChatText(
                          context,
                          '输入消息',
                          draft.text,
                        );
                        if (mounted && value != null) draft.text = value;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () async {
                            if (chat != null) {
                              await chat!.load();
                              if (context.mounted) {
                                await showChatModels(
                                  context,
                                  chat!,
                                  widget.onOpenModels,
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: c.outline.withValues(alpha: .2),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    chat?.modelName ?? '未选择',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: c.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ShellAction(Icons.tune, '设置选项', onTap: widget.onOpenModels),
                    const SizedBox(width: 8),
                    const ShellAction(Icons.add, '添加附件', iconSize: 24),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: draft,
                      builder: (context, value, _) {
                        final empty = value.text.trim().isEmpty;
                        final running = chat?.execution?.active ?? false;
                        return ShellAction(
                          running
                              ? Icons.stop
                              : empty
                              ? Icons.mic_none
                              : Icons.send_outlined,
                          running
                              ? '停止生成'
                              : empty
                              ? '语音输入'
                              : '发送',
                          iconSize: 18,
                          color: empty ? c.onSurfaceVariant : c.onPrimary,
                          background: empty ? null : c.primary,
                          onTap: running
                              ? () => unawaited(chat!.stop())
                              : empty
                              ? emptyAction
                              : send,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> messageAction(ConversationMessage message, String action) async {
    final owner = chat;
    final item = owner?.snapshot?.conversation;
    if (owner == null || item == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      return;
    }
    if (action == 'edit' || action == 'resend') {
      final text = await editChatText(
        context,
        action == 'edit' ? '编辑消息' : '编辑并重发',
        message.content,
      );
      if (!mounted ||
          text == null ||
          owner.snapshot?.conversation.id != item.id) {
        return;
      }
      if (action == 'edit') {
        await owner.changeMessage(item, message, 'edit', text);
      } else {
        await owner.send(
          text,
          replaceFrom: message.id,
          revision: item.revision,
        );
      }
    } else if (action == 'regenerate') {
      final messages = owner.snapshot!.messages;
      final index = messages.indexWhere((m) => m.id == message.id);
      final user = messages
          .take(index)
          .where((m) => m.role == 'user')
          .lastOrNull;
      if (user != null &&
          await confirmChatAction(context, '重新生成回复？', '将从这条提问重新生成，后续消息会被移除。') &&
          mounted &&
          owner.snapshot?.conversation.id == item.id) {
        await owner.send(
          user.content,
          replaceFrom: user.id,
          revision: item.revision,
        );
      }
    } else if (await confirmChatAction(
          context,
          action == 'delete' ? '删除消息？' : '回滚到此处？',
          action == 'delete' ? '此消息将从会话中移除。' : '此条及后续消息将被移除，提问会回填输入区。',
        ) &&
        mounted &&
        owner.snapshot?.conversation.id == item.id) {
      if (await owner.changeMessage(
            item,
            message,
            action == 'delete' ? 'delete' : 'deleteFrom',
            '',
          ) &&
          action != 'delete') {
        draft.text = message.content;
      }
    }
  }
}
