import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart' show IconTone;

import 'chat_controller.dart';
import 'ai_drawer.dart';
import 'chat_model_popup.dart';
import 'chat_modal_session.dart';
import 'chat_characters.dart';
import 'chat_history_management.dart';
import 'chat_history_list.dart';
import 'chat_history_widgets.dart';
import 'chat_panel_route.dart';

Widget _registered(
  BuildContext context,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
  Widget child,
) {
  onRoute?.call(ModalRoute.of(context)!);
  return child;
}

Future<String?> editChatText(
  BuildContext context,
  String title,
  String initial, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<String>(
  context: context,
  builder: (context) => _registered(
    context,
    onRoute,
    _ChatTextDialog(title: title, initial: initial),
  ),
);

class _ChatTextDialog extends StatefulWidget {
  const _ChatTextDialog({required this.title, required this.initial});
  final String title, initial;
  @override
  State<_ChatTextDialog> createState() => _ChatTextDialogState();
}

class _ChatTextDialogState extends State<_ChatTextDialog> {
  late final editor = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: editor,
        autofocus: true,
        minLines: 1,
        maxLines: 12,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, editor.text),
        child: const Text('确定'),
      ),
    ],
  );
}

Future<bool> confirmChatAction(
  BuildContext context,
  String title,
  String message, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
  bool summary = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _registered(
        context,
        onRoute,
        AlertDialog(
          title: Text(title),
          content: Text(message),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            if (summary)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认删除'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
          ],
        ),
      ),
    ) ??
    false;

