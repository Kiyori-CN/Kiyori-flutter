import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/avatar_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/avatar_fixtures.dart';
import 'support/ui_test_helpers.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture avatar settings empty and loaded states',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      final boundary = GlobalKey();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final dark in [false, true]) {
        for (final loaded in [false, true]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                home: AvatarSettingsPage(
                  snapshot: loaded
                      ? avatarSnapshot
                      : const AvatarPresentation(),
                ),
              ),
            ),
          );
          await captureUi(
            tester,
            boundary,
            output,
            'avatar-${dark ? 'dark' : 'light'}-${loaded ? 'loaded' : 'empty'}',
          );
          expect(tester.takeException(), isNull);
          if (loaded) {
            await revealAvatar(tester, find.widgetWithText(TextButton, '展开'));
            await tester.tap(find.widgetWithText(TextButton, '展开'));
            await tester.pumpAndSettle();
            await captureUi(tester, boundary, output, 'avatar-moods-$dark');
            await revealAvatar(tester, find.text('添加自定义类型'));
            await tester.tap(find.text('添加自定义类型'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField).first, 'hello world');
            await tester.enterText(find.byType(TextField).last, '向用户问候时使用。');
            await captureUi(tester, boundary, output, 'avatar-custom-$dark');
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            await revealAvatar(
              tester,
              find.byKey(const ValueKey('avatar-pitch')),
            );
            await captureUi(tester, boundary, output, 'avatar-camera-$dark');
          }
        }
      }
    },
  );
}
