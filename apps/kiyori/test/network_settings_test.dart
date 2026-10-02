import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/network_proxy_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'settings_detail_test.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('network empty states and editors $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final navigator = GlobalKey<NavigatorState>();
        void open(NetworkProxySection section) =>
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    NetworkProxyPage(section: section, onOpen: open),
              ),
            );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: NetworkProxyPage(onOpen: open),
          ),
        );
        await reveal(tester, find.text('订阅管理'));
        await tester.tap(find.text('订阅管理'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('添加订阅地址'));
        await tester.tap(find.text('添加订阅地址'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.enterText(
          find.byType(TextField).last,
          'https://example.com/sub',
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isTrue,
        );
        await tester.tap(find.byTooltip('显示订阅地址'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        await tester.tap(find.text('导入'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('规则管理'));
        await tester.tap(find.text('规则管理'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('添加自定义规则'));
        await tester.tap(find.text('添加自定义规则'));
        await tester.pumpAndSettle();
        final dialogField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogField, 'example.com');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(PopupMenuButton<String>));
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('域名后缀 · DOMAIN-SUFFIX'));
        await tester.pumpAndSettle();
        expect(find.text('匹配该域名及其所有子域名'), findsOneWidget);
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('代理日志'));
        await tester.tap(find.text('代理日志'));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text('仅错误')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('仅错误'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
