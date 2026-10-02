import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_page.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/assistant_fixtures.dart';
import 'support/ui_test_helpers.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('usage snapshot pricing modes and reset modal $size/$scale', (
        tester,
      ) async {
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
            home: const UsagePage(snapshot: usageFixture),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('¥1.25'), findsOneWidget);
        await tester.tap(find.byTooltip('重置所有计数'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重置'));
        await tester.pumpAndSettle();
        expect(find.text('重置确认'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('usage-Model A'));
        await revealUsage(tester, card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('编辑模型定价 - Model A'), findsOneWidget);
        final input = find.byKey(const ValueKey('输入价格（每百万Token） (CNY)'));
        await tester.ensureVisible(input);
        await tester.pumpAndSettle();
        await tester.enterText(input, 'NaN');
        await tester.pumpAndSettle();
        final save = find.ancestor(
          of: find.text('保存'),
          matching: find.byType(TextButton),
        );
        expect(tester.widget<TextButton>(save).onPressed, isNull);
        await tester.enterText(input, '-1');
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(save).onPressed, isNull);
        await tester.enterText(input, '2.75');
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(save).onPressed, isNotNull);
        FocusManager.instance.primaryFocus?.unfocus();
        final mode = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('按次计费'),
        );
        await tester.ensureVisible(mode);
        await tester.pumpAndSettle();
        await tester.tap(mode);
        await tester.pumpAndSettle();
        final request = find.byKey(const ValueKey('单次请求价格（CNY）'));
        await tester.ensureVisible(request);
        await tester.pumpAndSettle();
        await tester.enterText(request, '0.45');
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 120 : 240,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.text('编辑模型定价 - Model A'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await revealUsage(tester, find.byKey(const ValueKey('usage-rate')));
        await tester.enterText(find.byKey(const ValueKey('usage-rate')), '8.5');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await revealUsage(tester, find.text('保存'));
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'usage default remains empty and unknown model counts are not invented',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.dark(), home: const UsagePage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无功能模块的Token使用记录。'), findsOneWidget);
      expect(find.text('模型使用分布'), findsNothing);
      expect(find.text('¥0.00'), findsOneWidget);
      expect(usageEditablePrice(100), '100');
      expect(usageEditablePrice(0), '0');
      expect(usageEditablePrice(.125), '0.125');
    },
  );
}
