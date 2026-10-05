import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 包事实来自同一Rust运行时；Dart只持目录快照、操作阶段和读取代次。
class ExtensionsController extends ChangeNotifier {
  ExtensionsController(this.connect, {this.onChanged});
  final Future<RuntimeClient> Function() connect;
  final Future<void> Function()? onChanged;
  List<ExtensionPackage> packages = const [];
  bool loaded = false, loading = false, busy = false, disposed = false;
  String? error;
  int _generation = 0;
  Future<void>? _load;

  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> load() => _load ??= _read().whenComplete(() => _load = null);
  Future<void> _read() async {
    if (disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final values = await (await connect()).extensionPackages();
      if (!disposed && generation == _generation) {
        packages = List.unmodifiable(values);
        loaded = true;
      }
    } catch (_) {
      if (!disposed && generation == _generation) error = '扩展目录读取失败，请重新加载';
    } finally {
      if (!disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> change(ExtensionPackage package, {bool? enabled}) async {
    if (disposed || busy) return false;
    busy = true;
    error = null;
    _notify();
    bool committed = false;
    String? failure;
    try {
      final runtime = await connect();
      if (disposed) return false;
      await runtime.changeExtension(
        package.id,
        package.revision,
        enabled: enabled,
      );
      committed = true;
    } on BridgeError catch (e) {
      failure = e.message;
    } catch (_) {
      failure = '扩展操作未完成，请重新加载后重试';
    } finally {
      await _load;
      if (!disposed) await load();
      if (committed) {
        try {
          await onChanged?.call();
        } catch (_) {
          failure ??= '扩展已保存，模型目录刷新失败，请重新打开模型设置';
        }
      }
      if (!disposed) {
        busy = false;
        error = failure ?? error;
        _notify();
      }
    }
    return committed;
  }

  Future<void> installed() async {
    await _load;
    if (!disposed) await load();
    try {
      await onChanged?.call();
    } catch (_) {
      if (!disposed) {
        error = '扩展已安装，模型目录刷新失败，请重新打开模型设置';
        _notify();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    ++_generation;
    super.dispose();
  }
}
