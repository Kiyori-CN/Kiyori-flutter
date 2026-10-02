import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/browser/presentation/browser_settings_page.dart';
import 'package:kiyori/features/settings/presentation/settings_page.dart';
import 'package:kiyori/features/settings/presentation/backup_settings_page.dart';
import 'package:kiyori/features/settings/presentation/permissions_page.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_settings_page.dart';
import 'package:kiyori/features/speech/presentation/tts_settings_page.dart';
import 'package:kiyori/features/onboarding/presentation/onboarding_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture settings primitives in both host themes',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      for (final dark in [false, true]) {
        final pages = <String, Widget>{
          'settings': const Scaffold(body: SettingsPage()),
          'browser-settings': BrowserSettingsPage(onOpen: (_) {}),
          'tts': const TtsSettingsPage(),
          'appearance': const AppearanceSettingsPage(),
          'backup': const BackupSettingsPage(
            snapshot: BackupPresentation(auditSummary: '测试快照'),
          ),
          'permissions': const PermissionsPage(),
          'onboarding': OnboardingPage(onFinish: () {}),
        };
        for (final entry in pages.entries) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                home: KeyedSubtree(
                  key: ValueKey('${entry.key}-$dark'),
                  child: entry.value,
                ),
              ),
            ),
          );
          await captureUi(
            tester,
            boundary,
            output,
            '${entry.key}-${dark ? 'dark' : 'light'}',
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
