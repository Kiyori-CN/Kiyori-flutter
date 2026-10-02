class BrowserScriptsPresentation {
  const BrowserScriptsPresentation({
    this.supported = false,
    this.allowed = false,
    this.reason = '',
    this.scripts = const [],
  });
  final bool supported, allowed;
  final String reason;
  final List<BrowserScriptPresentation> scripts;
}

class BrowserScriptPresentation {
  const BrowserScriptPresentation({
    required this.id,
    required this.name,
    this.enabled = false,
    this.world,
    this.grants = const [],
    this.pageRules = const [],
    this.connects = const [],
    this.unknownGrants = const [],
    this.blockedReasons = const [],
  });
  final String id, name;
  final bool enabled;
  final BrowserScriptWorld? world;
  final List<String> grants, pageRules, connects, unknownGrants, blockedReasons;
  String get state => blockedReasons.isNotEmpty
      ? '不可运行'
      : unknownGrants.isNotEmpty
      ? '需审查'
      : enabled
      ? '已启用'
      : '已停用';
  String get description => [
    switch (world) {
      BrowserScriptWorld.page => '页面世界',
      BrowserScriptWorld.isolated => '隔离世界',
      null => '执行世界未确定',
    },
    '${grants.toSet().length} 项权限',
    '页面：${pageRules.isEmpty ? '全部页面' : _rules(pageRules)}',
    '联网：${connects.isEmpty ? '仅页面同源' : _rules(connects)}',
    if (unknownGrants.isNotEmpty) '${unknownGrants.length} 项未知权限',
    if (blockedReasons.isNotEmpty) '${blockedReasons.length} 项阻塞',
  ].join(' · ');
  static String _rules(List<String> values) {
    final rules = values.toSet().toList();
    return rules.take(2).join('、') +
        (rules.length > 2 ? ' 等 ${rules.length} 项' : '');
  }
}

enum BrowserScriptWorld { page, isolated }
