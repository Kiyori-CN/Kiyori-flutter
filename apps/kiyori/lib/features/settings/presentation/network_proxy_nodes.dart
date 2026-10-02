import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'network_proxy_presentation.dart';

/// 筛选和排序属于界面草稿，选中节点与测速始终来自正式快照。
class NetworkProxyNodes extends StatefulWidget {
  const NetworkProxyNodes({
    required this.subscription,
    required this.enabled,
    this.order = 0,
    super.key,
  });
  final ProxySubscriptionPresentation subscription;
  final bool enabled;
  final int order;
  @override
  State<NetworkProxyNodes> createState() => _NetworkProxyNodesState();
}

class _NetworkProxyNodesState extends State<NetworkProxyNodes> {
  final search = TextEditingController();
  String? groupName;
  int get order => widget.order;
  List<ProxyNodePresentation> visible = [];
  ProxyGroupPresentation? get group =>
      widget.subscription.groups.where((g) => g.name == groupName).firstOrNull;
  @override
  void initState() {
    super.initState();
    reconcile();
  }

  @override
  void didUpdateWidget(covariant NetworkProxyNodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subscription.id != widget.subscription.id) {
      groupName = null;
      search.clear();
    }
    reconcile();
  }

  void reconcile() {
    if (group == null) groupName = widget.subscription.currentGroup;
    if (group == null) groupName = widget.subscription.groups.firstOrNull?.name;
    project();
  }

  void project() {
    final query = search.text.trim().toLowerCase();
    final entries = (group?.nodes ?? <ProxyNodePresentation>[]).indexed
        .where(
          (e) =>
              e.$2.name.toLowerCase().contains(query) ||
              e.$2.type.toLowerCase().contains(query),
        )
        .toList();
    if (order != 0) {
      entries.sort((a, b) {
        if (order == 2) {
          final aValid =
              a.$2.status == ProxyNodeStatus.success && a.$2.delay != null;
          final bValid =
              b.$2.status == ProxyNodeStatus.success && b.$2.delay != null;
          if (aValid != bValid) return aValid ? -1 : 1;
          final delay = (a.$2.delay ?? 0x7fffffff).compareTo(
            b.$2.delay ?? 0x7fffffff,
          );
          if (delay != 0) return delay;
        }
        final lower = a.$2.name.toLowerCase().compareTo(
          b.$2.name.toLowerCase(),
        );
        if (lower != 0) return lower;
        if (order == 1) {
          final exact = a.$2.name.compareTo(b.$2.name);
          if (exact != 0) return exact;
        }
        return a.$1.compareTo(b.$1);
      });
    }
    visible = entries.map((e) => e.$2).toList();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = group;
    return SettingsGroup(
      title: widget.subscription.name,
      description: widget.subscription.description,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: KiyoriSearchField(
            controller: search,
            hint: '搜索当前分组节点',
            showSearchIcon: true,
            showClear: true,
            onChanged: (_) => setState(project),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            spacing: 2,
            children: [
              for (final item in widget.subscription.groups)
                InkWell(
                  onTap: widget.enabled
                      ? () => setState(() {
                          groupName = item.name;
                          search.clear();
                          project();
                        })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.name == groupName
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: item.name == groupName
                                  ? PrimaryColors.of(context).accent
                                  : PrimaryColors.of(context).secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 2,
                            width: double.infinity,
                            child: ColoredBox(
                              color: item.name == groupName
                                  ? PrimaryColors.of(context).accent
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Text(
              '${current.label} · ${current.selectable ? '手动选择' : current.type} · ${current.nodes.length} 个项目 · 已选择：${current.selected ?? '未选择'}',
              style: TextStyle(
                fontSize: 12,
                height: 17 / 12,
                color: PrimaryColors.of(context).secondary,
              ),
            ),
          ),
        const SettingsDivider(),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              current?.nodes.isEmpty != false
                  ? '当前分组没有可显示的节点。'
                  : '没有匹配当前搜索条件的节点。',
            ),
          ),
        if (visible.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: ListView.separated(
              shrinkWrap: true,
              primary: false,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SettingsDivider(),
              itemBuilder: (context, i) {
                final item = visible[i];
                final selected = current?.selected == item.name;
                return Semantics(
                  selected: selected,
                  child: Material(
                    color: selected
                        ? PrimaryColors.of(context).accent
                              .withValues(alpha: .14)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: widget.enabled && current?.selectable == true
                          ? emptyAction
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 3,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.type} · ${item.delayLabel} · ${current?.selectable == true ? '点击切换' : '自动策略组由 Mihomo 决定'}',
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 17 / 12,
                                      color: PrimaryColors.of(context)
                                          .secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check,
                                size: 19,
                                semanticLabel: '已选择节点',
                                color: PrimaryColors.of(context).accent,
                              ),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                onPressed: widget.enabled ? emptyAction : null,
                                tooltip: '测速 ${item.name}',
                                icon: Icon(
                                  Icons.speed,
                                  size: 20,
                                  color: PrimaryColors.of(context).accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
