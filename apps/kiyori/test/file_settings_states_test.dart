import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/files/presentation/file_settings_page.dart';
import 'package:kiyori/features/files/presentation/file_settings_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

const snapshot = FileSettingsPresentation(
  hiddenFiles: ['/storage/emulated/0/B', '/storage/emulated/0/A'],
  hiddenLocations: ['共享目录', '外部存储'],
  openDefaults: {'ext:mp3': 'SYSTEM', 'mime:application/pdf': 'DOCUMENT'},
  searchCount: 5,
  finishedTaskCount: 3,
);
void main() {
  Future<void> mount(
    WidgetTester tester,
    FileSettingsPresentation snapshot,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: FileSettingsPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String title) async {
    await reveal(tester, find.text(title));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hidden list filters sorted paths without changing facts and updates in-place',
    (tester) async {
      await mount(tester, snapshot);
      await open(tester, '手动隐藏清单');
      expect(
        tester.getTopLeft(find.text('/storage/emulated/0/A')).dy,
        lessThan(tester.getTopLeft(find.text('/storage/emulated/0/B')).dy),
      );
      await tester.enterText(find.byType(TextField), '/b');
      await tester.pump();
      expect(find.text('/storage/emulated/0/A'), findsNothing);
      await tester.tap(find.text('恢复'));
      await tester.pump();
      expect(find.text('/storage/emulated/0/B'), findsOneWidget);
      await mount(
        tester,
        const FileSettingsPresentation(hiddenFiles: ['/storage/emulated/0/A']),
      );
      expect(find.text('没有匹配项'), findsOneWidget);
      await mount(tester, const FileSettingsPresentation());
      expect(find.text('暂无记录'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'existing format selections use stored kind and release removed nested editor',
    (tester) async {
      await mount(tester, snapshot);
      await open(tester, '按格式设置默认打开方式');
      await tester.tap(find.text('.mp3'));
      await tester.pumpAndSettle();
      expect(find.text('当前默认'), findsOneWidget);
      expect(find.text('恢复此格式的推荐方式'), findsOneWidget);
      final tile = find.byKey(const ValueKey('format-choice-system'));
      expect(tester.widget<Semantics>(tile).properties.selected, isTrue);
      await mount(
        tester,
        const FileSettingsPresentation(
          openDefaults: {'mime:application/pdf': 'DOCUMENT'},
        ),
      );
      expect(find.text('默认打开方式'), findsNothing);
      expect(find.text('按格式设置打开方式'), findsOneWidget);
      await tester.tap(find.text('application/pdf'));
      await tester.pumpAndSettle();
      expect(find.text('无扩展名文件'), findsOneWidget);
      expect(find.text('application/pdf 文件'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmation updates counts errors and busy blocks back and cancel',
    (tester) async {
      await mount(tester, snapshot);
      await open(tester, '清空搜索记录');
      expect(find.text('将清空 5 条搜索记录。当前目录和实际文件不会改变。'), findsOneWidget);
      await mount(
        tester,
        const FileSettingsPresentation(searchCount: 5, confirmationBusy: true),
      );
      expect(find.text('处理中…'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull,
      );
      await mount(
        tester,
        const FileSettingsPresentation(
          searchCount: 5,
          confirmationError: '存储写入失败',
        ),
      );
      expect(find.text('存储写入失败'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('file directories and nested editors fit $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
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
              home: const FileSettingsPage(snapshot: snapshot),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              '$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
            );
          }
          expect(tester.takeException(), isNull);
        }

        await open(tester, '按格式设置默认打开方式');
        await capture('file-formats');
        await tester.ensureVisible(find.text('.mp3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('.mp3'));
        await tester.pumpAndSettle();
        await capture('file-format-choice');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        await open(tester, '手动隐藏清单');
        await tester.enterText(find.byType(TextField), '/storage');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await capture('file-hidden-keyboard');
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await open(tester, '清空已结束的任务记录');
        await capture('file-clear-confirm');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
