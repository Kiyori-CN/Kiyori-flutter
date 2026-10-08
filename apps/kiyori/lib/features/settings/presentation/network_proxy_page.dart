import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'network_proxy_editors.dart';
import 'network_proxy_nodes.dart';
import 'network_proxy_presentation.dart';
import 'network_subscription_rule_editor.dart';

enum NetworkProxySection { overview, node, subscriptions, rules, scripts, logs }

/// 旧 KiyoriNetworkProxySettingsPage 的空配置快照，不加载或启动 Mihomo。
class NetworkProxyPage extends StatefulWidget {
  const NetworkProxyPage({
    this.section = NetworkProxySection.overview,
    required this.onOpen,
    this.snapshot = const NetworkProxyPresentation(),
    super.key,
  });
  final NetworkProxySection section;
  final ValueChanged<NetworkProxySection> onOpen;
  final NetworkProxyPresentation snapshot;
  @override
  State<NetworkProxyPage> createState() => _NetworkProxyPageState();
}

class _NetworkProxyPageState extends State<NetworkProxyPage> {
  final search = TextEditingController();
  int filter = 0;
  int nodeOrder = 0;
  NetworkProxyPresentation get snapshot => widget.snapshot;
  ProxySubscriptionPresentation? get active => snapshot.active;
  final routes = <ModalRoute<dynamic>, String?>{};
  final identities = <String, Object>{};
  final dialogRevision = ValueNotifier(0);
  Object sectionIdentity = Object();

  @override
  void initState() {
    super.initState();
    projectIdentities();
  }

