import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'adblock_editor_dialog.dart';
import 'adblock_presentation.dart';

/// 目录与弹层由页面拥有；筛选不改变实体存在期，也不销毁已打开草稿。
class AdblockManagedRules extends StatefulWidget {
  const AdblockManagedRules({
    required this.snapshot,
    required this.kind,
    super.key,
  });
  final AdblockPresentation snapshot;
  final AdblockEditorKind kind;
  @override
  State<AdblockManagedRules> createState() => _AdblockManagedRulesState();
}

class _AdblockManagedRulesState extends State<AdblockManagedRules> {
  final search = TextEditingController();
  final expanded = <String>{};
  final routes = <DialogRoute<void>, String?>{};
  late List<AdblockElementRule> sortedElements;
  late Set<String> identities;

  void project() {
    sortedElements = List.of(widget.snapshot.elementRules)
      ..sort((a, b) => a.domain.compareTo(b.domain));
    identities = {
      for (final item in widget.snapshot.networkRules) 'network:${item.id}',
      for (final item in widget.snapshot.elementRules) 'element:${item.id}',
      for (final domain in widget.snapshot.allowlist) 'allowlist:$domain',
    };
    expanded.retainAll(sortedElements.map((e) => e.domain).toSet());
  }

  @override
  void initState() {
    super.initState();
    project();
  }

  @override
  void didUpdateWidget(covariant AdblockManagedRules oldWidget) {
    super.didUpdateWidget(oldWidget);
    project();
    final removed = routes.entries
        .where(
          (entry) =>
              oldWidget.kind != widget.kind ||
              (entry.value != null && !identities.contains(entry.value)),
        )
        .map((entry) => entry.key)
        .toList();
    for (final route in removed) {
      routes.remove(route);
    }
    removeRoutes(removed);
    if (oldWidget.kind != widget.kind) search.clear();
  }

  void removeRoutes(List<DialogRoute<void>> removed) {
    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> open(WidgetBuilder builder, [String? identity]) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => SettingsTheme(child: builder(context)),
    );
    routes[route] = identity;
    await Navigator.of(context).push(route);
    routes.remove(route);
  }

  void edit({String? identity, String first = '', String second = ''}) {
    open(
      (_) => AdblockEditor(
        kind: widget.kind,
        editing: identity != null,
        initialFirst: first,
        initialSecond: second,
      ),
      identity,
    );
  }

  void delete(String identity, String title, String text) {
    open(
      (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: emptyAction,
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
      identity,
    );
  }

  @override
  void dispose() {
    removeRoutes(routes.keys.toList());
    search.dispose();
    super.dispose();
  }

  Widget row(
    String identity,
    String title,
    String description, {
    bool? enabled,
    VoidCallback? onEdit,
    required VoidCallback onDelete,
  }) => Padding(
    key: ValueKey(identity),
    padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 17 / 12,
                        fontFamily: 'monospace',
                        color: PrimaryColors.of(context).secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (enabled != null) Switch(value: enabled, onChanged: (_) {}),
            if (enabled == null) action('删除', Icons.delete_outline, onDelete),
          ],
        ),
        if (enabled != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onEdit != null) action('编辑', Icons.edit_outlined, onEdit),
              action('删除', Icons.delete_outline, onDelete),
            ],
          ),
      ],
    ),
  );

  Widget action(String label, IconData icon, VoidCallback callback) => SizedBox(
    width: 40,
    height: 40,
    child: IconButton(
      tooltip: label,
      onPressed: callback,
      icon: Icon(
        icon,
        color: label == '删除'
            ? Theme.of(context).colorScheme.error
            : PrimaryColors.of(context).muted,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final query = search.text.trim().toLowerCase();
    bool matches(String value) => value.toLowerCase().contains(query);
    final (
      title,
      description,
      searchDescription,
      empty,
    ) = switch (widget.kind) {
      AdblockEditorKind.network => (
        '自定义规则',
        '共 ${snapshot.networkRules.length} 条，已启用 ${snapshot.networkRules.where((r) => r.enabled).length} 条',
        '普通文本为包含匹配，也支持 ||host^、|prefix、suffix|、*、^、正则和 @@ 例外规则',
        '没有符合条件的网址过滤规则',
      ),
      AdblockEditorKind.element => (
        '按域名整理',
        '共 ${sortedElements.map((r) => r.domain).toSet().length} 个域名、${sortedElements.length} 条规则',
        '每条规则由站点域名和 CSS selector 组成；浏览器“标记广告”也会写入这里',
        '没有符合条件的网页元素规则',
      ),
      AdblockEditorKind.allowlist => (
        '已允许站点',
        '共 ${snapshot.allowlist.length} 个站点',
        '填写主机名，例如 example.com；其子域名会一并跳过广告拦截',
        '没有符合条件的白名单站点',
      ),
      AdblockEditorKind.subscription => throw StateError(
        'Subscriptions use their own list',
      ),
    };
    final rows = <Widget>[];
    if (widget.kind == AdblockEditorKind.network) {
      for (final item in snapshot.networkRules.where((r) => matches(r.rule))) {
        final id = 'network:${item.id}';
        rows.add(
          row(
            id,
            item.rule,
            '自定义网址过滤规则',
            enabled: item.enabled,
            onEdit: () => edit(identity: id, first: item.rule),
            onDelete: () => delete(id, '删除网址过滤规则', item.rule),
          ),
        );
      }
    } else if (widget.kind == AdblockEditorKind.element) {
      final groups = <String, List<AdblockElementRule>>{};
      for (final item in sortedElements.where(
        (r) => matches(r.domain) || matches(r.selector),
      )) {
        groups.putIfAbsent(item.domain, () => []).add(item);
      }
      for (final entry in groups.entries) {
        final isExpanded = query.isNotEmpty || expanded.contains(entry.key);
        rows.add(
          InkWell(
            key: ValueKey('domain:${entry.key}'),
            onTap: () => setState(() {
              if (isExpanded) {
                expanded.remove(entry.key);
              } else {
                expanded.add(entry.key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已启用 ${entry.value.where((r) => r.enabled).length} / 共 ${entry.value.length} 条',
                          style: TextStyle(
                            fontSize: 12,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    semanticLabel: isExpanded ? '收起规则' : '展开规则',
                  ),
                ],
              ),
            ),
          ),
        );
        if (isExpanded) {
          for (final item in entry.value) {
            final id = 'element:${item.id}';
            rows.add(
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: row(
                  id,
                  item.selector,
                  '手动元素规则',
                  enabled: item.enabled,
                  onEdit: () => edit(
                    identity: id,
                    first: item.domain,
                    second: item.selector,
                  ),
                  onDelete: () => delete(
                    id,
                    '删除网页元素规则',
                    '${item.domain}\n${item.selector}',
                  ),
                ),
              ),
            );
          }
        }
      }
    } else {
      for (final domain in snapshot.allowlist.where(matches)) {
        final id = 'allowlist:$domain';
        rows.add(
          row(
            id,
            domain,
            '请求拦截与网页元素隐藏均不执行',
            onDelete: () => delete(id, '移出站点白名单', domain),
          ),
        );
      }
    }
    return Column(
      children: [
        SettingsGroup(
          title: '查找与新增',
          description: searchDescription,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: KiyoriSearchField(
                      controller: search,
                      hint: '搜索',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: edit,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 3),
                        Text('新增'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: title,
          description: description,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SettingsDivider(),
              rows[i],
            ],
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                child: Text(
                  empty,
                  style: TextStyle(
                    fontSize: 13,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
