enum ProxyRuntimePhase { stopped, starting, running, stopping, error }

enum ProxyConnectionMode {
  rule('规则'),
  global('全局'),
  direct('直连');

  const ProxyConnectionMode(this.label);
  final String label;
}

/// 不包含真实订阅凭据；显示描述已由领域脱敏，运行事实不能由UI按钮推导。
class NetworkProxyPresentation {
  const NetworkProxyPresentation({
    this.readable = true,
    this.canEnable = false,
    this.enabled = false,
    this.hasProxyRoute = false,
    this.vpn = false,
    this.httpProxy = false,
    this.phase = ProxyRuntimePhase.stopped,
    this.mode = ProxyConnectionMode.direct,
    this.lan = false,
    this.busy = false,
    this.subscriptions = const [],
    this.activeId,
    this.rules = const [],
    this.scripts = const [],
    this.logs = const [],
    this.droppedLogs = 0,
    this.operation,
    this.feedback,
    this.feedbackError = false,
    this.feedbackSection = 'overview',
  });
  final bool readable,
      canEnable,
      enabled,
      hasProxyRoute,
      vpn,
      httpProxy,
      lan,
      busy;
  final ProxyRuntimePhase phase;
  final ProxyConnectionMode mode;
  final List<ProxySubscriptionPresentation> subscriptions;
  final String? activeId;
  final List<ProxyRulePresentation> rules;
  final List<ProxyScriptPresentation> scripts;
  final List<ProxyLogPresentation> logs;
  final int droppedLogs;
  final String? operation, feedback;
  final bool feedbackError;
  final String feedbackSection;
  bool get controlsEnabled => readable && !busy;
  ProxySubscriptionPresentation? get active =>
      subscriptions.where((s) => s.id == activeId).firstOrNull;
  String get runtimeDescription {
    if (!readable) return '加密配置不可读取，可在本页重置';
    if (!canEnable) return '请先导入并选择有效订阅，才能启用应用内代理';
    if (!enabled) return '已关闭；Kiyori Flutter 使用 Android 系统网络与系统代理';
    if (!hasProxyRoute) return '已开启；Kiyori Flutter 代理模块均直连，仍遵循 Android 系统路由';
    if (vpn || httpProxy) {
      final label = vpn && httpProxy
          ? '系统 VPN 与 HTTP/PAC 代理'
          : vpn
          ? '系统 VPN'
          : 'Android HTTP/PAC 代理';
      return '已开启；$label接管中，外部路由关闭后自动恢复内嵌代理';
    }
    final subscription = active;
    if (subscription == null) return '已开启；需要选择当前订阅';
    return switch (phase) {
      ProxyRuntimePhase.running => '运行中 · ${mode.label} · ${subscription.name}',
      ProxyRuntimePhase.starting => '正在启动 ${subscription.name}',
      ProxyRuntimePhase.stopping => '正在停止内嵌 Mihomo',
      ProxyRuntimePhase.error => '运行失败；设置仍保留',
      ProxyRuntimePhase.stopped => '已开启；等待代理模块发起请求',
    };
  }
}

class ProxySubscriptionPresentation {
  const ProxySubscriptionPresentation({
    required this.id,
    required this.name,
    required this.description,
    this.localFile = false,
    this.editUrl = '',
    this.groups = const [],
    this.rules = const [],
    this.currentGroup,
  });
  final String id, name, description, editUrl;
  final bool localFile;
  final List<ProxyGroupPresentation> groups;
  final List<String> rules;
  final String? currentGroup;
}

class ProxyGroupPresentation {
  const ProxyGroupPresentation({
    required this.name,
    required this.label,
    this.type = 'select',
    this.selectable = true,
    this.selected,
    this.nodes = const [],
  });
  final String name, label, type;
  final bool selectable;
  final String? selected;
  final List<ProxyNodePresentation> nodes;
}

enum ProxyNodeStatus { untested, success, timeout, failed }

class ProxyNodePresentation {
  const ProxyNodePresentation(
    this.name,
    this.type, {
    this.status = ProxyNodeStatus.untested,
    this.delay,
  });
  final String name, type;
  final ProxyNodeStatus status;
  final int? delay;
  String get delayLabel => switch (status) {
    ProxyNodeStatus.untested => '未测速',
    ProxyNodeStatus.success => delay == null ? '成功' : '$delay ms',
    ProxyNodeStatus.timeout => '超时',
    ProxyNodeStatus.failed => '失败',
  };
}

class ProxyRulePresentation {
  const ProxyRulePresentation(
    this.id,
    this.pattern, {
    this.type = 'DOMAIN',
    this.proxy = true,
    this.enabled = true,
  });
  final String id, pattern, type;
  final bool proxy, enabled;
}

class ProxyScriptPresentation {
  const ProxyScriptPresentation(
    this.id,
    this.name,
    this.category, {
    this.description = '',
    this.enabled = false,
    this.mode = '跟随模式',
  });
  final String id, name, category, description, mode;
  final bool enabled;
}

enum ProxyLogLevel { info, warning, error }

class ProxyLogPresentation {
  const ProxyLogPresentation(
    this.id,
    this.level,
    this.displayText, {
    this.searchText = '',
  });
  final String id, displayText, searchText;
  final ProxyLogLevel level;
}
