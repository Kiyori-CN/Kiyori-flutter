import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'model_api_connection.dart';
import 'model_api_sections.dart';
import 'model_parameters_card.dart';
import 'function_model_presentation.dart';

/// 配置目录仅由快照注入。新建、保存、删除和连接测试不产生业务事实。
class ModelApiPage extends StatefulWidget {
  const ModelApiPage({
    this.onOpenLocalModels = emptyAction,
    this.configurations = const [
      ModelConfigPresentation(id: 'default', name: '默认配置'),
    ],
    super.key,
  });
  final List<ModelConfigPresentation> configurations;
  final VoidCallback onOpenLocalModels;
  @override
  State<ModelApiPage> createState() => _ModelApiPageState();
}

class _ModelApiPageState extends State<ModelApiPage> {
  int selected = 0;
  final visited = <int>{0};

  @override
  void didUpdateWidget(ModelApiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configurations == widget.configurations) return;
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
  }

  Future<void> editName(BuildContext context, {bool rename = false}) =>
      showDialog<void>(
        context: context,
        builder: (_) => _ConfigNameDialog(
          rename: rename,
          name: rename ? widget.configurations[selected].name : '',
        ),
      );

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '模型与 API',
    onBack: () => Navigator.of(context).maybePop(),
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
                        child: _ModelConfigBody(
                          onOpenLocalModels: widget.onOpenLocalModels,
                          selector: Builder(
                            builder: (context) =>
                                _selector(context, widget.configurations[i]),
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
              onSelected: (id) {
                // 弹层打开后目录仍可能更新；旧索引不能选择另一个实体或越界。
                final index = widget.configurations.indexWhere(
                  (c) => c.id == id,
                );
                if (index < 0) return;
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  selected = index;
                  visited.add(index);
                });
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
                              onPressed: () {},
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  _action('测试模型', Icons.dns, () {}),
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
          ],
        ),
      ),
    );
  }

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
  });
  final Widget selector;
  final VoidCallback onOpenLocalModels;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selector,
        const SizedBox(height: 8),
        ModelApiConnection(onOpenLocalModels: onOpenLocalModels),
        const ModelApiContextCards(),
        const ModelParametersCard(),
        const ModelHeadersCard(),
        const ModelAdvancedCard(),
      ],
    ),
  );
}

class _ConfigNameDialog extends StatefulWidget {
  const _ConfigNameDialog({required this.rename, required this.name});
  final bool rename;
  final String name;
  @override
  State<_ConfigNameDialog> createState() => _ConfigNameDialogState();
}

class _ConfigNameDialogState extends State<_ConfigNameDialog> {
  late final name = TextEditingController(text: widget.name);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
          TextField(
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
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {},
        child: Text(widget.rename ? '确认重命名' : '创建'),
      ),
    ],
  );
}
