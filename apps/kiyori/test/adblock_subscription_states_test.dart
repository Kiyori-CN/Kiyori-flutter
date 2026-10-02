import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/browser/presentation/adblock_presentation.dart';
import 'package:kiyori/features/browser/presentation/adblock_subscription_group.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

const customSubscription = AdblockSubscription(
  id: 'custom',
  name: '测试过滤',
  url: 'https://example.invalid/rules',
  hasLocalRules: true,
  network: 10,
  networkExceptions: 2,
  elements: 3,
  ignored: 4,
  error: '更新超时',
  updatedLabel: '测试时间',
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    List<AdblockSubscription> items, {
    String query = '',
    Set<String> refreshing = const {},
    AdblockRefreshProgress? progress,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdblockSubscriptionGroup(
              title: '自定义订阅',
              description: '测试目录',
              query: query,
              group: AdblockSubscriptionGroupKind.custom,
              snapshot: AdblockPresentation(
                phase: AdblockRuntimePhase.ready,
                subscriptions: items,
                refreshing: refreshing,
                refreshProgress: progress,
              ),
            ),
          ),
        ),
      ),
    );
    if (refreshing.isEmpty) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
    'subscription status precedence and refresh facts do not mutate',
    (tester) async {
      await mount(tester, [customSubscription]);
      expect(find.text('更新失败 · 15 条规则仍可用'), findsOneWidget);
      await tester.tap(find.text('测试过滤'));
      await tester.pumpAndSettle();
      expect(find.text('错误：更新超时'), findsOneWidget);
      expect(find.text('忽略 4 行 · 测试时间'), findsOneWidget);
      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await mount(
        tester,
        [customSubscription],
        refreshing: {'custom'},
        progress: const AdblockRefreshProgress(
          title: '正在自动同步',
          completed: 1,
          total: 3,
          succeeded: 1,
          failed: 0,
        ),
      );
      expect(find.text('正在同步 · 2/3'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '编辑'))
            .onPressed,
        isNull,
      );
      await mount(tester, const [
        AdblockSubscription(
          id: 'custom',
          name: '测试过滤',
          url: 'https://example.invalid',
          enabled: false,
          hasLocalRules: true,
          network: 5,
          error: '错误',
        ),
      ]);
      expect(find.text('已停用 · 5 条规则'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search preserves expansion; reorder retains draft and removal closes it',
    (tester) async {
      const second = AdblockSubscription(
        id: 'second',
        name: '第二项',
        url: 'https://example.invalid/second',
      );
      await mount(tester, [customSubscription, second]);
      await tester.tap(find.text('测试过滤'));
      await tester.pumpAndSettle();
      await mount(tester, [customSubscription, second], query: 'second');
      expect(find.text('订阅地址'), findsNothing);
      await mount(tester, [customSubscription, second]);
      expect(find.text('错误：更新超时'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '草稿');
      final controller = tester.widget<TextField>(fields.first).controller!;
      await mount(tester, [second, customSubscription]);
      expect(controller.text, '草稿');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, [second]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, [customSubscription, second]);
      expect(find.text('订阅地址'), findsNothing);
      await tester.tap(find.text('测试过滤'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除广告拦截订阅'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'custom subscription actions and editor remain reachable $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await mount(tester, [customSubscription]);
        await tester.tap(find.text('测试过滤'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('编辑'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
