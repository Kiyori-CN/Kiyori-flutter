import 'package:flutter/material.dart';

import 'knowledge_controller.dart';

class KnowledgeNameDialog extends StatefulWidget {
  const KnowledgeNameDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.controller,
    required this.save,
  });
  final String title, initial;
  final KnowledgeController controller;
  final Future<bool> Function(String) save;
  @override
  State<KnowledgeNameDialog> createState() => KnowledgeNameDialogState();
}

class KnowledgeNameDialogState extends State<KnowledgeNameDialog> {
  late final text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !widget.controller.saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              enabled: !widget.controller.saving,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.controller.error != null) Text(widget.controller.error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.controller.saving
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: widget.controller.saving || text.text.trim().isEmpty
                ? null
                : () async {
                    final saved = await widget.save(text.text);
                    if (saved &&
                        context.mounted &&
                        (ModalRoute.of(context)?.isCurrent ?? false)) {
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
}

class KnowledgeConfirmDialog extends StatelessWidget {
  const KnowledgeConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.controller,
    required this.save,
  });
  final String title, message;
  final KnowledgeController controller;
  final Future<bool> Function() save;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop: !controller.saving,
      child: AlertDialog(
        title: Text(title),
        content: Text(controller.error ?? message),
        actions: [
          TextButton(
            onPressed: controller.saving
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: controller.saving
                ? null
                : () async {
                    final done = await save();
                    if (done &&
                        context.mounted &&
                        (ModalRoute.of(context)?.isCurrent ?? false)) {
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text('删除'),
          ),
        ],
      ),
    ),
  );
}
