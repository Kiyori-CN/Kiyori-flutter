import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/appearance/global_display_page.dart';
import 'package:kiyori/features/settings/presentation/appearance/layout_adjustment_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> show(WidgetTester tester, Finder finder) async {
  final viewport = find.byType(SingleChildScrollView).first;
  for (var i = 0; i < 100; i++) {
    final rect = tester.getRect(viewport);
    final center = tester.getCenter(finder);
    if (center.dy > rect.top + 24 &&
        center.dy < rect.bottom - 24 &&
        finder.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    final offset = center.dy > rect.bottom - 24 ? -100.0 : 100.0;
    await tester.dragFrom(
      Offset(rect.left + 12, rect.center.dy),
      Offset(0, offset),
    );
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to $finder');
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'display conditional settings and layout validation $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          Widget app(Widget page) => MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: page,
          );
          await tester.pumpWidget(
            app(const GlobalDisplayPage(rootPreferred: true)),
          );
          await tester.pumpAndSettle();
          expect(find.text('转换阈值'), findsOneWidget);
          final toggle = find.byType(Switch).at(5);
          await show(tester, toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('转换阈值'), findsNothing);
          await show(tester, find.text('手动 KernelSU'));
          await tester.tap(find.text('手动 KernelSU'));
          await tester.pumpAndSettle();
          final field = find.byType(TextField).last;
          await show(tester, field);
          await tester.enterText(field, 'draft-only');
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          await tester.pumpAndSettle();
          await show(tester, find.text('重置所有显示设置'));
          await tester.tap(find.text('重置所有显示设置'));
          expect(
            tester.widget<TextField>(field).controller!.text,
            'draft-only',
          );
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpWidget(app(const LayoutAdjustmentPage()));
          await tester.pumpAndSettle();
          final number = find.byType(TextField).at(2);
          await show(tester, number);
          await tester.enterText(number, 'NaN');
          await tester.pumpAndSettle();
          expect(find.text('无效值。请输入0.8到2.0之间的数字'), findsOneWidget);
          await tester.enterText(number, '1.5');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.text('无效值。请输入0.8到2.0之间的数字'), findsNothing);
          final reset = find.widgetWithText(TextButton, '恢复默认').at(2);
          await show(tester, reset);
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(number).controller!.text, '1');
          await show(tester, find.text('AI Markdown 预览'));
          expect(find.text('第一段预览：用来观察正文行距与字距。'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
