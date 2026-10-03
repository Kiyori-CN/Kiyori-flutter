import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 单次页面访问的草稿；核心同时校验聊天绑定、模型revision和全局媒体revision。
class ContextEditSession extends ChangeNotifier {
  ContextEditSession(this.connect, this.base) {
    final o = base.config.draft.options;
    options = ContextOptions(
      contextLength: o.contextLength,
      maxContextLength: o.maxContextLength,
      summaryEnabled: o.summaryEnabled,
      summaryThreshold: o.summaryThreshold,
      summaryByCount: o.summaryByCount,
      summaryCount: o.summaryCount,
      summaryRules: o.summaryRules,
    );
    history = base.history;
    _saved = _fingerprint();
  }
  final Future<RuntimeClient> Function() connect;
  ContextSettings base;
  late ContextOptions options;
  late HistoryRetention history;
  void Function()? read;
  String? error;
  late String _saved;
  Timer? _timer;
  Future<bool>? _flight;
  bool _disposed = false;
  int _edits = 0;
  bool get saving => _flight != null;
  Future<bool>? get pendingSave => _flight;

  String _fingerprint() => jsonEncode([
    options.contextLength,
    options.maxContextLength,
    options.summaryEnabled,
    options.summaryThreshold,
    options.summaryByCount,
    options.summaryCount,
    options.summaryRules,
    history.imageTurns,
    history.mediaTurns,
  ]);

  void changed() {
    if (_disposed) return;
    _edits++;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () => unawaited(flush()));
  }

  Future<bool> flush() async {
    _timer?.cancel();
    if (_flight != null) {
      final result = await _flight!;
      if (!result || _disposed) return result;
      return flush();
    }
    if (_disposed) return false;
    final operation = _drain();
    _flight = operation;
    notifyListeners();
    try {
      return await operation;
    } finally {
      _flight = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> _drain() async {
    try {
      while (!_disposed) {
        final version = _edits;
        read?.call();
        // FFI的u32编码不能用于验证Dart整数，须在跨桥前拒绝溢出及负数。
        for (final count in [
          options.summaryCount,
          history.imageTurns,
          history.mediaTurns,
        ]) {
          if (count < 0 || count > 0x7fffffff) {
            throw const FormatException('回合数量无效');
          }
        }
        final fingerprint = _fingerprint();
        if (fingerprint != _saved) {
          base = await (await connect()).saveContextSettings(
            base.config.id,
            base.config.revision,
            options,
            HistoryRetention(
              revision: base.history.revision,
              imageTurns: history.imageTurns,
              mediaTurns: history.mediaTurns,
            ),
          );
          _saved = fingerprint;
        }
        error = null;
        if (version == _edits) return true;
      }
    } catch (_) {
      error = '保存失败，请检查输入；若配置已在别处更改，请重新载入。当前草稿已保留';
    }
    return false;
  }

  @override
  void dispose() {
    discard();
    super.dispose();
  }

  void discard() {
    _disposed = true;
    _timer?.cancel();
    read = null;
  }
}
