import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/accounts/presentation/account_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/account_fixtures.dart';
import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture account states and modal returns',
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
                home: AccountSettingsPage(
                  key: ValueKey(suffix),
                  snapshot: large ? expiredAccounts : connectedAccounts,
                ),
              ),
            ),
          );
          await captureUi(tester, boundary, output, 'account-$suffix');
          await reveal(tester, find.text('移除本地账号'));
          await tester.tap(find.text('移除本地账号'));
          await captureUi(tester, boundary, output, 'account-remove-$suffix');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