Future<void> showChatHistory(
  BuildContext context,
  ChatController owner, {
  ChatModalSession? session,
}) async {
  final epoch = session?.epoch;
  final register = epoch == null ? null : session!.registration(epoch);
  if (owner.catalog == null) {
    await owner.load();
  } else {
    unawaited(owner.load());
  }
  if (!context.mounted || (epoch != null && !session!.valid(epoch))) return;
  await Navigator.of(context).push(
    ChatPanelRoute(
      label: '收起对话历史',
      builder: (context) => _registered(
        context,
        register,
        Align(
          alignment: Alignment.centerLeft,
          child: chatPanelTransition(
            context,
            Material(
              key: const Key('chat-history-panel'),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: SafeArea(
                child: SizedBox(
                  width: AiDrawer.widthFor(MediaQuery.sizeOf(context).width),
                  child: _HistorySearchScope(
                    owner: owner,
                    builder: (context, search) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '对话历史',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 24 / 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      search.query.text.trim().isEmpty
                                          ? '共 ${owner.catalog?.conversations.length ?? 0} 个对话'
                                          : '匹配 ${search.items.length} / 共 ${owner.catalog?.conversations.length ?? 0}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 16 / 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '聊天记录设置',
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () => showHistorySettings(
                                  context,
                                  owner,
                                  onRoute: register,
                                ),
                                icon: const Icon(Icons.tune, size: 20),
                              ),
                              IconButton(
                                tooltip: '收起对话历史',
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            key: const Key('chat-history-search'),
                            controller: search.query,
                            onChanged: (_) => search.search(),
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              hintText: '搜索标题或正文',
                              constraints: const BoxConstraints(minHeight: 42),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 42,
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              prefixIcon: search.searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.search, size: 18),
                              suffixIcon: search.query.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清空搜索',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        search.query.clear();
                                        search.search();
                                        FocusScope.of(context).unfocus();
                                      },
                                    ),
                              isDense: true,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: const Color(0xFF9AA0A6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        if (search.failed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
                            child: Text(
                              '正文搜索失败，当前仅显示标题匹配。请重新输入关键词后重试。',
                              style: TextStyle(
                                fontSize: 11,
                                height: 16 / 11,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (await owner.setPreference(
                                          'history_create',
                                          historyBinding(owner),
                                        ) &&
                                        context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('新建对话'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: '新建分组',
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(40, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 20,
                                  color: historyTone(context, IconTone.folder),
                                ),
                                onPressed: () => showHistoryFolderEditor(
                                  context,
                                  owner,
                                  onRoute: register,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (owner.preferences?.showSwipeHint == true &&
                            (owner.catalog?.conversations.isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: .7),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '右滑编辑，左滑删除；点“更多”可管理对话',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .7),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '不再提示',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 28,
                                    height: 28,
                                  ),
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: owner.savingPreference
                                      ? null
                                      : () => owner.setPreference(
                                          'show_swipe_hint',
                                          'false',
                                        ),
                                  icon: const Icon(Icons.close, size: 14),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 1),
                        if (owner.error != null)
                          HistoryInlineBanner(
                            message: owner.error!,
                            dismiss: owner.dismissError,
                          ),
                        Expanded(
                          child:
                              search.items.isEmpty &&
                                  (search.query.text.isNotEmpty ||
                                      owner.preferences?.historyMode !=
                                          'folder' ||
                                      owner.preferences?.folders.isEmpty !=
                                          false)
                              ? SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 36,
                                      vertical: 48,
                                    ),
                                    child: Column(
                                      children: [
                                        if (search.searching)
                                          const SizedBox.square(
                                            dimension: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                            ),
                                          )
                                        else
                                          Icon(
                                            search.query.text.isEmpty
                                                ? Icons.forum_outlined
                                                : Icons.search_off,
                                            size: 40,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: .55),
                                          ),
                                        const SizedBox(height: 10),
                                        Text(
                                          search.searching
                                              ? '正在搜索'
                                              : search.query.text.isEmpty
                                              ? '还没有对话'
                                              : '没有匹配的对话',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 20 / 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          search.searching
                                              ? '正在匹配对话正文，标题结果会先显示。'
                                              : search.query.text.isEmpty
                                              ? '新建一个对话开始协作，之后可以按角色卡或文件夹归类。'
                                              : '没有匹配的聊天记录，请调整筛选条件。',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 16 / 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (!search.searching)
                                          TextButton(
                                            onPressed:
                                                search.query.text.isNotEmpty
                                                ? () {
                                                    search.query.clear();
                                                    search.search();
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                  }
                                                : () async {
                                                    if (await owner
                                                            .setPreference(
                                                              'history_create',
                                                              historyBinding(
                                                                owner,
                                                              ),
                                                            ) &&
                                                        context.mounted) {
                                                      final route =
                                                          ModalRoute.of(
                                                            context,
                                                          );
                                                      if (route?.isActive ==
                                                          true) {
                                                        route!.navigator
                                                            ?.removeRoute(
                                                              route,
                                                            );
                                                      }
                                                    }
                                                  },
                                            child: Text(
                                              search.query.text.isNotEmpty
                                                  ? '清空搜索'
                                                  : '新建对话',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : ChatHistoryList(
                                  owner: owner,
                                  items: search.items,
                                  searching: search.query.text
                                      .trim()
                                      .isNotEmpty,
                                  onRoute: register,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HistorySearchScope extends StatefulWidget {
  const _HistorySearchScope({required this.owner, required this.builder});
  final ChatController owner;
  final Widget Function(BuildContext, _HistorySearchScopeState) builder;
  @override
  State<_HistorySearchScope> createState() => _HistorySearchScopeState();
}

class _HistorySearchScopeState extends State<_HistorySearchScope> {
  final query = TextEditingController();
  Set<String>? matches;
  int generation = 0;
  Timer? timer;
  bool searching = false, failed = false;
  List<Conversation> get items => [
    for (final item in widget.owner.catalog?.conversations ?? <Conversation>[])
      if ((matches == null || matches!.contains(item.id)) &&
          (widget.owner.preferences?.historyMode != 'current' ||
              item.characterId ==
                  (widget.owner.prompts?.activeGroup ??
                      widget.owner.character?.id)))
        item,
  ];

  @override
  void initState() {
    super.initState();
    widget.owner.addListener(changed);
  }

  void changed() {
    if (mounted) {
      setState(() {});
      if (query.text.isNotEmpty) search();
    }
  }

  void search() {
    final version = ++generation;
    timer?.cancel();
    final text = query.text.trim();
    setState(() {
      searching = text.length >= 2;
      failed = false;
      matches = text.isEmpty
          ? null
          : {
              for (final item
                  in widget.owner.catalog?.conversations ?? <Conversation>[])
                if (item.title.toLowerCase().contains(text.toLowerCase()) ||
                    item.folder.toLowerCase().contains(text.toLowerCase()))
                  item.id,
            };
    });
    if (text.length < 2) return;
    timer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await (await widget.owner.connect()).searchConversations(
          text,
        );
        if (!mounted || generation != version) return;
        setState(() {
          matches = result.toSet();
          searching = false;
        });
      } catch (_) {
        if (!mounted || generation != version) return;
        setState(() {
          failed = true;
          searching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    widget.owner.removeListener(changed);
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, this);
}

Future<void> showChatModels(
  BuildContext context,
  ChatController owner,
  VoidCallback onManage, {
  ChatModalSession? session,
}) async {
  final epoch = session?.epoch;
  final register = epoch == null ? null : session!.registration(epoch);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭模型选择',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) => _registered(
      context,
      register,
      ChatModelPopup(owner: owner, onManage: onManage, onRoute: register),
    ),
  );
}

Future<void> showChatCharacters(
  BuildContext context,
  ChatController owner, {
  ChatModalSession? session,
  VoidCallback? onManage,
}) async {
  final epoch = session?.epoch;
  final register = epoch == null ? null : session!.registration(epoch);
  if (owner.prompts == null) {
    await owner.load();
  } else {
    unawaited(owner.load());
  }
  if (!context.mounted || (epoch != null && !session!.valid(epoch))) return;
  await Navigator.of(context).push(
    ChatPanelRoute(
      label: '关闭角色选择',
      fromTop: true,
      builder: (context) => _registered(
        context,
        register,
        ChatCharacters(
          owner: owner,
          onManage: onManage ?? () {},
          onRoute: register,
        ),
      ),
    ),
  );
}
