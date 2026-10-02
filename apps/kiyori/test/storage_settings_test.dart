import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/settings/presentation/artifact_storage_page.dart';
import 'package:kiyori/features/settings/presentation/storage_paths_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'app_test.dart' show FakeClient;
import 'settings_detail_test.dart' show reveal;

void main() {
  testWidgets(
    'workspace consumes 72px while header shrinks 64px and footer stays fixed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const ArtifactStoragePage(),
        ),
      );
      final state = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      final header = find.byKey(const Key('settings-workspace-header'));
      final footerTop = tester.getTopLeft(find.text('当前保存的设置')).dy;
      expect(tester.getSize(header).height, 128);
      state.outerController.jumpTo(36);
      await tester.pump();
      expect(tester.getSize(header).height, 96);
      state.outerController.jumpTo(72);
      await tester.pump();
      expect(tester.getSize(header).height, 64);
      expect(tester.getTopLeft(find.text('当前保存的设置')).dy, footerTop);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('more and storage navigation return to exact source', (
    tester,
  ) async {
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('更多功能'));
    await tester.tap(find.text('更多功能'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('存储与路径'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Android工作区'));
    await tester.pumpAndSettle();
    expect(find.text('文件管理器'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StoragePathsPage), findsOneWidget);
    await reveal(tester, find.text('导出根目录'));
    await tester.tap(find.text('导出根目录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '/draft');
    await tester.tap(find.text('填入默认路径'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      StoragePathPresentation.exports,
    );
    await tester.tap(find.text('保存'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Android 默认产物目录'));
    await tester.tap(find.text('Android 默认产物目录'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactStoragePage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StoragePathsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'artifact drafts, validation, keyboard and discard $size / $scale',
        (tester) async {
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const ArtifactStoragePage(),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          final field = find.byType(TextField).first;
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, '/storage/emulated/0/Android/private');
          await tester.pumpAndSettle();
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          await tester.enterText(field, '/sdcard/Download/draft');
          await tester.pumpAndSettle();
          expect(
            find.textContaining('/storage/emulated/0/Download/draft/office'),
            findsOneWidget,
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(find.text('有未保存的更改'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('保存更改？'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(find.byType(ArtifactStoragePage), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.text('放弃更改'));
          await tester.pumpAndSettle();
          expect(find.text('打开'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
