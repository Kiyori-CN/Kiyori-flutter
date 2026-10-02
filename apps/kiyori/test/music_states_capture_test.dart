import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/music/presentation/music_settings_page.dart';
import 'package:kiyori/features/music/presentation/music_desktop_lyric_settings.dart';
import 'package:kiyori/features/music/presentation/music_settings_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/music_settings_fixtures.dart';
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
      testWidgets('music populated dialogs $size dark=$dark', (tester) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        Future<void> mount(
          MusicSettingsPresentation snapshot, {
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
                home: MusicSettingsPage(snapshot: snapshot),
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

        await mount(musicFixture);
        await revealAvatar(tester, find.byKey(const ValueKey('online')));
        await tester.tap(find.byKey(const ValueKey('online')));
        await tester.pumpAndSettle();
        await capture('source-detail');
        await tester.ensureVisible(find.text('修改链接并更新'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('修改链接并更新'));
        await tester.pumpAndSettle();
        await mount(musicFixture, keyboard: 120);
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        await capture('source-link-keyboard');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await mount(musicFixture);
        await revealAvatar(tester, find.text('清空搜索历史'));
        await tester.tap(find.text('清空搜索历史'));
        await tester.pumpAndSettle();
        await capture('history-confirm');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await revealAvatar(tester, find.text('导出 LX 列表'));
        await tester.tap(find.text('导出 LX 列表'));
        await tester.pumpAndSettle();
        await capture('backup-export');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await mount(
          const MusicSettingsPresentation(
            backup: MusicBackupPresentation(preview: musicBackupPreview),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('导入列表预览'), findsOneWidget);
        await capture('backup-preview');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        // 整页真正离屏再返回，不应把取消过的同一解析结果重新弹出。
        await tester.scrollUntilVisible(
          find.text('当前音源'),
          -350,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 120,
        );
        await tester.pumpAndSettle();
        await revealAvatar(tester, find.text('当前音源'));
        await revealAvatar(tester, find.text('导出 LX 列表'));
        expect(find.text('导入列表预览'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: MusicDesktopLyricSettings(
                    style: MusicDesktopLyricPresentation(
                      color: 0xff08e664,
                      font: '等宽',
                      bold: true,
                      size: 24,
                      align: '居右',
                      opacity: 80,
                      backgroundOpacity: 60,
                      maxLines: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('desktop-style');
      });
    }
  }
}
