import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/network_proxy_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/network_proxy_fixtures.dart';
import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart' show revealAvatar;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('populated proxy viewport $size dark=$dark', (tester) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        Future<void> mount(
          NetworkProxySection section, {
          double keyboard = 0,
        }) async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(dark ? 2 : 1),
                    viewInsets: EdgeInsets.only(bottom: keyboard),
                  ),
                  child: child!,
                ),
                home: NetworkProxyPage(
                  section: section,
                  snapshot: proxyFixture,
                  onOpen: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name) async {
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-$suffix');
          }
          expect(tester.takeException(), isNull);
        }

        for (final section in NetworkProxySection.values) {
          await mount(section);
          await capture(section.name);
        }
        await mount(NetworkProxySection.subscriptions);
        await revealAvatar(tester, find.byTooltip('管理 测试订阅'));
        await tester.tap(find.byTooltip('管理 测试订阅'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        await mount(NetworkProxySection.subscriptions, keyboard: 120);
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(TextField).last).height,
          greaterThan(40),
        );
        await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
        await tester.pumpAndSettle();
        await capture('subscription-editor-keyboard');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await mount(NetworkProxySection.rules);
        await revealAvatar(tester, find.text(proxySubscription.rules.first));
        await tester.tap(find.text(proxySubscription.rules.first));
        await tester.pumpAndSettle();
        await mount(NetworkProxySection.rules, keyboard: 120);
        await tester.ensureVisible(find.widgetWithText(TextButton, '保存'));
        await tester.pumpAndSettle();
        await capture('subscription-rule-keyboard');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      });
    }
  }
}
