import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/backup_settings_page.dart';
import 'package:kiyori/features/settings/presentation/backup_dialogs.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

// 审计未加载态有原始 spinner，使用有界 pump，不能等待永不结束的动画。
Future<void> revealBackup(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) {
      final y = tester.getCenter(finder).dy;
      final height = tester.view.physicalSize.height;
      if (y > 90 && y < height - 60) return;
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('Could not reveal $finder');
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('backup empty UI and dialogs $size / $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const BackupSettingsPage(),
          ),
        );
        await revealBackup(
          tester,
          find.byKey(const ValueKey('backup-export-聊天记录')),
        );
        await tester.tap(find.byKey(const ValueKey('backup-export-聊天记录')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('已选择 0 / 0 条'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '确认'))
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        await revealBackup(tester, find.text('删除全部'));
        await tester.tap(find.text('删除全部'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('确认'));
        expect(find.text('确认删除'), findsOneWidget);
        expect(find.text('清除成功'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        await revealBackup(
          tester,
          find.byKey(const ValueKey('backup-export-记忆库')),
        );
        await tester.tap(find.byKey(const ValueKey('backup-export-记忆库')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('选择要导出的配置'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        await revealBackup(tester, find.text('每日自动备份'));
        expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
        await revealBackup(tester, find.text('文件快照备份（实验）'));
        await revealBackup(tester, find.text('立即备份').last);
        await tester.tap(find.text('立即备份').last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('导出成功'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('injected chats select all and open second format layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const BackupSettingsPage(
          snapshot: BackupPresentation(
            chats: [(id: 'one', title: '第一段对话'), (id: 'two', title: '')],
          ),
        ),
      ),
    );
    await revealBackup(
      tester,
      find.byKey(const ValueKey('backup-export-聊天记录')),
    );
    await tester.tap(find.byKey(const ValueKey('backup-export-聊天记录')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(find.text('已选择 2 / 2 条'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BackupFormatDialog), findsOneWidget);
    await tester.tap(find.text('HTML'));
    await tester.pump();
    expect(
      tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
      2,
    );
    await tester.tap(find.widgetWithText(TextButton, '导出'));
    expect(find.byType(BackupFormatDialog), findsOneWidget);
    expect(find.text('导出成功'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
