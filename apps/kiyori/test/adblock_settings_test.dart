import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/browser/presentation/adblock_settings_page.dart';

import 'app_test.dart' show FakeClient;
import 'settings_detail_test.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'adblock editor drafts, subscription expansion and Back $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-4')));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('广告拦截器'));
          await tester.tap(find.text('广告拦截器'));
          await tester.pumpAndSettle();
          for (final section in [
            AdblockSection.network,
            AdblockSection.elements,
            AdblockSection.allowlist,
          ]) {
            await reveal(tester, find.text(section.title));
            await tester.tap(find.text(section.title));
            await tester.pumpAndSettle();
            await reveal(tester, find.text('新增'));
            await tester.tap(find.text('新增'));
            await tester.pumpAndSettle();
            final fields = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            );
            for (var i = 0; i < fields.evaluate().length; i++) {
              await tester.enterText(
                fields.at(i),
                i == 0 ? 'example.com' : '.advertisement',
              );
            }
            await tester.pumpAndSettle();
            await tester.tap(find.text('保存'));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          await reveal(tester, find.text('订阅与更新'));
          await tester.tap(find.text('订阅与更新'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('My AdFilters'));
          await tester.tap(find.text('My AdFilters'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('忽略 0 行 · 尚未成功更新'));
          expect(find.text('网址阻断'), findsOneWidget);
          expect(find.text('网址例外'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
