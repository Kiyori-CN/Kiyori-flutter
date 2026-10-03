import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_dialogs.dart';

Future<void> showHistoryFolderEditor(
  BuildContext context,
  ChatController owner, {
  String? initial,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _FolderEditor(owner: owner, initial: initial, onRoute: onRoute);
  },
);

Future<void> showHistoryFolderManagement(
  BuildContext context,
  ChatController owner,
  String folder, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) async {
  final action = await showKiyoriModalDrawer<String>(
    context,
    onRoute: onRoute,
    builder: (context, dismiss) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            folder,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('重命名文件夹'),
          onTap: () => dismiss('rename'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('删除文件夹'),
          onTap: () => dismiss('delete'),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  if (action == 'rename') {
    await showHistoryFolderEditor(
      context,
      owner,
      initial: folder,
      onRoute: onRoute,
    );
  } else if (await confirmChatAction(
        context,
        '删除文件夹？',
        '对话将移至未分组，消息不会删除。',
        onRoute: onRoute,
      ) &&
      context.mounted) {
    await owner.setPreference('delete_folder', folder);
  }
}

class _FolderEditor extends StatefulWidget {
  const _FolderEditor({required this.owner, this.initial, this.onRoute});
  final ChatController owner;
  final String? initial;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<_FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<_FolderEditor> {
  late final name = TextEditingController(text: widget.initial ?? '');
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (saving) return;
    if (name.text != (widget.initial ?? '') &&
        !await confirmChatAction(
          context,
          '放弃修改？',
          '尚未保存的修改将丢失。',
          onRoute: widget.onRoute,
        )) {
      return;
    }
    if (mounted) {
      final route = ModalRoute.of(context)!;
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.owner.setPreference(
      widget.initial == null ? 'create_folder' : 'rename_folder',
      widget.initial == null
          ? name.text
          : jsonEncode([widget.initial, name.text]),
    );
    if (!mounted) return;
    if (ok) {
      final route = ModalRoute.of(context)!;
      route.navigator?.removeRoute(route);
    } else {
      setState(() {
        saving = false;
        error = widget.owner.error ?? '保存失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: AlertDialog(
      title: Text(widget.initial == null ? '新建文件夹' : '重命名文件夹'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '文件夹名称'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: saving ? null : close, child: const Text('取消')),
        TextButton(
          onPressed: saving ? null : save,
          child: Text(saving ? '保存中…' : '保存'),
        ),
      ],
    ),
  );
}

Future<void> showHistoryManagement(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) async {
  final action = await showKiyoriModalDrawer<String>(
    context,
    onRoute: onRoute,
    canDismiss: () => !owner.changing,
    builder: (context, dismiss) => AnimatedBuilder(
      animation: owner,
      builder: (context, _) {
        final current = owner.catalog?.conversations
            .where((c) => c.id == item.id)
            .firstOrNull;
        Future<void> change(String action, String value) async {
          if (current == null || owner.changing) return;
          if (await owner.change(current, action, value) && context.mounted) {
            await dismiss();
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '管理对话',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭管理',
                    onPressed: () => dismiss(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text(
                      current?.title ?? item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      current?.folder.isNotEmpty == true
                          ? current!.folder
                          : '未分组',
                    ),
                  ),
                  if (current == null || owner.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        owner.error ?? '对话已不存在',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (owner.changing) const LinearProgressIndicator(),
                  for (final row in <(IconData, String, String, VoidCallback)>[
                    (
                      Icons.edit_outlined,
                      '编辑标题',
                      'rename',
                      () => dismiss('rename'),
                    ),
                    (
                      current?.locked == true ? Icons.lock_open : Icons.lock,
                      current?.locked == true ? '解锁对话' : '锁定对话',
                      'locked',
                      () => change('locked', '${!(current?.locked ?? false)}'),
                    ),
                    (
                      Icons.push_pin,
                      current?.pinned == true ? '取消置顶' : '置顶对话',
                      'pinned',
                      () => change('pinned', '${!(current?.pinned ?? false)}'),
                    ),
                    (
                      Icons.vertical_align_bottom,
                      '移到底部',
                      'bottom',
                      () => change('bottom', ''),
                    ),
                    (Icons.arrow_upward, '上移', 'up', () => change('up', '')),
                    (
                      Icons.arrow_downward,
                      '下移',
                      'down',
                      () => change('down', ''),
                    ),
                    (
                      Icons.info_outline,
                      '对话详情',
                      'details',
                      () => dismiss('details'),
                    ),
                    (
                      Icons.delete_outline,
                      '删除对话',
                      'delete',
                      () => dismiss('delete'),
                    ),
                  ])
                    ListTile(
                      leading: Icon(row.$1, size: 20),
                      title: Text(row.$2, style: const TextStyle(fontSize: 14)),
                      enabled:
                          current != null &&
                          !owner.changing &&
                          (row.$3 != 'delete' || !current.locked),
                      subtitle: row.$3 == 'delete' && current?.locked == true
                          ? const Text('已锁定的对话不能删除')
                          : null,
                      onTap: row.$4,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  if (!context.mounted || action == null) return;
  final current = owner.catalog?.conversations
      .where((c) => c.id == item.id)
      .firstOrNull;
  if (current == null) return;
  if (action == 'rename' || action == 'details') {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        onRoute?.call(ModalRoute.of(context)!);
        return _MetadataEditor(
          owner: owner,
          item: current,
          details: action == 'details',
          onRoute: onRoute,
        );
      },
    );
  } else if (action == 'delete' &&
      await confirmChatAction(
        context,
        '删除对话？',
        '确定删除“${current.title}”及其全部消息？',
        onRoute: onRoute,
      ) &&
      context.mounted) {
    await owner.change(current, 'delete', '');
  }
}

Future<void> showHistoryMetadata(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _MetadataEditor(
      owner: owner,
      item: item,
      details: true,
      onRoute: onRoute,
    );
  },
);

class _MetadataEditor extends StatefulWidget {
  const _MetadataEditor({
    required this.owner,
    required this.item,
    required this.details,
    this.onRoute,
  });
  final ChatController owner;
  final Conversation item;
  final bool details;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<_MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<_MetadataEditor> {
  late final title = TextEditingController(text: widget.item.title);
  late String folder = widget.item.folder;
  late String character = widget.item.characterId;
  bool saving = false;
  String? error;
  bool get dirty =>
      title.text != widget.item.title ||
      folder != widget.item.folder ||
      character != widget.item.characterId;
  Future<void> close() async {
    if (saving) return;
    if (dirty &&
        !await confirmChatAction(
          context,
          '放弃修改？',
          '尚未保存的修改将丢失。',
          onRoute: widget.onRoute,
        )) {
      return;
    }
    if (mounted) {
      final route = ModalRoute.of(context)!;
      route.navigator?.removeRoute(route);
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.owner.change(
        widget.item,
        'metadata',
        jsonEncode({
          'title': title.text,
          'folder': folder,
          'character': character,
        }),
      );
      if (!mounted) return;
      if (!result) {
        setState(() => error = widget.owner.error);
        return;
      }
      if (mounted) {
        final route = ModalRoute.of(context)!;
        route.navigator?.removeRoute(route);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: AlertDialog(
      title: Text(widget.details ? '对话详情' : '编辑标题'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              enabled: !saving,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: character,
                decoration: const InputDecoration(labelText: '绑定角色'),
                items: [
                  for (final card
                      in widget.owner.prompts?.characters ??
                          <PromptCharacter>[])
                    DropdownMenuItem(
                      value: card.id,
                      child: Text(
                        card.draft.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) character = value;
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: folder,
                decoration: const InputDecoration(labelText: '文件夹'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('未分组')),
                  for (final name
                      in widget.owner.preferences?.folders ?? <String>[])
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: saving ? null : (value) => folder = value ?? '',
              ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : close, child: const Text('取消')),
        TextButton(
          onPressed: saving ? null : save,
          child: Text(saving ? '保存中…' : '保存'),
        ),
      ],
    ),
  );
}

Future<void> showHistorySettings(
  BuildContext context,
  ChatController owner, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showKiyoriModalDrawer<void>(
  context,
  onRoute: onRoute,
  builder: (context, dismiss) => AnimatedBuilder(
    animation: owner,
    builder: (context, _) {
      final p = owner.preferences;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '聊天历史设置',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(onPressed: dismiss, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const Text('显示模式'),
                for (final mode in [
                  ('character', '按角色卡归类', '按角色卡显示对应的对话'),
                  ('folder', '按文件夹归类', '按文件夹显示全部对话'),
                  ('current', '仅当前角色', '仅显示当前角色的对话'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Material(
                      color: p?.historyMode == mode.$1
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: Icon(
                          p?.historyMode == mode.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(mode.$2),
                        subtitle: Text(mode.$3),
                        onTap: () =>
                            owner.setPreference('history_mode', mode.$1),
                      ),
                    ),
                  ),
                const Divider(height: 24),
                const Text('切换行为'),
                SwitchListTile(
                  title: const Text('自动切换角色卡'),
                  subtitle: const Text('打开对话时切换到对应角色卡'),
                  value: p?.autoCharacter ?? false,
                  onChanged: (v) => owner.setPreference('auto_character', '$v'),
                ),
                SwitchListTile(
                  title: const Text('自动切换对话'),
                  subtitle: const Text('选择角色时切换到该角色最近的对话'),
                  value: p?.autoChat ?? false,
                  onChanged: (v) => owner.setPreference('auto_chat', '$v'),
                ),
                if (owner.error != null)
                  Text(
                    owner.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: dismiss, child: const Text('完成')),
            ),
          ),
        ],
      );
    },
  ),
);
