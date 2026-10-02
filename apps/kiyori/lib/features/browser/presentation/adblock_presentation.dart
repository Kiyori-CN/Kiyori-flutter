/// 过滤统计与规则目录只由业务 owner 注入；这里不编译或执行规则。
enum AdblockRuntimePhase { reading, loading, compiling, ready, failed }

class AdblockPresentation {
  const AdblockPresentation({
    this.phase = AdblockRuntimePhase.reading,
    this.enabled = true,
    this.completed = 0,
    this.total = 0,
    this.cacheHits = 0,
    this.compiled = 0,
    this.warning,
    this.error,
    this.blockedRequests = 0,
    this.networkCount = 0,
    this.networkExceptions = 0,
    this.elementCount = 0,
    this.elementExceptions = 0,
    this.networkRules = const [],
    this.elementRules = const [],
    this.allowlist = const [],
    this.subscriptions = builtInAdblockSubscriptions,
    this.refreshing = const {},
    this.refreshProgress,
    this.autoUpdate = true,
  });
  final AdblockRuntimePhase phase;
  final bool enabled;
  final int completed, total, cacheHits, compiled;
  final String? warning, error;
  final int blockedRequests, networkCount, networkExceptions;
  final int elementCount, elementExceptions;
  final List<AdblockNetworkRule> networkRules;
  final List<AdblockElementRule> elementRules;
  final List<String> allowlist;
  final List<AdblockSubscription> subscriptions;
  final Set<String> refreshing;
  final AdblockRefreshProgress? refreshProgress;
  final bool autoUpdate;
  int get readyBuiltIn => subscriptions
      .where(
        (s) =>
            s.group != AdblockSubscriptionGroupKind.custom && s.hasLocalRules,
      )
      .length;
  bool get subscriptionActions =>
      ready && refreshing.isEmpty && refreshProgress == null;

  bool get ready => phase == AdblockRuntimePhase.ready;
  String get status => switch (phase) {
    AdblockRuntimePhase.reading => '读取中',
    AdblockRuntimePhase.loading ||
    AdblockRuntimePhase.compiling => '$completed/$total',
    AdblockRuntimePhase.ready => '已就绪',
    AdblockRuntimePhase.failed => '失败',
  };
  String get description => switch (phase) {
    AdblockRuntimePhase.reading => '正在后台读取广告拦截设置，页面和浏览器请求不会等待',
    AdblockRuntimePhase.loading =>
      '正在加载本地编译规则 $completed/$total，规则内容未变化时不会重新解析和编译',
    AdblockRuntimePhase.compiling => '正在后台编译已变化规则 $completed/$total，完成后一次性启用',
    AdblockRuntimePhase.ready =>
      warning != null
          ? '本地规则已就绪；$warning'
          : total > 0
          ? '已加载 $cacheHits 份本地编译快照，本次编译 $compiled 份；浏览器请求直接读取不可变快照'
          : '本地编译规则已就绪，浏览器请求直接读取不可变快照',
    AdblockRuntimePhase.failed => error ?? '广告拦截规则初始化失败',
  };
}

enum AdblockSubscriptionGroupKind { pro, plus, custom }

class AdblockSubscription {
  const AdblockSubscription({
    required this.id,
    required this.name,
    required this.url,
    this.group = AdblockSubscriptionGroupKind.custom,
    this.enabled = true,
    this.hasLocalRules = false,
    this.network = 0,
    this.networkExceptions = 0,
    this.elements = 0,
    this.elementExceptions = 0,
    this.ignored = 0,
    this.updatedLabel,
    this.error,
  });
  final String id, name, url;
  final AdblockSubscriptionGroupKind group;
  final bool enabled, hasLocalRules;
  final int network, networkExceptions, elements, elementExceptions, ignored;
  final String? updatedLabel, error;
  int get count => network + networkExceptions + elements + elementExceptions;
}

class AdblockRefreshProgress {
  const AdblockRefreshProgress({
    required this.title,
    required this.completed,
    required this.total,
    required this.succeeded,
    required this.failed,
    this.currentId,
  });
  final String title;
  final int completed, total, succeeded, failed;
  final String? currentId;
}

const builtInAdblockSubscriptions = [
  AdblockSubscription(
    id: 'builtin-pro-my-adfilters',
    name: 'My AdFilters',
    url: 'https://cdn.jsdelivr.net/gh/xun404/adblock@main/ad.txt',
    group: AdblockSubscriptionGroupKind.pro,
  ),
  AdblockSubscription(
    id: 'builtin-pro-adguard-chinese',
    name: 'AdGuard 中文过滤器',
    url: 'https://filters.adtidy.org/extension/chromium/filters/224.txt',
    group: AdblockSubscriptionGroupKind.pro,
  ),
  AdblockSubscription(
    id: 'builtin-pro-adrules-lite',
    name: 'AdRules Lite',
    url: 'https://adrules.top/adblock_lite.txt',
    group: AdblockSubscriptionGroupKind.pro,
  ),
  AdblockSubscription(
    id: 'builtin-abp-easylist-china',
    name: 'EasyList China + EasyList',
    url:
        'https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt',
    group: AdblockSubscriptionGroupKind.plus,
  ),
  AdblockSubscription(
    id: 'builtin-abp-acceptable-ads',
    name: '可接受广告例外规则',
    url: 'https://easylist-downloads.adblockplus.org/exceptionrules.txt',
    group: AdblockSubscriptionGroupKind.plus,
  ),
];

class AdblockNetworkRule {
  const AdblockNetworkRule(this.id, this.rule, {this.enabled = true});
  final String id, rule;
  final bool enabled;
}

class AdblockElementRule {
  const AdblockElementRule(
    this.id,
    this.domain,
    this.selector, {
    this.enabled = true,
  });
  final String id, domain, selector;
  final bool enabled;
}
