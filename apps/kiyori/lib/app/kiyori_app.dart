import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'diagnostics/runtime_diagnostics_page.dart';
import 'runtime_controller.dart';
import 'shell/home_shell.dart';
import '../features/workflows/presentation/workflow_controller.dart';
import '../features/knowledge/presentation/knowledge_controller.dart';
import '../features/assistant/presentation/prompts/prompts_controller.dart';
import '../features/assistant/presentation/models/models_controller.dart';
import '../features/assistant/presentation/chat_controller.dart';
import '../features/extensions/presentation/extensions_controller.dart';

class KiyoriApp extends StatefulWidget {
  const KiyoriApp({required this.connect, this.diagnostics = false, super.key});
  final Future<RuntimeClient> Function() connect;

  /// 独立开发入口，运行时探针不占用产品首页与设置空点击。
  final bool diagnostics;
  @override
  State<KiyoriApp> createState() => _KiyoriAppState();
}

class _KiyoriAppState extends State<KiyoriApp> with WidgetsBindingObserver {
  late final RuntimeController controller;
  late final WorkflowController workflows;
  late final KnowledgeController knowledge;
  late final PromptsController prompts;
  late final ModelsController models;
  late final ChatController chat;
  late final ExtensionsController extensions;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = RuntimeController(widget.connect);
    workflows = WorkflowController(controller.connectedClient);
    knowledge = KnowledgeController(controller.connectedClient);
    prompts = PromptsController(controller.connectedClient);
    models = ModelsController(
      controller.connectedClient,
      openNativeSecretStore,
    );
    chat = ChatController(controller.connectedClient, openNativeSecretStore);
    extensions = ExtensionsController(
      controller.connectedClient,
      onChanged: models.refreshProviders,
    );
    unawaited(controller.initialize());
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await chat.shutdown();
    await controller.shutdown();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    workflows.dispose();
    knowledge.dispose();
    prompts.dispose();
    models.dispose();
    chat.dispose();
    extensions.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kiyori',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const KiyoriScrollBehavior(),
    theme: KiyoriTheme.light(),
    darkTheme: KiyoriTheme.dark(),
    themeMode: ThemeMode.light,
    home: widget.diagnostics
        ? AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Scaffold(
              appBar: AppBar(title: const Text('运行检查')),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: KiyoriPage(
                    child: RuntimeDiagnosticsPage(controller: controller),
                  ),
                ),
              ),
            ),
          )
        : HomeShell(
            workflows: workflows,
            knowledge: knowledge,
            prompts: prompts,
            models: models,
            chat: chat,
            extensions: extensions,
          ),
  );
}
