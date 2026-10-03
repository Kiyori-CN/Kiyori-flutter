import 'dart:async';

import 'package:flutter/material.dart';

import 'model_prompts_page.dart';
import 'prompts_controller.dart';

class PersistentPromptsPage extends StatefulWidget {
  const PersistentPromptsPage({
    required this.controller,
    required this.onOpenTagMarket,
    required this.onOpenPersona,
    super.key,
  });
  final PromptsController controller;
  final VoidCallback onOpenTagMarket, onOpenPersona;
  @override
  State<PersistentPromptsPage> createState() => _PersistentPromptsPageState();
}

class _PersistentPromptsPageState extends State<PersistentPromptsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.load());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return PopScope(
        canPop: !controller.saving,
        child: Column(
          children: [
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.error != null)
              Material(
                child: ListTile(
                  title: Text(controller.error!),
                  trailing: TextButton(
                    onPressed: controller.load,
                    child: const Text('重试'),
                  ),
                ),
              ),
            Expanded(
              child: AbsorbPointer(
                absorbing: controller.loading || controller.saving,
                child: ModelPromptsPage(
                  snapshot: controller.snapshot,
                  controller: controller,
                  onOpenTagMarket: widget.onOpenTagMarket,
                  onOpenPersona: widget.onOpenPersona,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
