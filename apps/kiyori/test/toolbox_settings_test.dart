import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_page.dart';

import 'support/fake_runtime.dart' show FakeClient;
import 'support/ui_test_helpers.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('toolbox nested drawers and keyboard $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('工具箱设置'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('常用工具'));
        await tester.tap(find.text('常用工具'));
        await tester.pumpAndSettle();
        expect(find.text('长按工具拖动排序，点减号移出常用。'), findsOneWidget);
        expect(find.text('完成').hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('管理分组'));
        await tester.tap(find.text('管理分组'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('新建分组'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), '内容处理');
        await tester.pumpAndSettle();
        expect(find.text('已存在同名分组'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '学习');
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('批量移动工具'));
        await tester.pumpAndSettle();
        expect(find.text('选择工具'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '文档');
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 500 ? 240 : 110,
        );
        await tester.pumpAndSettle();
        expect(find.text('下一步 · 0 项').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.text('文档工作台').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('下一步 · 1 项'));
        await tester.pumpAndSettle();
        expect(find.text('移动到分组'), findsOneWidget);
        await tester.tap(find.text('内容处理').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('移动 1 项'));
        await tester.pumpAndSettle();
        expect(find.text('移动到分组'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('管理分组').hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ToolboxSettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
