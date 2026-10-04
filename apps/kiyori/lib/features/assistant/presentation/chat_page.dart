import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_messages.dart';
import 'chat_dialogs.dart';
import 'chat_fullscreen_input.dart';
import 'chat_copy_preview.dart';
import 'chat_message_editor.dart';
import 'chat_modal_session.dart';
import 'chat_statistics.dart';
import 'chat_input_options.dart';
import 'chat_classic_input.dart';
import 'chat_message_info.dart';
import 'chat_input_surface.dart';
import 'chat_history_button.dart';

/// 原聊天宿主；运行与持久化由注入的共享controller连接Rust。
class ChatPage extends StatefulWidget {
  const ChatPage({
    this.onOpenDrawer = emptyAction,
    this.onOpenModels = emptyAction,
    this.onOpenCharacters = emptyAction,
    this.onOpenMemory = emptyAction,
    this.onOpenTools = emptyAction,
    this.controller,
    super.key,
  });
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenCharacters;
  final VoidCallback onOpenMemory, onOpenTools;
  final ChatController? controller;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin {
  final draft = TextEditingController();
  String draftId = 'new';
  ChatController? get chat => widget.controller;
  DialogRoute<void>? fullscreen;
  DialogRoute<void>? messageEditor;
  final modals = ChatModalSession();
  bool openingModel = false, openingHistory = false, openingCharacter = false;
  bool classicAttachments = false;
  Set<String>? selectedMessages;
  String? modalCharacterId;

  void closeMessageEditor() {
    final route = messageEditor;
    messageEditor = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void closeFullscreen() {
    final route = fullscreen;
    fullscreen = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> expandInput() async {
    if (fullscreen != null) return;
    final identity = draftId;
    final owner = chat;
    final route = DialogRoute<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => ChatFullscreenInput(
        initial: draft.value,
        onChanged: (value) {
          if (mounted && chat == owner && draftId == identity) {
            draft.value = value;
          }
        },
      ),
    );
    fullscreen = route;
    await Navigator.of(context).push(route);
    if (fullscreen == route) fullscreen = null;
  }

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
      classicAttachments = false;
      selectedMessages = null;
      modals.invalidate();
      closeFullscreen();
      closeMessageEditor();
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
    final nextCharacter = chat?.character?.id;
    if (modalCharacterId != nextCharacter) {
      modalCharacterId = nextCharacter;
      modals.invalidate();
    }
    if (next != draftId) {
      classicAttachments = false;
      selectedMessages = null;
      modals.invalidate();
      closeFullscreen();
      closeMessageEditor();
      final previous = draft.text;
      final wasNew = draftId == 'new';
      draftId = next;
      draft.text =
          chat?.drafts[next] ??
          (wasNew && next != 'new' && chat?.snapshot?.messages.isEmpty == true
              ? previous
              : '');
    }
    selectedMessages?.removeWhere(
      (id) => chat?.snapshot?.messages.any((m) => m.id == id) != true,
    );
    if (chat?.preferences?.inputStyle != 'classic') classicAttachments = false;
    setState(() {});
  }

  void send() {
    final value = draft.text;
    unawaited(
      chat?.send(
        value,
        accepted: () {
          if (mounted && draft.text == value) draft.clear();
          if (mounted) setState(() => classicAttachments = false);
        },
      ),
    );
  }

  Future<void> openHistory() async {
    final owner = chat;
    if (owner == null || openingHistory) return;
    setState(() => openingHistory = true);
    try {
      await showChatHistory(context, owner, session: modals);
    } finally {
      if (mounted) setState(() => openingHistory = false);
    }
  }

  void openStatistics() {
    final owner = chat;
    if (owner != null) {
      showChatStatistics(
        context,
        owner,
        onRoute: modals.registration(modals.epoch),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    closeFullscreen();
    closeMessageEditor();
    modals.dispose();
    chat?.removeListener(changed);
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).colorScheme;
    final dark = c.brightness == Brightness.dark;
    final characterName = chat?.character?.draft.name ?? 'Kiyori';
    final contextLimit = chat?.contextLimit;
    final contextTokens = chat?.statistics?.contextTokens ?? 0;
    final contextRatio = contextLimit == null || contextLimit <= 0
        ? null
        : contextTokens / contextLimit;
    final contextColor = chatContextColor(context, contextRatio);
    return PopScope(
      canPop: selectedMessages == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedMessages != null) {
          setState(() => selectedMessages = null);
        }
      },
      child: SafeArea(
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
                  ShellAction(
                    Icons.language,
                    '浏览器',
                    size: 48,
                    iconSize: 21,
                    color: Color(dark ? 0xFF7DBAFF : 0xFF2584E9),
                  ),
                  ShellAction(
                    Icons.folder_outlined,
                    '文件管理器',
                    size: 48,
                    iconSize: 21,
                    color: Color(dark ? 0xFFFFD16A : 0xFFB07C07),
                  ),
                  ShellAction(
                    Icons.terminal,
                    'AI 电脑',
                    size: 48,
                    iconSize: 21,
                    color: Color(dark ? 0xFFA9BFEA : 0xFF657CA8),
                  ),
                  ShellAction(
                    Icons.article_outlined,
                    '对话详情',
                    size: 48,
                    iconSize: 21,
                    color: Color(dark ? 0xFF92B8FF : 0xFF427FEB),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Divider(height: .5, thickness: .5, color: c.outlineVariant),
            ColoredBox(
              color: c.surfaceContainerHighest.withValues(alpha: .2),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    ChatHistoryButton(
                      runningCount:
                          chat?.executions.values
                              .where((e) => e.active && e.run != null)
                              .length ??
                          0,
                      expanded: openingHistory,
                      onTap: openHistory,
                    ),
                    const SizedBox(width: 8),
                    ShellAction(
                      Icons.picture_in_picture_alt_rounded,
                      '打开悬浮窗',
                      size: 32,
                      color: Color(dark ? 0xFFCBD5E1 : 0xFF607080),
                      onTap: () => localCapability('悬浮窗', '当前平台尚未接入悬浮聊天窗口。'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () async {
                            if (chat == null || openingCharacter) return;
                            openingCharacter = true;
                            try {
                              await showChatCharacters(
                                context,
                                chat!,
                                session: modals,
                                onManage: widget.onOpenCharacters,
                              );
                            } finally {
                              openingCharacter = false;
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 176),
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
                                  decoration: BoxDecoration(
                                    color: Color(
                                      dark ? 0xFF293729 : 0xFFEDF6EF,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    semanticLabel: 'Character Avatar',
                                    size: 16,
                                    color: Color(
                                      dark ? 0xFF8BDC87 : 0xFF34974E,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 116,
                                    ),
                                    child: Text(
                                      characterName.length > 12
                                          ? '${characterName.substring(0, 12)}…'
                                          : characterName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
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
                      excludeSemantics: true,
                      onTap: openStatistics,
                      value: contextRatio == null
                          ? '上下文占用未提供'
                          : '上下文占用 ${(contextRatio * 100).toStringAsFixed(1)}%',
                      child: SizedBox.square(
                        dimension: 36,
                        child: InkWell(
                          onTap: openStatistics,
                          child: Center(
                            child: SizedBox.square(
                              dimension: 28,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: (contextRatio ?? 0).clamp(0, 1),
                                    strokeWidth: 2.5,
                                    color: contextColor,
                                    backgroundColor: c.surfaceContainerHighest,
                                  ),
                                  if (contextRatio == null)
                                    Icon(
                                      Icons.bar_chart_outlined,
                                      size: 15,
                                      color: contextColor,
                                    )
                                  else
                                    Text(
                                      '${(contextRatio * 100).round().clamp(0, 999)}%',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 9,
                                        height: 1,
                                        fontWeight: FontWeight.w600,
                                        color: contextColor,
                                      ),
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
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: ChatMessages(
                            controller: chat!,
                            onAction: messageAction,
                            onRoute: modals.registration(modals.epoch),
                            selected: selectedMessages,
                            onSelect: (message) => setState(() {
                              if (!selectedMessages!.remove(message.id)) {
                                selectedMessages!.add(message.id);
                              }
                            }),
                          ),
                        ),
                        if (selectedMessages != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: selectionBar(),
                          ),
                        if (selectedMessages == null &&
                            chat?.preferences?.inputStyle == 'classic')
                          Positioned(
                            right: 6,
                            bottom: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 2,
                              ),
                              child: ShellAction(
                                Icons.tune,
                                '设置选项',
                                size: 40,
                                iconSize: 22,
                                onTap: () => showChatInputOptions(
                                  context,
                                  chat!,
                                  onRoute: modals.registration(modals.epoch),
                                  onMemory: widget.onOpenMemory,
                                  onTools: widget.onOpenTools,
                                  onModels: widget.onOpenModels,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (chat?.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat!.error!,
                        style: TextStyle(color: c.error),
                      ),
                    ),
                    IconButton(
                      tooltip: '重新载入',
                      onPressed: () => chat!.load(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            if (chat?.memoryFolders.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('memory_context.xml'),
                    deleteButtonTooltipMessage: '移除记忆附件',
                    onDeleted: chat!.clearMemoryFolders,
                    onPressed: () => showChatCopyPreview(
                      context,
                      '<memory_context>\n<available_folders>\n${chat!.memoryFolders.map((p) => '  - $p').join('\n')}\n</available_folders>\n</memory_context>',
                      onRoute: modals.registration(modals.epoch),
                    ),
                  ),
                ),
              ),
            if (chat?.preferences?.inputStyle == 'classic')
              ChatClassicInput(
                draft: draft,
                running: chat?.execution?.active ?? false,
                onExpand: expandInput,
                onSend: send,
                onStop: () => unawaited(chat?.stop()),
                onVoice: () => localCapability('语音输入', '当前平台尚未接入语音识别服务。'),
                reply: chat?.replyTo?.content,
                onClearReply: () => chat?.clearReply(),
                attachmentsExpanded: classicAttachments,
                onAttach: () {
                  if (chat != null) {
                    setState(() => classicAttachments = !classicAttachments);
                  }
                },
              )
            else
              ChatInputSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chat?.replyTo != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply, size: 16, color: c.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '回复：${chat!.replyTo!.content}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: '取消回复',
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: chat!.clearReply,
                            ),
                          ],
                        ),
                      ),
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
                          onTap: expandInput,
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
                                if (chat != null && !openingModel) {
                                  openingModel = true;
                                  final epoch = modals.epoch;
                                  final owner = chat!;
                                  try {
                                    if (owner.models == null) {
                                      await owner.load();
                                    } else {
                                      unawaited(owner.load());
                                    }
                                    if (context.mounted &&
                                        modals.valid(epoch)) {
                                      await showChatModels(
                                        context,
                                        owner,
                                        widget.onOpenModels,
                                        session: modals,
                                      );
                                    }
                                  } finally {
                                    openingModel = false;
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
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
                        ShellAction(
                          Icons.tune,
                          '设置选项',
                          onTap: () {
                            if (chat != null) {
                              showChatInputOptions(
                                context,
                                chat!,
                                onRoute: modals.registration(modals.epoch),
                                onMemory: widget.onOpenMemory,
                                onTools: widget.onOpenTools,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ShellAction(
                          Icons.add,
                          '添加附件',
                          iconSize: 24,
                          onTap: () {
                            if (chat != null) {
                              showChatInputOptions(
                                context,
                                chat!,
                                attachments: true,
                                onRoute: modals.registration(modals.epoch),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: draft,
                          builder: (context, value, _) {
                            final empty = value.text.trim().isEmpty;
                            final running = chat?.execution?.active ?? false;
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
                              color: running
                                  ? c.onError
                                  : empty
                                  ? c.onSurfaceVariant
                                  : c.onPrimary,
                              background: running
                                  ? c.error
                                  : empty
                                  ? null
                                  : c.primary,
                              onTap: running
                                  ? () => unawaited(chat!.stop())
                                  : empty
                                  ? () => localCapability(
                                      '语音输入',
                                      '当前平台尚未接入语音识别服务。',
                                    )
                                  : send,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (chat != null && chat?.preferences?.inputStyle == 'classic')
              ChatClassicAttachments(
                owner: chat!,
                visible: classicAttachments,
                onDismiss: () {
                  if (mounted) setState(() => classicAttachments = false);
                },
                onRoute: modals.registration(modals.epoch),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> messageAction(ConversationMessage message, String action) async {
    final owner = chat;
    final item = owner?.snapshot?.conversation;
    if (owner == null || item == null) return;
    if (action.startsWith('variant:')) {
      await owner.changeMessage(item, message, 'variant', action.substring(8));
      return;
    }
    if (action == 'delete_variant') {
      await owner.changeMessage(item, message, action, '');
      return;
    }
    if (action == 'select') {
      setState(() => selectedMessages = {message.id});
      return;
    }
    if (action == 'info') {
      await showDialog<void>(
        context: context,
        builder: (context) {
          modals.registration(modals.epoch)(ModalRoute.of(context)!);
          return ChatMessageInfo(message: message);
        },
      );
      return;
    }
    if (action == 'speak' || action == 'summary') {
      await showDialog<void>(
        context: context,
        builder: (context) {
          modals.registration(modals.epoch)(ModalRoute.of(context)!);
          return AlertDialog(
            title: Text(switch (action) {
              'speak' => '朗读消息',
              _ => '插入总结',
            }),
            scrollable: true,
            content: Text(switch (action) {
              'speak' => '当前平台尚未接入语音播放服务。',
              _ => '对话摘要生成服务尚未接入，现有消息保持不变。',
            }),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (action == 'branch') {
      await owner.changeMessage(item, message, 'branch', '');
      return;
    }
    if (action == 'reply') {
      owner.setReply(message);
      return;
    }
    if (action == 'copy') {
      await showChatCopyPreview(
        context,
        message.content,
        onRoute: modals.registration(modals.epoch),
      );
      return;
    }
    if (action == 'edit' || action == 'resend') {
      if (messageEditor != null) return;
      bool current() =>
          mounted &&
          chat == owner &&
          owner.snapshot?.conversation.id == item.id;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChatMessageEditor(
          initial: message.content,
          onSave: (text) async =>
              current() &&
              await owner.changeMessage(item, message, 'edit', text),
          onResend: message.role != 'user'
              ? null
              : (text) async {
                  if (!current()) return false;
                  final accepted = Completer<bool>();
                  unawaited(
                    owner
                        .send(
                          text,
                          replaceFrom: message.id,
                          revision: item.revision,
                          accepted: () {
                            if (!accepted.isCompleted) accepted.complete(true);
                          },
                        )
                        .whenComplete(() {
                          if (!accepted.isCompleted) accepted.complete(false);
                        }),
                  );
                  return accepted.future;
                },
        ),
      );
      messageEditor = route;
      await Navigator.of(context).push(route);
      if (messageEditor == route) messageEditor = null;
    } else if (action == 'regenerate') {
      final messages = owner.snapshot!.messages;
      final index = messages.indexWhere((m) => m.id == message.id);
      final user = messages
          .take(index)
          .where((m) => m.role == 'user')
          .lastOrNull;
      if (user != null &&
          mounted &&
          owner.snapshot?.conversation.id == item.id) {
        await owner.send(
          user.content,
          replaceFrom: message.id,
          revision: item.revision,
        );
      }
    } else if (await confirmChatAction(
          context,
          action == 'delete' ? '删除消息？' : '回滚到此处？',
          action == 'delete' ? '此消息将从会话中移除。' : '此条及后续消息将被移除，提问会回填输入区。',
          onRoute: modals.registration(modals.epoch),
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

  Widget selectionBar() {
    final selected = selectedMessages!;
    final messages = chat!.snapshot!.messages;
    final c = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: c.surface.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ShellAction(
              Icons.close,
              '退出多选',
              iconSize: 18,
              onTap: () => setState(() => selectedMessages = null),
            ),
            const SizedBox(width: 8),
            Text(
              selected.isEmpty ? '多选' : '已选 ${selected.length}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            ShellAction(
              Icons.select_all,
              '全选消息',
              iconSize: 16,
              onTap: () => setState(() {
                selectedMessages = selected.length == messages.length
                    ? {}
                    : messages.map((m) => m.id).toSet();
              }),
            ),
            const SizedBox(width: 6),
            ShellAction(
              Icons.check_circle,
              '加入记忆',
              iconSize: 16,
              background: c.tertiaryContainer,
              onTap: () => localCapability('加入记忆', '对话记忆提取服务尚未接入。'),
            ),
            const SizedBox(width: 6),
            ShellAction(
              Icons.share_outlined,
              '分享选中消息',
              iconSize: 16,
              background: c.primaryContainer,
              onTap: selected.isEmpty
                  ? emptyAction
                  : () => showChatCopyPreview(
                      context,
                      messages
                          .where((m) => selected.contains(m.id))
                          .map((m) => m.content)
                          .join('\n\n'),
                      onRoute: modals.registration(modals.epoch),
                    ),
            ),
            const SizedBox(width: 6),
            ShellAction(
              Icons.delete_outline,
              '删除选中消息',
              iconSize: 16,
              background: c.errorContainer,
              onTap: selected.isEmpty
                  ? emptyAction
                  : () async {
                      final owner = chat!;
                      final snapshot = owner.snapshot!;
                      final ids = selected.toList();
                      if (!await confirmChatAction(
                            context,
                            '删除选中消息？',
                            '确定删除 ${ids.length} 条消息？',
                            onRoute: modals.registration(modals.epoch),
                          ) ||
                          !mounted ||
                          owner.snapshot?.conversation.id !=
                              snapshot.conversation.id) {
                        return;
                      }
                      final first = snapshot.messages
                          .where((m) => ids.contains(m.id))
                          .first;
                      if (await owner.changeMessage(
                            snapshot.conversation,
                            first,
                            'delete_selected',
                            jsonEncode(ids),
                          ) &&
                          mounted) {
                        setState(() => selectedMessages = null);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> localCapability(String title, String reason) => showDialog<void>(
    context: context,
    builder: (context) {
      modals.registration(modals.epoch)(ModalRoute.of(context)!);
      return AlertDialog(
        title: Text(title),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}
