import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/accounts/presentation/account_presentation.dart';
import 'package:kiyori/features/accounts/presentation/account_settings_page.dart';
import 'package:kiyori/features/accounts/presentation/bilibili_login_dialog.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/account_fixtures.dart';
import 'support/ui_test_helpers.dart';

void main() {
  Future<void> mount(WidgetTester tester, AccountPresentation snapshot) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: AccountSettingsPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('connected confirmation closes without inventing logout facts', (
    tester,
  ) async {
    await mount(tester, connectedAccounts);
    expect(find.text('@fixture-user'), findsOneWidget);
    await tester.tap(find.text('GitHub 已连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('@fixture-user'), findsOneWidget);
    await reveal(tester, find.text('移除本地账号'));
    await tester.tap(find.text('移除本地账号'));
    await tester.pumpAndSettle();
    expect(find.text('移除哔哩哔哩账号'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('测试账号'), findsOneWidget);
    await tester.tap(find.text('移除本地账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(find.text('测试账号'), findsOneWidget);
  });

  testWidgets(
    'loading busy expired and unreadable states come from snapshots',
    (tester) async {
      await mount(tester, const AccountPresentation(bilibiliLoading: true));
      await reveal(tester, find.text('登录哔哩哔哩'));
      await tester.tap(find.text('登录哔哩哔哩'));
      await tester.pumpAndSettle();
      expect(find.byType(BilibiliLoginDialog), findsNothing);
      expect(find.text('正在读取本机账号…'), findsOneWidget);
      await mount(
        tester,
        AccountPresentation(
          bilibili: connectedAccounts.bilibili,
          bilibiliBusy: true,
        ),
      );
      await reveal(tester, find.text('正在验证…'));
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '移除本地账号'),
      );
      expect(button.onPressed, isNull);
      await mount(tester, expiredAccounts);
      expect(find.text('读取中'), findsOneWidget);
      await reveal(tester, find.text('失效测试账号'));
      expect(find.text('UID 10002 · 登录已失效，请重新登录'), findsOneWidget);
      await mount(tester, const AccountPresentation(bilibiliError: '无法读取本地账号'));
      await reveal(tester, find.text('清除无法读取的本地账号'));
      await tester.tap(find.text('清除无法读取的本地账号'));
      await tester.pumpAndSettle();
      expect(find.text('移除哔哩哔哩账号'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login drafts clear between accounts and error never replaces account',
    (tester) async {
      await mount(tester, connectedAccounts);
      await reveal(tester, find.text('测试账号'));
      await tester.tap(find.text('测试账号'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号：测试账号。验证成功后切换；失败时保留原账号。'), findsOneWidget);
      await tester.tap(find.text('Cookie 登录'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'fixture-only');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, expiredAccounts);
      await reveal(tester, find.text('失效测试账号'));
      await tester.tap(find.text('失效测试账号'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cookie 登录'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy login projects progress without consuming input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.dark(),
        home: const Scaffold(
          body: BilibiliLoginDialog(
            busy: true,
            error: true,
            message: '验证失败，原账号未变更',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Cookie 登录'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '验证并登录'))
          .onPressed,
      isNull,
    );
    expect(find.text('验证失败，原账号未变更'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
