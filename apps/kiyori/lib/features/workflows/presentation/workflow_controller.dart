import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 只投影 Rust 权威目录；不在 Dart 合成成功记录或写入第二套存储。
class WorkflowController extends ChangeNotifier {
  WorkflowController(this._connect);
  final Future<RuntimeClient> Function() _connect;
  List<WorkflowRecord> records = const [];
  bool loaded = false;
  bool loading = false;
  bool saving = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final client = await _connect();
      if (_disposed || generation != _generation) return;
      final values = await client.listWorkflows();
      if (_disposed || generation != _generation) return;
      records = List.unmodifiable(values);
      loaded = true;
    } catch (failure) {
      if (!_disposed && generation == _generation) error = _message(failure);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<WorkflowRecord?> create(String name, String description) async {
    WorkflowRecord? created;
    await _mutate((client) async {
      created = await client.createWorkflow(name, description);
    });
    return _disposed ? null : created;
  }

  Future<bool> delete(String id) => _mutate((client) async {
    await client.deleteWorkflow(id);
  });

  Future<bool> deleteMany(List<String> ids) => _mutate((client) async {
    await client.deleteWorkflows(ids);
  });

  Future<bool> update(
    WorkflowRecord record, {
    String? name,
    String? description,
    bool? enabled,
  }) => _mutate((client) async {
    await client.updateWorkflow(
      id: record.id,
      name: name ?? record.name,
      description: description ?? record.description,
      enabled: enabled ?? record.enabled,
    );
  });

  Future<bool> _mutate(Future<void> Function(RuntimeClient) action) async {
    if (_disposed || saving) return false;
    ++_generation; // 撤销更早的列表读取，禁止覆盖提交后的快照。
    loading = false;
    saving = true;
    error = null;
    notifyListeners();
    var committed = false;
    try {
      final client = await _connect();
      if (_disposed) return false;
      await action(client);
      committed = true;
      // 写入已提交后，即使刷新失败也不能提示用户重复创建。
      final values = await client.listWorkflows();
      if (!_disposed) {
        records = List.unmodifiable(values);
        loaded = true;
      }
    } catch (failure) {
      if (!_disposed) {
        error = committed ? '操作已保存，但目录刷新失败，请重试刷新。' : _message(failure);
      }
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
    return committed && !_disposed;
  }

  String _message(Object failure) => switch (failure) {
    BridgeError(code: ErrorCode.invalidInput) => '工作流名称不能为空。',
    BridgeError(code: ErrorCode.runtimeClosed) => '工作空间已关闭，请重新打开应用。',
    _ => '无法读取或保存工作流，请检查应用存储后重试。',
  };

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
