import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_history_groups.dart';
import 'chat_history_widgets.dart';
import 'chat_history_details.dart';
import 'chat_history_lifetime.dart';
import 'chat_history_menu.dart';

export 'chat_history_groups.dart'
    show showHistoryFolderEditor, showHistoryFolderManagement, historyBinding;
export 'chat_history_settings.dart' show showHistorySettings;

Future<void> showHistoryDelete(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => withHistoryEntity(
  owner,
  () => owner.catalog?.conversations.any((c) => c.id == item.id) == true,
  (register) => _showHistoryDelete(context, owner, item, onRoute: register),
  onRoute,
);
Future<void> _showHistoryDelete(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _DeleteChat(owner: owner, item: item);
  },
);

class _DeleteChat extends StatefulWidget {
  const _DeleteChat({required this.owner, required this.item});
  final ChatController owner;
  final Conversation item;
  @override
  State<_DeleteChat> createState() => _DeleteChatState();
}

class _DeleteChatState extends State<_DeleteChat> {
  bool saving = false;
  String? error;
  Future<void> apply() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    final current = widget.owner.catalog?.conversations
        .where((c) => c.id == widget.item.id)
        .firstOrNull;
    final ok =
        current != null && await widget.owner.change(current, 'delete', '');
    if (!mounted) return;
    if (ok) {
      final r = ModalRoute.of(context)!;
      if (r.isActive) r.navigator?.removeRoute(r);
    } else {
      setState(() {
        saving = false;
        error = widget.owner.error ?? '未删除：聊天已锁定、已不存在，或当前会话尚未切换完成。请核对列表后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: HistoryAlert(
      icon: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: '确认删除聊天',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('确定要删除聊天“${widget.item.title}”吗？\n\n此操作不可撤销。'),
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
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: saving ? null : apply,
          child: const Text('确定删除'),
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
  List<Conversation>? visible,
}) => withHistoryEntity(
  owner,
  () => owner.catalog?.conversations.any((c) => c.id == item.id) == true,
  (register) => _showHistoryManagement(
    context,
    owner,
    item,
    onRoute: register,
    visible: visible,
  ),
  onRoute,
);
Future<void> _showHistoryManagement(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
  List<Conversation>? visible,
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
        final all = owner.catalog?.conversations ?? <Conversation>[];
        final mode = owner.preferences?.historyMode ?? 'folder';
        bool same(Conversation c) =>
            current != null &&
            c.folder == current.folder &&
            c.pinned == current.pinned &&
            historySameSortBinding(mode, c.characterId, current.characterId);
        final visibleIds = visible?.map((c) => c.id).toSet();
        final bucket = all
            .where(
              (c) =>
                  same(c) && (visibleIds == null || visibleIds.contains(c.id)),
            )
            .toList();
        final index = bucket.indexWhere((c) => c.id == item.id);
        final complete = all.where(same).toList();
        final enabled = current != null && !owner.changing;
        Future<void> change(
          String action,
          String value, {
          bool close = false,
        }) async {
          if (!enabled) return;
          if (await owner.change(current, action, value) &&
              close &&
              context.mounted) {
            await dismiss();
          }
        }

        return HistoryDrawer(
          title: '管理对话',
          close: () => dismiss(),
          bottomPadding: 4,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current?.title ?? item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${historyTime((current ?? item).updatedAt)} · ${(current ?? item).folder.isEmpty ? '未分组' : (current ?? item).folder}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (current == null || owner.error != null)
                    Text(
                      owner.error ?? '操作未完成，对话可能已变化。请重试或关闭后重新打开。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (owner.changing) const LinearProgressIndicator(),
                ],
              ),
            ),
            HistoryActionRow(
              icon: Icons.edit_outlined,
              label: '编辑标题',
              onTap: enabled ? () => dismiss('rename') : null,
            ),
            HistoryActionRow(
              icon: current?.locked == true
                  ? Icons.lock_open_outlined
                  : Icons.lock,
              label: current?.locked == true ? '解锁对话' : '锁定对话',
              tone: IconTone.tools,
              onTap: enabled
                  ? () => change('locked', '${!current.locked}', close: true)
                  : null,
            ),
            HistoryActionRow(
              icon: current?.pinned == true
                  ? Icons.push_pin_outlined
                  : Icons.push_pin,
              label: current?.pinned == true ? '取消置顶' : '置顶',
              tone: IconTone.memory,
              onTap: enabled
                  ? () => change('pinned', '${!current.pinned}', close: true)
                  : null,
            ),
            HistoryActionRow(
              icon: Icons.vertical_align_bottom,
              label: '置底',
              tone: IconTone.code,
              onTap:
                  enabled && complete.isNotEmpty && complete.last.id != item.id
                  ? () => change('bottom', '')
                  : null,
            ),
            HistoryActionRow(
              icon: Icons.arrow_upward,
              label: '上移',
              tone: IconTone.success,
              onTap: enabled && index > 0
                  ? () => change('before', bucket[index - 1].id)
                  : null,
            ),
            HistoryActionRow(
              icon: Icons.arrow_downward,
              label: '下移',
              onTap: enabled && index >= 0 && index < bucket.length - 1
                  ? () => change('after', bucket[index + 1].id)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                '在当前分组与置顶分区内排序；置底包含搜索隐藏的对话。',
                style: TextStyle(
                  fontSize: 11,
                  height: 16 / 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            HistoryActionRow(
              icon: Icons.info_outline,
              label: '对话详情',
              tone: IconTone.audio,
              onTap: enabled ? () => dismiss('details') : null,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Divider(height: 1),
            ),
            HistoryActionRow(
              icon: Icons.delete_outline,
              label: '删除对话',
              destructive: true,
              supporting: current?.locked == true ? '已锁定的对话不能删除' : null,
              onTap: enabled && !current.locked
                  ? () => dismiss('delete')
                  : null,
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
  if (action == 'rename') {
    await showHistoryMetadata(context, owner, current, onRoute: onRoute);
  } else if (action == 'delete') {
    await showHistoryDelete(context, owner, current, onRoute: onRoute);
  } else if (action == 'details') {
    await showHistoryDetails(context, owner, current, onRoute: onRoute);
  }
}

Future<void> showHistoryMetadata(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => withHistoryEntity(
  owner,
  () => owner.catalog?.conversations.any((c) => c.id == item.id) == true,
  (register) => _showHistoryMetadata(context, owner, item, onRoute: register),
  onRoute,
);
Future<void> _showHistoryMetadata(
  BuildContext context,
  ChatController owner,
  Conversation item, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (context) {
    onRoute?.call(ModalRoute.of(context)!);
    return _MetadataEditor(owner: owner, item: item, onRoute: onRoute);
  },
);

class _MetadataEditor extends StatefulWidget {
  const _MetadataEditor({
    required this.owner,
    required this.item,
    this.onRoute,
  });
  final ChatController owner;
  final Conversation item;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<_MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<_MetadataEditor> {
  late final title = TextEditingController(text: widget.item.title);
  late String character = widget.item.characterId;
  late String characterName = widget.item.characterName;
  late bool groupBinding =
      widget.owner.prompts?.groups.any((g) => g.id == character) == true;
  final bindingMenu = MenuController();
  final bindingField = GlobalKey();
  final bindingFocus = FocusNode();
  double bindingWidth = 0;
  bool saving = false, closing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.owner.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    final p = widget.owner.prompts;
    final card = p?.characters.where((c) => c.id == character).firstOrNull;
    final group = p?.groups.where((g) => g.id == character).firstOrNull;
    if (card != null) {
      characterName = card.draft.name;
      groupBinding = false;
    } else if (group != null) {
      characterName = group.draft.name;
      groupBinding = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.owner.removeListener(changed);
    bindingFocus.dispose();
    title.dispose();
    super.dispose();
  }

  Future<void> close() async {
    // 旧DropdownMenu先消费遮罩和Back；未保存确认只在菜单收起之后出现。
    if (bindingMenu.isOpen) {
      bindingMenu.close();
      return;
    }
    if (saving || closing) return;
    closing = true;
    if ((title.text != widget.item.title ||
            character != widget.item.characterId) &&
        !await historyDiscard(
          context,
          '关闭后，本次未保存的对话标题和角色绑定修改将丢失。',
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
    if (saving || title.text.trim().isEmpty) return;
    bindingMenu.close();
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.owner.change(
      widget.item,
      'metadata',
      jsonEncode({
        'title': title.text,
        'folder': widget.item.folder,
        'character': character,
      }),
    );
    if (!mounted) return;
    if (ok) {
      final r = ModalRoute.of(context)!;
      if (r.isActive) r.navigator?.removeRoute(r);
    } else {
      setState(() {
        saving = false;
        error = widget.owner.error ?? '保存失败，输入已保留。请重试。';
      });
    }
  }

  void toggleBinding() {
    if (saving) return;
    if (bindingMenu.isOpen) {
      bindingMenu.close();
    } else {
      // 量实际字段，避开AlertDialog的固有尺寸测量，也支持大字与键盘。
      final box = bindingField.currentContext!.findRenderObject()! as RenderBox;
      setState(() => bindingWidth = box.size.width);
      bindingMenu.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.owner.prompts;
    final options = <String, String>{
      '': '未绑定',
      for (final c in p?.characters ?? <PromptCharacter>[]) c.id: c.draft.name,
      for (final g in p?.groups ?? <PromptGroup>[]) g.id: '群聊: ${g.draft.name}',
    };
    // 已移除的绑定仍显示原名称供核对，但不能作为当前目录里的可选项。
    final bindingLabel =
        options[character] ??
        (groupBinding ? '缺失角色群聊（$character）' : characterName);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: HistoryAlert(
        title: '编辑标题',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              enabled: !saving,
              maxLines: 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '新标题',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.maxFinite,
              child: HistoryBindingMenu(
                controller: bindingMenu,
                viewport: MediaQuery.of(context),
                focus: bindingFocus,
                onOpen: () => setState(() {}),
                onClose: () => setState(() {}),
                children: [
                  for (final entry in options.entries)
                    MenuItemButton(
                      key: ValueKey('history-binding-option-${entry.key}'),
                      autofocus: entry.key.isEmpty,
                      style: MenuItemButton.styleFrom(
                        minimumSize: Size(bindingWidth, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontSize: 16, height: 24 / 16),
                      ),
                      onPressed: saving
                          ? null
                          : () {
                              bindingMenu.close();
                              setState(() {
                                character = entry.key;
                                characterName = entry.value;
                                groupBinding =
                                    p?.groups.any((g) => g.id == character) ==
                                    true;
                              });
                            },
                      child: SizedBox(
                        width: (bindingWidth - 24).clamp(0, double.infinity),
                        child: Text(entry.value),
                      ),
                    ),
                ],
                builder: (context, controller, _) => Semantics(
                  label: '绑定角色卡',
                  value: bindingLabel,
                  button: true,
                  enabled: !saving,
                  expanded: controller.isOpen,
                  excludeSemantics: true,
                  onTap: saving ? null : toggleBinding,
                  child: FocusableActionDetector(
                    focusNode: bindingFocus,
                    enabled: !saving,
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter):
                          ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.space):
                          ActivateIntent(),
                    },
                    actions: {
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (_) {
                          toggleBinding();
                          return null;
                        },
                      ),
                    },
                    child: SizedBox(
                      key: bindingField,
                      child: GestureDetector(
                        key: const Key('history-binding-field'),
                        behavior: HitTestBehavior.opaque,
                        onTap: saving ? null : toggleBinding,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '绑定角色卡',
                            enabled: !saving,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            suffixIcon: Icon(
                              controller.isOpen
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            bindingLabel,
                            style: TextStyle(
                              fontSize: 16,
                              height: 24 / 16,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: saving ? .38 : 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '仅影响此对话的绑定，不会修改已有消息',
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
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
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: saving ? null : close, child: const Text('取消')),
          FilledButton(
            onPressed: saving || title.text.trim().isEmpty ? null : save,
            child: Text(saving ? '正在保存…' : '保存'),
          ),
        ],
      ),
    );
  }
}
