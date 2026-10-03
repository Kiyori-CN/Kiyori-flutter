import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'context_edit_session.dart';
import 'context_summary_page.dart';

class PersistentContextPage extends StatefulWidget {
  const PersistentContextPage({required this.connect, super.key});
  final Future<RuntimeClient> Function() connect;
  @override
  State<PersistentContextPage> createState() => _PersistentContextPageState();
}

class _PersistentContextPageState extends State<PersistentContextPage> {
  ContextEditSession? session;
  ContextSummaryPresentation? snapshot;
  bool loading = true, leaving = false, busy = false;
  String? error;
  DialogRoute<bool>? _decision;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final old = session;
    old?.discard();
    session = null;
    snapshot = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    final generation = ++_generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await old?.pendingSave;
      final data = await (await widget.connect()).contextSettings();
      if (!mounted || generation != _generation) return;
      session = ContextEditSession(widget.connect, data);
      final o = data.config.draft.options;
      snapshot = ContextSummaryPresentation(
        configId: data.config.id,
        configName: data.config.draft.name,
        contextLength: o.contextLength.toString(),
        maxContextLength: o.maxContextLength.toString(),
        enableSummary: o.summaryEnabled,
        threshold: o.summaryThreshold.toString(),
        byMessageCount: o.summaryByCount,
        messageCount: o.summaryCount.toString(),
        rules: o.summaryRules,
        imageTurns: data.history.imageTurns.toString(),
        mediaTurns: data.history.mediaTurns.toString(),
      );
    } catch (_) {
      if (mounted && generation == _generation) error = '上下文设置读取失败，请重试';
    } finally {
      if (mounted && generation == _generation) setState(() => loading = false);
    }
  }

  Future<bool> confirm(String title, String action) async {
    if (_decision != null) return false;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('当前草稿已保留。此操作将放弃未保存的更改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    _decision = route;
    final result = await Navigator.of(context).push(route);
    if (identical(_decision, route)) _decision = null;
    return mounted && result == true;
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    setState(() => busy = true);
    final saved = session == null || await session!.flush();
    if (!mounted) return;
    final proceed = saved || await confirm('未能保存上下文设置', '放弃更改');
    if (!mounted) return;
    setState(() {
      busy = false;
      leaving = proceed;
    });
    if (proceed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    session?.dispose();
    final route = _decision;
    _decision = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(leave());
    },
    child: loading || session == null
        ? SettingsWorkspacePage(
            title: '上下文与总结',
            onBack: leave,
            body: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: load, child: Text(error ?? '重新载入')),
            ),
          )
        : ListenableBuilder(
            listenable: session!,
            builder: (context, _) => Column(
              children: [
                if (error != null || session!.error != null)
                  Material(
                    child: ListTile(
                      title: Text(error ?? session!.error!),
                      trailing: TextButton(
                        onPressed: session!.saving
                            ? null
                            : () async {
                                if (await confirm('重新载入上下文设置？', '重新载入')) {
                                  await load();
                                }
                              },
                        child: const Text('重新载入'),
                      ),
                    ),
                  ),
                Expanded(
                  child: ContextSummaryPage(
                    key: ObjectKey(session),
                    snapshot: snapshot!,
                    session: session,
                    onBack: leave,
                  ),
                ),
              ],
            ),
          ),
  );
}
