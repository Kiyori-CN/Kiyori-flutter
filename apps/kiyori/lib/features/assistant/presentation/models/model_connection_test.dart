import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'model_credentials.dart';

enum ModelTestOutcome { passed, unverified, failed }

class ModelTestItem {
  const ModelTestItem(this.label, this.outcome, this.message);
  final String label, message;
  final ModelTestOutcome outcome;
}

/// 单次配置快照的测试投影；网络、协议、取消与错误由同一Rust请求核心负责。
class ModelConnectionTest extends ChangeNotifier {
  ModelConnectionTest(this.connect);
  final Future<RuntimeClient> Function() connect;
  ChatRun? _run;
  bool running = false, _disposed = false;
  int _generation = 0;
  String model = '';
  List<ModelTestItem>? results;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> cancel() async {
    _generation++;
    running = false;
    await _run?.cancel();
    _notify();
  }

  Future<void> start(
    ModelConfigDraft draft,
    ModelCredentials credentials, {
    ModelConfig? config,
  }) async {
    if (running || _disposed) return;
    final generation = ++_generation;
    running = true;
    results = null;
    model = draft.models.firstOrNull ?? '';
    _notify();
    final items = <ModelTestItem>[];
    try {
      if (model.isEmpty) throw const FormatException('请先添加模型');
      if (credentials.usePool && config == null) {
        throw const FormatException('密钥池测试需要已保存的配置');
      }
      Future<ModelTestItem> probe(String label, String kind) async {
        final runtime = await connect();
        if (_disposed || generation != _generation) {
          return ModelTestItem(label, ModelTestOutcome.unverified, '已取消');
        }
        final run = config != null
            ? await runtime.startConfiguredProbe(
                config.id,
                config.revision,
                credentials.encode(),
                kind,
              )
            : await runtime.startModelProbe(draft, credentials.apiKey, [
                for (final h in credentials.headers.entries)
                  ChatHeader(name: h.key, value: h.value),
              ], kind);
        if (_disposed || generation != _generation) {
          await run.cancel();
          await run.events.drain<void>();
          return ModelTestItem(label, ModelTestOutcome.unverified, '已取消');
        }
        _run = run;
        var verified = false;
        try {
          await for (final event in run.events) {
            if (event.phase == ChatPhase.failed) {
              return ModelTestItem(
                label,
                ModelTestOutcome.failed,
                event.errorMessage,
              );
            } else if (event.phase == ChatPhase.completed) {
              verified = event.verified == true;
            }
          }
        } finally {
          if (identical(_run, run)) _run = null;
        }
        return ModelTestItem(
          label,
          verified ? ModelTestOutcome.passed : ModelTestOutcome.unverified,
          verified ? '通过' : '未能验证，请检查模型实际输出或重试',
        );
      }

      items.add(await probe('聊天', 'chat'));
      if (_disposed || generation != _generation) return;
      items.add(
        ModelTestItem(
          draft.options.toolCall ? 'Tool Call' : '内置工具调用',
          ModelTestOutcome.unverified,
          '未能验证此能力',
        ),
      );
      items.add(await probe('系统指令遵循', 'system'));
      for (final (enabled, label) in [
        (draft.options.image, '图像'),
        (draft.options.audio, '音频'),
        (draft.options.video, '视频'),
      ]) {
        if (enabled) {
          items.add(
            ModelTestItem(label, ModelTestOutcome.unverified, '未能验证此能力'),
          );
        }
      }
    } catch (_) {
      items.add(
        const ModelTestItem(
          '聊天',
          ModelTestOutcome.failed,
          '测试无法启动，请检查模型、密钥池可用性及请求参数',
        ),
      );
    } finally {
      if (!_disposed && generation == _generation) {
        results = List.unmodifiable(items);
        running = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_run?.cancel());
    super.dispose();
  }
}
