import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'model_api_connection.dart';
import 'model_api_sections.dart';
import 'model_parameters_card.dart';
import 'function_model_presentation.dart';
import 'models_controller.dart';
import 'model_edit_session.dart';
import 'model_test_results.dart';

/// 目录为核心投影，编辑会话可注入真实保存；纯快照仍不写入。
class ModelApiPage extends StatefulWidget {
  const ModelApiPage({
    this.onOpenLocalModels = emptyAction,
    this.controller,
    this.configurations = const [
      ModelConfigPresentation(id: 'default', name: '默认配置'),
    ],
    super.key,
  });
  final List<ModelConfigPresentation> configurations;
  final ModelsController? controller;
  final VoidCallback onOpenLocalModels;
  @override
  State<ModelApiPage> createState() => _ModelApiPageState();
}

class _ModelApiPageState extends State<ModelApiPage> {
  int selected = 0;
  final visited = <int>{0};
  final sessions = <String, ModelEditSession>{};
  final pending = <String>{};
  final failures = <String>{};
  bool leaving = false, busy = false;

  Future<void> prepare(String id) async {
    final owner = widget.controller;
    if (owner == null || sessions.containsKey(id) || !pending.add(id)) return;
    try {
      final config = owner.catalog!.configs.firstWhere((c) => c.id == id);
      final credentials = await owner.readCredentials(config);
      if (!mounted || !widget.configurations.any((c) => c.id == id)) return;
      sessions[id] = ModelEditSession(owner, config, credentials);
      failures.remove(id);
    } catch (_) {
      failures.add(id);
    } finally {
      pending.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<bool> flush() async {
    if (pending.isNotEmpty) return false;
    for (final session in sessions.values.toList()) {
      await session.poolTest.pause();
      if (!await session.flush()) return false;
    }
    return true;
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    if (widget.controller == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => busy = true);
    final success = await flush();
    if (!mounted) return;
    setState(() {
      busy = false;
      leaving = success;
    });
    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('未能保存模型配置'),
          content: const Text('当前草稿已保留。继续编辑并重试，或放弃未保存的更改后返回。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃更改'),
            ),
          ],
        ),
      );
      if (mounted && discard == true) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.configurations.isNotEmpty) {
      unawaited(prepare(widget.configurations.first.id));
    }
  }

  @override
  void dispose() {
    for (final s in sessions.values) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ModelApiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configurations == widget.configurations) return;
    final removed = sessions.keys
        .where((id) => !widget.configurations.any((c) => c.id == id))
        .toList();
    for (final id in removed) {
      sessions.remove(id)!.dispose();
    }
    final selectedId = selected < oldWidget.configurations.length
        ? oldWidget.configurations[selected].id
        : null;
    final retainedIds = {
      for (final index in visited)
        if (index < oldWidget.configurations.length)
          oldWidget.configurations[index].id,
    };
    selected = widget.configurations.indexWhere(
      (entry) => entry.id == selectedId,
    );
    if (selected < 0) selected = 0;
    visited
      ..clear()
      ..addAll([
        for (var i = 0; i < widget.configurations.length; i++)
          if (retainedIds.contains(widget.configurations[i].id)) i,
      ])
      ..add(selected);
    if (widget.configurations.isNotEmpty) {
      unawaited(prepare(widget.configurations[selected].id));
    }
  }

  Future<void> editName(BuildContext context, {bool rename = false}) {
    final target = widget.configurations[selected];
    return showDialog<void>(
      context: context,
      builder: (_) => _ConfigNameDialog(
        rename: rename,
        name: rename ? target.name : '',
        onSave: widget.controller == null
            ? null
            : (name) async {
                final owner = widget.controller!;
                if (rename) {
                  final session = sessions[target.id];
                  if (session == null) throw StateError('配置未加载');
                  session.update(name: name);
                  if (!await session.flush()) throw StateError('保存失败');
                } else {
                  if (!await flush()) throw StateError('保存失败');
                  final id = await owner.create(name);
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final index = widget.configurations.indexWhere(
                      (c) => c.id == id,
                    );
                    if (index < 0) return;
                    setState(() {
                      selected = index;
                      visited.add(index);
                    });
                    unawaited(prepare(id));
                  });
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.controller == null || leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(leave());
    },
    child: SettingsWorkspacePage(
      title: '模型与 API',
      onBack: leave,
      body: Column(
        children: [
          Expanded(
            // Key 必须位于直接子节点；框架 IndexedStack 的位置包装层会在重排时
            // 丢失内层实体状态，也会使仍打开的配置菜单失去原 State。
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < widget.configurations.length; i++)
                  if (visited.contains(i))
                    Offstage(
                      key: ValueKey(widget.configurations[i].id),
                      offstage: i != selected,
                      child: ExcludeFocus(
                        excluding: i != selected,
                        child: TickerMode(
                          enabled: i == selected,
                          child:
                              widget.controller != null &&
                                  !sessions.containsKey(
                                    widget.configurations[i].id,
                                  )
                              ? Center(
                                  child:
                                      failures.contains(
                                        widget.configurations[i].id,
                                      )
                                      ? TextButton(
                                          onPressed: () => prepare(
                                            widget.configurations[i].id,
                                          ),
                                          child: const Text('安全配置读取失败，点击重试'),
                                        )
                                      : const CircularProgressIndicator(),
                                )
                              : _ModelConfigBody(
                                  session:
                                      sessions[widget.configurations[i].id],
                                  onOpenLocalModels: widget.onOpenLocalModels,
                                  selector: Builder(
                                    builder: (context) => _selector(
                                      context,
                                      widget.configurations[i],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _selector(BuildContext context, ModelConfigPresentation config) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: .5),
          width: .7,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择模型配置',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => editName(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    side: BorderSide(color: colors.primary, width: .8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('新建', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PopupMenuButton<String>(
              tooltip: '选择配置',
              constraints: const BoxConstraints(maxWidth: 280),
              onSelected: (id) async {
                if (busy || !await flush() || !mounted) return;
                // 弹层打开后目录仍可能更新；旧索引不能选择另一个实体或越界。
                final index = widget.configurations.indexWhere(
                  (c) => c.id == id,
                );
                if (index < 0) return;
                await sessions[config.id]?.connectionTest.cancel();
                if (!mounted) return;
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  selected = index;
                  visited.add(index);
                });
                await prepare(id);
              },
              itemBuilder: (_) => [
                for (var i = 0; i < widget.configurations.length; i++)
                  PopupMenuItem(
                    value: widget.configurations[i].id,
                    child: Row(
                      children: [
                        if (i == selected) ...[
                          const Icon(Icons.check, size: 16),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: Text(widget.configurations[i].name)),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        config.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = <Widget>[
                  if (config.id != 'default') ...[
                    _action(
                      '重命名',
                      Icons.edit_outlined,
                      () => editName(context, rename: true),
                    ),
                    _action(
                      '删除',
                      Icons.delete_outline,
                      () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('删除模型配置？'),
                          content: Text(
                            '“${config.name}”将被永久删除。使用此配置的功能需要重新分配模型。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: widget.controller == null
                                  ? () {}
                                  : () async {
                                      final target = widget
                                          .controller!
                                          .catalog!
                                          .configs
                                          .where((c) => c.id == config.id)
                                          .firstOrNull;
                                      if (target == null) return;
                                      try {
                                        await widget.controller!.delete(target);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '删除失败：请先重新分配引用此配置的功能或角色',
                                                  ),
                                                ),
                                              );
                                        }
                                      }
                                    },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (sessions[config.id] case final session?)
                    ListenableBuilder(
                      listenable: session.connectionTest,
                      builder: (context, _) =>
                          _testAction(session.connectionTest.running, () async {
                            if (session.connectionTest.running) {
                              await session.connectionTest.cancel();
                            } else {
                              await session.poolTest.pause();
                              if (await session.flush() &&
                                  mounted &&
                                  identical(sessions[config.id], session)) {
                                unawaited(
                                  session.connectionTest.start(
                                    session.draft,
                                    session.credentials,
                                  ),
                                );
                              }
                            }
                          }),
                    )
                  else
                    _testAction(false, () {}),
                ];
                if (constraints.maxWidth < 400 &&
                    MediaQuery.textScalerOf(context).scale(12) > 18) {
                  return Wrap(spacing: 8, runSpacing: 8, children: actions);
                }
                return Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                );
              },
            ),
            if (sessions[config.id] case final session?)
              ListenableBuilder(
                listenable: session.connectionTest,
                builder: (context, _) =>
                    ModelTestResults(session.connectionTest),
              ),
          ],
        ),
      ),
    );
  }

  Widget _testAction(bool running, VoidCallback onPressed) =>
      FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: running
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.dns, size: 14),
        label: Text(
          running ? '取消' : '测试模型',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _action(String text, IconData icon, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 17),
        label: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

class _ModelConfigBody extends StatelessWidget {
  const _ModelConfigBody({
    required this.selector,
    required this.onOpenLocalModels,
    this.session,
  });
  final Widget selector;
  final VoidCallback onOpenLocalModels;
  final ModelEditSession? session;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selector,
        if (session != null)
          ListenableBuilder(
            listenable: session!,
            builder: (context, _) => session!.error == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session!.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (session!.replacementRequired)
                        DropdownButton<String>(
                          hint: const Text('选择替代模型并保存'),
                          items: [
                            for (final name in session!.draft.models)
                              DropdownMenuItem(value: name, child: Text(name)),
                          ],
                          onChanged: session!.saving
                              ? null
                              : (value) async {
                                  session!.replacement = value;
                                  await session!.flush();
                                },
                        )
                      else
                        TextButton(
                          onPressed: session!.saving ? null : session!.flush,
                          child: const Text('重试保存'),
                        ),
                    ],
                  ),
          ),
        const SizedBox(height: 8),
        ModelApiConnection(
          onOpenLocalModels: onOpenLocalModels,
          session: session,
        ),
        ModelApiContextCards(session: session),
        ModelParametersCard(session: session),
        ModelHeadersCard(session: session),
        ModelAdvancedCard(session: session),
      ],
    ),
  );
}

