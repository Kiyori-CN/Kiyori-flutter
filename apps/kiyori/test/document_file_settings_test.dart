import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/documents/presentation/document_settings_page.dart';
import 'package:kiyori/features/files/presentation/file_settings_page.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_page.dart';

import 'support/fake_runtime.dart' show FakeClient;
import 'support/ui_test_helpers.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'document defaults and nested file format dialogs $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-2')));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('工具箱设置'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('文档工作台'));
          await tester.tap(find.text('文档工作台'));
          await tester.pumpAndSettle();
          expect(find.byType(DocumentSettingsPage), findsOneWidget);
          await reveal(tester, find.text('行距'));
          await tester.tap(find.text('行距'));
          await tester.pumpAndSettle();
          expect(find.text('当前：1.65 倍'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await reveal(tester, find.text('草稿与保存'));
          await tester.tap(find.text('草稿与保存'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.textContaining('文本修改需主动保存为副本'), findsOneWidget);
          await tester.tap(find.text('知道了'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(ToolboxSettingsPage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-3')));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('文件管理器设置'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('按格式设置默认打开方式'));
          await tester.tap(find.text('按格式设置默认打开方式'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '.MP3');
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'mp3',
          );
          await tester.ensureVisible(find.text('设置此格式'));
          await tester.tap(find.text('设置此格式'));
          await tester.pumpAndSettle();
          expect(find.text('默认打开方式'), findsOneWidget);
          expect(find.text('文件.mp3'), findsOneWidget);
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(find.text('默认打开方式'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('按格式设置打开方式'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(FileSettingsPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
