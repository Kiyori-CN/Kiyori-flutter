import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'adblock_editor_dialog.dart';
import 'adblock_presentation.dart';

/// 搜索不丢失展开；实体移除或宿主退出时精确释放其模态。
class AdblockSubscriptionGroup extends StatefulWidget {
  const AdblockSubscriptionGroup({
    required this.title,
    required this.description,
    required this.query,
    required this.group,
    required this.snapshot,
    super.key,
  });
  final String title, description, query;
  final AdblockSubscriptionGroupKind group;
  final AdblockPresentation snapshot;
  @override
  State<AdblockSubscriptionGroup> createState() => _GroupState();
}

class _GroupState extends State<AdblockSubscriptionGroup> {
  final expanded = <String>{};
  final routes = <DialogRoute<void>, String>{};

  @override
  void didUpdateWidget(covariant AdblockSubscriptionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.snapshot.subscriptions
        .where((s) => s.group == widget.group)
        .map((s) => s.id)
        .toSet();
    expanded.retainAll(ids);
    final removed = routes.keys.where((r) => !ids.contains(routes[r])).toList();
    for (final route in removed) {
      routes.remove(route);
    }
    removeRoutes(removed);
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

  Future<void> open(AdblockSubscription item, bool deleting) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => SettingsTheme(
        child: deleting
            ? AlertDialog(
                scrollable: true,
                title: const Text('删除广告拦截订阅'),
                content: Text('${item.name}\n${item.url}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: emptyAction,
                    child: Text(
                      '删除',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              )
            : AdblockEditor(
                kind: AdblockEditorKind.subscription,
                editing: true,
                initialFirst: item.name,
                initialSecond: item.url,
              ),
      ),
    );
    routes[route] = item.id;
    await Navigator.of(context).push(route);
    routes.remove(route);
  }

  @override
  void dispose() {
    removeRoutes(routes.keys.toList());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.snapshot.subscriptions
        .where((s) => s.group == widget.group)
        .toList();
    final query = widget.query.trim().toLowerCase();
    final visible = group
        .where(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.url.toLowerCase().contains(query),
        )
        .toList();
    final custom = widget.group == AdblockSubscriptionGroupKind.custom;
    return SettingsGroup(
      title: widget.title,
      description: widget.description,
      children: [
        if (!custom) ...[
          SettingsRow(
            title: '启用整组',
            description:
                '已开启 ${group.where((s) => s.enabled).length} / ${group.length} · 已就绪 ${group.where((s) => s.hasLocalRules).length} / ${group.length}',
            checked: group.isNotEmpty && group.every((s) => s.enabled),
            enabled: widget.snapshot.subscriptionActions,
            onTap: emptyAction,
          ),
          const SettingsDivider(),
        ],
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SettingsDivider(),
          AdblockSubscriptionRow(
            key: ValueKey(visible[i].id),
            item: visible[i],
            expanded: expanded.contains(visible[i].id),
            refreshing: widget.snapshot.refreshing.contains(visible[i].id),
            progress: widget.snapshot.refreshProgress,
            actionsEnabled: widget.snapshot.subscriptionActions,
            onExpand: () => setState(() {
              if (!expanded.add(visible[i].id)) expanded.remove(visible[i].id);
            }),
            onEdit: custom ? () => open(visible[i], false) : null,
            onDelete: custom ? () => open(visible[i], true) : null,
          ),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              custom ? '没有符合条件的自定义订阅' : '没有符合条件的内置订阅',
              style: TextStyle(
                fontSize: 13,
                color: PrimaryColors.of(context).secondary,
              ),
            ),
          ),
      ],
    );
  }
}

class AdblockSubscriptionRow extends StatelessWidget {
  const AdblockSubscriptionRow({
    required this.item,
    required this.expanded,
    required this.refreshing,
    required this.actionsEnabled,
    required this.onExpand,
    this.progress,
    this.onEdit,
    this.onDelete,
    super.key,
  });
  final AdblockSubscription item;
  final bool expanded, refreshing, actionsEnabled;
  final AdblockRefreshProgress? progress;
  final VoidCallback onExpand;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = PrimaryColors.of(context);
    final active = actionsEnabled && !refreshing;
    final status = refreshing
        ? (progress == null
              ? '正在同步'
              : '正在同步 · ${progress!.completed + 1}/${progress!.total}')
        : !item.enabled
        ? (item.hasLocalRules ? '已停用 · ${item.count} 条规则' : '已停用 · 尚未同步')
        : item.error != null
        ? (item.hasLocalRules ? '更新失败 · ${item.count} 条规则仍可用' : '更新失败 · 展开查看原因')
        : item.hasLocalRules
        ? '已就绪 · ${item.count} 条规则'
        : '等待首次同步';
    final color = refreshing
        ? Theme.of(context).colorScheme.tertiary
        : !item.enabled
        ? colors.secondary
        : item.error != null
        ? Theme.of(context).colorScheme.error
        : item.hasLocalRules
        ? colors.accent
        : colors.secondary;
    final icon = refreshing
        ? Icons.hourglass_empty
        : !item.enabled
        ? Icons.shield
        : item.error != null
        ? Icons.error_outline
        : item.hasLocalRules
        ? Icons.check_circle
        : Icons.hourglass_empty;
    Widget stat(String title, int value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: colors.secondary),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    Widget button(String title, IconData icon, VoidCallback callback) =>
        TextButton.icon(
          onPressed: active ? callback : null,
          icon: Icon(
            icon,
            size: 17,
            color: title == '删除' ? Theme.of(context).colorScheme.error : null,
          ),
          label: Text(title),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onExpand,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(icon, size: 16, color: color),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Switch(
                  value: item.enabled,
                  onChanged: active ? (_) {} : null,
                ),
              ),
              IconButton(
                onPressed: active ? emptyAction : null,
                tooltip: '更新订阅',
                icon: refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh, color: colors.muted),
              ),
              IconButton(
                onPressed: onExpand,
                tooltip: expanded ? '收起详情' : '展开详情',
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.muted,
                ),
              ),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Text(
                        '订阅地址',
                        style: TextStyle(fontSize: 11, color: colors.secondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        item.url,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 17 / 12,
                        ),
                      ),
                    ),
                    const SettingsDivider(),
                    Row(
                      children: [
                        stat('网址阻断', item.network),
                        stat('网址例外', item.networkExceptions),
                      ],
                    ),
                    Row(
                      children: [
                        stat('元素隐藏', item.elements),
                        stat('元素例外', item.elementExceptions),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '忽略 ${item.ignored} 行 · ${item.updatedLabel ?? '尚未成功更新'}',
                        style: TextStyle(fontSize: 11, color: colors.secondary),
                      ),
                    ),
                    if (item.error?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        child: Text(
                          '错误：${item.error}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 17 / 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        button('立即更新', Icons.refresh, emptyAction),
                        if (onEdit != null)
                          button('编辑', Icons.edit_outlined, onEdit!),
                        if (onDelete != null)
                          button('删除', Icons.delete_outline, onDelete!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