class _ConfigNameDialog extends StatefulWidget {
  const _ConfigNameDialog({
    required this.rename,
    required this.name,
    this.onSave,
  });
  final Future<void> Function(String)? onSave;
  final bool rename;
  final String name;
  @override
  State<_ConfigNameDialog> createState() => _ConfigNameDialogState();
}

class _ConfigNameDialogState extends State<_ConfigNameDialog> {
  late final name = TextEditingController(text: widget.name);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      scrollable: true,
      title: Text(
        widget.rename ? '重命名模型配置' : '新建模型配置',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.rename ? '修改模型配置的名称' : '创建新的模型配置，自定义API和参数设置',
              style: TextStyle(
                fontSize: 12,
                color: PrimaryColors.of(context).secondary,
              ),
            ),
            const SizedBox(height: 8),
            if (error != null) Text(error!),
            TextField(
              enabled: !busy,
              controller: name,
              decoration: const InputDecoration(
                labelText: '配置名称',
                hintText: '例如: GPT-4配置、Claude配置...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (widget.onSave == null || name.text.trim().isEmpty) return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.onSave!(name.text.trim());
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {
                    if (mounted) setState(() => error = '保存失败，输入已保留');
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(widget.rename ? '确认重命名' : '创建'),
        ),
      ],
    ),
  );
}
