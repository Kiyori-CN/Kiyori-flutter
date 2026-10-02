import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/network_proxy_editors.dart';
import 'package:kiyori/features/settings/presentation/network_proxy_page.dart';
import 'package:kiyori/features/settings/presentation/network_proxy_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/network_proxy_fixtures.dart';
import 'support/ui_test_helpers.dart' show revealAvatar;

void main() {
  Future<void> mount(
    WidgetTester tester,
    NetworkProxySection section, [
    NetworkProxyPresentation snapshot = proxyFixture,
  ]) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: NetworkProxyPage(
          section: section,
          snapshot: snapshot,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending menu is removed with its host while unrelated route remains',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      Widget host(bool visible) => MaterialApp(
        navigatorKey: navigator,
        home: visible
            ? NetworkProxyPage(
                section: NetworkProxySection.subscriptions,
                snapshot: proxyFixture,
                onOpen: (_) {},
              )
            : const Scaffold(body: Text('替换宿主')),
      );
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
      await tester.tap(find.byTooltip('管理 测试订阅'));
      // 菜单尚未构建，不能依赖已登记的route集合。
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsNothing);
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
      await tester.tap(find.byTooltip('管理 测试订阅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('独立页面')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      expect(find.text('独立页面'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('替换宿主'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('node sort menu closes when active subscription changes', (
    tester,
  ) async {
    await mount(tester, NetworkProxySection.node);
    await tester.tap(find.byTooltip('节点排序'));
    await tester.pumpAndSettle();
    await mount(
      tester,
      NetworkProxySection.node,
      const NetworkProxyPresentation(
        activeId: 'local',
        subscriptions: [proxySubscription, proxyLocalSubscription],
      ),
    );
    expect(find.text('延迟'), findsNothing);
    expect(find.text('本地测试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'open editor follows busy snapshots without resetting its draft',
    (tester) async {
      await mount(tester, NetworkProxySection.subscriptions);
      await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
      await tester.tap(find.byTooltip('管理 测试订阅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '未保存草稿');
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: NetworkProxyPage(
            section: NetworkProxySection.subscriptions,
            snapshot: const NetworkProxyPresentation(
              busy: true,
              subscriptions: [proxySubscription],
            ),
            onOpen: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, NetworkProxySection.subscriptions);
      expect(find.text('未保存草稿'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription rule draft closes on rule revision or active subscription change',
    (tester) async {
      await mount(tester, NetworkProxySection.rules);
      await revealAvatar(tester, find.text(proxySubscription.rules.first));
      await tester.tap(find.text(proxySubscription.rules.first));
      await tester.pumpAndSettle();
      expect(find.text('编辑当前订阅规则'), findsOneWidget);
      await mount(
        tester,
        NetworkProxySection.rules,
        NetworkProxyPresentation(
          activeId: 'url',
          subscriptions: [
            ProxySubscriptionPresentation(
              id: 'url',
              name: '新快照',
              description: '',
              rules: proxySubscription.rules.reversed.toList(),
            ),
          ],
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      await mount(tester, NetworkProxySection.rules);
      await revealAvatar(tester, find.text(proxySubscription.rules.first));
      await tester.tap(find.text(proxySubscription.rules.first));
      await tester.pumpAndSettle();
      await mount(
        tester,
        NetworkProxySection.rules,
        const NetworkProxyPresentation(
          activeId: 'local',
          subscriptions: [proxySubscription, proxyLocalSubscription],
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription menu resolves the current entity after same-ID snapshot replacement',
    (tester) async {
      await mount(tester, NetworkProxySection.subscriptions);
      await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
      await tester.tap(find.byTooltip('管理 测试订阅'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        NetworkProxySection.subscriptions,
        const NetworkProxyPresentation(
          subscriptions: [
            ProxySubscriptionPresentation(
              id: 'url',
              name: '已更新名称',
              description: '',
              editUrl: 'https://example.invalid/updated',
            ),
          ],
        ),
      );
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('已更新名称'), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'https://example.invalid/updated',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'URL/local editors, reorder, removal and menu disposal preserve entity boundaries',
    (tester) async {
      await mount(tester, NetworkProxySection.subscriptions);
      await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
      await tester.tap(find.byTooltip('管理 测试订阅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(fields.last).obscureText, isTrue);
      final controller = tester.widget<TextField>(fields.first).controller!;
      await tester.enterText(fields.first, '草稿名称');
      await mount(
        tester,
        NetworkProxySection.subscriptions,
        const NetworkProxyPresentation(
          subscriptions: [proxyLocalSubscription, proxySubscription],
        ),
      );
      expect(controller.text, '草稿名称');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(
        tester,
        NetworkProxySection.subscriptions,
        const NetworkProxyPresentation(subscriptions: [proxyLocalSubscription]),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await revealAvatar(tester, find.byTooltip('管理 本地测试'));
      await tester.tap(find.byTooltip('管理 本地测试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('重命名订阅'), findsOneWidget);
      expect(fields, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('管理 本地测试'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        NetworkProxySection.subscriptions,
        const NetworkProxyPresentation(),
      );
      expect(find.text('复制'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rule removal closes nested type menu; script removal closes its drawer',
    (tester) async {
      await mount(tester, NetworkProxySection.rules);
      await revealAvatar(tester, find.text('example.net'));
      await tester.tap(find.text('example.net'));
      await tester.pumpAndSettle();
      expect(find.text('编辑自定义规则'), findsOneWidget);
      await tester.ensureVisible(find.text('完整域名 · DOMAIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整域名 · DOMAIN'));
      await tester.pumpAndSettle();
      expect(find.text('PROCESS-NAME'), findsOneWidget);
      await mount(
        tester,
        NetworkProxySection.rules,
        const NetworkProxyPresentation(),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('PROCESS-NAME'), findsNothing);
      await mount(tester, NetworkProxySection.scripts);
      await revealAvatar(tester, find.text('测试脚本'));
      await tester.tap(find.text('测试脚本'));
      await tester.pumpAndSettle();
      expect(find.text('测试脚本脚本规则'), findsOneWidget);
      await mount(
        tester,
        NetworkProxySection.scripts,
        const NetworkProxyPresentation(),
      );
      expect(find.text('测试脚本脚本规则'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'node sorting puts measured delay before timeout and does not select on tap',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mount(tester, NetworkProxySection.node);
      await tester.tap(find.byTooltip('节点排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('延迟'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Beta')).dy,
        lessThan(tester.getTopLeft(find.text('Zulu')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Zulu')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy),
      );
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已选择：Zulu'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();
      expect(find.text('Zulu'), findsNothing);
      await tester.tap(find.text('自动选择'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.textContaining('自动策略组由 Mihomo 决定'), findsOneWidget);
      await tester.tap(find.byTooltip('测速 Auto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未测速'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logs keep insertion order across clock rollback and filter locally',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mount(tester, NetworkProxySection.logs);
      expect(
        tester.getTopLeft(find.text(proxyFixture.logs.last.displayText)).dy,
        lessThan(
          tester.getTopLeft(find.text(proxyFixture.logs.first.displayText)).dy,
        ),
      );
      await tester.tap(find.text('仅错误'));
      await tester.pumpAndSettle();
      expect(find.text(proxyFixture.logs.first.displayText), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的日志。可清除搜索或切换为全部级别。'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '17:00');
      await tester.pumpAndSettle();
      expect(find.text(proxyFixture.logs.last.displayText), findsOneWidget);
      await tester.tap(find.text('清空日志'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(proxyFixture.logs.last.displayText), findsOneWidget);
    },
  );

  testWidgets(
    'runtime failure/system route and busy editor remain authoritative',
    (tester) async {
      await mount(
        tester,
        NetworkProxySection.overview,
        const NetworkProxyPresentation(
          canEnable: true,
          enabled: true,
          hasProxyRoute: true,
          activeId: 'url',
          subscriptions: [proxySubscription],
          phase: ProxyRuntimePhase.error,
        ),
      );
      expect(find.text('运行失败；设置仍保留'), findsOneWidget);
      await mount(
        tester,
        NetworkProxySection.overview,
        const NetworkProxyPresentation(
          canEnable: true,
          enabled: true,
          hasProxyRoute: true,
          vpn: true,
          httpProxy: true,
        ),
      );
      expect(find.textContaining('系统 VPN 与 HTTP/PAC 代理接管中'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            body: NetworkSubscriptionEditor(busy: true, error: '订阅校验失败'),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull,
      );
      expect(find.text('订阅校验失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
