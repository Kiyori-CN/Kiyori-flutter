import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'local_model_presentation.dart';
import 'local_models_page.dart';

/// 页面只投影Rust目录/Transfer；离开暂停本页启动的前台任务，原文与下载进度不丢失。
class PersistentLocalModelsPage extends StatefulWidget {
  const PersistentLocalModelsPage({required this.connect, super.key});
  final Future<RuntimeClient> Function() connect;
  @override
  State<PersistentLocalModelsPage> createState() =>
      _PersistentLocalModelsPageState();
}

class _PersistentLocalModelsPageState extends State<PersistentLocalModelsPage> {
  List<LocalModel> models = [];
  final tasks = <String, TransferSnapshot>{};
  final runs = <String, TransferRun>{};
  final preparing = <String>{};
  bool loading = true, failed = false, refreshing = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (refreshing) return;
    refreshing = true;
    try {
      final runtime = await widget.connect();
      final cached = await runtime.localModels();
      final transfers = await runtime.transfers();
      if (!mounted) return;
      setState(() {
        models = cached;
        for (final task in transfers) {
          tasks[task.owner] = task;
        }
        loading = cached.isEmpty;
      });
      final fresh = refresh || cached.isEmpty
          ? await runtime.refreshLocalModels()
          : cached;
      if (!mounted) return;
      setState(() {
        models = fresh;
        loading = false;
        failed = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = models.isEmpty;
        });
        message(error is BridgeError ? error.message : '模型目录读取失败');
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> start(String name) async {
    if (runs.containsKey(name) || !preparing.add(name)) return;
    setState(() {});
    TransferRun? run;
    try {
      final runtime = await widget.connect();
      run = await runtime.downloadLocalModel(name);
      if (!mounted) {
        await run.stop();
        return;
      }
      runs[name] = run;
      preparing.remove(name);
      setState(() {});
      await for (final event in run.events) {
        if (!mounted || !identical(runs[name], run)) break;
        setState(() {
          tasks[event.owner] = event;
        });
      }
    } catch (error) {
      message(error is BridgeError ? error.message : '模型下载失败');
    } finally {
      if (run != null) await run.stop();
      if (identical(runs[name], run)) runs.remove(name);
      preparing.remove(name);
      if (mounted) {
        await reconcile();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> reconcile() async {
    try {
      final values = await (await widget.connect()).transfers();
      if (mounted) {
        setState(() {
          tasks.clear();
          for (final task in values) {
            tasks[task.owner] = task;
          }
        });
      }
    } catch (error) {
      message(error is BridgeError ? error.message : '下载状态读取失败');
    }
  }

  Future<void> pause(String name) async {
    await runs[name]?.stop();
    await reconcile();
  }

  Future<void> delete(String name) async {
    final task = tasks['mnn:$name'];
    if (task == null) return;
    try {
      await runs[name]?.stop(cancel: true);
      await (await widget.connect()).deleteTransfer(task.id);
      await reconcile();
    } catch (error) {
      message(error is BridgeError ? error.message : '模型删除失败');
    }
  }

  @override
  void dispose() {
    for (final run in runs.values.toList()) {
      unawaited(run.stop());
    }
    super.dispose();
  }

  String bytes(double value) => value >= 1024 * 1024 * 1024
      ? '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB'
      : value >= 1024 * 1024
      ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(value / 1024).toStringAsFixed(1)} KB';
  LocalModelPresentation projection(LocalModel model) {
    final task = tasks['mnn:${model.name}'];
    final phase = preparing.contains(model.name)
        ? LocalModelPhase.connecting
        : switch (task?.phase) {
            'running' || 'queued' || 'verifying' => LocalModelPhase.downloading,
            'paused' || 'cancelled' => LocalModelPhase.paused,
            'completed' => LocalModelPhase.completed,
            'failed' => LocalModelPhase.failed,
            _ => LocalModelPhase.idle,
          };
    final transferred = task?.transferred.toDouble() ?? 0;
    final total = task?.total.toDouble() ?? 0;
    return LocalModelPresentation(
      id: model.name,
      name: model.name,
      sizeGb: model.sizeGb,
      tags: model.tags,
      description: model.description,
      hasSource: model.hasSource,
      phase: phase,
      downloaded: phase == LocalModelPhase.completed,
      progress: total > 0 ? transferred / total : 0,
      transferred: '${bytes(transferred)} / ${bytes(total)}',
      speed: '${bytes(task?.bytesPerSecond ?? 0)}/s',
      currentFile: task?.currentFile ?? '',
      currentFileIndex: task?.fileIndex ?? 0,
      totalFiles: task?.totalFiles ?? 0,
      error: task?.error ?? '',
    );
  }

  @override
  Widget build(BuildContext context) => LocalModelsPage(
    snapshot: LocalModelsPresentation(
      models: models.map(projection).toList(),
      loading: loading,
      error: failed,
    ),
    onRefresh: () => unawaited(load(refresh: true)),
    onDownload: (name) => unawaited(start(name)),
    onPause: (name) => unawaited(pause(name)),
    onDelete: (name) => unawaited(delete(name)),
  );
}
