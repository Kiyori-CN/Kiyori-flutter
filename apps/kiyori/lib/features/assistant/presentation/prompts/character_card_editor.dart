import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'prompt_dialog.dart';
import 'prompt_presentation.dart';
import 'character_binding_dialogs.dart';

class CharacterCardEditor extends StatefulWidget {
  const CharacterCardEditor({
    required this.card,
    required this.session,
    super.key,
  });
  final CharacterPresentation card;
  final PromptDialogState session;
  @override
  State<CharacterCardEditor> createState() => _CharacterCardEditorState();
}

class _CharacterCardEditorState extends State<CharacterCardEditor> {
  static const labels = [
    '角色卡名称',
    '描述',
    '角色设定',
    '开场白',
    '其他内容（聊天）',
    '其他内容（语音）',
    '自定义提示词',
    '备注',
  ];
  static const hints = [
    '',
    '',
    '描述角色的性格特点...',
    '角色的开场白或问候语...',
    '角色背景、经历等...',
    '语音想要附加的写在这里...',
    '高级自定义提示词...',
    '私人备注，不会影响AI...',
  ];
  late final fields = [
    widget.card.name,
    widget.card.description,
    widget.card.setting,
    widget.card.opening,
    widget.card.chat,
    widget.card.voice,
    widget.card.custom,
    widget.card.marks,
  ].map((e) => TextEditingController(text: e)).toList();
  late final tags = widget.card.tagIds.toSet();
  late bool fixedModel = widget.card.fixedModel,
      fixedMemory = widget.card.fixedMemory;
  late String? modelId = widget.card.modelConfigId,
      modelName = widget.card.modelName,
      memoryId = widget.card.memoryId;
  late CharacterToolAccess access = widget.card.toolAccess;
  bool advanced = false;
  String? validationError;

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> expand(int index) async {
    final title = index == 0 ? '编辑名称' : '编辑${labels[index]}';
    final result = await widget.session.showChild<String>(
      (_) => PromptTextEditor(title: title, value: fields[index].text),
    );
    if (!mounted || !widget.session.valid || result == null) return;
    fields[index].text = result;
  }