  void projectIdentities() {
    final ids = {
      for (final s in snapshot.subscriptions) 'subscription:${s.id}',
      for (final r in snapshot.rules) 'rule:${r.id}',
      for (final s in snapshot.scripts) 'script:${s.id}',
      if (active != null) ...['active-rules', 'active-node'],
    };
    identities.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      identities.putIfAbsent(id, Object.new);
    }
  }

  void registerRoute(
    ModalRoute<dynamic> route,
    String? id,
    Object? token,
    Object section,
  ) {
    if (!mounted ||
        !identical(section, sectionIdentity) ||
        (id != null && !identical(identities[id], token))) {
      removeRoutes([route]);
      return;
    }
    if (routes.containsKey(route)) return;
    routes[route] = id;
    route.popped.whenComplete(() => routes.remove(route));
  }

  Widget menuLabel(
    BuildContext context,
    String label,
    String? id,
    Object? token,
    Object section,
  ) {
    final route = ModalRoute.of(context);
    if (route != null) registerRoute(route, id, token, section);
    return Text(label);
  }

  void removeRoutes(List<ModalRoute<dynamic>> removed) {
    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(covariant NetworkProxyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.section != widget.section;
    final activeChanged = oldWidget.snapshot.activeId != snapshot.activeId;
    final rulesChanged =
        activeChanged ||
        !listEquals(oldWidget.snapshot.active?.rules, active?.rules);
    final invalidated = {
      if (activeChanged) 'active-node',
      if (rulesChanged) 'active-rules',
    };
    for (final id in invalidated) {
      identities.remove(id);
    }
    projectIdentities();
    if (changed) sectionIdentity = Object();
    final removed = routes.keys
        .where(
          (r) =>
              changed ||
              invalidated.contains(routes[r]) ||
              (routes[r] != null && !identities.containsKey(routes[r])),
        )
        .toList();
    for (final route in removed) {
      routes.remove(route);
    }
    removeRoutes(removed);
    // 模态路由不随页面重建；只通知展示更新，不持有第二份业务快照。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) dialogRevision.value++;
    });
    if (changed) {
      search.clear();
      filter = 0;
    }
  }

  Future<void> openDialog(WidgetBuilder builder, [String? identity]) async {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: dialogRevision,
        builder: (context, _, _) => PopScope(
          canPop: !snapshot.busy,
          child: SettingsTheme(child: builder(context)),
        ),
      ),
    );
    routes[route] = identity;
    await Navigator.of(context).push(route);
    routes.remove(route);
  }

  void confirm(
    String title,
    String message,
    String action, {
    String? identity,
  }) {
    openDialog(
      (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: snapshot.busy ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: snapshot.busy ? null : emptyAction,
            child: Text(action),
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
    dialogRevision.dispose();
    super.dispose();
  }

  String get title => switch (widget.section) {
    NetworkProxySection.overview => '网络代理',
    NetworkProxySection.node => '节点选择',
    NetworkProxySection.subscriptions => '订阅管理',
    NetworkProxySection.rules => '规则管理',
    NetworkProxySection.scripts => '脚本规则',
    NetworkProxySection.logs => '代理日志',
  };

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: title,
    actionWidth: 96,
    actions: widget.section == NetworkProxySection.logs
        ? Row(
            children: [
              IconButton(
                onPressed: snapshot.logs.isNotEmpty && !snapshot.busy
                    ? emptyAction
                    : null,
                tooltip: '复制全部代理日志',
                icon: Icon(Icons.content_copy_outlined),
              ),
              IconButton(
                onPressed: snapshot.logs.isNotEmpty && !snapshot.busy
                    ? emptyAction
                    : null,
                tooltip: '导出全部代理日志',
                icon: Icon(Icons.save_alt_outlined),
              ),
            ],
          )
        : widget.section == NetworkProxySection.scripts
        ? Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: snapshot.controlsEnabled ? emptyAction : null,
              tooltip: '刷新脚本',
              icon: Icon(Icons.refresh_outlined),
            ),
          )
        : widget.section == NetworkProxySection.node && active != null
        ? Row(
            children: [
              IconButton(
                onPressed: snapshot.controlsEnabled ? emptyAction : null,
                tooltip: '测速当前分组',
                icon: const Icon(Icons.speed),
              ),
              PopupMenuButton<(int, Object?, Object)>(
                tooltip: '节点排序',
                enabled: snapshot.controlsEnabled,
                icon: const Icon(Icons.sort),
                onSelected: (v) {
                  if (mounted &&
                      snapshot.controlsEnabled &&
                      identical(v.$2, identities['active-node']) &&
                      identical(v.$3, sectionIdentity)) {
                    setState(() => nodeOrder = v.$1);
                  }
                },
                itemBuilder: (_) {
                  final section = sectionIdentity;
                  final token = identities['active-node'];
                  return [
                    for (var i = 0; i < 3; i++)
                      PopupMenuItem(
                        value: (i, token, section),
                        child: Row(
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) => menuLabel(
                                  context,
                                  ['默认', '名称', '延迟'][i],
                                  'active-node',
                                  token,
                                  section,
                                ),
                              ),
                            ),
                            if (nodeOrder == i)
                              const Icon(Icons.check, semanticLabel: '当前排序'),
                          ],
                        ),
                      ),
                  ];
                },
              ),
            ],
          )
        : null,
    children: [
      ...switch (widget.section) {
        NetworkProxySection.overview => _overview(),
        NetworkProxySection.node => [
          if (active != null)
            NetworkProxyNodes(
              subscription: active!,
              enabled: snapshot.controlsEnabled,
              order: nodeOrder,
            )
          else
            const SettingsGroup(
              title: '节点选择',
              description: '请先在订阅管理中导入并切换一份 Clash / Mihomo 订阅。',
              children: [NetworkProxyNote('当前没有可用订阅。')],
            ),
        ],
        NetworkProxySection.subscriptions => [_subscriptions()],
        NetworkProxySection.rules => _rules(),
        NetworkProxySection.scripts => [
          if (snapshot.scripts.isEmpty)
            const SettingsGroup(
              title: '脚本规则',
              description:
                  '只显示已安装的传统 JsEngine 脚本，启用状态不影响识别；ToolPkg 统一归入 AI 工具。',
              children: [NetworkProxyNote('当前没有已安装的传统脚本。')],
            ),
          for (final category
              in snapshot.scripts.map((s) => s.category).toSet())
            SettingsGroup(
              title: category,
              description:
                  '${snapshot.scripts.where((s) => s.category == category).length} 个已安装脚本；未启用脚本也可预先配置规则。',
              children: [
                for (final script in snapshot.scripts.where(
                  (s) => s.category == category,
                ))
                  SettingsRow(
                    title: script.name,
                    description:
                        '${script.enabled ? '已启用' : '未启用'} · ${script.id}${script.description.isEmpty ? '' : ' · ${script.description}'}',
                    value: script.mode,
                    enabled: snapshot.controlsEnabled,
                    onTap: () {
                      final token = identities['script:${script.id}'];
                      final section = sectionIdentity;
                      showSettingsSelection(
                        context,
                        title: '${script.name}脚本规则',
                        current: script.mode,
                        onRoute: (route) => registerRoute(
                          route,
                          'script:${script.id}',
                          token,
                          section,
                        ),
                        options: [
                          SettingsOption(
                            '跟随模式',
                            description: '移除此脚本的单独规则，跟随代理模式',
                            selected: script.mode == '跟随模式',
                          ),
                          SettingsOption(
                            '直连',
                            description:
                                '绕过 Kiyori Flutter 内嵌 Mihomo；仍受系统 VPN 影响',
                            selected: script.mode == '直连',
                          ),
                          SettingsOption(
                            '代理',
                            description: '经过内嵌 Mihomo，并使用上方代理模式',
                            selected: script.mode == '代理',
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
        ],
        NetworkProxySection.logs => [_logs()],
      },
      if (snapshot.feedbackSection == widget.section.name &&
          (snapshot.operation != null ||
              snapshot.feedback != null ||
              snapshot.phase == ProxyRuntimePhase.error))
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (snapshot.operation != null)
                const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  snapshot.feedbackError ||
                          snapshot.phase == ProxyRuntimePhase.error
                      ? Icons.error
                      : Icons.check_circle,
                  color:
                      snapshot.feedbackError ||
                          snapshot.phase == ProxyRuntimePhase.error
                      ? Theme.of(context).colorScheme.error
                      : PrimaryColors.of(context).accent,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snapshot.operation ??
                      snapshot.feedback ??
                      'Mihomo 运行异常，请检查当前订阅与 VPN 设置。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 17 / 12,
                    color: snapshot.feedbackError
                        ? Theme.of(context).colorScheme.error
                        : PrimaryColors.of(context).secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  List<Widget> _overview() => [
    SettingsGroup(
      title: '应用内代理',
      description: '只影响 Kiyori Flutter 进程内已接入模块；不会改变其他应用的网络。',
      children: [
        SettingsRow(
          title: '启用应用内代理',
          description: snapshot.runtimeDescription,
          checked: snapshot.enabled,
          enabled:
              snapshot.controlsEnabled &&
              (snapshot.enabled || snapshot.canEnable),
          onTap: emptyAction,
        ),
        const SettingsDivider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Text(
            '代理模式',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Text(
            '规则按域名细分；全局让 Kiyori Flutter 请求统一进入当前策略组；直连不经过内嵌 Mihomo。',
            style: TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: PrimaryColors.of(context).secondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final label in ['规则', '全局', '直连']) ...[
                if (label != '规则') const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: label == snapshot.mode.label
                        ? PrimaryColors.of(context).accent
                        : PrimaryColors.of(context).background,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: snapshot.controlsEnabled ? emptyAction : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: label == snapshot.mode.label
                                  ? PrimaryColors.of(context).accentContent
                                  : PrimaryColors.of(context).text,
                              fontWeight: label == snapshot.mode.label
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: '连接范围',
      description: '进入对应子页面管理节点选择、订阅、规则和脚本规则。',
      children: [
        _nav('节点选择', '选择当前订阅中的策略组和节点', NetworkProxySection.node),
        const SettingsDivider(),
        _nav(
          '订阅管理',
          active?.description ?? '尚未导入 Clash / Mihomo 订阅',
          NetworkProxySection.subscriptions,
        ),
        const SettingsDivider(),
        _nav(
          '规则管理',
          active == null
              ? '自定义规则 ${snapshot.rules.length} 条；导入订阅后读取订阅规则'
              : '订阅规则 ${active!.rules.length} 条 · 自定义规则 ${snapshot.rules.length} 条',
          NetworkProxySection.rules,
        ),
        const SettingsDivider(),
        _nav(
          '脚本规则',
          snapshot.scripts.isEmpty
              ? '当前没有已安装的传统脚本'
              : '已发现 ${snapshot.scripts.length} 个脚本，已配置 ${snapshot.scripts.where((s) => s.mode != '跟随模式').length} 个规则',
          NetworkProxySection.scripts,
        ),
      ],
    ),
    SettingsGroup(
      title: '网络选项',
      description: '系统 VPN 或 Android HTTP/PAC 代理接管时暂停内嵌代理；外部路由关闭后自动恢复。',
      children: [
        _nav(
          '代理日志',
          snapshot.logs.isEmpty
              ? '当前进程暂无代理日志'
              : '当前进程 ${snapshot.logs.length} 条日志',
          NetworkProxySection.logs,
        ),
        const SettingsDivider(),
        SettingsRow(
          title: '代理局域网地址',
          description: '私有地址不再直连，交由内嵌核心按当前模式处理',
          checked: snapshot.lan,
          enabled: snapshot.controlsEnabled,
          onTap: emptyAction,
        ),
        const SettingsDivider(),
        const NetworkProxyNote(
          '当系统 VPN 实际作用于 Kiyori Flutter，或 Android 配置 HTTP/PAC 代理时，应用会自动暂停内嵌代理并使用系统路由；所有外部路由关闭后自动恢复。按应用分流且排除 Kiyori Flutter 的 VPN 不会触发暂停。',
          small: true,
        ),
        const SettingsDivider(),
        SettingsRow(
          title: '重置网络代理',
          enabled: !snapshot.busy,
          description: '停止核心并删除订阅、模块规则和加密配置',
          onTap: () => confirm(
            '重置网络代理？',
            '这会停止内嵌 Mihomo，并删除全部订阅、脚本规则、自定义规则和加密代理配置。',
            '重置',
          ),
        ),
      ],
    ),
  ];

  Widget _subscriptions() => SettingsGroup(
    title: '订阅管理',
    description: '保存多份 Clash / Mihomo 订阅；点击订阅行立即切换当前配置，右侧菜单管理条目。',
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttons = [
              OutlinedButton.icon(
                onPressed: snapshot.controlsEnabled
                    ? () => openDialog(
                        (_) => NetworkSubscriptionEditor(busy: snapshot.busy),
                      )
                    : null,
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('添加订阅地址', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: snapshot.controlsEnabled ? emptyAction : null,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('导入订阅文件', style: TextStyle(fontSize: 12)),
              ),
            ];
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(12) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buttons.first,
                  const SizedBox(height: 8),
                  buttons.last,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: buttons.first),
                const SizedBox(width: 8),
                Expanded(child: buttons.last),
              ],
            );
          },
        ),
      ),
      if (snapshot.subscriptions.isEmpty)
        const NetworkProxyNote(
          '还没有订阅。支持 Clash/Mihomo YAML、Base64 和 URI 节点列表；请添加地址或导入本地文件。',
        ),
      for (final item in snapshot.subscriptions) ...[
        const SettingsDivider(),
        InkWell(
          key: ValueKey('subscription:${item.id}'),
          onTap: snapshot.controlsEnabled ? emptyAction : null,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: item.id == snapshot.activeId
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 17 / 12,
                          color: PrimaryColors.of(context).secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.id == snapshot.activeId)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '使用中',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PrimaryColors.of(context).accent,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: PopupMenuButton<(String, Object?, Object)>(
                    enabled: snapshot.controlsEnabled,
                    tooltip: '管理 ${item.name}',
                    itemBuilder: (_) {
                      final id = 'subscription:${item.id}';
                      final token = identities[id];
                      final section = sectionIdentity;
                      return [
                        for (final label in ['更新', '编辑', '复制', '删除'])
                          PopupMenuItem(
                            value: (label, token, section),
                            child: Builder(
                              builder: (context) =>
                                  menuLabel(context, label, id, token, section),
                            ),
                          ),
                      ];
                    },
                    onSelected: (result) {
                      if (!mounted ||
                          !snapshot.controlsEnabled ||
                          !identical(
                            result.$2,
                            identities['subscription:${item.id}'],
                          ) ||
                          !identical(result.$3, sectionIdentity)) {
                        return;
                      }
                      final value = result.$1;
                      final current = snapshot.subscriptions
                          .where((s) => s.id == item.id)
                          .firstOrNull;
                      if (current == null) return;
                      if (value == '编辑') {
                        openDialog(
                          (_) => NetworkSubscriptionEditor(
                            editing: true,
                            busy: snapshot.busy,
                            localFile: current.localFile,
                            initialName: current.name,
                            initialUrl: current.editUrl,
                          ),
                          'subscription:${item.id}',
                        );
                      }
                      if (value == '删除') {
                        confirm(
                          '删除 ${current.name}？',
                          '将删除该订阅的加密 YAML、策略选择和测速记录。正在使用时必须先切换或关闭代理。',
                          '删除',
                          identity: 'subscription:${item.id}',
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  List<Widget> _rules() => [
    SettingsGroup(
      title: '规则管理',
      description: '自定义规则优先于当前订阅规则；订阅更新会覆盖订阅规则编辑，不影响自定义规则。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: KiyoriSearchField(
            controller: search,
            hint: '搜索规则类型、匹配内容或目标',
            showSearchIcon: true,
            showClear: true,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: '自定义规则',
      description: '由你创建并单独加密保存，始终排在订阅规则前。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: OutlinedButton.icon(
            onPressed: snapshot.controlsEnabled
                ? () =>
                      openDialog((_) => NetworkRuleEditor(busy: snapshot.busy))
                : null,
            icon: const Icon(Icons.add_outlined, size: 18),
            label: const Text('添加自定义规则', style: TextStyle(fontSize: 12)),
          ),
        ),
        if (!snapshot.rules.any(ruleMatches))
          NetworkProxyNote(snapshot.rules.isEmpty ? '暂无自定义规则。' : '没有匹配的自定义规则。'),
        for (final item in snapshot.rules.where(ruleMatches))
          InkWell(
            key: ValueKey('rule:${item.id}'),
            onTap: snapshot.controlsEnabled
                ? () => openDialog(
                    (_) => NetworkRuleEditor(
                      editing: true,
                      busy: snapshot.busy,
                      initialPattern: item.pattern,
                      initialType: item.type,
                      initialProxy: item.proxy,
                    ),
                    'rule:${item.id}',
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.pattern,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.proxy ? '代理' : '直连'} · ${item.type}',
                          style: TextStyle(
                            fontSize: 12,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: item.enabled,
                    onChanged: snapshot.controlsEnabled ? (_) {} : null,
                  ),
                  TextButton(
                    onPressed: snapshot.controlsEnabled
                        ? () => confirm(
                            '删除自定义规则？',
                            item.pattern,
                            '删除',
                            identity: 'rule:${item.id}',
                          )
                        : null,
                    child: const Text('删除'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
    SettingsGroup(
      title: '当前订阅规则',
      description: active == null
          ? '尚未选择订阅。'
          : '${active!.name} · ${active!.rules.length} 条；点击规则可编辑，更新订阅时覆盖。',
      children: [
        if (active?.rules.any(textMatches) != true)
          NetworkProxyNote(
            active?.rules.isEmpty != false ? '当前订阅没有可执行规则。' : '没有匹配的订阅规则。',
          ),
        for (final entry in (active?.rules ?? <String>[]).indexed.where(
          (e) => textMatches(e.$2),
        ))
          InkWell(
            onTap: snapshot.controlsEnabled
                ? () => openDialog(
                    (_) => NetworkSubscriptionRuleEditor(
                      name: active!.name,
                      index: entry.$1,
                      rule: entry.$2,
                      busy: snapshot.busy,
                    ),
                    'active-rules',
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.$2.split(',').first.trim()} · 目标 ${entry.$2.split(',').last.trim()} · 点击编辑',
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
  ];

  bool textMatches(String value) =>
      value.toLowerCase().contains(search.text.trim().toLowerCase());
  bool ruleMatches(ProxyRulePresentation rule) =>
      textMatches('${rule.pattern} ${rule.type} ${rule.proxy ? '代理' : '直连'}');

  List<ProxyLogPresentation> get visibleLogs => snapshot.logs.reversed
      .where(
        (log) =>
            (filter == 0 ||
                (filter == 1 && log.level != ProxyLogLevel.info) ||
                (filter == 2 && log.level == ProxyLogLevel.error)) &&
            textMatches(
              '${log.displayText} ${log.searchText} ${log.level.name}',
            ),
      )
      .toList();

  Widget _logs() {
    final visibleLogs = this.visibleLogs;
    return SettingsGroup(
      title: '当前进程日志',
      description:
          '显示 ${visibleLogs.length}/${snapshot.logs.length} 条，最新记录在前；已淘汰 ${snapshot.droppedLogs} 条旧记录。最多保留 1000 条，核心重复输出按一秒窗口合并，请求失败逐条保留。顶部复制和导出包含全部记录，按发生顺序排列，不受筛选影响。凭据、私有路径和订阅地址已遮蔽。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: KiyoriSearchField(
            controller: search,
            hint: '搜索日志',
            showSearchIcon: true,
            showClear: true,
            onChanged: (_) => setState(() {}),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            spacing: 8,
            children: [
              for (var index = 0; index < 3; index++)
                FilterChip(
                  selected: filter == index,
                  onSelected: (_) => setState(() => filter = index),
                  label: Text(['全部', '警告与错误', '仅错误'][index]),
                ),
            ],
          ),
        ),
        if (snapshot.logs.isEmpty)
          const NetworkProxyNote('暂无日志。导入、启用代理、切换节点或测速后，相关状态会显示在这里。')
        else if (visibleLogs.isEmpty)
          const NetworkProxyNote('没有匹配的日志。可清除搜索或切换为全部级别。')
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: ListView.builder(
              shrinkWrap: true,
              primary: false,
              itemCount: visibleLogs.length,
              itemBuilder: (context, i) => Padding(
                key: ValueKey(visibleLogs[i].id),
                padding: const EdgeInsets.all(18),
                child: SelectableText(
                  visibleLogs[i].displayText,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 18 / 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        if (snapshot.logs.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: snapshot.busy
                  ? null
                  : () => confirm(
                      '清空代理日志？',
                      '这会删除当前进程内的全部代理日志，不会修改订阅、节点或连接模式。',
                      '清空',
                    ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空日志'),
            ),
          ),
      ],
    );
  }

  SettingsRow _nav(
    String title,
    String description,
    NetworkProxySection section,
  ) => SettingsRow(
    title: title,
    description: description,
    enabled: section == NetworkProxySection.logs
        ? !snapshot.busy
        : snapshot.controlsEnabled,
    onTap: () => widget.onOpen(section),
  );
}

class NetworkProxyNote extends StatelessWidget {
  const NetworkProxyNote(this.text, {this.small = false, super.key});
  final String text;
  final bool small;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: small ? 12 : 18),
    child: Text(
      text,
      style: TextStyle(
        fontSize: small ? 12 : 13,
        height: small ? 17 / 12 : 19 / 13,
        color: PrimaryColors.of(context).secondary,
      ),
    ),
  );
}
