import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 单一 Rust 快照的界面投影。所有写入固定空间 ID，不读取提交时的当前选择。
class KnowledgeController extends ChangeNotifier {
  KnowledgeController(this._connect);
  final Future<RuntimeClient> Function() _connect;
  KnowledgeSnapshot? snapshot;
  MemoryRecord? detail;
  DiaryDocument? diary;
  MemoryGraph? graph;
  MemorySearchSettings? searchSettings;
  bool graphVisible = false;
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

  Future<MemoryRecord?> open(MemoryRecord record) =>
      openId(record.spaceId, record.id);

  Future<MemoryRecord?> openId(String space, String id) async {
    final generation = ++_detailGeneration;
    final catalogGeneration = _generation;
    try {
      final client = await _connect();
      final value = await client.getMemory(space, id);
      final document = value?.draft.kind == 'diary'
          ? await client.parseDiary(value!.draft.content)
          : null;
      if (_disposed ||
          generation != _detailGeneration ||
          catalogGeneration != _generation ||
          snapshot?.activeSpace != space) {
        return null;
      }
      detail = value;
      diary = document;
      return value;
    } catch (_) {
      if (!_disposed &&
          generation == _detailGeneration &&
          catalogGeneration == _generation &&
          snapshot?.activeSpace == space) {
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
      diary = null;
      return;
    }
    final refreshed = await client.getMemory(current.spaceId, current.id);
    final document = refreshed?.draft.kind == 'diary'
        ? await client.parseDiary(refreshed!.draft.content)
        : null;
    if (!_disposed && generation == _generation && identical(detail, current)) {
      detail = refreshed;
      diary = document;
    }
  }

  bool loading = false, saving = false, _disposed = false;
  String? error;
  int _generation = 0;

  Future<void> showGraph(bool visible) async {
    if (saving || _disposed || graphVisible == visible) return;
    final space = snapshot?.activeSpace;
    if (space == null) return;
    await _mutate((client) => client.setMemoryGraphVisible(space, visible));
  }

  Future<void> _refreshSettings(
    RuntimeClient client,
    String space,
    int generation,
  ) async {
    final value = await client.memorySearchSettings(space);
    if (_disposed || generation != _generation) return;
    searchSettings = value;
    graphVisible = value.graphVisible;
    if (!graphVisible) graph = null;
  }

  Future<bool> saveSearchSettings(String space, MemorySearchSettings value) =>
      _mutate((client) => client.saveMemorySearchSettings(space, value));

  Future<MemorySearchReport> simulateSearch(
    String space,
    MemoryQuery request,
  ) async {
    final client = await _connect();
    if (_disposed) throw StateError('Knowledge page closed.');
    return client.simulateMemorySearch(space, request);
  }

  Future<void> _refreshGraph(
    RuntimeClient client,
    int generation,
    String space,
  ) async {
    if (!graphVisible) return;
    final value = await client.memoryGraph(query);
    if (value.spaceId != space) {
      throw StateError('Knowledge space changed while reading.');
    }
    if (!_disposed && generation == _generation && graphVisible) graph = value;
  }

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
        diaryClosed: query.diaryClosed,
      );
      final value = await client.queryKnowledge(request);
      if (!_disposed && generation == _generation) {
        await _refreshDetail(client, value, generation);
        await _refreshSettings(client, value.activeSpace, generation);
        await _refreshGraph(client, generation, value.activeSpace);
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
          availableTags: value.availableTags,
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
  String _stamp() => DateTime.now().toString().substring(0, 16);
  Future<bool> createDiary(String space, MemoryDraft draft, String phase) =>
      _mutate((client) async {
        await client.createDiary(space, draft, phase, _stamp());
      });
  Future<bool> appendDiary(MemoryRecord record, String body, String phase) =>
      _mutate((client) async {
        await client.appendDiary(
          record.spaceId,
          record.id,
          body,
          phase,
          _stamp(),
        );
      });
  Future<bool> archive(MemoryRecord record) => _mutate(
    (client) =>
        client.archiveMemory(record.spaceId, record.id, !record.archived),
  );
  Future<bool> delete(MemoryRecord record) => _mutate((client) async {
    await client.deleteMemory(record.spaceId, record.id);
  });
  Future<bool> saveLink(String space, String? id, MemoryLinkDraft draft) =>
      _mutate((client) async {
        await client.saveMemoryLink(space, id, draft);
      });
  Future<bool> deleteLink(String space, String id) => _mutate((client) async {
    await client.deleteMemoryLink(space, id);
  });
  Future<bool> deleteNodes(String space, List<String> ids) =>
      _mutate((client) async {
        await client.deleteMemories(space, ids);
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
      await _refreshSettings(client, value.activeSpace, _generation);
      await _refreshGraph(client, _generation, value.activeSpace);
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
