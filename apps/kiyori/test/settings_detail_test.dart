import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/browser/presentation/browser_home_page.dart';
import 'package:kiyori/features/browser/presentation/browser_settings_page.dart';
import 'package:kiyori/features/browser/presentation/browser_text_size_page.dart';
import 'package:kiyori/features/settings/presentation/settings_page.dart';
import 'package:kiyori/features/downloads/presentation/download_settings_page.dart';
import 'package:kiyori/features/files/presentation/file_settings_page.dart';
import 'package:kiyori/features/files/presentation/files_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/fake_runtime.dart' show FakeClient;

import 'support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'file settings opened from files preserve the file home and modal draft',
    (tester) async {
      await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('文件管理器设置'));
      await tester.pumpAndSettle();
      expect(find.byType(FileSettingsPage), findsOneWidget);
      await tester.tap(find.text('Android工作区'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '/storage/test');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FilesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'settings hierarchy and modal Back preserve origin $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final client = FakeClient();
          await tester.pumpWidget(KiyoriApp(connect: () async => client));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-4')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('网页浏览器'));
          await tester.tap(find.text('网页浏览器'));
          await tester.pumpAndSettle();
          expect(find.byType(BrowserSettingsPage), findsOneWidget);
          expect(
            tester
                .getSize(find.byKey(const Key('settings-detail-header')))
                .height,
            128,
          );
          await tester.drag(find.byType(ListView).first, const Offset(0, -100));
          await tester.pumpAndSettle();
          expect(
            tester
                .getSize(find.byKey(const Key('settings-detail-header')))
                .height,
            64,
          );
          await reveal(tester, find.text('网页主页'));
          await tester.tap(find.text('网页主页'));
          await tester.pumpAndSettle();
          expect(find.byType(BrowserHomePage), findsOneWidget);
          await reveal(tester, find.text('当前网址'));
          await tester.tap(find.text('当前网址'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.enterText(
            find.byType(TextField),
            'https://example.com/',
          );
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(
            find.byType(AlertDialog),
            findsOneWidget,
            reason: 'Save remains an empty business action.',
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(BrowserHomePage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(BrowserSettingsPage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          expect(find.text('网页浏览器'), findsOneWidget);
          expect(client.starts, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('text size preview is bounded and resettable without a WebView', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const BrowserTextSizePage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('增大网页文字'), 120);
    await tester.tap(find.byTooltip('增大网页文字'));
    await tester.pumpAndSettle();
    expect(find.text('105%'), findsOneWidget);
    await tester.ensureVisible(find.text('恢复默认'));
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(find.text('默认 · 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(1280, 800), 1.0),
    (const Size(640, 320), 1.0),
    (const Size(640, 320), 2.0),
  ]) {
    testWidgets(
      'download drawer expands, scrolls, dismisses and does not change settings $config',
      (tester) async {
        tester.view.physicalSize = config.$1;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: const DownloadSettingsPage(),
          ),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.text('默认下载器'));
        await tester.tap(find.text('默认下载器'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('展开 / 收起'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Android 系统下载器'),
          60,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('Android 系统下载器'), findsOneWidget);
        await tester.tap(find.text('Android 系统下载器'));
        await tester.pumpAndSettle();
        expect(find.text('Android 系统下载器'), findsNothing);
        expect(find.text('Kiyori 内置下载器'), findsOneWidget);
        await tester.tap(find.text('默认下载器'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Android 系统下载器'), findsNothing);
        expect(find.byType(DownloadSettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
