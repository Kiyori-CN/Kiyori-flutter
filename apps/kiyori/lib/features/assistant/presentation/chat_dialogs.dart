import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_controller.dart';
import 'ai_drawer.dart';
import 'chat_model_popup.dart';
import 'chat_modal_session.dart';
import 'chat_characters.dart';
import 'chat_history_management.dart';
import 'chat_history_list.dart';

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
  await owner.load();
  if (!context.mounted || (epoch != null && !session!.valid(epoch))) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '收起对话历史',
    barrierColor: Colors.black.withValues(alpha: .32),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
    pageBuilder: (context, _, _) => _registered(
      context,
      register,
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
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
                                  '聊天历史',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  search.query.text.trim().isEmpty
                                      ? '共 ${owner.catalog?.conversations.length ?? 0} 个对话'
                                      : '匹配 ${search.items.length} / 共 ${owner.catalog?.conversations.length ?? 0}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '聊天历史设置',
                            onPressed: () => showHistorySettings(
                              context,
                              owner,
                              onRoute: register,
                            ),
                            icon: const Icon(Icons.tune, size: 20),
                          ),
                          IconButton(
                            tooltip: '收起对话历史',
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
                        decoration: InputDecoration(
                          hintText: '搜索标题或正文',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: search.query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空搜索',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    search.query.clear();
                                    search.search();
                                  },
                                ),
                          isDense: true,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
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
                                if (await owner.create() && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('新建对话'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '新建文件夹',
                            icon: const Icon(
                              Icons.create_new_folder_outlined,
                              size: 20,
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
                    const Divider(height: 1),
                    if (search.searching) const LinearProgressIndicator(),
                    if (search.failed)
                      TextButton(
                        onPressed: search.search,
                        child: const Text('搜索失败，请重试'),
                      ),
                    if (owner.error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          owner.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child:
                          search.items.isEmpty &&
                              (search.query.text.isNotEmpty ||
                                  owner.preferences?.historyMode != 'folder' ||
                                  owner.preferences?.folders.isEmpty != false)
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 40,
                                ),
                                child: Column(
                                  children: [
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
                                      search.query.text.isEmpty
                                          ? '还没有对话'
                                          : '没有匹配的对话',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      search.query.text.isEmpty
                                          ? '新建一个对话开始协作，之后可以按角色卡或文件夹归类。'
                                          : '没有匹配的聊天记录，请调整筛选条件。',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ChatHistoryList(
                              owner: owner,
                              items: search.items,
                              searching: search.query.text.trim().isNotEmpty,
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
              item.characterId == widget.owner.character?.id))
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
      searching = text.isNotEmpty;
      failed = false;
      if (text.isEmpty) matches = null;
    });
    if (text.isEmpty) return;
    timer = Timer(const Duration(milliseconds: 200), () async {
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
  await owner.load();
  if (!context.mounted || (epoch != null && !session!.valid(epoch))) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭角色选择',
    barrierColor: Colors.black.withValues(alpha: .4),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
    pageBuilder: (context, _, _) => _registered(
      context,
      register,
      ChatCharacters(
        owner: owner,
        onManage: onManage ?? () {},
        onRoute: register,
      ),
    ),
  );
}
