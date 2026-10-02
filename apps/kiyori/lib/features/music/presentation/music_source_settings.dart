import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_settings_presentation.dart';
import 'music_source_dialogs.dart';

class MusicSourceSettings extends StatefulWidget {
  const MusicSourceSettings({required this.snapshot, super.key});
  final MusicSettingsPresentation snapshot;
  @override
  State<MusicSourceSettings> createState() => _MusicSourceSettingsState();
}

class _MusicSourceSettingsState extends State<MusicSourceSettings> {
  final revision = ValueNotifier(0);
  final identities = <String, Object>{};
  final routes = <ModalRoute<dynamic>, String?>{};
  final selections = <ModalRoute<dynamic>, Map<String, Object>>{};
  MusicSourcesPresentation get sources => widget.snapshot.sources;
  bool get editable => widget.snapshot.editable && !sources.working;
  MusicSourcePresentation? item(String id) =>
      sources.items.where((s) => s.id == id).firstOrNull;

  @override
  void initState() {
    super.initState();
    reconcile();
  }

  void reconcile() {
    identities.removeWhere((id, _) => item(id) == null);
    for (final source in sources.items) {
      identities.putIfAbsent(source.id, Object.new);
    }
  }

  void removeRoutes(Iterable<ModalRoute<dynamic>> owned) {
    final removed = owned.toList().reversed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(covariant MusicSourceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    reconcile();
    removeRoutes(
      routes.keys.where(
        (route) => routes[route] != null && item(routes[route]!) == null,
      ),
    );
    removeRoutes(
      selections.entries
          .where(
            (entry) => entry.value.entries.any(
              (e) => !identical(identities[e.key], e.value),
            ),
          )
          .map((e) => e.key),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revision.value++;
    });
  }

  Future<void> dialog(WidgetBuilder builder, {String? id}) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => ValueListenableBuilder(
        valueListenable: revision,
        builder: (context, _, _) => PopScope(
          canPop: !sources.working,
          child: SettingsTheme(child: builder(context)),
        ),
      ),
    );
    routes[route] = id;
    await Navigator.of(context).push(route);
    routes.remove(route);
  }

  void link([String? id]) {
    final current = id == null ? null : item(id);
    if (id != null && current == null) return;
    dialog(
      (_) => MusicSourceLinkDialog(
        editing: id != null,
        initialUrl: current?.url ?? '',
        working: sources.working,
        editable: editable,
        error: sources.error,
      ),
      id: id,
    );
  }

  void detail(String id) {
    dialog((context) {
      final current = item(id);
      if (current == null) return const SizedBox.shrink();
      return MusicSourceDetailDialog(
        source: current,
        active: sources.activeId == id,
        working: sources.working,
        editable: editable,
        error: sources.error,
        onEditLink: () {
          Navigator.pop(context);
          link(id);
        },
        onRemove: () => dialog(
          (context) => AlertDialog(
            scrollable: true,
            title: const Text('移除音源？'),
            content: const Text('仅移除此音源的脚本和链接，收藏与列表保留。若移除当前音源，需要手动选择其他音源。'),
            actions: [
              TextButton(
                onPressed: sources.working
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: editable ? emptyAction : null,
                child: const Text('移除'),
              ),
            ],
          ),
          id: id,
        ),
      );
    }, id: id);
  }

  void select() {
    final tokens = Map<String, Object>.of(identities);
    showSettingsSelection(
      context,
      title: '切换音源',
      current: sources.active?.name ?? '未启用',
      options: [
        SettingsOption(
          '停用音源',
          selected: sources.activeId == null || sources.activeId == '',
        ),
        for (final source in sources.items)
          SettingsOption(source.name, selected: sources.activeId == source.id),
      ],
      onRoute: (route) {
        if (!mounted ||
            tokens.entries.any((e) => !identical(identities[e.key], e.value))) {
          removeRoutes([route]);
          return;
        }
        if (routes.containsKey(route)) return;
        // 抽屉展示一份目录，任何被展示实体移除时撤销该目录会话。
        routes[route] = null;
        selections[route] = tokens;
        route.popped.whenComplete(() {
          routes.remove(route);
          selections.remove(route);
        });
      },
    );
  }

  @override
  void dispose() {
    removeRoutes(routes.keys);
    revision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.snapshot.loaded) const LinearProgressIndicator(),
        if (widget.snapshot.error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SettingsGroup(
          title: '音源管理',
          description: '可保存多个 LX 音源；首次导入自动启用，播放时使用当前音源',
          children: [
            SettingsRow(
              title: '当前音源',
              description: '切换后用于下一次播放或下载地址解析',
              value: sources.active?.name ?? '未启用',
              enabled: editable && sources.items.isNotEmpty,
              onTap: select,
            ),
            const SettingsDivider(),
            SettingsRow(
              title: '在线导入',
              description: '保存 HTTPS 链接，之后可在音源详情中更新',
              enabled: editable,
              onTap: link,
            ),
            const SettingsDivider(),
            SettingsRow(
              title: '本地导入',
              description: '可多选 LX 脚本，单个最大 256 KiB',
              enabled: editable,
            ),
            for (final source in sources.items) ...[
              const SettingsDivider(),
              SettingsRow(
                key: ValueKey(source.id),
                title: source.name,
                description: source.summary,
                value: sources.activeId == source.id ? '使用中' : '',
                enabled: !sources.working,
                onTap: () => detail(source.id),
              ),
            ],
            if (sources.working || widget.snapshot.importing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: LinearProgressIndicator(),
              ),
            if (sources.error case final error?)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
