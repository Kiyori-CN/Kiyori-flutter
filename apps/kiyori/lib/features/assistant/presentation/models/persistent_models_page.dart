import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart' as bridge;

import 'function_model_presentation.dart';
import 'function_models_page.dart';
import 'model_api_page.dart';
import 'models_controller.dart';

ModelConfigPresentation presentModel(bridge.ModelConfig config) =>
    ModelConfigPresentation(
      id: config.id,
      name: config.draft.name,
      models: config.draft.models,
      image: config.draft.options.image,
      audio: config.draft.options.audio,
      video: config.draft.options.video,
    );

class PersistentModelsPage extends StatefulWidget {
  const PersistentModelsPage({
    required this.controller,
    required this.onManage,
    this.functions = false,
    super.key,
  });
  final ModelsController controller;
  final VoidCallback onManage;
  final bool functions;
  @override
  State<PersistentModelsPage> createState() => _PersistentModelsPageState();
}

class _PersistentModelsPageState extends State<PersistentModelsPage> {
  final messenger = GlobalKey<ScaffoldMessengerState>();
  String? shownError;

  void changed() {
    final error = widget.controller.error;
    if (error == shownError) return;
    shownError = error;
    if (error == null || widget.controller.catalog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.error != error) return;
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(error),
          action: SnackBarAction(
            label: '重试',
            onPressed: widget.controller.load,
          ),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    unawaited(widget.controller.load());
  }

  @override
  void didUpdateWidget(PersistentModelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
      shownError = null;
      unawaited(widget.controller.load());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final owner = widget.controller, catalog = owner.catalog;
      if (catalog == null) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.functions ? '功能模型分配' : '模型与 API')),
          body: Center(
            child: owner.loading
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: owner.load,
                    child: Text(owner.error ?? '重新载入'),
                  ),
          ),
        );
      }
      final configs = catalog.configs.map(presentModel).toList();
      return ScaffoldMessenger(
        key: messenger,
        child: widget.functions
            ? FunctionModelsPage(
                onManage: widget.onManage,
                onSelect: owner.select,
                onReset: owner.resetFunctions,
                snapshot: FunctionModelsPresentation(
                  configs: configs,
                  selections: {
                    for (final f in catalog.functions)
                      AssistantFunction.values.byName(
                        f.function,
                      ): FunctionModelSelection(
                        f.configId,
                        configs
                            .firstWhere((c) => c.id == f.configId)
                            .models
                            .indexOf(f.modelName),
                      ),
                  },
                ),
              )
            : ModelApiPage(
                controller: owner,
                configurations: configs,
                onOpenLocalModels: widget.onManage,
              ),
      );
    },
  );
}
