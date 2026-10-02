import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/music/presentation/music_settings_page.dart';

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
        'music source draft, quality and desktop lyrics $size / $scale',
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
          await reveal(tester, find.text('音乐播放器'));
          await tester.tap(find.text('音乐播放器'));
          await tester.pumpAndSettle();
          expect(find.byType(MusicSettingsPage), findsOneWidget);
          await reveal(tester, find.text('在线导入'));
          await tester.tap(find.text('在线导入'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, '导入'))
                .onPressed,
            isNull,
          );
          await tester.enterText(
            find.byType(TextField),
            'https://example.invalid/source.js',
          );
          await tester.ensureVisible(find.text('显示链接'));
          await tester.tap(find.text('显示链接'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).obscureText,
            isFalse,
          );
          await tester.tap(find.text('导入'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await reveal(tester, find.text('下载音质'));
          await tester.tap(find.text('下载音质'));
          await tester.pumpAndSettle();
          expect(find.text('当前：高品质 · 320k'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await reveal(tester, find.text('文字颜色'));
          await tester.tap(find.text('文字颜色'));
          await tester.pumpAndSettle();
          expect(find.text('桌面歌词颜色'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await reveal(tester, find.text('导出 LX 列表'));
          await tester.tap(find.text('导出 LX 列表'));
          await tester.pumpAndSettle();
          expect(find.text('导出 LX 在线列表'), findsOneWidget);
          await tester.tap(find.text('选择保存位置'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
