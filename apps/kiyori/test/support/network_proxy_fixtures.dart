import 'package:kiyori/features/settings/presentation/network_proxy_presentation.dart';

const proxySubscription = ProxySubscriptionPresentation(
  id: 'url',
  name: '测试订阅',
  description: 'example.invalid · Clash YAML · 3 节点 · 2 组',
  editUrl: 'https://example.invalid/subscription',
  currentGroup: 'manual',
  rules: ['DOMAIN,example.com,DIRECT', 'DOMAIN-SUFFIX,example.net,PROXY'],
  groups: [
    ProxyGroupPresentation(
      name: 'manual',
      label: '默认代理',
      selected: 'Zulu',
      nodes: [
        ProxyNodePresentation(
          'Zulu',
          'vmess',
          status: ProxyNodeStatus.success,
          delay: 80,
        ),
        ProxyNodePresentation(
          'Alpha',
          'ss',
          status: ProxyNodeStatus.timeout,
          delay: 1,
        ),
        ProxyNodePresentation(
          'Beta',
          'ss',
          status: ProxyNodeStatus.success,
          delay: 20,
        ),
      ],
    ),
    ProxyGroupPresentation(
      name: 'auto',
      label: '自动选择',
      type: 'url-test',
      selectable: false,
      selected: 'Auto',
      nodes: [ProxyNodePresentation('Auto', '策略组')],
    ),
  ],
);
const proxyLocalSubscription = ProxySubscriptionPresentation(
  id: 'local',
  name: '本地测试',
  localFile: true,
  description: '本地 YAML · 1 节点 · 1 组',
);
const proxyFixture = NetworkProxyPresentation(
  canEnable: true,
  enabled: true,
  hasProxyRoute: true,
  phase: ProxyRuntimePhase.running,
  mode: ProxyConnectionMode.rule,
  activeId: 'url',
  subscriptions: [proxySubscription, proxyLocalSubscription],
  rules: [
    ProxyRulePresentation('first', 'example.com'),
    ProxyRulePresentation('second', 'example.net', proxy: false),
  ],
  scripts: [
    ProxyScriptPresentation(
      'fixture.script',
      '测试脚本',
      '网络',
      description: '测试目录',
      mode: '直连',
    ),
  ],
  logs: [
    ProxyLogPresentation(
      'first',
      ProxyLogLevel.info,
      '10-03 02:00:00.000  信息  runtime\n已读取测试配置',
    ),
    ProxyLogPresentation(
      'second',
      ProxyLogLevel.error,
      '10-03 01:00:00.000  错误  runtime\n连接超时',
      searchText: '2026-10-02T17:00:00Z',
    ),
  ],
);