  Widget field(int index) => Padding(
    padding: EdgeInsets.only(top: index < 2 || index > 5 ? 6 : 0, bottom: 8),
    child: CompactExpandField(
      fieldKey: ValueKey('character-field-$index'),
      expandKey: ValueKey('expand-character-$index'),
      controller: fields[index],
      label: index < 2 || index > 5 ? labels[index] : null,
      hint: hints[index].isEmpty ? null : hints[index],
      minLines: index < 2 || index == 7 ? 1 : 2,
      maxLines: index == 0
          ? 1
          : index == 1 || index == 7
          ? 2
          : index == 6
          ? 3
          : 4,
      expandLabel: '大屏编辑${labels[index]}',
      onExpand: () => expand(index),
    ),
  );

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget binding(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          width: .8,
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> chooseModel() async {
    final result = await widget.session.showChild<(String, String?)>(
      (_) => CharacterModelPicker(
        session: widget.session,
        selectedId: modelId,
        selectedName: modelName,
      ),
    );
    if (!mounted || !widget.session.valid || result == null) return;
    // 选择身份为配置 ID + 模型名，目录重排后绝不沿用旧索引。
    final config = widget.session.snapshot.models
        .where((e) => e.id == result.$1)
        .firstOrNull;
    if (config == null ||
        (result.$2 != null && !config.models.contains(result.$2))) {
      return;
    }
    setState(() {
      modelId = config.id;
      modelName = result.$2;
    });
  }

  Future<void> chooseMemory() async {
    final result = await widget.session.showChild<String>(
      (_) =>
          CharacterMemoryPicker(session: widget.session, selectedId: memoryId),
    );
    if (!mounted ||
        !widget.session.valid ||
        result == null ||
        !widget.session.snapshot.memories.any((e) => e.id == result)) {
      return;
    }
    setState(() => memoryId = result);
  }

  Future<void> chooseTools() async {
    final result = await widget.session.showChild<CharacterToolAccess>(
      (_) => CharacterToolPicker(session: widget.session, initial: access),
    );
    if (!mounted || !widget.session.valid || result == null) return;
    setState(() => access = result);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.session.snapshot;
    final model = snapshot.models.where((e) => e.id == modelId).firstOrNull;
    final memory = snapshot.memories.where((e) => e.id == memoryId).firstOrNull;
    final modelSummary = !fixedModel
        ? '跟随全局'
        : '固定配置${model == null ? '' : ' · ${model.name}'} · ${model?.models.contains(modelName) == true ? modelName : '未选择'}';
    final memorySummary = !fixedMemory
        ? '跟随全局'
        : '固定配置${memory == null ? '' : ' · ${memory.name}'}';
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 2; i <= 5; i++) ...[
          if (i == 3)
            Row(
              children: [
                Expanded(child: heading(labels[i])),
                ValueListenableBuilder(
                  valueListenable: fields[i],
                  builder: (context, value, _) => IconButton(
                    onPressed: value.text.trim().isEmpty ? null : () {},
                    tooltip: '翻译开场白',
                    iconSize: 14,
                    color: IconTone.reading.iconFor(context),
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: const Icon(Icons.translate),
                  ),
                ),
              ],
            )
          else
            heading(labels[i]),
          field(i),
        ],
        heading('标签'),
        if (snapshot.tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '没有可用标签。请在设置中创建。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final tag in snapshot.tags)
                FilterChip(
                  key: ValueKey('attached-tag-${tag.id}'),
                  label: Text(tag.name, style: const TextStyle(fontSize: 10)),
                  selected: tags.contains(tag.id),
                  onSelected: (value) => setState(() {
                    value ? tags.add(tag.id) : tags.remove(tag.id);
                  }),
                ),
            ],
          ),
        InkWell(
          key: const ValueKey('character-advanced'),
          onTap: () => setState(() => advanced = !advanced),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  advanced ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                heading('高级选项'),
              ],
            ),
          ),
        ),
        if (advanced) ...[
          heading('对话模型绑定'),
          binding(
            '指定固定配置',
            modelSummary,
            fixedModel,
            (value) => setState(() {
              fixedModel = value;
              if (value && model == null && snapshot.models.isNotEmpty) {
                modelId = snapshot.models.first.id;
                modelName = snapshot.models.first.models.firstOrNull;
              }
            }),
          ),
          if (fixedModel)
            _selection(
              'character-model',
              model?.name ?? '选择模型配置',
              model?.models.contains(modelName) == true ? modelName! : '未选择',
              snapshot.models.isEmpty ? () {} : chooseModel,
            ),
          heading('记忆配置绑定'),
          binding(
            '指定固定记忆配置',
            memorySummary,
            fixedMemory,
            (value) => setState(() {
              fixedMemory = value;
              if (value && memory == null && snapshot.memories.isNotEmpty) {
                memoryId = snapshot.memories.first.id;
              }
            }),
          ),
          if (fixedMemory)
            _selection(
              'character-memory',
              memory?.name ?? '选择记忆配置',
              memory?.id ?? '未选择',
              snapshot.memories.isEmpty ? () {} : chooseMemory,
            ),
          heading('自定义允许使用的工具'),
          binding(
            '启用角色卡级工具白名单',
            access.summary,
            access.enabled,
            (value) => setState(
              () => access = CharacterToolAccess(
                enabled: value,
                allowed: access.allowed,
              ),
            ),
          ),
          _selection(
            'character-tools',
            '配置允许项',
            access.summary,
            chooseTools,
            icon: Icons.tune_outlined,
          ),
          field(6),
          field(7),
        ],
      ],
    );
    final media = MediaQuery.of(context);
    final compact =
        media.size.height - media.viewInsets.bottom < 650 ||
        media.textScaler.scale(12) > 18;
    return PromptFormDialog(
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (validationError != null)
            Text(
              validationError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          PromptActions(
            onConfirm: () {
              final external = CharacterToolKind.values
                  .where((e) => e != CharacterToolKind.builtin)
                  .any((e) => access.allowed[e]?.isNotEmpty == true);
              setState(
                () => validationError =
                    access.enabled &&
                        external &&
                        !(access.allowed[CharacterToolKind.builtin]?.contains(
                              'use_package',
                            ) ??
                            false)
                    ? '当前已允许包 / Skill / MCP，但未允许 use_package，请先在内建工具中开启 use_package'
                    : null,
              );
            },
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                children: [
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 1.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      child: ClipOval(
                        child: widget.card.avatarAsset == null
                            ? const Icon(Icons.person, size: 24)
                            : Image.asset(
                                widget.card.avatarAsset!,
                                fit: BoxFit.cover,
                                cacheWidth: 96,
                              ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: Icon(
                      widget.card.avatarAsset == null
                          ? Icons.add
                          : Icons.refresh_outlined,
                      size: 12,
                    ),
                    label: Text(
                      widget.card.avatarAsset == null ? '添加' : '重置',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(children: [field(0), field(1)])),
            ],
          ),
          const SizedBox(height: 12),
          if (compact)
            body
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                key: const ValueKey('character-body'),
                child: body,
              ),
            ),
        ],
      ),
    );
  }

  Widget _selection(
    String key,
    String title,
    String subtitle,
    VoidCallback onTap, {
    IconData icon = Icons.keyboard_arrow_down,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          width: .8,
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .55),
        ),
      ),
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
