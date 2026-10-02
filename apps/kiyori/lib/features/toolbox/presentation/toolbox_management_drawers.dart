import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_presentation.dart';
import 'toolbox_settings_presentation.dart';
import 'toolbox_settings_session.dart';

Future<void> showToolboxFavorites(
  BuildContext context,
  ToolboxSettingsSession session,
) => session.drawer(
  context,
  (_, dismiss) => _GroupEditor(
    title: '常用工具',
    session: session,
    favorites: true,
    dismiss: dismiss,
  ),
);

Future<void> showToolboxGroups(
  BuildContext context,
  ToolboxSettingsSession session,
) => session.drawer(
  context,
  (_, dismiss) => _Groups(session: session, dismiss: dismiss),
);

class _ToolIcon extends StatelessWidget {
  const _ToolIcon(this.tool);
  final ToolPresentation tool;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tool.$3.containerFor(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Icon(tool.$2, size: 18, color: tool.$3.iconFor(context)),
    ),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
    required this.title,
    required this.session,
    this.groupId,
    required this.dismiss,
    this.favorites = false,
  });
  final String title;
  final ToolboxSettingsSession session;
  final String? groupId;
  final bool favorites;
  final VoidCallback dismiss;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  ToolboxSettingsPresentation get snapshot => widget.session.snapshot;
  List<ToolboxToolPresentation> get ordered => widget.favorites
      ? snapshot.favoriteTools
      : snapshot.group(widget.groupId!)?.tools ?? [];
  List<ToolboxToolPresentation> get available => snapshot.tools
      .where((tool) => !ordered.any((item) => item.id == tool.id))
      .toList();
  // 排序提交仍由领域 owner 接入；不把拖动结果伪造成已保存布局。
  void move(int from, int to) {
    if (!snapshot.enabled) return;
  }

  @override
  void dispose() {
    widget.session.dragging = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: widget.session.canDismiss ? widget.dismiss : null,
                child: const Text('完成'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.favorites ? '长按工具拖动排序，点减号移出常用。' : '长按工具拖动排序，松手后自动保存。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: PrimaryColors.of(context).secondary),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: ToolboxPreferenceNotice(snapshot)),
              if (ordered.isEmpty && snapshot.loaded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      widget.favorites ? '还没有常用工具，从下方添加。' : '此分组暂无可用工具。',
                    ),
                  ),
                ),
              SliverReorderableList(
                itemCount: ordered.length,
                onReorderItem: move,
                onReorderStart: (_) =>
                    setState(() => widget.session.dragging = true),
                onReorderEnd: (_) =>
                    setState(() => widget.session.dragging = false),
                itemBuilder: (context, index) {
                  final tool = ordered[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(tool.id),
                    enabled: snapshot.enabled && ordered.length > 1,
                    index: index,
                    child: Semantics(
                      value: '第 ${index + 1} 项，共 ${ordered.length} 项',
                      customSemanticsActions: {
                        if (snapshot.enabled && index > 0)
                          const CustomSemanticsAction(label: '上移'): () =>
                              move(index, index - 1),
                        if (snapshot.enabled && index < ordered.length - 1)
                          const CustomSemanticsAction(label: '下移'): () =>
                              move(index, index + 1),
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Row(
                                children: [
                                  _ToolIcon(tool.visual),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        tool.visual.$1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.drag_handle,
                                    semanticLabel: '长按拖动排序',
                                    size: 20,
                                    color: PrimaryColors.of(context).accent,
                                  ),
                                  if (widget.favorites)
                                    IconButton(
                                      onPressed: snapshot.enabled
                                          ? emptyAction
                                          : null,
                                      tooltip: '移出常用：${tool.visual.$1}',
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.favorites) ...[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 8),
                        child: Divider(height: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '添加工具 · ${available.length}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                if (available.isEmpty && snapshot.loaded)
                  const SliverToBoxAdapter(child: Text('所有可用工具都已添加。')),
                SliverList.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final tool = available[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: snapshot.enabled ? emptyAction : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  _ToolIcon(tool.visual),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(tool.visual.$1),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                      color: PrimaryColors.of(context).accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// KiyoriDrawerScaffold 的固定标题和操作栏，只有正文消费滚动。
class _DrawerScaffold extends StatelessWidget {
  const _DrawerScaffold({
    required this.title,
    required this.dismiss,
    required this.body,
    required this.footer,
  });
  final String title;
  final VoidCallback? dismiss;
  final Widget body, footer;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 20, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: dismiss,
              tooltip: '关闭',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      Expanded(child: body),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(width: double.infinity, child: footer),
      ),
    ],
  );
}

class _Groups extends StatelessWidget {
  const _Groups({required this.dismiss, required this.session});
  final VoidCallback dismiss;
  final ToolboxSettingsSession session;
  @override
  Widget build(BuildContext context) {
    final snapshot = session.snapshot;
    final groups = snapshot.orderedGroups;
    return _DrawerScaffold(
      title: '管理分组',
      dismiss: session.canDismiss ? dismiss : null,
      body: ListView.builder(
        itemCount: groups.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    '分组只整理工具入口，不影响插件的安装与启停。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: PrimaryColors.of(context).secondary),
                  ),
                ),
                ToolboxPreferenceNotice(snapshot),
              ],
            );
          }
          final group = groups[index - 1];
          final identity = session.identity(group.id);
          return ConstrainedBox(
            key: ValueKey(group.id),
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          group.title,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '${group.tools.length} 个可用工具',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: PrimaryColors.of(context).secondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: snapshot.enabled,
                  tooltip: '管理${group.title}',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    final current = session.snapshot.group(group.id);
                    if (!session.snapshot.enabled ||
                        current == null ||
                        !identical(identity, session.identity(group.id))) {
                      return;
                    }
                    if (action == 'edit') {
                      session.drawer(
                        context,
                        (_, close) => _GroupEditor(
                          title: session.snapshot.group(group.id)?.title ?? '',
                          groupId: group.id,
                          session: session,
                          dismiss: close,
                        ),
                        id: group.id,
                      );
                    } else if (action == 'rename') {
                      session.dialog(
                        context,
                        (_) => _NameDialog(
                          session: session,
                          id: group.id,
                          initialName: current.title,
                        ),
                        id: group.id,
                      );
                    } else if (action == 'delete') {
                      session.dialog(
                        context,
                        (context) =>
                            _DeleteGroup(session: session, id: group.id),
                        id: group.id,
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Builder(
                        builder: (context) {
                          session.registerMenu(context, group.id);
                          return const Text('整理组内顺序');
                        },
                      ),
                    ),
                    PopupMenuItem(
                      value: 'up',
                      enabled: index > 1,
                      child: const Text('上移'),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      enabled: index < groups.length,
                      child: const Text('下移'),
                    ),
                    if (group.custom) ...[
                      const PopupMenuItem(value: 'rename', child: Text('重命名')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除分组',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
      footer: Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: snapshot.enabled
                ? () => session.dialog(
                    context,
                    (_) => _NameDialog(session: session),
                  )
                : null,
            child: const Text('新建分组'),
          ),
          TextButton(
            onPressed: snapshot.enabled && snapshot.tools.isNotEmpty
                ? () => session.drawer(
                    context,
                    (_, close) => _MoveTools(session: session, dismiss: close),
                  )
                : null,
            child: const Text('批量移动工具'),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.session, this.id, this.initialName = ''});
  final ToolboxSettingsSession session;
  final String? id;
  final String initialName;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final snapshot = widget.session.snapshot;
      final error = toolboxGroupNameError(
        value.text,
        snapshot.orderedGroups.where((g) => g.id != widget.id),
      );
      return AlertDialog(
        scrollable: true,
        title: Text(widget.id == null ? '新建分组' : '重命名分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              enabled: snapshot.enabled,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: '分组名称',
                border: const OutlineInputBorder(),
                errorText: value.text.isNotEmpty ? error : null,
                helperText: error ?? '最多 40 个字符',
              ),
            ),
            if (snapshot.error != null)
              Text(
                snapshot.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: snapshot.enabled ? () => Navigator.pop(context) : null,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: snapshot.enabled && error == null ? emptyAction : null,
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}

class _DeleteGroup extends StatelessWidget {
  const _DeleteGroup({required this.session, required this.id});
  final ToolboxSettingsSession session;
  final String id;
  @override
  Widget build(BuildContext context) {
    final snapshot = session.snapshot;
    return AlertDialog(
      scrollable: true,
      title: Text('删除${snapshot.group(id)?.title ?? ''}？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('该组的工具（包括暂时停用的工具）会移入未分组，不会卸载插件。'),
          if (snapshot.error != null)
            Text(
              snapshot.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: snapshot.enabled ? () => Navigator.pop(context) : null,
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: snapshot.enabled ? emptyAction : null,
          child: const Text('删除分组'),
        ),
      ],
    );
  }
}

class _MoveTools extends StatefulWidget {
  const _MoveTools({required this.dismiss, required this.session});
  final VoidCallback dismiss;
  final ToolboxSettingsSession session;
  @override
  State<_MoveTools> createState() => _MoveToolsState();
}

class _MoveToolsState extends State<_MoveTools> {
  final selected = <String>{};
  final search = TextEditingController();
  ToolboxSettingsPresentation get snapshot => widget.session.snapshot;
  List<ToolboxToolPresentation> get tools => snapshot.tools;
  @override
  void didUpdateWidget(covariant _MoveTools oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected.retainAll(tools.map((tool) => tool.id));
    if (snapshot.group(target ?? '') == null) target = null;
  }

  bool choosing = false;
  String? target;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DrawerScaffold(
    title: choosing ? '移动到分组' : '选择工具',
    dismiss: widget.session.canDismiss ? widget.dismiss : null,
    footer: Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: !snapshot.enabled
              ? null
              : () {
                  if (choosing) {
                    setState(() => choosing = false);
                  } else {
                    widget.dismiss();
                  }
                },
          child: Text(choosing ? '上一步' : '取消'),
        ),
        FilledButton(
          onPressed:
              !snapshot.enabled ||
                  selected.isEmpty ||
                  (choosing && target == null)
              ? null
              : () {
                  if (!choosing) setState(() => choosing = true);
                },
          child: Text(
            choosing ? '移动 ${selected.length} 项' : '下一步 · ${selected.length} 项',
          ),
        ),
      ],
    ),
    body: ListView(
      children: [
        ToolboxPreferenceNotice(snapshot),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: choosing
              ? Text(
                  '将所选 ${selected.length} 个工具移到以下分组；常用保持不变。',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : KiyoriSearchField(
                  enabled: snapshot.enabled,
                  controller: search,
                  hint: '搜索工具',
                  onChanged: (_) => setState(() {}),
                ),
        ),
        ...(choosing
            ? [
                for (final group in snapshot.orderedGroups)
                  _selectionRow(
                    label: group.title,
                    selected: target == group.id,
                    radio: true,
                    onTap: () => setState(() => target = group.id),
                  ),
              ]
            : [
                if (!tools.any(_matches))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('未找到相关工具'),
                  ),
                for (final tool in tools.where(_matches))
                  _selectionRow(
                    label: tool.visual.$1,
                    selected: selected.contains(tool.id),
                    tool: tool,
                    onTap: () => setState(
                      () => selected.contains(tool.id)
                          ? selected.remove(tool.id)
                          : selected.add(tool.id),
                    ),
                  ),
              ]),
      ],
    ),
  );
  bool _matches(ToolboxToolPresentation tool) => tool.matches(search.text);
  Widget _selectionRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool radio = false,
    ToolboxToolPresentation? tool,
  }) => Semantics(
    selected: radio ? selected : null,
    checked: radio ? null : selected,
    inMutuallyExclusiveGroup: radio,
    child: InkWell(
      onTap: snapshot.enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (tool != null) ...[
                _ToolIcon(tool.visual),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(label),
                ),
              ),
              ExcludeSemantics(
                child: IgnorePointer(
                  child: radio
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? PrimaryColors.of(context).accent
                                : PrimaryColors.of(context).secondary,
                          ),
                        )
                      : Checkbox(value: selected, onChanged: (_) {}),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
