import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 单一 Rust 快照的界面投影。所有写入固定空间 ID，不读取提交时的当前选择。
class KnowledgeController extends ChangeNotifier {
  KnowledgeController(this._connect);
  final Future<RuntimeClient> Function() _connect;
  KnowledgeSnapshot? snapshot;
  MemoryRecord? detail;
  static const initialQuery = MemoryQuery(
    kind: 'memory',
    folder: '',
    text: '',
    archived: false,
    sortTitle: false,
    offset: 0,
  );
  MemoryQuery query = initialQuery;
  int _detailGeneration = 0;

  void setQuery(MemoryQuery value) {
    if (saving || _disposed) return;
    query = value;
  }

  Future<MemoryRecord?> open(MemoryRecord record) async {
    final generation = ++_detailGeneration;
    final catalogGeneration = _generation;
    try {
      final client = await _connect();
      final value = await client.getMemory(record.spaceId, record.id);
      if (_disposed ||
          generation != _detailGeneration ||
          catalogGeneration != _generation ||
          snapshot?.activeSpace != record.spaceId) {
        return null;
      }
      detail = value;
      return value;
    } catch (_) {
      if (!_disposed &&
          generation == _detailGeneration &&
          catalogGeneration == _generation &&
          snapshot?.activeSpace == record.spaceId) {
        error = '无法读取条目，请重试。';
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> _refreshDetail(
    RuntimeClient client,
    KnowledgeSnapshot value,
    int generation,
  ) async {
    final current = detail;
    if (current == null) return;
    if (current.spaceId != value.activeSpace) {
      detail = null;
      return;
    }
    final refreshed = await client.getMemory(current.spaceId, current.id);
    if (!_disposed && generation == _generation && identical(detail, current)) {
      detail = refreshed;
    }
  }

  bool loading = false, saving = false, _disposed = false;
  String? error;
  int _generation = 0;

  Future<void> load({bool more = false}) async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final client = await _connect();
      if (_disposed || generation != _generation) return;
      final request = MemoryQuery(
        kind: query.kind,
        folder: query.folder,
        text: query.text,
        category: query.category,
        tag: query.tag,
        archived: query.archived,
        sortTitle: query.sortTitle,
        offset: more ? (snapshot?.records.length ?? 0) : 0,
      );
      final value = await client.queryKnowledge(request);
      if (!_disposed && generation == _generation) {
        await _refreshDetail(client, value, generation);
        if (_disposed || generation != _generation) return;
        final records = more && snapshot?.activeSpace == value.activeSpace
            ? [...snapshot!.records, ...value.records]
            : value.records;
        snapshot = KnowledgeSnapshot(
          spaces: value.spaces,
          activeSpace: value.activeSpace,
          folders: value.folders,
          records: records,
          hasMore: value.hasMore,
        );
      }
    } catch (_) {
      if (!_disposed && generation == _generation) error = '无法读取记忆库，请重试。';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveSpace(String? id, String name) => _mutate((client) async {
    await client.saveKnowledgeSpace(id, name);
    if (id == null) query = initialQuery;
  });
  Future<bool> selectSpace(String id) => _mutate((client) async {
    await client.selectKnowledgeSpace(id);
    query = initialQuery;
  });
  Future<bool> deleteSpace(String id) => _mutate((client) async {
    await client.deleteKnowledgeSpace(id);
    query = initialQuery;
  });
  Future<bool> createFolder(String space, String path) =>
      _mutate((client) => client.createKnowledgeFolder(space, path));
  Future<bool> renameFolder(String space, String old, String path) =>
      _mutate((client) => client.renameKnowledgeFolder(space, old, path));
  Future<bool> deleteFolder(String space, String path) =>
      _mutate((client) => client.deleteKnowledgeFolder(space, path));
  Future<bool> save(String space, String? id, MemoryDraft draft) =>
      _mutate((client) async {
        await client.saveMemory(space, id, draft);
      });
  Future<bool> archive(MemoryRecord record) => _mutate(
    (client) =>
        client.archiveMemory(record.spaceId, record.id, !record.archived),
  );
  Future<bool> delete(MemoryRecord record) => _mutate((client) async {
    await client.deleteMemory(record.spaceId, record.id);
  });

  Future<bool> _mutate(Future<void> Function(RuntimeClient) action) async {
    if (_disposed || saving) return false;
    ++_generation;
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
      final value = await client.queryKnowledge(query);
      await _refreshDetail(client, value, _generation);
      if (!_disposed) snapshot = value;
    } catch (failure) {
      if (!_disposed) {
        error = committed
            ? '操作已保存，但目录刷新失败，请刷新后继续。'
            : switch (failure) {
                BridgeError(code: ErrorCode.invalidInput) =>
                  '内容无效或条目已变化，请检查后重试。',
                BridgeError(code: ErrorCode.runtimeClosed) =>
                  '工作空间已关闭，请重新打开应用。',
                _ => '无法保存记忆库，请重试。',
              };
      }
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
    return committed && !_disposed;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_detailGeneration;
    ++_generation;
    super.dispose();
  }
}
