import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'adblock_subscription_group.dart';
import 'adblock_editor_dialog.dart';
import 'adblock_managed_rules.dart';
import 'adblock_presentation.dart';

enum AdblockSection {
  overview('广告拦截器'),
  network('网址过滤'),
  elements('网页元素'),
  allowlist('站点白名单'),
  subscriptions('广告拦截订阅');

  const AdblockSection(this.title);
  final String title;
}

/// 默认是尚未加载的快照；目录与运行结果由 owner 注入，不执行过滤或同步。
class AdblockSettingsPage extends StatefulWidget {
  const AdblockSettingsPage({
    required this.section,
    required this.onOpen,
    this.snapshot = const AdblockPresentation(),
    super.key,
  });
  final AdblockSection section;
  final ValueChanged<AdblockSection> onOpen;
  final AdblockPresentation snapshot;
  @override
  State<AdblockSettingsPage> createState() => _AdblockSettingsPageState();
}

class _AdblockSettingsPageState extends State<AdblockSettingsPage> {
  AdblockPresentation get snapshot => widget.snapshot;
  final search = TextEditingController();
  final editorRoutes = <DialogRoute<void>>{};

  void removeEditors() {
    final routes = editorRoutes.toList();
    editorRoutes.clear();
    if (routes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> addSubscription() async {
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => const SettingsTheme(
        child: AdblockEditor(kind: AdblockEditorKind.subscription),
      ),
    );
    editorRoutes.add(route);
    await Navigator.of(context).push(route);
    editorRoutes.remove(route);
  }

  @override
  void didUpdateWidget(covariant AdblockSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      search.clear();
      removeEditors();
    }
  }

  @override
  void dispose() {
    removeEditors();
    search.dispose();
    super.dispose();
  }

  String summary(AdblockSubscriptionGroupKind group) {
    final items = snapshot.subscriptions.where((s) => s.group == group);
    return '${items.where((s) => s.hasLocalRules).length}/${items.length} 就绪';
  }

