import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'model_settings_components.dart';

const _categories = ['生成参数', '创造性参数', '重复控制参数', '自定义参数'];
const _types = ['整数', '小数', '文本', '布尔值', '对象(JSON)'];

class _ParameterDefinition {
  const _ParameterDefinition(
    this.name,
    this.api,
    this.description,
    this.initial,
    this.tab, {
    this.integer = false,
    this.range,
  });
  final String name, api, description, initial;
  final int tab;
  final bool integer;
  final String? range;
}

const _definitions = [
  _ParameterDefinition(
    '最大生成Token数',
    'max_tokens',
    '限制每次生成的总 token，包含思考。额度过低可能在回答前耗尽；提高额度可能增加耗时和费用，仍受模型上下文上限约束。',
    '4096',
    0,
    integer: true,
  ),
  _ParameterDefinition(
    '温度',
    'temperature',
    '控制输出的随机性。较低的值更确定性，较高的值更随机',
    '1.0',
    1,
    range: '0.0 - 2.0',
  ),
  _ParameterDefinition(
    'Top-P 采样',
    'top_p',
    '作为温度的替代方案，模型仅考虑概率最高的Top-P比例的token',
    '1.0',
    1,
    range: '0.0 - 1.0',
  ),
  _ParameterDefinition(
    'Top-K 采样',
    'top_k',
    '模型仅考虑概率最高的K个token。0表示禁用',
    '0',
    1,
    integer: true,
    range: '0 - 100',
  ),
  _ParameterDefinition(
    '存在惩罚',
    'presence_penalty',
    '增强模型谈论新主题的倾向。值越高，惩罚越大',
    '0.0',
    2,
    range: '-2.0 - 2.0',
  ),
  _ParameterDefinition(
    '频率惩罚',
    'frequency_penalty',
    '减少模型重复同一词语的可能性。值越高，惩罚越大',
    '0.0',
    2,
    range: '-2.0 - 2.0',
  ),
  _ParameterDefinition(
    '重复惩罚',
    'repetition_penalty',
    '进一步减少重复。1.0表示不惩罚，大于1.0会降低重复可能性',
    '1.0',
    2,
    range: '0.0 - 2.0',
  ),
];

class _ParameterDraft {
  _ParameterDraft(this.definition)
    : value = TextEditingController(text: definition.initial);
  final _ParameterDefinition definition;
  final TextEditingController value;
  final error = ValueNotifier<String?>(null);
  bool enabled = false, expanded = false;
  void validate(String text) {
    final value = num.tryParse(text);
    error.value = definition.integer
        ? int.tryParse(text) == null
              ? '必须是整数'
              : null
        : value == null || !value.isFinite
        ? '必须是浮点数'
        : null;
  }

  void dispose() {
    value.dispose();
    error.dispose();
  }
}

class ModelParametersCard extends StatefulWidget {
  const ModelParametersCard({super.key});
  @override
  State<ModelParametersCard> createState() => _ModelParametersCardState();
}

class _ModelParametersCardState extends State<ModelParametersCard>
    with SingleTickerProviderStateMixin {
  bool expanded = false;
  late final tabs = TabController(length: 4, vsync: this);
  final values = [
    for (final definition in _definitions) _ParameterDraft(definition),
  ];
  @override
  void initState() {
    super.initState();
    tabs.addListener(changed);
  }

  void changed() {
    setState(() {});
  }

  @override
  void dispose() {
    tabs.removeListener(changed);
    tabs.dispose();
    for (final value in values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModelSettingsCard(
    children: [
      ModelSettingsExpansion(
        '模型参数设置',
        Icons.tune,
        IconTone.neutral,
        expanded: expanded,
        onTap: () => setState(() => expanded = !expanded),
      ),
      if (expanded) ...[
        const Text(
          '启用参数时，该参数将被包含在API请求中。默认情况下，所有参数均处于关闭状态，使用模型的默认值。',
          style: TextStyle(fontSize: 14, color: PrimaryColors.secondary),
        ),
        TabBar(
          controller: tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: [
            for (var i = 0; i < 4; i++)
              Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      [
                        Icons.auto_fix_high,
                        Icons.lightbulb,
                        Icons.repeat,
                        Icons.settings_outlined,
                      ][i],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(_categories[i]),
                  ],
                ),
              ),
          ],
        ),
        if (tabs.index == 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '暂无自定义参数',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: PrimaryColors.secondary),
            ),
          )
        else
          for (final draft in values.where(
            (entry) => entry.definition.tab == tabs.index,
          )) ...[
            _parameter(draft),
            if (draft.definition.api == 'temperature')
              Row(
                children: [
                  const Expanded(
                    child: Text('温度推荐设置', style: TextStyle(fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '1.3',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: PrimaryColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(onPressed: () {}, child: const Text('重置')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _CustomParameterDialog(),
                ),
                child: const Text('添加'),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _parameter(_ParameterDraft draft) {
    final definition = draft.definition;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        definition.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                      Text(
                        'API名称: ${definition.api}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: draft.enabled,
                  onChanged: (value) => setState(() => draft.enabled = value),
                ),
                IconButton(
                  tooltip: '${draft.expanded ? '收起' : '展开'}${definition.name}',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () =>
                      setState(() => draft.expanded = !draft.expanded),
                  icon: Icon(
                    draft.expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ),
              ],
            ),
            if (draft.expanded) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder(
                valueListenable: draft.error,
                builder: (context, error, _) => TextField(
                  controller: draft.value,
                  onChanged: draft.validate,
                  decoration: InputDecoration(
                    labelText: '参数值',
                    border: const OutlineInputBorder(),
                    errorText: error,
                    helperText: definition.range == null
                        ? null
                        : '范围: ${definition.range}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '默认值: ${definition.initial}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomParameterDialog extends StatefulWidget {
  const _CustomParameterDialog();
  @override
  State<_CustomParameterDialog> createState() => _CustomParameterDialogState();
}

class _CustomParameterDialogState extends State<_CustomParameterDialog> {
  final name = TextEditingController(), value = TextEditingController();
  int type = 2, category = 0;
  String? nameError, valueError;
  @override
  void dispose() {
    name.dispose();
    value.dispose();
    super.dispose();
  }

  void validate() => setState(() {
    nameError = name.text.trim().isEmpty ? '参数名称不能为空' : null;
    valueError = switch (type) {
      0 => int.tryParse(value.text) == null ? '必须是整数' : null,
      1 => double.tryParse(value.text)?.isFinite != true ? '必须是浮点数' : null,
      3 =>
        ['true', 'false'].contains(value.text.toLowerCase())
            ? null
            : "必须为'true'或'false'",
      4 => _validJson(value.text) ? null : '必须是有效的 JSON',
      _ => null,
    };
  });
  bool _validJson(String text) {
    try {
      jsonDecode(text);
      return true;
    } on FormatException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: '参数名称',
              errorText: nameError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '参数类型',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < _types.length; i++)
                DropdownMenuItem(value: i, child: Text(_types[i])),
            ],
            onChanged: (index) {
              if (index == null) return;
              setState(() {
                type = index;
                value.text = ['0', '0.0', '', 'true', '{}'][type];
                valueError = null;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: value,
            minLines: 1,
            maxLines: type == 4 ? 6 : 1,
            decoration: InputDecoration(
              labelText: '默认值',
              errorText: valueError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '参数类别',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < 4; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(i == 3 ? '其他参数' : _categories[i]),
                ),
            ],
            onChanged: (value) => setState(() => category = value ?? category),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: validate, child: const Text('保存')),
    ],
  );
}
