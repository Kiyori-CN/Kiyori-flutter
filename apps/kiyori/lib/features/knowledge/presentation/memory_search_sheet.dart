import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'knowledge_controller.dart';

class MemorySearchSheet extends StatefulWidget {
  const MemorySearchSheet({
    required this.controller,
    required this.space,
    required this.initial,
    required this.dismiss,
    required this.onSimulate,
    super.key,
  });
  final KnowledgeController controller;
  final String space;
  final MemorySearchSettings initial;
  final Future<void> Function() dismiss;
  final VoidCallback onSimulate;
  @override
  State<MemorySearchSheet> createState() => _MemorySearchSheetState();
}

class _MemorySearchSheetState extends State<MemorySearchSheet> {
  late double keyword = widget.initial.keywordWeight,
      tag = widget.initial.tagWeight,
      vector = widget.initial.vectorWeight,
      edge = widget.initial.edgeWeight;
  late int interval = widget.initial.autoInterval;
  late final rules = TextEditingController(
    text: widget.initial.extractionRules,
  );
  String? error;
  @override
  void dispose() {
    rules.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (rules.text.length > 20000) {
      setState(() => error = '附加规则过长，请缩短后保存。');
      return;
    }
    final saved = await widget.controller.saveSearchSettings(
      widget.space,
      MemorySearchSettings(
        graphVisible: widget.initial.graphVisible,
        scoreMode: widget.initial.scoreMode,
        keywordWeight: keyword,
        tagWeight: tag,
        vectorWeight: vector,
        edgeWeight: edge,
        autoInterval: interval,
        extractionRules: rules.text,
      ),
    );
    if (saved && mounted) await widget.dismiss();
  }

  Widget section(String title, List<Widget> children) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          ...children,
        ],
      ),
    ),
  );
  Widget slider(
    String label,
    double value,
    double maximum,
    ValueChanged<double> changed, {
    int? divisions,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '$label：${divisions == null ? value.toStringAsFixed(2) : value.round()}',
      ),
      Slider(
        value: value,
        min: divisions == null ? 0 : 1,
        max: maximum,
        divisions: divisions,
        semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
        onChanged: widget.controller.saving
            ? null
            : (v) => setState(() => changed(v)),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.saving;
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                section('自动保存记忆', [
                  // 尚无自动提取执行owner，保留旧入口外观，不虚构启用事实。
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动保存记忆'),
                    value: false,
                    onChanged: (_) {},
                  ),
                  slider(
                    '自动保存间隔（分钟）',
                    interval.toDouble(),
                    30,
                    (v) => interval = v.round(),
                    divisions: 29,
                  ),
                  const Text('可调范围 1-30 分钟，默认 5 分钟'),
                  TextField(
                    controller: rules,
                    enabled: !busy,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '记忆提取附加规则',
                      hintText: '例如：只记录项目决策和用户偏好，按项目分类。',
                    ),
                  ),
                ]),
                section('权重', [
                  slider('关键词权重', keyword, 20, (v) => keyword = v),
                  slider('标签权重', tag, 20, (v) => tag = v),
                  slider('向量权重', vector, 2, (v) => vector = v),
                  slider('边传播权重', edge, 2, (v) => edge = v),
                ]),
                section('云端嵌入', [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用云端嵌入'),
                    subtitle: const Text('未配置'),
                    value: false,
                    onChanged: (_) {},
                  ),
                ]),
                section('搜索调试', [
                  OutlinedButton(
                    onPressed: busy ? null : widget.onSimulate,
                    child: const Text('模拟搜索'),
                  ),
                ]),
                if (error ?? widget.controller.error case final String message)
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            keyword = 10;
                            tag = 0;
                            vector = 0;
                            edge = .4;
                            interval = 5;
                            rules.clear();
                            error = null;
                          }),
                    child: const Text('恢复默认'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => unawaited(save()),
                    child: Text(busy ? '保存中' : '保存'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
