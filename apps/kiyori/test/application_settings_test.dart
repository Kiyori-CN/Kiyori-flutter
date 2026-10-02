import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/accounts/presentation/account_settings_page.dart';
import 'package:kiyori/features/accounts/presentation/bilibili_login_dialog.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_menu_page.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_settings_page.dart';
import 'package:kiyori/features/settings/presentation/data_settings_page.dart';
import 'package:kiyori/features/settings/presentation/backup_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'app_test.dart' show FakeClient;
import 'settings_detail_test.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('account dialogs preserve empty actions $size / $scale', (
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
            home: const AccountSettingsPage(),
          ),
        );
        await reveal(tester, find.text('登录 GitHub'));
        await tester.tap(find.text('登录 GitHub'));
        await tester.pumpAndSettle();
        final external = find.text('使用外部浏览器登录');
        await tester.ensureVisible(external);
        await tester.tap(external);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await reveal(tester, find.text('登录哔哩哔哩'));
        await tester.tap(find.text('登录哔哩哔哩'));
        await tester.pumpAndSettle();
        expect(find.text('登录二维码'), findsOneWidget);
        await tester.ensureVisible(find.text('Cookie 登录'));
        await tester.tap(find.text('Cookie 登录'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'test-draft');
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('验证并登录'));
        await tester.tap(find.text('验证并登录'));
        await tester.pumpAndSettle();
        expect(find.byType(BilibiliLoginDialog), findsOneWidget);
        expect(find.text('登录成功'), findsNothing);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('扫码登录'));
        await tester.tap(find.text('扫码登录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cookie 登录'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AccountSettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('appearance and data parent pages survive detail Back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('界面定制'));
    await tester.tap(find.text('界面定制'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceMenuPage), findsOneWidget);
    await tester.tap(find.text('主题与外观'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceMenuPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('数据备份'));
    await tester.tap(find.text('数据备份'));
    await tester.pumpAndSettle();
    expect(find.byType(DataSettingsPage), findsOneWidget);
    await tester.tap(find.text('数据备份与恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BackupSettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DataSettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
