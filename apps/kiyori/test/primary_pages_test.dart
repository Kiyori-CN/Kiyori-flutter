import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/app/shell/bottom_navigation.dart';

import 'app_test.dart' show FakeClient;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'primary navigation, empty actions, scroll and Back $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final client = FakeClient();
          await tester.pumpWidget(KiyoriApp(connect: () async => client));
          await tester.pumpAndSettle();
          for (final entry in [(2, '文档工作台'), (3, '文件类型'), (4, '我的账号')]) {
            await tester.tap(find.byKey(Key('nav-${entry.$1}')));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<HomeBottomNavigation>(
                    find.byType(HomeBottomNavigation),
                  )
                  .selected,
              entry.$1,
            );
            expect(find.text(entry.$2), findsWidgets);
            await tester.tap(find.text(entry.$2).first);
            await tester.pumpAndSettle();
            expect(find.text(entry.$2), findsWidgets);
            expect(client.starts, 0);
            expect(tester.takeException(), isNull);
            if (entry.$1 == 4) {
              // 账号入口已接入详情，返回设置列表后继续验证一级滚动。
              expect(find.text('GitHub 账号'), findsOneWidget);
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            }
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -1500),
            );
            await tester.pumpAndSettle();
            final last = switch (entry.$1) {
              2 => '幻象进程限制',
              3 => '回收站',
              _ => '更多功能',
            };
            await tester.ensureVisible(find.text(last));
            await tester.pumpAndSettle();
            expect(
              tester.getBottomLeft(find.text(last)).dy,
              lessThan(tester.getTopLeft(find.byType(HomeBottomNavigation)).dy),
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('搜索网页或输入网址'), findsOneWidget);
          }
          // 浏览器有独立工具栏，顶栏返回恢复准确入口，空点击不创建标签页。
          await tester.tap(find.byKey(const Key('nav-4')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-1')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('browser-toolbar')), findsOneWidget);
          expect(
            tester
                .widget<Opacity>(find.byKey(const Key('bar-opacity')))
                .opacity,
            0,
          );
          await tester.tap(find.text('about:blank'));
          await tester.tap(find.bySemanticsLabel('窗口，1'));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('browser-blank-page')), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('退出浏览器'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<HomeBottomNavigation>(find.byType(HomeBottomNavigation))
                .selected,
            4,
          );
          expect(client.starts, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'tool groups fold without launching tools and home draft survives visits',
    (tester) async {
      await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-draft')), '保留的本地草稿');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('文档工作台'), findsNWidgets(2));
      await tester.tap(find.text('常用工具'));
      await tester.pumpAndSettle();
      expect(find.text('文档工作台'), findsOneWidget);
      await tester.tap(find.text('常用工具'));
      await tester.pumpAndSettle();
      expect(find.text('文档工作台'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('保留的本地草稿'), findsOneWidget);
    },
  );
}
