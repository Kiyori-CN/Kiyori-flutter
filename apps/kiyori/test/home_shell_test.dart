import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/app/shell/bottom_navigation.dart';

import 'app_test.dart' show FakeClient;

void main() {
  testWidgets('horizontal drag follows after slop without rebuilding the bar', (
    tester,
  ) async {
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    final pageView = tester.widget<PageView>(find.byType(PageView));
    final bar = tester.widget<HomeBottomNavigation>(
      find.byType(HomeBottomNavigation),
    );
    // 在可点击控件上验证点击/拖动仲裁；空白区只有一个识别器，可直接胜出。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('AI')),
    );
    await gesture.moveBy(const Offset(-5, 0));
    await tester.pump();
    expect(pageView.controller!.page, 1, reason: 'Small jitter remains a tap.');
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(pageView.controller!.page, greaterThan(1));
    expect(
      identical(bar, tester.widget(find.byType(HomeBottomNavigation))),
      isTrue,
      reason: 'Per-pixel fade must reuse the complete navigation subtree.',
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(pageView.controller!.page, closeTo(1, .001));
  });

  testWidgets('vertical content drag and rapid reversal keep one pager owner', (
    tester,
  ) async {
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    await tester.drag(find.byType(PageView), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(pager.page, closeTo(0, .001));
    await tester.dragFrom(const Offset(400, 300), const Offset(3, -150));
    await tester.pumpAndSettle();
    expect(pager.page, closeTo(0, .001));
    await tester.flingFrom(const Offset(600, 300), const Offset(-300, 0), 1200);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.dragFrom(const Offset(100, 300), const Offset(450, 0));
    await tester.pumpAndSettle();
    expect(pager.page, closeTo(0, .001));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 1280.0]) {
    testWidgets('three page parity, geometry and empty actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = FakeClient();
      await tester.pumpWidget(KiyoriApp(connect: () async => client));
      await tester.pumpAndSettle();
      expect(find.text('搜索网页或输入网址'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.getSize(find.byType(HomeBottomNavigation)).height, 50);
      for (var i = 0; i < 5; i++) {
        expect(tester.getSize(find.byKey(Key('nav-$i'))), const Size(44, 44));
        await tester.tapAt(tester.getCenter(find.byKey(Key('nav-$i'))));
        await tester.pumpAndSettle();
        if (i == 1) {
          expect(find.text('about:blank'), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('退出浏览器'));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('home-search-frame'))).height,
        114,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('home-search-frame'))).dy,
        closeTo((800 - 72) * .382, .01),
      );
      await tester.drag(find.byType(PageView), Offset(width * .85, 0));
      await tester.pumpAndSettle();
      expect(find.text('负一屏'), findsOneWidget);
      expect(find.text('我的数据'), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byKey(const Key('bar-opacity'))).opacity,
        0,
      );
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('负一屏'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('关闭负一屏'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('把问题和任务发给AI'));
      await tester.pumpAndSettle();
      expect(find.text('AI 对话'), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byKey(const Key('bar-opacity'))).opacity,
        0,
      );
      await tester.enterText(find.byKey(const Key('chat-draft')), '保留草稿');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('发送'));
      await tester.pumpAndSettle();
      expect(find.text('保留草稿'), findsOneWidget);
      expect(client.starts, 0);
      await tester.dragFrom(
        tester.getCenter(find.byKey(const Key('empty-conversation'))),
        Offset(width * .85, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('把问题和任务发给AI'), findsOneWidget);
      await tester.drag(find.byType(PageView), Offset(-width * .85, 0));
      await tester.pumpAndSettle();
      expect(find.text('保留草稿'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(client.closed, isTrue);
    });
  }

  testWidgets(
    'bottom inset and in-flight pager fade preserve original geometry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(HomeBottomNavigation)).height, 74);
      final gesture = await tester.startGesture(const Offset(180, 550));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      final opacity = tester
          .widget<Opacity>(find.byKey(const Key('bar-opacity')))
          .opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all five icons replay original selected animation', (
    tester,
  ) async {
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      final button = find.byKey(Key('nav-$i'));
      await tester.tapAt(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final transform = find.descendant(
        of: button,
        matching: find.byType(Transform),
      );
      expect(
        tester.widget<Transform>(transform).transform.entry(0, 0),
        closeTo(i == 4 ? .9 : 1, .01),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Transform>(transform).transform.entry(0, 0),
        closeTo(
          i == 4
              ? 1
              : i == 2
              ? 1.12
              : 1.1,
          .01,
        ),
      );
      if (i == 1) {
        await tester.tap(find.bySemanticsLabel('退出浏览器'));
        await tester.pumpAndSettle();
      }
    }
  });
}
