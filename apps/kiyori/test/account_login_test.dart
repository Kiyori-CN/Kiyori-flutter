import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/accounts/presentation/account_settings_page.dart';
import 'package:kiyori/features/accounts/presentation/bilibili_login_dialog.dart';
import 'package:kiyori/features/accounts/presentation/github_login_dialog.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  testWidgets('embedded login closes to origin and reopen starts at chooser', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const AccountSettingsPage(),
      ),
    );
    await tester.tap(find.text('登录 GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用内嵌页面登录'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('使用内嵌页面登录'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(GitHubLoginDialog), findsNothing);
    expect(find.text('我的账号'), findsOneWidget);
    await tester.tap(find.text('登录 GitHub'));
    await tester.pumpAndSettle();
    expect(find.text('使用内嵌页面登录'), findsOneWidget);
    await tester.tap(find.text('使用内嵌页面登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(GitHubLoginDialog), findsNothing);
  });

  testWidgets('completion blocks close and back until authoritative failure', (
    tester,
  ) async {
    final state = ValueNotifier(
      const GitHubLoginPresentation(
        loading: true,
        completing: true,
        launchingExternal: true,
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ValueListenableBuilder(
                  valueListenable: state,
                  builder: (_, value, _) => GitHubLoginDialog(snapshot: value),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('使用内嵌页面登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '关闭'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '刷新'),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(GitHubLoginDialog), findsOneWidget);
    state.value = const GitHubLoginPresentation(error: '登录验证失败');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('登录验证失败'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(GitHubLoginDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QR polling permits refresh and confirmation; expiration clears image',
    (tester) async {
      // 复用已打包图片验证解码与释放，不冒充可用登录挑战。
      const image = AssetImage('assets/branding/kiyori-app-icon.png');
      final code = BilibiliQrPresentation(image: image);
      Future<void> mount(BilibiliQrPresentation? qr, {bool busy = true}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BilibiliLoginDialog(
                busy: busy,
                qrCode: qr,
                message: qr == null ? '二维码已过期，请重新获取' : '等待扫码',
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await mount(code);
      await tester.runAsync(() async {
        await precacheImage(image, tester.element(find.byType(Image)));
      });
      await tester.pump();
      expect(find.bySemanticsLabel('哔哩哔哩登录二维码'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '刷新二维码'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '打开哔哩哔哩确认'),
            )
            .onPressed,
        isNotNull,
      );
      await mount(null, busy: false);
      expect(find.byType(Image), findsNothing);
      expect(find.text('获取二维码'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '打开哔哩哔哩确认'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('二维码已过期，请重新获取'), findsOneWidget);
      await mount(code, busy: false);
      await tester.tap(find.text('Cookie 登录'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'fixture-only');
      await tester.ensureVisible(find.text('从 Kiyori 浏览器获取并登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从 Kiyori 浏览器获取并登录'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.ensureVisible(find.text('扫码登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('扫码登录'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('获取二维码'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('embedded login fits double text and keyboard $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 160),
            ),
            child: child!,
          ),
          home: const Scaffold(body: GitHubLoginDialog()),
        ),
      );
      await tester.ensureVisible(find.text('使用内嵌页面登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用内嵌页面登录'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭').hitTestable(), findsOneWidget);
      expect(find.byTooltip('刷新').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
