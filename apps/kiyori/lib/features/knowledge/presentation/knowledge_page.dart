import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'knowledge_controller.dart';
import 'memory_editor.dart';
import 'knowledge_dialogs.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({
    required this.controller,
    required this.onMenu,
    super.key,
  });
  final KnowledgeController controller;
  final VoidCallback onMenu;
  @override
  State<KnowledgePage> createState() => KnowledgePageState();
}

class KnowledgePageState extends State<KnowledgePage> {
  String kind = 'memory', folder = '', query = '';
  String? category, tag;
  bool archived = false, sortTitle = false;
  final search = TextEditingController();
  final _routes = <ModalRoute<dynamic>>[];
  String? _space;
  bool _opening = false;
  KnowledgeController get state => widget.controller;
  MemoryQuery get _query => MemoryQuery(
    kind: kind,
    folder: folder,
    text: query,
    category: category,
    tag: tag,
    archived: archived,
    sortTitle: sortTitle,
    offset: 0,
  );
  void _change(VoidCallback change) {
    if (state.saving) return;
    final before = _query;
    setState(change);
    final after = _query;
    if (before != after) {
      state.setQuery(after);
      unawaited(state.load());
    }
  }

  bool handleBack() {
    if (folder.isEmpty) return false;
    _change(
      () => folder = folder.contains('/')
          ? folder.substring(0, folder.lastIndexOf('/'))
          : '',
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    state.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && state.snapshot == null) unawaited(state.load());
    });
  }

  void _changed() {
    if (!mounted) return;
    final current = state.snapshot?.activeSpace;
    if (_space != null && current != _space) {
      kind = 'memory';
      folder = '';
      query = '';
      search.clear();
      category = null;
      tag = null;
      archived = false;
      sortTitle = false;
      _removeRoutes();
    }
    _space = current;
    if (folder.isNotEmpty &&
        !(state.snapshot?.folders.contains(folder) ?? false)) {
      folder = '';
      state.setQuery(_query);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !state.saving && !state.loading) unawaited(state.load());
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant KnowledgePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, state)) return;
    oldWidget.controller.removeListener(_changed);
    _removeRoutes();
    _opening = false;
    _space = state.snapshot?.activeSpace;
    final value = state.query;
    kind = value.kind ?? 'memory';
    folder = value.folder;
    query = value.text;
    search.text = query;
    category = value.category;
    tag = value.tag;
    archived = value.archived;
    sortTitle = value.sortTitle;
    state.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && state.snapshot == null) unawaited(state.load());
    });
  }

  void _removeRoutes() {
    final routes = _routes.reversed.toList();
    _routes.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    state.removeListener(_changed);
    _removeRoutes();
    search.dispose();
    super.dispose();
  }

  Future<T?> _dialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(
      context: context,
      builder: (context) => SettingsTheme(child: builder(context)),
    );
    _routes.add(route);
    final value = await Navigator.of(context).push(route);
    _routes.remove(route);
    return mounted ? value : null;
  }

  Future<void> _drawer(
    String title,
    Widget Function(BuildContext, Future<void> Function()) content,
  ) async {
    ModalRoute<dynamic>? owned;
    await showKiyoriModalDrawer<void>(
      context,
      canDismiss: () => !state.saving,
      onRoute: (route) {
        if (owned != null) return;
        owned = route;
        if (mounted) {
          _routes.add(route);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route.isActive) route.navigator?.removeRoute(route);
          });
          WidgetsBinding.instance.ensureVisualUpdate();
        }
      },
      builder: (context, dismiss) => SettingsTheme(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => unawaited(dismiss()),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(child: content(context, dismiss)),
          ],
        ),
      ),
    );
    _routes.remove(owned);
  }

  Future<String?> _menu(
    BuildContext anchor,
    List<(String, String)> options,
  ) async {
    final button = anchor.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final space = state.snapshot?.activeSpace;
    ModalRoute<dynamic>? owned;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final option in options)
          PopupMenuItem(
            value: option.$1,
            child: Builder(
              builder: (context) {
                final route = ModalRoute.of(context);
                if (owned == null && route != null) {
                  owned = route;
                  if (mounted) {
                    _routes.add(route);
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (route.isActive) route.navigator?.removeRoute(route);
                    });
                    WidgetsBinding.instance.ensureVisualUpdate();
                  }
                }
                return Text(option.$2);
              },
            ),
          ),
      ],
    );
    _routes.remove(owned);
    return mounted && space == state.snapshot?.activeSpace && !state.saving
        ? value
        : null;
  }

  Future<void> _folderMenu(BuildContext context, String path) async {
    final space = state.snapshot!.activeSpace;
    final choice = await _menu(context, [('rename', '重命名'), ('delete', '删除')]);
    if (!mounted || !(state.snapshot?.folders.contains(path) ?? false)) return;
    if (choice == 'rename') {
      _nameDialog(
        '重命名文件夹',
        path,
        (value) => state.renameFolder(space, path, value),
      );
    }
    if (choice == 'delete') {
      _confirm('删除文件夹', '保留正文，移到根目录', () => state.deleteFolder(space, path));
    }
  }

  Future<void> _recordMenu(BuildContext context, MemoryRecord record) async {
    final choice = await _menu(context, [
      ('archive', record.archived ? '恢复' : '归档'),
      ('delete', '删除'),
    ]);
    if (!mounted ||
        state.detail?.id != record.id ||
        state.detail?.spaceId != record.spaceId) {
      return;
    }
    if (choice == 'archive') unawaited(state.archive(record));
    if (choice == 'delete') {
      _confirm('删除', '删除后无法恢复，确定删除此条目及其关联吗？', () => state.delete(record));
    }
  }

  void _edit([MemoryRecord? record]) async {
    if (_opening || state.saving || state.snapshot == null || kind == 'diary') {
      return;
    }
    _opening = true;
    final space = state.snapshot!.activeSpace;
    final key = GlobalKey<MemoryEditorState>();
    ModalRoute<dynamic>? owned;
    await showKiyoriModalDrawer<void>(
      context,
      canDismiss: () => key.currentState?.canDismiss() ?? true,
      onRoute: (route) {
        if (owned != null) return;
        owned = route;
        if (mounted) {
          _routes.add(route);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route.isActive) route.navigator?.removeRoute(route);
          });
          WidgetsBinding.instance.ensureVisualUpdate();
        }
      },
      builder: (context, dismiss) => MemoryEditor(
        key: key,
        controller: state,
        space: space,
        kind: record?.draft.kind ?? kind,
        folder: folder,
        record: record,
        dismiss: dismiss,
      ),
    );
    _routes.remove(owned);
    _opening = false;
  }

  void _nameDialog(
    String title,
    String initial,
    Future<bool> Function(String) save,
  ) => unawaited(
    _dialog(
      (context) => KnowledgeNameDialog(
        title: title,
        initial: initial,
        controller: state,
        save: save,
      ),
    ),
  );
  void _createFolder() {
    final space = state.snapshot?.activeSpace;
    if (space == null) return;
    _nameDialog(
      '新建文件夹',
      folder.isEmpty ? '' : '$folder/',
      (value) => state.createFolder(space, value),
    );
  }

  void _spaceDialog() => unawaited(
    _drawer(
      '空间与文件夹',
      (context, dismiss) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final snapshot = state.snapshot!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) => OutlinedButton(
                          onPressed: state.saving
                              ? null
                              : () async {
                                  final id = await _menu(context, [
                                    for (final space in snapshot.spaces)
                                      (space.id, space.name),
                                  ]);
                                  if (id != null) await state.selectSpace(id);
                                },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '选择记忆空间',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      snapshot.spaces
                                          .firstWhere(
                                            (s) => s.id == snapshot.activeSpace,
                                          )
                                          .name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: '管理记忆空间',
                        onPressed: state.saving
                            ? null
                            : () async {
                                final choice = await _menu(context, [
                                  ('create', '新建记忆空间'),
                                  ('rename', '重命名记忆空间'),
                                  if (snapshot.activeSpace != 'default')
                                    ('delete', '删除记忆空间'),
                                ]);
                                if (!mounted) return;
                                if (choice == 'create') {
                                  _nameDialog(
                                    '新建记忆空间',
                                    '',
                                    (name) => state.saveSpace(null, name),
                                  );
                                }
                                if (choice == 'rename') {
                                  _nameDialog(
                                    '重命名记忆空间',
                                    snapshot.spaces
                                        .firstWhere(
                                          (s) => s.id == snapshot.activeSpace,
                                        )
                                        .name,
                                    (name) => state.saveSpace(
                                      snapshot.activeSpace,
                                      name,
                                    ),
                                  );
                                }
                                if (choice == 'delete') {
                                  _confirm(
                                    '删除记忆空间',
                                    '确定删除此空间及其中的全部记忆吗？此操作无法撤销。',
                                    () =>
                                        state.deleteSpace(snapshot.activeSpace),
                                  );
                                }
                              },
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                TextButton(
                  onPressed: () => _chooseFolder(dismiss, ''),
                  child: const Text('根目录'),
                ),
                for (final path in snapshot.folders)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _chooseFolder(dismiss, path),
                          child: Text(path),
                        ),
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: '$path 的文件夹操作',
                          onPressed: state.saving
                              ? null
                              : () => _folderMenu(context, path),
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                    ],
                  ),
                if (snapshot.folders.isEmpty)
                  const Text('还没有文件夹。可以按项目或主题整理内容。'),
                TextButton(
                  onPressed: state.saving ? null : _createFolder,
                  child: const Text('新建文件夹'),
                ),
                if (state.error != null) Text(state.error!),
              ],
            ),
          );
        },
      ),
    ),
  );
  void _chooseFolder(Future<void> Function() dismiss, String path) {
    if (state.saving) return;
    _change(() => folder = path);
    unawaited(dismiss());
  }

  void _confirm(String title, String message, Future<bool> Function() save) =>
      unawaited(
        _dialog(
          (context) => KnowledgeConfirmDialog(
            title: title,
            message: message,
            controller: state,
            save: save,
          ),
        ),
      );
  Future<void> _details(MemoryRecord original) async {
    if (_opening || state.saving) return;
    _opening = true;
    final owner = state;
    final full = await owner.open(original);
    if (!identical(owner, state)) return;
    if (!mounted || full == null) {
      _opening = false;
      return;
    }
    _opening = false;
    await _dialog(
      (context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final record = state.detail;
          if (record == null) {
            final route = ModalRoute.of(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (route?.isActive ?? false) {
                route!.navigator?.removeRoute(route);
              }
            });
            WidgetsBinding.instance.ensureVisualUpdate();
            return const SizedBox.shrink();
          }
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .9,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.draft.kind == 'knowledge' ? '知识' : '记忆',
                            ),
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: '更多操作',
                              onPressed: state.saving
                                  ? null
                                  : () => _recordMenu(context, record),
                              icon: const Icon(Icons.more_vert),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: state.saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            SelectableText(
                              record.draft.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${memoryCategories[record.draft.category]} · ${_source(record.draft.source)} · ${_date(record.updatedAt)}',
                            ),
                            if (record.archived)
                              const Text('归档内容保留在库中，但不会参与日常和 AI 检索。'),
                            if (state.error != null) Text(state.error!),
                            SelectableText(record.draft.content),
                            Text(
                              record.draft.tags.map((t) => '#$t').join('  '),
                            ),
                            ExpansionTile(
                              title: const Text('条目信息'),
                              children: [
                                Text(
                                  '文件夹：${record.draft.folder.isEmpty ? '根目录' : record.draft.folder}\n可信度：${record.draft.credibility}\n重要性：${record.draft.importance}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: state.saving ? null : () => _edit(record),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _filters() => unawaited(
    _drawer(
      '筛选与排序',
      (context, dismiss) => StatefulBuilder(
        builder: (context, update) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('最近更新'),
                          selected: !sortTitle,
                          onSelected: (_) {
                            _change(() => sortTitle = false);
                            update(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('标题顺序'),
                          selected: sortTitle,
                          onSelected: (_) {
                            _change(() => sortTitle = true);
                            update(() {});
                          },
                        ),
                      ],
                    ),
                    if (kind != 'diary')
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('全部主题'),
                            selected: category == null,
                            onSelected: (_) {
                              _change(() => category = null);
                              update(() {});
                            },
                          ),
                          for (final value in memoryCategories.entries)
                            ChoiceChip(
                              label: Text(value.value),
                              selected: category == value.key,
                              onSelected: (_) {
                                _change(() => category = value.key);
                                update(() {});
                              },
                            ),
                        ],
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('只看已归档'),
                      subtitle: const Text('归档内容保留在库中，但不会参与日常和 AI 检索。'),
                      value: archived,
                      onChanged: (v) {
                        _change(() => archived = v);
                        update(() {});
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('全部标签'),
                          selected: tag == null,
                          onSelected: (_) {
                            _change(() => tag = null);
                            update(() {});
                          },
                        ),
                        for (final value in {
                          ...?state.snapshot?.records.expand(
                            (r) => r.draft.tags,
                          ),
                          ?tag,
                        })
                          ChoiceChip(
                            label: Text(value),
                            selected: tag == value,
                            onSelected: (_) {
                              _change(() => tag = value);
                              update(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _change(() {
                        category = null;
                        tag = null;
                        archived = false;
                        sortTitle = false;
                      });
                      update(() {});
                    },
                    child: const Text('重置筛选'),
                  ),
                  FilledButton(
                    onPressed: () => unawaited(dismiss()),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String _source(String value) => value == 'user_input' ? '手动记录' : value;
  String _date(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value)
          .toLocal()
          .toString()
          .substring(0, 16);
  void _search() => _change(() => query = search.text.trim());
  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final busy = state.saving;
    final filtered =
        query.isNotEmpty || category != null || tag != null || archived;
    final entries = snapshot?.records ?? <MemoryRecord>[];
    final folders = filtered
        ? <String>[]
        : (snapshot?.folders ?? <String>[])
              .where(
                (p) => folder.isEmpty
                    ? !p.contains('/')
                    : p.startsWith('$folder/') &&
                          !p.substring(folder.length + 1).contains('/'),
              )
              .toList();
    final pending = search.text.trim() != query;
    return PrimaryPage(
      title: '记忆库',
      onMenu: widget.onMenu,
      actionWidth: 160,
      actions: [
        ShellAction(Icons.settings_outlined, '记忆与检索设置'),
        ShellAction(Icons.tune_outlined, '筛选', onTap: _filters),
        ShellAction(Icons.account_tree_outlined, '图谱'),
        ShellAction(Icons.refresh, '刷新', onTap: () => unawaited(state.load())),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final selector = TextButton(
                  onPressed: snapshot == null || busy ? null : _spaceDialog,
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('记忆空间', style: TextStyle(fontSize: 11)),
                            Text(
                              snapshot?.spaces
                                      .where(
                                        (s) => s.id == snapshot.activeSpace,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  '...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                );
                final kinds = SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'memory', label: Text('记忆')),
                    ButtonSegment(value: 'diary', label: Text('日记')),
                    ButtonSegment(value: 'knowledge', label: Text('知识')),
                  ],
                  selected: {kind},
                  onSelectionChanged: busy
                      ? null
                      : (value) => _change(() {
                          kind = value.first;
                          category = null;
                          tag = null;
                        }),
                );
                return MediaQuery.textScalerOf(context).scale(12) > 18
                    ? Column(children: [selector, kinds])
                    : Row(
                        children: [
                          Expanded(child: selector),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: kinds),
                        ],
                      );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: search,
              enabled: !busy,
              onChanged: (_) => _change(() {}),
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: kind == 'knowledge'
                    ? '搜索知识'
                    : kind == 'diary'
                    ? '搜索日记'
                    : '搜索记忆',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                prefixIcon: IconButton(
                  tooltip: '搜索',
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          search.clear();
                          _search();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: '返回上级',
                onPressed: folder.isEmpty || busy ? null : handleBack,
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => _change(() => folder = ''),
                        child: const Text('根目录'),
                      ),
                      if (folder.isNotEmpty) Text(folder),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(state.load()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.loading && snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : pending
                ? _empty(
                    '查找需要的内容',
                    '点击搜索图标或键盘搜索键开始查找。',
                    FilledButton(onPressed: _search, child: const Text('搜索')),
                  )
                : entries.isEmpty && folders.isEmpty
                ? _empty(
                    filtered
                        ? '没有找到内容'
                        : kind == 'knowledge'
                        ? '建立你的参考资料库'
                        : kind == 'diary'
                        ? '记录正在推进的工作'
                        : '让有用的信息留下来',
                    filtered
                        ? '试试其他关键词，或重置筛选条件。'
                        : kind == 'knowledge'
                        ? '收藏文档与参考笔记，\n需要时随时查找。'
                        : kind == 'diary'
                        ? '把复杂任务的进展、决策和证据写成一篇日记，\n之后随时续写。'
                        : '记下偏好、事实或经验，\n让之后的对话更懂你。',
                    filtered
                        ? TextButton(
                            onPressed: () => _change(() {
                              query = '';
                              search.clear();
                              category = null;
                              tag = null;
                              archived = false;
                            }),
                            child: const Text('重置筛选'),
                          )
                        : Column(
                            children: [
                              FilledButton.icon(
                                onPressed: snapshot == null || busy
                                    ? null
                                    : kind == 'knowledge' || kind == 'diary'
                                    ? () {}
                                    : () => _edit(),
                                icon: Icon(
                                  kind == 'knowledge'
                                      ? Icons.upload_file
                                      : Icons.add,
                                ),
                                label: Text(
                                  kind == 'knowledge'
                                      ? '导入资料'
                                      : kind == 'diary'
                                      ? '新建日记'
                                      : '新建记忆',
                                ),
                              ),
                              if (kind == 'knowledge')
                                TextButton(
                                  onPressed: snapshot == null || busy
                                      ? null
                                      : () => _edit(),
                                  child: const Text('新建笔记'),
                                ),
                            ],
                          ),
                  )
                : Stack(
                    children: [
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount:
                            folders.length +
                            entries.length +
                            (snapshot?.hasMore == true ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == folders.length + entries.length) {
                            return TextButton(
                              onPressed: state.loading
                                  ? null
                                  : () => unawaited(state.load(more: true)),
                              child: const Text('加载更多'),
                            );
                          }
                          if (index < folders.length) {
                            final path = folders[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.folder_outlined),
                                title: Text(path.split('/').last),
                                onTap: () => _change(() => folder = path),
                              ),
                            );
                          }
                          final record = entries[index - folders.length];
                          return Card(
                            child: InkWell(
                              onTap: () => _details(record),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 8,
                                  children: [
                                    Text(
                                      record.draft.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      record.draft.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${memoryCategories[record.draft.category]} · ${_source(record.draft.source)} · ${_date(record.updatedAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    if (record.draft.tags.isNotEmpty)
                                      Text(
                                        record.draft.tags
                                            .take(3)
                                            .map((t) => '#$t')
                                            .join('  '),
                                      ),
                                    if (filtered &&
                                        record.draft.folder.isNotEmpty)
                                      Text(record.draft.folder),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          onPressed: busy ? null : () => _addMenu(),
                          icon: const Icon(Icons.add),
                          label: const Text('添加内容'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _addMenu() => unawaited(
    _dialog(
      (context) => SimpleDialog(
        children: [
          if (kind == 'knowledge')
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('导入资料'),
            ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(context).pop();
              _edit();
            },
            child: Text(
              kind == 'knowledge'
                  ? '新建笔记'
                  : kind == 'diary'
                  ? '新建日记'
                  : '新建记忆',
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(context).pop();
              _createFolder();
            },
            child: const Text('新建文件夹'),
          ),
        ],
      ),
    ),
  );
  Widget _empty(String title, String hint, Widget action) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: IconTone.memory.containerFor(context),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              kind == 'knowledge'
                  ? Icons.menu_book
                  : kind == 'diary'
                  ? Icons.event_note
                  : Icons.psychology_outlined,
              size: 28,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(hint, textAlign: TextAlign.center),
          action,
        ],
      ),
    ),
  );
}
