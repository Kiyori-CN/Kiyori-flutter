import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/context/context_summary_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealContext(
  WidgetTester tester,
  Finder target, {
  bool up = false,
}) async {
  var towardTop = up;
  for (var i = 0; i < 120; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final body = find.byKey(const PageStorageKey('context-summary'));
    final rect = tester.getRect(body);
    if (target.evaluate().isNotEmpty) {
      towardTop = tester.getRect(target).center.dy < rect.center.dy;
    }
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      Offset(0, towardTop ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'context switches, invalid fields and scoped reset $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ContextSummaryPage(),
            ),
          );
          await tester.pumpAndSettle();
          final length = find.byKey(const ValueKey('上下文长度'));
          await revealContext(tester, length);
          await tester.enterText(length, '0');
          await tester.pumpAndSettle();
          expect(find.text('请输入有效的上下文长度'), findsOneWidget);
          await tester.enterText(length, '32.5');
          await tester.pumpAndSettle();
          expect(find.text('请输入有效的上下文长度'), findsNothing);
          final summary = find.byType(Switch).first;
          await revealContext(tester, summary);
          await tester.tap(summary);
          await tester.pumpAndSettle();
          expect(
            tester.widget<Switch>(find.byType(Switch).last).onChanged,
            isNull,
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('summary-rules')))
                .enabled,
            isFalse,
          );
          await tester.tap(summary);
          await tester.pumpAndSettle();
          final threshold = find.byKey(const ValueKey('上下文使用比例阈值'));
          await revealContext(tester, threshold);
          await tester.enterText(threshold, '1');
          await tester.pumpAndSettle();
          expect(find.text('请输入0-1之间的总结触发阈值'), findsOneWidget);
          await tester.enterText(threshold, '0.75');
          await tester.pumpAndSettle();
          final rules = find.byKey(const ValueKey('summary-rules'));
          await revealContext(tester, rules);
          await tester.enterText(rules, '保留人物关系。');
          final images = find.byKey(const ValueKey('历史图片保留回合数'));
          await revealContext(tester, images);
          await tester.enterText(images, '9');
          final reset = find.text('恢复历史媒体默认值');
          await revealContext(tester, reset);
          await tester.tap(reset);
          await tester.pumpAndSettle();
          await tester.tap(find.text('恢复默认'));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(images).controller!.text, '2');
          expect(tester.widget<TextField>(length).controller!.text, '32.5');
          expect(tester.widget<TextField>(rules).controller!.text, '保留人物关系。');
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          await revealContext(tester, images, up: true);
          await tester.tap(images);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
