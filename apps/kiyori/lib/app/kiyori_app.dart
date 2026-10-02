import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'diagnostics/runtime_diagnostics_page.dart';
import 'runtime_controller.dart';
import 'shell/home_shell.dart';
import '../features/workflows/presentation/workflow_controller.dart';

class KiyoriApp extends StatefulWidget {
  const KiyoriApp({required this.connect, this.diagnostics = false, super.key});
  final Future<RuntimeClient> Function() connect;

  /// 独立开发入口，运行时探针不占用产品首页与设置空点击。
  final bool diagnostics;
  @override
  State<KiyoriApp> createState() => _KiyoriAppState();
}

class _KiyoriAppState extends State<KiyoriApp> {
  late final RuntimeController controller;
  late final WorkflowController workflows;
  @override
  void initState() {
    super.initState();
    controller = RuntimeController(widget.connect);
    workflows = WorkflowController(controller.connectedClient);
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    workflows.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kiyori',
    debugShowCheckedModeBanner: false,
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
        : HomeShell(workflows: workflows),
  );
}
