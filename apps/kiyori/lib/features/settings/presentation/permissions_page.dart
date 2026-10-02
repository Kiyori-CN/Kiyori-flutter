import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'permission_presentation.dart';

/// 快照由宿主注入；默认未检查，无系统授权请求或虚构授权计数。
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({
    this.statuses = const {},
    this.onRefresh = emptyAction,
    this.onAction,
    super.key,
  });
  final Map<String, PermissionStatus> statuses;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '权限管理',
    actions: IconButton(
      onPressed: onRefresh,
      tooltip: '重新检查权限状态',
      icon: const Icon(Icons.refresh),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: PrimaryCard(child: _Summary(statuses)),
      ),
      for (var index = 0; index < permissionGroups.length; index++)
        _PermissionGroup(
          key: ValueKey(permissionGroups[index].$1),
          index: index,
          statuses: statuses,
          onAction: onAction,
        ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 31, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '还有哪些访问方式？',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              '联网、网络状态、前台服务、唤醒锁等由 Android 按声明管理，不需要逐项弹窗。照片和文档可通过系统选择器按次提供；屏幕捕获在使用时确认。网站授权与 AI 工具执行授权另行管理，不因同意协议而自动开启。',
              style: TextStyle(
                fontSize: 12,
                height: 20 / 12,
                color: PrimaryColors.of(context).secondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '拒绝可选权限不影响进入应用，对应功能可能不可用。已授予的访问可到系统设置或对应的 Shizuku、Root 管理器撤销。',
              style: TextStyle(
                fontSize: 12,
                height: 20 / 12,
                color: PrimaryColors.of(context).secondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary(this.statuses);
  final Map<String, PermissionStatus> statuses;
  @override
  Widget build(BuildContext context) {
    final known = permissionEntries.every(
      (entry) =>
          statuses.containsKey(entry.id) &&
          statuses[entry.id] != PermissionStatus.unchecked,
    );
    String count(bool Function(PermissionStatus) predicate) => known
        ? permissionEntries
              .where((entry) => predicate(statuses[entry.id]!))
              .length
              .toString()
        : '—';
    final ready = count((status) => status == PermissionStatus.granted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '权限，由你决定',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '按功能开启，随时可以在系统中调整。无需全部授权。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 17 / 12,
                        color: PrimaryColors.of(context).secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$ready 项已授权',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: PrimaryColors.of(context).accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            spacing: 8,
            children: [
              for (final item in [
                ('已授权', ready),
                (
                  '可选开启',
                  count(
                    (status) => const {
                      PermissionStatus.notGranted,
                      PermissionStatus.partial,
                      PermissionStatus.setup,
                    }.contains(status),
                  ),
                ),
                (
                  '使用时确认',
                  count((status) => status == PermissionStatus.onDemand),
                ),
              ])
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PrimaryColors.of(context).background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            known
                ? '${count((status) => status == PermissionStatus.notApplicable)} 项在当前系统无需单独授权。下方分组可展开查看完整用途。'
                : '权限状态未检查。下方分组可展开查看完整用途。',
            style: TextStyle(
              fontSize: 12,
              height: 18 / 12,
              color: PrimaryColors.of(context).secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionGroup extends StatefulWidget {
  const _PermissionGroup({
    required this.index,
    required this.statuses,
    required this.onAction,
    super.key,
  });
  final int index;
  final Map<String, PermissionStatus> statuses;
  final ValueChanged<String>? onAction;
  @override
  State<_PermissionGroup> createState() => _PermissionGroupState();
}

class _PermissionGroupState extends State<_PermissionGroup>
    with AutomaticKeepAliveClientMixin {
  late bool expanded = widget.index == 0;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final group = permissionGroups[widget.index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCard(
            child: Semantics(
              header: true,
              expanded: expanded,
              child: InkWell(
                onTap: () => setState(() => expanded = !expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              group.$2,
                              style: TextStyle(
                                fontSize: 12,
                                height: 19 / 12,
                                color: PrimaryColors.of(context).secondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${group.$4 - group.$3} 项 · 按需开启',
                              style: TextStyle(
                                fontSize: 11,
                                color: PrimaryColors.of(context).accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      for (var index = group.$3; index < group.$4; index++) ...[
                        if (index != group.$3) const SettingsDivider(),
                        _PermissionRow(
                          permissionEntries[index],
                          widget.statuses[permissionEntries[index].id] ??
                              PermissionStatus.unchecked,
                          () => widget.onAction?.call(
                            permissionEntries[index].id,
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow(this.entry, this.status, this.onTap);
  final PermissionEntry entry;
  final PermissionStatus status;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final action = switch ((entry.action, status)) {
      (PermissionAction.settings, _)
          when entry.id == 'restricted_settings' &&
              status != PermissionStatus.notApplicable =>
        '前往设置',
      (_, PermissionStatus.notApplicable || PermissionStatus.onDemand) ||
      (PermissionAction.none, _) => null,
      (PermissionAction.authorize, PermissionStatus.granted) => '管理',
      (PermissionAction.authorize, _) => '授权',
      (PermissionAction.settings, PermissionStatus.granted) => '管理',
      (PermissionAction.settings, _) => '前往设置',
      (PermissionAction.manage, PermissionStatus.granted) ||
      (PermissionAction.shizuku, PermissionStatus.granted) ||
      (PermissionAction.root, PermissionStatus.granted) => null,
      (PermissionAction.manage, _) => '管理',
      (PermissionAction.accessibility, PermissionStatus.granted) => '管理',
      (PermissionAction.accessibility, PermissionStatus.setup) => '安装并设置',
      (PermissionAction.accessibility, _) => '启用',
      (PermissionAction.shizuku, PermissionStatus.setup) => '配置',
      (PermissionAction.shizuku, _) => '授权',
      (PermissionAction.root, _) => '请求授权',
    };
    final label = switch (status) {
      PermissionStatus.unchecked => '未检查',
      PermissionStatus.granted => '已授权',
      PermissionStatus.partial => '部分授权',
      PermissionStatus.notGranted => '未开启',
      PermissionStatus.setup => '需要配置',
      PermissionStatus.notApplicable => '本机无需',
      PermissionStatus.onDemand => '使用时确认',
    };
    final (foreground, background) = switch (status) {
      PermissionStatus.granted => (
        const Color(0xFF16734F),
        const Color(0xFFE6F5EE),
      ),
      PermissionStatus.partial => (
        const Color(0xFFA85A12),
        const Color(0xFFFFF0DF),
      ),
      PermissionStatus.setup => (
        const Color(0xFF2B5FAF),
        const Color(0xFFEAF1FF),
      ),
      PermissionStatus.onDemand => (
        const Color(0xFF17768B),
        const Color(0xFFE4F5F8),
      ),
      PermissionStatus.unchecked => (
        PrimaryColors.of(context).secondary,
        PrimaryColors.of(context).divider,
      ),
      _ => (const Color(0xFF256DB0), const Color(0xFFE8F3FE)),
    };
    return InkWell(
      onTap: action == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            ToneBadge(entry.icon, entry.tone, size: 40, iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 17 / 12,
                      color: PrimaryColors.of(context).secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (action != null)
                    Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PrimaryColors.of(context).accent,
                      ),
                    )
                  else
                    const SizedBox(height: 17),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
