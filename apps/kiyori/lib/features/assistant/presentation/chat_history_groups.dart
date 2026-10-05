import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_history_lifetime.dart';
import 'chat_history_widgets.dart';

String historyBinding(ChatController owner) =>
    owner.preferences?.historyMode == 'folder'
    ? ''
    : owner.prompts?.activeGroup ?? owner.character?.id ?? '';

Map<String, int> historyMembers(
  ChatController owner,
  String folder,
  String? binding,
) => {
  for (final c in owner.catalog?.conversations ?? <Conversation>[])
    if (c.folder == folder && (binding == null || c.characterId == binding))
      c.id: c.revision,
};

bool _groupAlive(ChatController owner, String name, String? binding) =>
    historyMembers(owner, name, binding).isNotEmpty ||
    (owner.preferences?.folders.contains(name) == true &&
        owner.catalog?.conversations.any((c) => c.folder == name) != true);

Future<void> showHistoryFolderEditor(
  BuildContext context,
  ChatController owner, {
  String? initial,
  String? binding,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => initial == null
    ? _showHistoryFolderEditor(
        context,
        owner,
        binding: binding,
        onRoute: onRoute,
      )
    : withHistoryEntity(
        owner,
        () => _groupAlive(owner, initial, binding),
        (register) => _showHistoryFolderEditor(
          context,
          owner,
          initial: initial,
          binding: binding,
          onRoute: register,
        ),
        onRoute,
      );

Future<void> _showHistoryFolderEditor(
  BuildContext context,
  ChatController owner, {
  String? initial,
  String? binding,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _FolderEditor(
      owner: owner,
      initial: initial,
      binding: binding,
      onRoute: onRoute,
    );
  },
);

Future<void> showHistoryFolderManagement(
  BuildContext context,
  ChatController owner,
  String folder, {
  String? binding,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => withHistoryEntity(
  owner,
  () => _groupAlive(owner, folder, binding),
  (register) => _showHistoryFolderManagement(
    context,
    owner,
    folder,
    binding: binding,
    onRoute: register,
  ),
  onRoute,
);

Future<void> _showHistoryFolderManagement(
  BuildContext context,
  ChatController owner,
  String folder, {
  String? binding,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) async {
  final action = await showKiyoriModalDrawer<String>(
    context,
    onRoute: onRoute,
    builder: (context, dismiss) => HistoryDrawer(
      title: '管理分组',
      close: () => dismiss(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: historyTone(context, IconTone.folder),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folder,
                  style: const TextStyle(fontSize: 14, height: 20 / 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        HistoryActionRow(
          icon: Icons.drive_file_rename_outline,
          label: '重命名分组',
          onTap: () => dismiss('rename'),
        ),
        const SizedBox(height: 2),
        HistoryActionRow(
          icon: Icons.delete_outline,
          label: '删除分组',
          destructive: true,
          supporting: '可选择连同对话一起删除，或只解散分组。',
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
      binding: binding,
      onRoute: onRoute,
    );
  } else {
    final members = historyMembers(owner, folder, binding);
    await showKiyoriModalDrawer<void>(
      context,
      onRoute: onRoute,
      canDismiss: () => !owner.savingPreference,
      builder: (context, dismiss) => _GroupDelete(
        owner: owner,
        folder: folder,
        binding: binding,
        members: members,
        dismiss: () => dismiss(),
      ),
    );
  }
}

class _GroupDelete extends StatefulWidget {
  const _GroupDelete({
    required this.owner,
    required this.folder,
    required this.binding,
    required this.members,
    required this.dismiss,
  });
  final ChatController owner;
  final String folder;
  final String? binding;
  final Map<String, int> members;
  final VoidCallback dismiss;
  @override
  State<_GroupDelete> createState() => _GroupDeleteState();
}

class _GroupDeleteState extends State<_GroupDelete> {
  bool saving = false;
  String? error;
  Future<void> apply(String action) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.owner.setPreference(
      'history_group',
      jsonEncode({
        'action': action,
        'name': widget.folder,
        'binding': widget.binding,
        'members': widget.members,
      }),
    );
    if (!mounted) return;
    if (ok) widget.dismiss();
    setState(() {
      saving = false;
      error = ok ? null : widget.owner.error;
    });
  }

  @override
  Widget build(BuildContext context) => HistoryDrawer(
    title: '确认删除分组',
    close: saving ? () {} : widget.dismiss,
    footer: Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: saving ? null : widget.dismiss,
        child: const Text('取消'),
      ),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 18,
              color: historyTone(context, IconTone.folder),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.folder,
                style: const TextStyle(fontSize: 14, height: 20 / 14),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          '请选择删除方式：',
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      if (saving)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: LinearProgressIndicator(),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            error!,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      const SizedBox(height: 4),
      HistoryActionRow(
        icon: Icons.folder_outlined,
        label: '仅删除分组',
        tone: IconTone.folder,
        supporting: '对话将移至"未分组"',
        onTap: saving ? null : () => apply('dissolve'),
      ),
      const SizedBox(height: 2),
      HistoryActionRow(
        icon: Icons.delete_outline,
        label: '删除分组和所有对话',
        supporting: '此操作无法撤销',
        destructive: true,
        onTap: saving ? null : () => apply('delete'),
      ),
    ],
  );
}

Future<bool> historyDiscard(
  BuildContext context,
  String message, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        onRoute?.call(ModalRoute.of(context)!);
        return HistoryAlert(
          title: '放弃未保存的修改？',
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃修改'),
            ),
          ],
        );
      },
    ) ??
    false;

class _FolderEditor extends StatefulWidget {
  const _FolderEditor({
    required this.owner,
    this.initial,
    this.binding,
    this.onRoute,
  });
  final ChatController owner;
  final String? initial, binding;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<_FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<_FolderEditor> {
  late final name = TextEditingController(text: widget.initial ?? '');
  late final members = widget.initial == null
      ? <String, int>{}
      : historyMembers(widget.owner, widget.initial!, widget.binding);
  late final binding = widget.initial == null
      ? historyBinding(widget.owner)
      : widget.binding;
  bool saving = false, closing = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (saving || closing) return;
    closing = true;
    if (name.text != (widget.initial ?? '') &&
        !await historyDiscard(
          context,
          '分组名称尚未保存。要放弃此次修改吗？',
          onRoute: widget.onRoute,
        )) {
      closing = false;
      return;
    }
    if (mounted) {
      final r = ModalRoute.of(context)!;
      if (r.isActive) r.navigator?.removeRoute(r);
    }
  }

  Future<void> save() async {
    if (saving || name.text.trim().isEmpty) return;
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.owner.setPreference(
      'history_group',
      jsonEncode({
        'action': widget.initial == null ? 'create' : 'rename',
        'name': widget.initial ?? name.text.trim(),
        'next_name': name.text.trim(),
        'binding': binding,
        'members': members,
      }),
    );
    if (!mounted) return;
    if (ok) {
      final r = ModalRoute.of(context)!;
      if (r.isActive) r.navigator?.removeRoute(r);
    } else {
      setState(() {
        saving = false;
        error = widget.owner.error ?? '分组操作未完成，输入和确认已保留。请核对列表后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: HistoryAlert(
      title: widget.initial == null ? '新建分组' : '重命名分组',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: name,
            enabled: !saving,
            maxLines: 1,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: widget.initial == null ? '分组名称' : '新分组名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: saving ? null : close, child: const Text('取消')),
        FilledButton(
          onPressed: saving || name.text.trim().isEmpty ? null : save,
          child: Text(widget.initial == null ? '创建' : '保存'),
        ),
      ],
    ),
  );
}
