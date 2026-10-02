import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/music/presentation/music_backup_settings.dart';
import 'package:kiyori/features/music/presentation/music_settings_presentation.dart';
import 'package:kiyori/features/music/presentation/music_source_settings.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/music_settings_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    MusicSettingsPresentation snapshot, {
    bool backup = false,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: Scaffold(
          body: SettingsTheme(
            child: SingleChildScrollView(
              child: backup
                  ? MusicBackupSettings(snapshot: snapshot)
                  : MusicSourceSettings(snapshot: snapshot),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'source detail preserves secrecy, update drafts and entity lifetime',
    (tester) async {
      await mount(tester, musicFixture);
      await tester.tap(find.text('在线测试音源').last);
      await tester.pumpAndSettle();
      expect(find.text(onlineMusicSource.url), findsNothing);
      await tester.ensureVisible(find.text('查看导入链接'));
      await tester.tap(find.text('查看导入链接'));
      await tester.pumpAndSettle();
      expect(find.text(onlineMusicSource.url), findsOneWidget);
      await tester.ensureVisible(find.text('修改链接并更新'));
      await tester.tap(find.text('修改链接并更新'));
      await tester.pumpAndSettle();
      expect(find.text('更新音源链接'), findsOneWidget);
      final field = find.byType(TextField);
      final controller = tester.widget<TextField>(field).controller!;
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.enterText(field, 'https://example.invalid/draft');
      await mount(
        tester,
        const MusicSettingsPresentation(
          sources: MusicSourcesPresentation(
            items: [localMusicSource, onlineMusicSource],
            activeId: 'online',
          ),
        ),
      );
      expect(controller.text, 'https://example.invalid/draft');
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(
        tester,
        const MusicSettingsPresentation(
          sources: MusicSourcesPresentation(items: [localMusicSource]),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, musicFixture);
      await tester.tap(find.text('在线测试音源').last);
      await tester.pumpAndSettle();
      expect(find.text(onlineMusicSource.url), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nested removal and source selection release only their owner', (
    tester,
  ) async {
    await mount(tester, musicFixture);
    await tester.tap(find.text('本地测试音源'));
    await tester.pumpAndSettle();
    expect(find.text('从文件更新'), findsOneWidget);
    await tester.ensureVisible(find.text('移除此音源'));
    await tester.tap(find.text('移除此音源'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNWidgets(2));
    await mount(
      tester,
      const MusicSettingsPresentation(
        sources: MusicSourcesPresentation(items: [onlineMusicSource]),
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('当前音源'));
    await tester.pumpAndSettle();
    expect(find.text('切换音源'), findsOneWidget);
    await mount(tester, const MusicSettingsPresentation());
    expect(find.text('切换音源'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'working/error snapshots update an open source editor and block Back',
    (tester) async {
      await mount(tester, musicFixture);
      await tester.tap(find.text('在线导入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://example.invalid/new',
      );
      await mount(
        tester,
        const MusicSettingsPresentation(
          sources: MusicSourcesPresentation(
            working: true,
            error: '更新失败，原音源保留',
            items: [onlineMusicSource],
          ),
        ),
        settle: false,
      );
      expect(find.text('正在校验'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, musicFixture);
      expect(find.text('https://example.invalid/new'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'backup preview supports cancel, new identity, busy and empty mutation',
    (tester) async {
      const previewSnapshot = MusicSettingsPresentation(
        backup: MusicBackupPresentation(preview: musicBackupPreview),
      );
      await mount(tester, previewSnapshot, backup: true);
      expect(find.text('导入列表预览'), findsOneWidget);
      await tester.tap(find.text('合并'));
      await tester.pumpAndSettle();
      expect(find.text('导入列表预览'), findsOneWidget);
      await mount(
        tester,
        const MusicSettingsPresentation(
          backup: MusicBackupPresentation(
            preview: musicBackupPreview,
            busy: true,
            message: '导入未保存，原资料已保留',
          ),
        ),
        backup: true,
        settle: false,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '合并'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('导入列表预览'), findsOneWidget);
      await mount(tester, previewSnapshot, backup: true);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await mount(tester, previewSnapshot, backup: true);
      expect(find.text('导入列表预览'), findsNothing);
      await mount(tester, musicFixture, backup: true);
      await mount(tester, previewSnapshot, backup: true);
      expect(find.text('导入列表预览'), findsOneWidget);
      await mount(tester, musicFixture, backup: true);
      expect(find.text('导入列表预览'), findsNothing);
      await tester.ensureVisible(find.text('导出 LX 列表'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出 LX 列表'));
      await tester.pumpAndSettle();
      expect(find.textContaining('导出收藏及 2 个自建列表'), findsOneWidget);
      await tester.tap(find.text('选择保存位置'));
      await tester.pumpAndSettle();
      expect(find.text('导出 LX 在线列表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
