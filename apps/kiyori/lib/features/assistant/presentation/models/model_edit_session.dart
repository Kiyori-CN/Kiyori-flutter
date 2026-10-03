import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'model_credentials.dart';
import 'model_connection_test.dart';
import 'model_options_editing.dart';
import 'models_controller.dart';

/// 单配置编辑会话。700ms去抖沿用旧版；提交串行，保存期间的新输入进入下一次。
class ModelEditSession extends ChangeNotifier {
  ModelEditSession(this.owner, this.base, this.credentials) {
    connectionTest = ModelConnectionTest(owner.connect);
    draft = base.draft;
    _saved = _fingerprint();
    _persistedCredentials = credentials;
  }
  final ModelsController owner;
  late final ModelConnectionTest connectionTest;
  ModelConfig base;
  late ModelConfigDraft draft;
  ModelCredentials credentials;
  late ModelCredentials _persistedCredentials;
  final readers = <Object, void Function()>{};
  late String _saved;
  Timer? _timer;
  Future<bool>? _flight;
  Future<void>? exchange;
  bool _disposed = false;
  int _edits = 0;
  String? error;
  String? replacement;
  bool replacementRequired = false;
  bool get saving => _flight != null;

  String _fingerprint() => jsonEncode([
    draft.name,
    draft.provider,
    draft.protocol,
    draft.endpoint,
    draft.models,
    draft.options.comparison,
    credentials.encode(),
  ]);

  void update({
    String? name,
    String? provider,
    String? protocol,
    String? endpoint,
    List<String>? models,
    ModelOptions? options,
  }) {
    draft = ModelConfigDraft(
      name: name ?? draft.name,
      provider: provider ?? draft.provider,
      protocol: protocol ?? draft.protocol,
      endpoint: endpoint ?? draft.endpoint,
      models: models ?? draft.models,
      options: options ?? draft.options,
    );
  }

  void changed() {
    if (_disposed) return;
    _edits++;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      unawaited(flush());
    });
  }

  Future<bool> flush() async {
    _timer?.cancel();
    await exchange;
    if (_flight != null) {
      final succeeded = await _flight!;
      if (!succeeded || _disposed) return succeeded;
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
    while (!_disposed) {
      final version = _edits;
      if (!await _save()) return false;
      if (version == _edits) return true;
    }
    return false;
  }

  Future<bool> _save() async {
    try {
      for (final read in readers.values.toList()) {
        read();
      }
      final fingerprint = _fingerprint();
      if (fingerprint == _saved) {
        error = null;
        return true;
      }
      final submitted = draft;
      final submittedCredentials = credentials;
      base = await owner.save(
        base,
        submitted,
        _persistedCredentials,
        submittedCredentials,
        replacement: replacement,
      );
      _persistedCredentials = submittedCredentials;
      _saved = fingerprint;
      error = null;
      replacement = null;
      replacementRequired = false;
      return true;
    } catch (failure) {
      // 不拼接异常，桥或native错误可能源于用户的端点/凭据输入。
      error = '保存失败，请检查输入或重新载入；当前草稿已保留';
      replacementRequired =
          failure is BridgeError &&
          failure.message ==
              'Bound models require an explicit valid replacement.';
      if (replacementRequired) error = '已移除的模型仍被功能或角色使用，请选择替代模型';
      return false;
    }
  }

  @override
  void dispose() {
    connectionTest.dispose();
    _disposed = true;
    _timer?.cancel();
    readers.clear();
    super.dispose();
  }
}
