import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum ToolPermissionChoice {
  allow('允许', '这些工具将自动运行。'),
  ask('询问', '所有工具的默认行为。'),
  forbid('禁止', '这些工具永远不会运行。');

  const ToolPermissionChoice(this.title, this.description);
  final String title, description;
}

class PermissionToolPresentation {
  const PermissionToolPresentation(this.name, [this.description = '']);
  final String name, description;
}

/// 只读工具目录与授权事实由领域 owner 注入；此页选择不授予执行权限。
class ToolPermissionsPresentation {
  const ToolPermissionsPresentation({
    this.tools = const [],
    this.defaultChoice = ToolPermissionChoice.ask,
    this.overrides = const {},
  });
  final List<PermissionToolPresentation> tools;
  final ToolPermissionChoice defaultChoice;
  final Map<String, ToolPermissionChoice> overrides;
}

int _compareNames(String a, String b) {
  final folded = a.toLowerCase().compareTo(b.toLowerCase());
  return folded == 0 ? a.compareTo(b) : folded;
}

class ToolPermissionsPage extends StatefulWidget {
  const ToolPermissionsPage({
    this.snapshot = const ToolPermissionsPresentation(),
    super.key,
  });
  final ToolPermissionsPresentation snapshot;
  @override
  State<ToolPermissionsPage> createState() => _ToolPermissionsPageState();
}

class _ToolPermissionsPageState extends State<ToolPermissionsPage> {
  late ToolPermissionChoice master = widget.snapshot.defaultChoice;
  late final overrides = ValueNotifier(
    Map<String, ToolPermissionChoice>.of(widget.snapshot.overrides),
  );
  late List<PermissionToolPresentation> tools = _catalog();
  List<PermissionToolPresentation> _catalog() => {
    for (final tool in widget.snapshot.tools)
      if (!['package_proxy', 'proxy', 'search'].contains(tool.name))
        tool.name: tool,
  }.values.toList()..sort((a, b) => _compareNames(a.name, b.name));
  @override
  void didUpdateWidget(ToolPermissionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      tools = _catalog();
      master = widget.snapshot.defaultChoice;
      overrides.value = Map.of(widget.snapshot.overrides);
    }
  }

  @override
  void dispose() {
    overrides.dispose();
    super.dispose();
  }

  void toggle(String name, ToolPermissionChoice choice) {
    final next = Map<String, ToolPermissionChoice>.of(overrides.value);
    if (next[name] == choice) {
      next.remove(name);
    } else {
      next[name] = choice;
    }
    overrides.value = next;
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: 'AI 工具授权',
    onBack: () => Navigator.of(context).maybePop(),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          key: const PageStorageKey('tool-permissions'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '默认情况下，所有工具都需要您"询问"。您可以在下面添加例外。',
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _PermissionCard(
                children: [
                  const Text(
                    '全局权限开关',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '此设置作为主控制，可以覆盖单个工具权限。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in ToolPermissionChoice.values)
                        Semantics(
                          selected: master == choice,
                          button: true,
                          child: Material(
                            color: master == choice
                                ? colors.primary
                                : colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colors.primary),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => master = choice),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  choice.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: master == choice
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: master == choice
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PermissionCard(
                children: [
                  const Text(
                    '使用说明',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. 上面的"全局默认权限"控制所有工具的默认行为。\n2. 下面每个分组中添加的工具，是对该工具设置"例外规则"，会覆盖全局默认。\n3. 再次点击同一分组中的工具，或在选择对话框中取消勾选，即可移除该工具的例外配置，让它重新跟随全局默认。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              for (final choice in [
                ToolPermissionChoice.allow,
                ToolPermissionChoice.forbid,
              ]) ...[
                const SizedBox(height: 16),
                ValueListenableBuilder(
                  valueListenable: overrides,
                  builder: (context, entries, _) {
                    final names =
                        entries.entries
                            .where((entry) => entry.value == choice)
                            .map((entry) => entry.key)
                            .toList()
                          ..sort(_compareNames);
                    final color = choice == ToolPermissionChoice.allow
                        ? colors.primary
                        : colors.error;
                    return _PermissionCard(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    choice.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    choice.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: ValueKey('add-${choice.name}'),
                              tooltip: '添加工具',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _ToolSelector(
                                  tools: tools,
                                  choice: choice,
                                  overrides: overrides,
                                  onToggle: (name) => toggle(name, choice),
                                ),
                              ),
                              icon: Icon(Icons.add, color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (names.isEmpty)
                          Text(
                            '此组中未添加任何工具。',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        for (final name in names)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(
                              key: ValueKey('${choice.name}-$name'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer.withValues(
                                  alpha: .5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: '移除 $name',
                                    child: InkWell(
                                      onTap: () => toggle(name, choice),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: colors.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _ToolSelector extends StatefulWidget {
  const _ToolSelector({
    required this.tools,
    required this.choice,
    required this.overrides,
    required this.onToggle,
  });
  final List<PermissionToolPresentation> tools;
  final ToolPermissionChoice choice;
  final ValueNotifier<Map<String, ToolPermissionChoice>> overrides;
  final ValueChanged<String> onToggle;
  @override
  State<_ToolSelector> createState() => _ToolSelectorState();
}

class _ToolSelectorState extends State<_ToolSelector> {
  final search = TextEditingController();
  late List<PermissionToolPresentation> filtered = widget.tools;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 只在键盘+大字极短窗口时合并标题/搜索滚动，常规保持旧固定搜索栏。
              final compact =
                  constraints.maxHeight <
                  180 + MediaQuery.textScalerOf(context).scale(38);
              final heading = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '选择工具',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    KiyoriSearchField(
                      controller: search,
                      hint: '搜索',
                      onChanged: (value) => setState(() {
                        final query = value.trim().toLowerCase();
                        filtered = widget.tools
                            .where(
                              (entry) =>
                                  entry.name.toLowerCase().contains(query) ||
                                  entry.description.toLowerCase().contains(
                                    query,
                                  ),
                            )
                            .toList();
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact) heading,
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: widget.overrides,
                      builder: (context, entries, _) => ListView.builder(
                        itemCount:
                            (compact ? 1 : 0) +
                            (filtered.isEmpty ? 1 : filtered.length),
                        itemBuilder: (context, index) {
                          if (compact && index == 0) return heading;
                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Text(
                                '没有找到匹配的工具。请尝试工具名称或功能关键词。',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          final tool = filtered[index - (compact ? 1 : 0)];
                          return InkWell(
                            key: ValueKey('select-tool-${tool.name}'),
                            onTap: () => widget.onToggle(tool.name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: entries[tool.name] == widget.choice,
                                    onChanged: (_) =>
                                        widget.onToggle(tool.name),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tool.name,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        if (tool.description.trim().isNotEmpty)
                                          Text(
                                            tool.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('完成'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
