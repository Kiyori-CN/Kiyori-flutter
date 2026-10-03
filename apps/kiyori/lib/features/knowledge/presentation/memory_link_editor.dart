import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'knowledge_controller.dart';

class MemoryLinkEditor extends StatefulWidget {
  const MemoryLinkEditor({
    required this.controller,
    required this.space,
    required this.source,
    required this.target,
    this.link,
    super.key,
  });
  final KnowledgeController controller;
  final String space;
  final GraphNode source, target;
  final MemoryLink? link;
  @override
  State<MemoryLinkEditor> createState() => _MemoryLinkEditorState();
}

class _MemoryLinkEditorState extends State<MemoryLinkEditor> {
  late final relation = TextEditingController(
    text: widget.link?.draft.relation ?? 'related',
  );
  late final weight = TextEditingController(
    text: widget.link?.draft.weight.toString() ?? '1.0',
  );
  late final description = TextEditingController(
    text: widget.link?.draft.description ?? '',
  );
  String? error;
  Future<void> save() async {
    if (widget.controller.saving) return;
    final value = double.tryParse(weight.text);
    if (relation.text.trim().isEmpty || value == null || !value.isFinite) {
      setState(() => error = '请填写关联类型和有效权重。');
      return;
    }
    final saved = await widget.controller.saveLink(
      widget.space,
      widget.link?.id,
      MemoryLinkDraft(
        sourceId: widget.source.id,
        targetId: widget.target.id,
        relation: relation.text,
        weight: value,
        description: description.text,
      ),
    );
    if (saved && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    relation.dispose();
    weight.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.saving;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          title: Text(
            widget.link == null
                ? '关联 ${widget.source.title} → ${widget.target.title}'
                : '编辑关联',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              TextField(
                controller: relation,
                enabled: !busy,
                decoration: const InputDecoration(labelText: '类型'),
              ),
              TextField(
                controller: weight,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '权重'),
              ),
              TextField(
                controller: description,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              if (error ?? widget.controller.error case final String message)
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? '保存中'
                    : widget.link == null
                    ? '创建关联'
                    : '保存',
              ),
            ),
          ],
        ),
      );
    },
  );
}
