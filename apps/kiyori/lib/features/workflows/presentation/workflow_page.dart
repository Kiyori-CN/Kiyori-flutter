import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'workflow_controller.dart';

class WorkflowPage extends StatefulWidget {
  const WorkflowPage({
    required this.controller,
    required this.onMenu,
    super.key,
  });
  final WorkflowController controller;
  final VoidCallback onMenu;

  @override
  State<WorkflowPage> createState() => WorkflowPageState();
}

class WorkflowPageState extends State<WorkflowPage> {
  String? selectedId;
  DialogRoute<void>? _dialog;
  bool menuOpen = false;
  bool selectionMode = false;
  final selectedIds = <String>{};

  bool handleBack() {
    if (menuOpen) {
      setState(() => menuOpen = false);
      return true;
    }
    if (selectedId != null) {
      setState(() => selectedId = null);
      return true;
    }
    if (selectionMode) {
      setState(() {
        selectionMode = false;
        selectedIds.clear();
      });
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (!widget.controller.loaded && !widget.controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.load());
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    selectedIds.retainAll(widget.controller.records.map((item) => item.id));
    if (widget.controller.loaded && widget.controller.records.isEmpty) {
      selectionMode = false;
    }
    if (selectedId != null &&
        widget.controller.loaded &&
        !widget.controller.records.any((item) => item.id == selectedId)) {
      selectedId = null;
      _removeDialog();
    }
    setState(() {});
  }

  void _removeDialog() {
    final route = _dialog;
    _dialog = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _removeDialog();
    super.dispose();
  }

  Future<void> _show(Widget child) async {
    if (_dialog != null) return;
    final route = DialogRoute<void>(context: context, builder: (_) => child);
    _dialog = route;
    await Navigator.of(context).push(route);
    if (identical(_dialog, route)) _dialog = null;
  }

  void _create() => unawaited(
    _show(
      _CreateWorkflowDialog(
        controller: widget.controller,
        onCreated: (record) {
          if (mounted) setState(() => selectedId = record.id);
        },
      ),
    ),
  );

  void _delete(WorkflowRecord record) => unawaited(
    _show(_DeleteWorkflowDialog(controller: widget.controller, record: record)),
  );

  void _edit(WorkflowRecord record) => unawaited(
    _show(
      _CreateWorkflowDialog(
        controller: widget.controller,
        record: record,
        onCreated: (_) {},
      ),
    ),
  );

  void _deleteSelected() => unawaited(
    _show(
      _DeleteWorkflowDialog(
        controller: widget.controller,
        ids: selectedIds.toList(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    final record = state.records
        .where((item) => item.id == selectedId)
        .firstOrNull;
    return PrimaryPage(
      title: '工作流',
      onMenu: record == null ? widget.onMenu : null,
      onBack: record == null ? null : handleBack,
      actions: [
        if (record == null) ...[
          ShellAction(
            Icons.refresh,
            '刷新工作流',
            onTap: () => unawaited(state.load()),
          ),
        ] else ...[
          const ShellAction(Icons.add, '添加节点'),
        ],
      ],
      child: Stack(
        children: [
          Column(
            children: [
              if (state.error != null)
                MaterialBanner(
                  content: Text(state.error!),
                  actions: [
                    TextButton(
                      onPressed: () => unawaited(state.load()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    color: IconTone.tools.containerFor(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('已选择 ${selectedIds.length} 项'),
                          if (selectedIds.length < state.records.length)
                            TextButton(
                              onPressed: () => setState(
                                () => selectedIds.addAll(
                                  state.records.map((item) => item.id),
                                ),
                              ),
                              child: const Text('全选当前列表'),
                            ),
                          if (selectedIds.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(selectedIds.clear),
                              child: const Text('清空选择'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: state.loading && !state.loaded
                    ? const Center(child: CircularProgressIndicator())
                    : record != null
                    ? _WorkflowDetail(record: record)
                    : state.records.isEmpty
                    ? _WorkflowEmpty(onCreate: _create)
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: state.records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = state.records[index];
                          return Card.outlined(
                            color: selectedIds.contains(item.id)
                                ? IconTone.tools.containerFor(context)
                                : null,
                            child: InkWell(
                              key: ValueKey('workflow-${item.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() {
                                if (selectionMode) {
                                  if (!selectedIds.remove(item.id)) {
                                    selectedIds.add(item.id);
                                  }
                                } else {
                                  selectedId = item.id;
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const ToneBadge(
                                          Icons.play_circle_outline,
                                          IconTone.tools,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (selectionMode)
                                          Checkbox(
                                            value: selectedIds.contains(
                                              item.id,
                                            ),
                                            onChanged: (value) => setState(() {
                                              if (value == true) {
                                                selectedIds.add(item.id);
                                              } else {
                                                selectedIds.remove(item.id);
                                              }
                                            }),
                                          )
                                        else
                                          Transform.scale(
                                            scale: .82,
                                            child: Switch(
                                              value: item.enabled,
                                              activeThumbColor: IconTone.tools
                                                  .iconFor(context),
                                              activeTrackColor: IconTone.tools
                                                  .containerFor(context),
                                              onChanged: state.saving
                                                  ? null
                                                  : (value) => unawaited(
                                                      state.update(
                                                        item,
                                                        enabled: value,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (item.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: .7),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          '0 节点',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: IconTone.tools.iconFor(
                                              context,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDate(item.updatedAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: .5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (menuOpen) ...[
                  if (selectionMode) ...[
                    if (selectedIds.isNotEmpty)
                      _menuAction(
                        '删除选中 (${selectedIds.length})',
                        Icons.delete_outline,
                        IconTone.recycle,
                        _deleteSelected,
                      ),
                    _menuAction(
                      '退出多选',
                      Icons.check_circle,
                      IconTone.success,
                      () => setState(() {
                        selectionMode = false;
                        selectedIds.clear();
                      }),
                    ),
                  ] else if (record == null) ...[
                    _menuAction('新建空白', Icons.add, IconTone.tools, _create),
                    _menuAction(
                      '从模板新建',
                      Icons.play_circle_outline,
                      IconTone.memory,
                      emptyAction,
                    ),
                    _menuAction(
                      '多选',
                      Icons.check_circle,
                      IconTone.ai,
                      () => setState(() {
                        selectionMode = true;
                        selectedIds.clear();
                      }),
                    ),
                  ] else ...[
                    _menuAction(
                      '触发工作流',
                      Icons.play_arrow,
                      IconTone.success,
                      emptyAction,
                    ),
                    _menuAction('查看日志', Icons.call, IconTone.ai, emptyAction),
                    _menuAction(
                      '编辑工作流',
                      Icons.edit_outlined,
                      IconTone.extensionAccent,
                      () => _edit(record),
                    ),
                    _menuAction(
                      '删除工作流',
                      Icons.delete_outline,
                      IconTone.recycle,
                      () => _delete(record),
                    ),
                  ],
                ],
                FloatingActionButton(
                  heroTag: null,
                  tooltip: record == null ? '创建工作流' : '打开操作菜单',
                  backgroundColor: IconTone.tools.containerFor(context),
                  foregroundColor: IconTone.tools.iconFor(context),
                  onPressed: () => setState(() => menuOpen = !menuOpen),
                  child: AnimatedRotation(
                    turns: menuOpen ? .125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuAction(
    String label,
    IconData icon,
    IconTone tone,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(label),
          ),
        ),
        const SizedBox(width: 16),
        FloatingActionButton.small(
          heroTag: null,
          tooltip: label,
          backgroundColor: tone.containerFor(context),
          foregroundColor: tone.iconFor(context),
          onPressed: () {
            setState(() => menuOpen = false);
            action();
          },
          child: Icon(icon),
        ),
      ],
    ),
  );
}

String _formatDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

class _WorkflowEmpty extends StatelessWidget {
  const _WorkflowEmpty({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ToneBadge(
            Icons.play_circle_outline,
            IconTone.tools,
            size: 72,
            iconSize: 38,
          ),
          const SizedBox(height: 24),
          Text(
            '开始创建工作流',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '自动化你的任务流程',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新建工作流'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: IconTone.tools.containerFor(context),
              foregroundColor: IconTone.tools.iconFor(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkflowDetail extends StatelessWidget {
  const _WorkflowDetail({required this.record});
  final WorkflowRecord record;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ToneBadge(Icons.add, IconTone.tools, size: 72, iconSize: 36),
            const SizedBox(height: 12),
            const Text('暂无节点'),
            const SizedBox(height: 8),
            const Text('点击右上角 + 按钮添加节点'),
          ],
        ),
      ),
    ),
  );
}

class _CreateWorkflowDialog extends StatefulWidget {
  const _CreateWorkflowDialog({
    required this.controller,
    required this.onCreated,
    this.record,
  });
  final WorkflowController controller;
  final ValueChanged<WorkflowRecord> onCreated;
  final WorkflowRecord? record;
  @override
  State<_CreateWorkflowDialog> createState() => _CreateWorkflowDialogState();
}

class _CreateWorkflowDialogState extends State<_CreateWorkflowDialog> {
  final name = TextEditingController();
  final description = TextEditingController();
  bool saving = false;
  String? error;
  late bool enabled = widget.record?.enabled ?? true;
  @override
  void initState() {
    super.initState();
    name.text = widget.record?.name ?? '';
    description.text = widget.record?.description ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || name.text.trim().isEmpty) return;
    setState(() {
      saving = true;
      error = null;
    });
    final original = widget.record;
    final WorkflowRecord? result;
    if (original == null) {
      result = await widget.controller.create(name.text, description.text);
    } else {
      result =
          await widget.controller.update(
            original,
            name: name.text,
            description: description.text,
            enabled: enabled,
          )
          ? original
          : null;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (result != null) {
      widget.onCreated(result);
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: widget.record == null
        ? const Center(child: ToneBadge(Icons.add, IconTone.tools))
        : null,
    title: Text(widget.record == null ? '创建工作流' : '编辑工作流'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('workflow-name'),
            controller: name,
            enabled: !saving,
            decoration: settingsFieldDecoration(context, label: '工作流名称'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('workflow-description'),
            controller: description,
            enabled: !saving,
            minLines: 3,
            maxLines: 5,
            decoration: settingsFieldDecoration(context, label: '描述'),
          ),
          if (widget.record != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用工作流'),
              value: enabled,
              onChanged: saving
                  ? null
                  : (value) => setState(() => enabled = value),
            ),
          if (error != null) ...[const SizedBox(height: 12), Text(error!)],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.record == null ? '关闭' : '取消'),
      ),
      TextButton(
        onPressed: saving || name.text.trim().isEmpty ? null : save,
        child: Text(
          saving
              ? '保存中…'
              : widget.record == null
              ? '创建'
              : '保存',
        ),
      ),
    ],
  );
}

class _DeleteWorkflowDialog extends StatefulWidget {
  const _DeleteWorkflowDialog({
    required this.controller,
    this.record,
    this.ids,
  });
  final WorkflowController controller;
  final WorkflowRecord? record;
  final List<String>? ids;
  @override
  State<_DeleteWorkflowDialog> createState() => _DeleteWorkflowDialogState();
}

class _DeleteWorkflowDialogState extends State<_DeleteWorkflowDialog> {
  bool saving = false;
  String? error;
  Future<void> remove() async {
    if (saving) return;
    setState(() => saving = true);
    final deleted = widget.record != null
        ? await widget.controller.delete(widget.record!.id)
        : await widget.controller.deleteMany(widget.ids!);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('确认删除'),
    content: Text(
      error ??
          (widget.record != null
              ? '确定要删除工作流 "${widget.record!.name}" 吗？此操作不可恢复。'
              : '确定要删除选中的 ${widget.ids!.length} 个工作流吗？此操作不可恢复。'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(onPressed: saving ? null : remove, child: const Text('删除')),
    ],
  );
}
