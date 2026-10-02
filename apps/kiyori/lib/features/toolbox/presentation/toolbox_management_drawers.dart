import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_presentation.dart';

Future<void> showToolboxFavorites(BuildContext context) =>
    showKiyoriModalDrawer<void>(
      context,
      builder: (_, dismiss) => _GroupEditor(
        title: '常用工具',
        tools: ToolboxPresentation.groups.first.$2,
        favorites: true,
        dismiss: dismiss,
      ),
    );

Future<void> showToolboxGroups(BuildContext context) =>
    showKiyoriModalDrawer<void>(
      context,
      builder: (_, dismiss) => _Groups(dismiss: dismiss),
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
    required this.tools,
    required this.dismiss,
    this.favorites = false,
  });
  final String title;
  final List<ToolPresentation> tools;
  final bool favorites;
  final VoidCallback dismiss;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  // 拖动顺序只是本次抽屉的展示草稿；没有替代领域布局存储。
  late final ordered = [...widget.tools];
  late final available = ToolboxPresentation.all
      .where((tool) => !widget.tools.contains(tool))
      .toList();
  void move(int from, int to) => setState(() {
    ordered.insert(to, ordered.removeAt(from));
  });
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
              TextButton(onPressed: widget.dismiss, child: const Text('完成')),
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
              if (ordered.isEmpty)
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
                itemBuilder: (context, index) {
                  final tool = ordered[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(tool.$1),
                    index: index,
                    child: Semantics(
                      value: '第 ${index + 1} 项，共 ${ordered.length} 项',
                      customSemanticsActions: {
                        if (index > 0)
                          const CustomSemanticsAction(label: '上移'): () =>
                              move(index, index - 1),
                        if (index < ordered.length - 1)
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
                                  _ToolIcon(tool),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        tool.$1,
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
                                      onPressed: emptyAction,
                                      tooltip: '移出常用：${tool.$1}',
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
                          onTap: emptyAction,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  _ToolIcon(tool),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(tool.$1),
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
  final VoidCallback dismiss;
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
  const _Groups({required this.dismiss});
  final VoidCallback dismiss;
  @override
  Widget build(BuildContext context) {
    final groups = ToolboxPresentation.categories;
    return _DrawerScaffold(
      title: '管理分组',
      dismiss: dismiss,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    '分组只整理工具入口，不影响插件的安装与启停。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: PrimaryColors.of(context).secondary),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ConstrainedBox(
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
                                group.$1,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                '${group.$2.length} 个可用工具',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: PrimaryColors.of(context)
                                          .secondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '管理${group.$1}',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            showKiyoriModalDrawer<void>(
                              context,
                              builder: (_, close) => _GroupEditor(
                                title: group.$1,
                                tools: group.$2,
                                dismiss: close,
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('整理组内顺序'),
                          ),
                          PopupMenuItem(
                            value: 'up',
                            enabled: index > 0,
                            child: const Text('上移'),
                          ),
                          PopupMenuItem(
                            value: 'down',
                            enabled: index < groups.length - 1,
                            child: const Text('下移'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _NameDialog(),
            ),
            child: const Text('新建分组'),
          ),
          TextButton(
            onPressed: () => showKiyoriModalDrawer<void>(
              context,
              builder: (_, close) => _MoveTools(dismiss: close),
            ),
            child: const Text('批量移动工具'),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final name = value.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final error = name.isEmpty
          ? '请输入分组名称'
          : name.length > 40
          ? '分组名称不能超过 40 个字符'
          : name.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))
          ? '分组名称不能包含控制字符'
          : [
              '常用工具',
              ...ToolboxPresentation.categories.map((group) => group.$1),
            ].contains(name)
          ? '已存在同名分组'
          : null;
      return AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: '分组名称',
            border: const OutlineInputBorder(),
            errorText: value.text.isNotEmpty ? error : null,
            helperText: error ?? '最多 40 个字符',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: error == null ? emptyAction : null,
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}

class _MoveTools extends StatefulWidget {
  const _MoveTools({required this.dismiss});
  final VoidCallback dismiss;
  @override
  State<_MoveTools> createState() => _MoveToolsState();
}

class _MoveToolsState extends State<_MoveTools> {
  final selected = <String>{};
  final search = TextEditingController();
  final tools = ToolboxPresentation.all;
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
    dismiss: widget.dismiss,
    footer: Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            if (choosing) {
              setState(() => choosing = false);
            } else {
              widget.dismiss();
            }
          },
          child: Text(choosing ? '上一步' : '取消'),
        ),
        FilledButton(
          onPressed: selected.isEmpty || (choosing && target == null)
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: choosing
              ? Text(
                  '将所选 ${selected.length} 个工具移到以下分组；常用保持不变。',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : KiyoriSearchField(
                  controller: search,
                  hint: '搜索工具',
                  onChanged: (_) => setState(() {}),
                ),
        ),
        ...(choosing
            ? [
                for (final group in ToolboxPresentation.categories)
                  _selectionRow(
                    label: group.$1,
                    selected: target == group.$1,
                    radio: true,
                    onTap: () => setState(() => target = group.$1),
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
                    label: tool.$1,
                    selected: selected.contains(tool.$1),
                    tool: tool,
                    onTap: () => setState(
                      () => selected.contains(tool.$1)
                          ? selected.remove(tool.$1)
                          : selected.add(tool.$1),
                    ),
                  ),
              ]),
      ],
    ),
  );
  bool _matches(ToolPresentation tool) =>
      tool.$1.toLowerCase().contains(search.text.trim().toLowerCase());
  Widget _selectionRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool radio = false,
    ToolPresentation? tool,
  }) => Semantics(
    selected: radio ? selected : null,
    checked: radio ? null : selected,
    inMutuallyExclusiveGroup: radio,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (tool != null) ...[_ToolIcon(tool), const SizedBox(width: 10)],
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
