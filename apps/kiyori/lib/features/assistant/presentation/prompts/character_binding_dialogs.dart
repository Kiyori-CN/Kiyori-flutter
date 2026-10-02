import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'prompt_dialog.dart';
import 'prompt_presentation.dart';

class CharacterModelPicker extends StatefulWidget {
  const CharacterModelPicker({
    required this.session,
    this.selectedId,
    this.selectedName,
    super.key,
  });
  final PromptDialogState session;
  final String? selectedId, selectedName;
  @override
  State<CharacterModelPicker> createState() => _CharacterModelPickerState();
}

class _CharacterModelPickerState extends State<CharacterModelPicker> {
  String? expandedId;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.session.widget.catalog,
    builder: (context, snapshot, _) => PromptFormDialog(
      widthFraction: .9,
      actions: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '选择配置',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (final model in snapshot.models)
            Column(
              key: ValueKey(model.id),
              children: [
                _BindingChoice(
                  title: model.name,
                  selected: model.id == widget.selectedId,
                  trailing: model.models.length > 1
                      ? Icon(
                          expandedId == model.id
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        )
                      : null,
                  onTap: () {
                    if (!widget.session.valid) return;
                    if (model.models.length > 1) {
                      setState(
                        () => expandedId = expandedId == model.id
                            ? null
                            : model.id,
                      );
                    } else {
                      Navigator.pop(context, (
                        model.id,
                        model.models.firstOrNull,
                      ));
                    }
                  },
                ),
                if (expandedId == model.id && model.models.length > 1)
                  for (final name in model.models)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _BindingChoice(
                        key: ValueKey('model-${model.id}-$name'),
                        title: name,
                        nested: true,
                        selected:
                            model.id == widget.selectedId &&
                            name == widget.selectedName,
                        onTap: () {
                          if (widget.session.valid) {
                            Navigator.pop(context, (model.id, name));
                          }
                        },
                      ),
                    ),
              ],
            ),
        ],
      ),
    ),
  );
}

class CharacterMemoryPicker extends StatelessWidget {
  const CharacterMemoryPicker({
    required this.session,
    this.selectedId,
    super.key,
  });
  final PromptDialogState session;
  final String? selectedId;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: session.widget.catalog,
    builder: (context, snapshot, _) => PromptFormDialog(
      widthFraction: .9,
      actions: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '选择记忆配置',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          for (final memory in snapshot.memories)
            _BindingChoice(
              key: ValueKey(memory.id),
              title: memory.name,
              subtitle: memory.id,
              selected: memory.id == selectedId,
              onTap: () {
                if (session.valid) Navigator.pop(context, memory.id);
              },
            ),
        ],
      ),
    ),
  );
}

/// 对应旧固定模型/记忆选择中的紧凑 Surface，保持选中色块与细描边。
class _BindingChoice extends StatelessWidget {
  const _BindingChoice({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.nested = false,
    super.key,
  });
  final String title;
  final String? subtitle;
  final bool selected, nested;
  final Widget? trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: nested ? 1 : 2),
      child: Material(
        color: selected
            ? (nested
                  ? colors.primary.withValues(alpha: .12)
                  : colors.primaryContainer.withValues(alpha: .65))
            : nested
            ? colors.surfaceContainerHighest.withValues(alpha: .35)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(nested ? 4 : 6),
          side: selected || nested
              ? BorderSide.none
              : BorderSide(
                  width: .5,
                  color: colors.outlineVariant.withValues(alpha: .35),
                ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: nested ? 8 : 10,
              vertical: nested ? 6 : 8,
            ),
            child: Row(
              children: [
                if (selected && trailing == null) ...[
                  Icon(
                    Icons.check,
                    size: nested ? 12 : 14,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: nested ? 11 : 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected ? colors.primary : colors.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  IconTheme(
                    data: IconThemeData(
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    child: trailing!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CharacterToolPicker extends StatefulWidget {
  const CharacterToolPicker({
    required this.session,
    required this.initial,
    super.key,
  });
  final PromptDialogState session;
  final CharacterToolAccess initial;
  @override
  State<CharacterToolPicker> createState() => _CharacterToolPickerState();
}

class _CharacterToolPickerState extends State<CharacterToolPicker> {
  final search = TextEditingController();
  late final selected = {
    for (final kind in CharacterToolKind.values)
      kind: {...?widget.initial.allowed[kind]},
  };
  CharacterToolKind tab = CharacterToolKind.builtin;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.session.widget.catalog,
    builder: (context, snapshot, _) {
      final options = snapshot.tools.where((e) => e.kind == tab).toList();
      final query = search.text.trim().toLowerCase();
      final filtered = options
          .where(
            (e) => '${e.id} ${e.name} ${e.description}'.toLowerCase().contains(
              query,
            ),
          )
          .toList();
      return PromptFormDialog(
        widthFraction: .94,
        actions: PromptActions(
          onConfirm: () {
            if (!widget.session.valid) return;
            // 只回填仍在当前目录中的 ID，删除再返回不能把旧选项写入草稿。
            Navigator.pop(
              context,
              CharacterToolAccess(
                enabled: widget.initial.enabled,
                allowed: {
                  for (final kind in CharacterToolKind.values)
                    kind: selected[kind]!
                        .where(
                          (id) => widget.session.snapshot.tools.any(
                            (e) => e.kind == kind && e.id == id,
                          ),
                        )
                        .toSet(),
                },
              ),
            );
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '自定义允许使用的工具',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final kind in CharacterToolKind.values)
                    TextButton(
                      onPressed: () => setState(() {
                        tab = kind;
                        search.clear();
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: tab == kind
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: Text(
                        kind.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (options.isNotEmpty)
              KiyoriSearchField(
                controller: search,
                hint: '搜索名称、描述或标识',
                showSearchIcon: true,
                showClear: true,
                onChanged: (_) => setState(() {}),
              ),
            if (options.isEmpty || filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  options.isEmpty ? tab.empty : '未找到匹配的工具',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            for (final option in filtered)
              CheckboxListTile(
                key: ValueKey('${tab.name}-${option.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(option.name, style: const TextStyle(fontSize: 13)),
                subtitle: option.description.isEmpty
                    ? null
                    : Text(
                        option.description,
                        style: const TextStyle(fontSize: 11),
                      ),
                value: selected[tab]!.contains(option.id),
                onChanged: (value) => setState(() {
                  value == true
                      ? selected[tab]!.add(option.id)
                      : selected[tab]!.remove(option.id);
                }),
              ),
          ],
        ),
      );
    },
  );
}