  Widget _group(String title, String description, List<Widget> rows) =>
      SettingsGroup(
        title: title,
        description: description,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            rows[i],
          ],
        ],
      );
  Widget _nav(
    AdblockSection section,
    String description,
    String value, {
    String? title,
  }) => SettingsRow(
    title: title ?? section.title,
    description: description,
    value: value,
    onTap: () => widget.onOpen(section),
  );
  Widget _search(String description, AdblockEditorKind kind) => SettingsGroup(
    title: '查找与新增',
    description: description,
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
              onPressed: kind == AdblockEditorKind.subscription
                  ? addSubscription
                  : () => showAdblockEditor(context, kind),
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
  );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: widget.section.title,
    children: switch (widget.section) {
      AdblockSection.overview => [
        _group('拦截状态', '用于 Kiyori 内置浏览器的网页广告过滤，不影响其他应用；网址过滤与元素隐藏共用此开关', [
          SettingsRow(
            title: '启用广告拦截',
            description: !snapshot.ready
                ? snapshot.description
                : !snapshot.enabled
                ? '规则与订阅仍会保留，但不执行拦截'
                : snapshot.networkCount + snapshot.elementCount > 0
                ? '规则引擎已就绪，请求线程直接读取不可变快照'
                : '拦截已开启，等待已启用订阅完成同步',
            checked: snapshot.enabled,
            enabled: snapshot.ready,
            onTap: emptyAction,
          ),
          AdblockMetric('本地规则引擎', snapshot.status, snapshot.description),
          AdblockMetric(
            '当前进程已拦截',
            '${snapshot.blockedRequests}',
            '从本次应用进程启动后累计的请求数量',
          ),
          AdblockMetric(
            '已启用的网址规则',
            '${snapshot.networkCount}',
            '阻断 ${snapshot.networkCount} 条，例外 ${snapshot.networkExceptions} 条；总开关关闭时不执行',
          ),
          AdblockMetric(
            '已启用的元素规则',
            '${snapshot.elementCount}',
            '隐藏 ${snapshot.elementCount} 条，例外 ${snapshot.elementExceptions} 条；总开关关闭时不执行',
          ),
          AdblockMetric(
            '内置订阅就绪',
            '${snapshot.readyBuiltIn}/5',
            '已完成本地同步；是否参与拦截仍由各组与单条开关决定',
          ),
        ]),
        _group('规则与站点', '所有入口共同使用同一份规则；修改后会立即应用到现有浏览器窗口', [
          _nav(
            AdblockSection.network,
            '拦截广告脚本、图片、接口和其他请求地址',
            '${snapshot.networkRules.length}',
          ),
          _nav(
            AdblockSection.elements,
            '按站点隐藏广告容器、浮层和干扰组件',
            '${snapshot.elementRules.length}',
          ),
          _nav(
            AdblockSection.allowlist,
            '白名单站点不会执行请求拦截或元素隐藏',
            '${snapshot.allowlist.length}',
          ),
        ]),
        _group('内置拦截方案', '两组规则共用同一运行时；已开启不等于已就绪，首次缺少本地规则时会立即同步', [
          _nav(
            AdblockSection.subscriptions,
            'My AdFilters、AdGuard 中文过滤器、AdRules Lite',
            summary(AdblockSubscriptionGroupKind.pro),
            title: '广告拦截器 Pro',
          ),
          _nav(
            AdblockSection.subscriptions,
            'EasyList China + EasyList 与可接受广告例外规则',
            summary(AdblockSubscriptionGroupKind.plus),
            title: 'Adblock Plus',
          ),
          _nav(
            AdblockSection.subscriptions,
            '自动更新、全部刷新、逐条状态和自定义订阅',
            '${snapshot.subscriptions.length}',
            title: '订阅与更新',
          ),
        ]),
      ],
      AdblockSection.network => [
        AdblockManagedRules(
          snapshot: widget.snapshot,
          kind: AdblockEditorKind.network,
        ),
      ],
      AdblockSection.elements => [
        AdblockManagedRules(
          snapshot: widget.snapshot,
          kind: AdblockEditorKind.element,
        ),
      ],
      AdblockSection.allowlist => [
        AdblockManagedRules(
          snapshot: widget.snapshot,
          kind: AdblockEditorKind.allowlist,
        ),
      ],
      AdblockSection.subscriptions => [
        _group('订阅状态', '先看规则是否已就绪，再决定是否启用；开关开启但未同步时不会产生拦截效果', [
          AdblockMetric('运行时状态', snapshot.status, snapshot.description),
          AdblockMetric(
            '已启用订阅',
            '${snapshot.subscriptions.where((s) => s.enabled).length}/${snapshot.subscriptions.length}',
            '参与统一广告拦截运行时的订阅数量',
          ),
          AdblockMetric(
            '已就绪订阅',
            '${snapshot.subscriptions.where((s) => s.hasLocalRules).length}/${snapshot.subscriptions.length}',
            '已经完成下载、解析并拥有本地规则载荷',
          ),
          AdblockMetric(
            '当前生效规则',
            '${snapshot.subscriptions.where((s) => s.enabled).fold(0, (n, s) => n + s.count)}',
            '已启用订阅的阻断、例外和网页元素规则总数',
          ),
          if (snapshot.refreshProgress case final progress?)
            AdblockMetric(
              progress.title,
              '${progress.completed}/${progress.total}',
              '成功 ${progress.succeeded} · 失败 ${progress.failed} · 正在处理 ${snapshot.subscriptions.where((s) => s.id == progress.currentId).firstOrNull?.name ?? '准备中'}',
            ),
        ]),
        _group('订阅更新', '首次缺少本地规则时自动同步；手动更新只在完整下载并解析后替换当前版本', [
          SettingsRow(
            title: '自动更新内置订阅',
            description: '应用启动时检查已启用且到期的内置订阅，开启新订阅时立即同步',
            checked: snapshot.autoUpdate,
            onTap: emptyAction,
          ),
          SettingsRow(
            title: snapshot.refreshProgress?.title ?? '更新已启用订阅',
            description: snapshot.refreshProgress == null
                ? '按顺序下载并验证当前已启用的内置与自定义订阅'
                : '已完成 ${snapshot.refreshProgress!.completed}/${snapshot.refreshProgress!.total}，成功 ${snapshot.refreshProgress!.succeeded}，失败 ${snapshot.refreshProgress!.failed}',
            enabled: snapshot.subscriptionActions,
            onTap: emptyAction,
          ),
        ]),
        _search(
          '搜索名称或地址；加号用于添加自定义 HTTP(S) 纯文本订阅',
          AdblockEditorKind.subscription,
        ),
        AdblockSubscriptionGroup(
          title: '广告拦截器 Pro',
          description: '三条高覆盖中文与通用过滤列表',
          query: search.text,
          group: AdblockSubscriptionGroupKind.pro,
          snapshot: snapshot,
        ),
        AdblockSubscriptionGroup(
          title: 'Adblock Plus',
          description: 'EasyList 中国规则与可接受广告例外规则',
          query: search.text,
          group: AdblockSubscriptionGroupKind.plus,
          snapshot: snapshot,
        ),
        AdblockSubscriptionGroup(
          title: '自定义订阅',
          description: '可添加、改名、换址、启停、刷新或删除',
          query: search.text,
          group: AdblockSubscriptionGroupKind.custom,
          snapshot: snapshot,
        ),
      ],
    },
  );
}

class AdblockMetric extends StatelessWidget {
  const AdblockMetric(this.title, this.value, this.description, {super.key});
  final String title, value, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 17 / 12,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: PrimaryColors.of(context).accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class AdblockEmptyRow extends StatelessWidget {
  const AdblockEmptyRow(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    child: Text(
      message,
      style: TextStyle(
        fontSize: 13,
        color: PrimaryColors.of(context).secondary,
      ),
    ),
  );
}
