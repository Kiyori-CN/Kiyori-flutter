import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/accounts/presentation/bilibili_login_dialog.dart';
import 'package:kiyori/features/accounts/presentation/github_login_dialog.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture login shells and challenge states',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      for (final dark in [false, true]) {
        for (final large in [false, true]) {
          tester.view.physicalSize = large
              ? const Size(320, 640)
              : const Size(390, 844);
          final suffix =
              '${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}';
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                    child: child!,
                  ),
                  home: Scaffold(body: child),
                ),
              ),
            );
            await tester.pump();
          }

          await mount(
            GitHubLoginDialog(
              key: ValueKey(suffix),
              snapshot: const GitHubLoginPresentation(loading: true),
            ),
          );
          await tester.ensureVisible(find.text('使用内嵌页面登录'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('使用内嵌页面登录'));
          await captureUi(
            tester,
            boundary,
            output,
            'github-loading-$suffix',
            animated: true,
          );
          await mount(
            BilibiliLoginDialog(
              key: ValueKey('qr-$suffix'),
              busy: true,
              qrCode: const BilibiliQrPresentation(),
              message: '等待扫码 · 请使用哔哩哔哩客户端扫描',
            ),
          );
          await captureUi(
            tester,
            boundary,
            output,
            'bilibili-challenge-$suffix',
            animated: true,
          );
          await tester.ensureVisible(find.text('刷新二维码'));
          await tester.pump();
          await captureUi(
            tester,
            boundary,
            output,
            'bilibili-actions-$suffix',
            animated: true,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
