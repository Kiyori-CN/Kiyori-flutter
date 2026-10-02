import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/toolbox_settings_fixtures.dart';
import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart' show reveal;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('toolbox populated states $size dark=$dark', (tester) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        Future<void> mount({double keyboard = 0}) async {
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
                home: const ToolboxSettingsPage(snapshot: toolboxFixture),
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

        Future<void> back() async {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }

        Future<void> action(String label) async {
          await tester.ensureVisible(find.byTooltip('管理学习'));
          await tester.tap(find.byTooltip('管理学习'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await mount();
        await reveal(tester, find.text('清除自定义颜色'));
        await tester.tap(find.text('清除自定义颜色'));
        await tester.pumpAndSettle();
        await capture('clear-colors');
        await back();
        await reveal(tester, find.text('管理分组'));
        await tester.tap(find.text('管理分组'));
        await tester.pumpAndSettle();
        await capture('custom-groups');
        await action('重命名');
        await tester.enterText(find.byType(TextField), '学习资料');
        await mount(keyboard: 110);
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        await capture('rename-keyboard');
        await back();
        await mount();
        await action('删除分组');
        await capture('delete-group');
        await back();
        await action('整理组内顺序');
        await capture('group-order');
        await back();
        await tester.tap(find.text('批量移动工具'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'pdf');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('文档工作台').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('文档工作台').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('下一步 · 1 项'));
        await tester.pumpAndSettle();
        await capture('move-target');
        await back();
        await back();
        expect(find.byType(ToolboxSettingsPage), findsOneWidget);
      });
    }
  }
}
