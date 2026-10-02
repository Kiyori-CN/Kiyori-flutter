import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/backup_dialogs.dart';
import 'package:kiyori/features/settings/presentation/backup_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

const chats = [(id: 'one', title: '第一段对话'), (id: 'two', title: '第二段对话')];
const profiles = [
  (id: 'default', title: '默认配置'),
  (id: 'second', title: '其他配置'),
];
const file = BackupFile(
  id: 'file',
  fileName: 'room_db_manual_backup_20261003_010000.zip',
  restoreLabel: '2026-10-03（手动 01:00:00）',
);
const populated = BackupPresentation(
  chats: chats,
  profiles: profiles,
  auditSummary: '共 2 个对话，4 条审计记录',
  chatOperation: BackupOperation(
    phase: BackupPhase.exporting,
    progress: .42,
    processedCharacters: 4200,
    totalCharacters: 10000,
  ),
  characterOperation: BackupOperation(
    phase: BackupPhase.failed,
    message: '无法读取备份文件',
  ),
  memoryOperation: BackupOperation(
    phase: BackupPhase.imported,
    message: '已导入到默认配置',
  ),
  modelOperation: BackupOperation(
    phase: BackupPhase.exported,
    message: '模型配置已导出',
  ),
  recentBackups: [file],
  dailyBackup: true,
  savingDailyBackup: true,
  dailyBackupError: '无法保存自动备份设置',
  lastBackup: '2026-10-03 01:00',
  lastError: '目标目录不可写',
  rawOperation: BackupOperation(
    phase: BackupPhase.importing,
    message: '正在解压... 42%',
  ),
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  Future<void> mount(WidgetTester tester, BackupPresentation snapshot) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: BackupSettingsPage(snapshot: snapshot),
      ),
    );
    await settle(tester);
  }

  Future<void> export(WidgetTester tester) async {
    final target = find.byKey(const ValueKey('backup-export-聊天记录'));
    await revealBackup(tester, target);
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets(
    'chat selection follows catalog through format layer and never revives removed IDs',
    (tester) async {
      await mount(
        tester,
        const BackupPresentation(chats: chats, auditSummary: '已读取'),
      );
      await export(tester);
      await tester.tap(find.text('全选'));
      await tester.pump();
      await mount(
        tester,
        BackupPresentation(chats: [chats[1]], auditSummary: '已读取'),
      );
      expect(find.text('已选择 1 / 1 条'), findsOneWidget);
      await mount(
        tester,
        const BackupPresentation(chats: chats, auditSummary: '已读取'),
      );
      expect(find.text('已选择 1 / 2 条'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await settle(tester);
      expect(
        tester
            .widget<BackupFormatDialog>(find.byType(BackupFormatDialog))
            .selectedChatIds,
        {'two'},
      );
      await mount(
        tester,
        BackupPresentation(chats: [chats[0]], auditSummary: '已读取'),
      );
      expect(find.byType(BackupFormatDialog), findsNothing);
      await mount(
        tester,
        const BackupPresentation(chats: chats, auditSummary: '已读取'),
      );
      expect(find.byType(BackupFormatDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'memory import owns selected profile until strategy or entity removal',
    (tester) async {
      const prompt = BackupPrompt(
        id: 'import-1',
        kind: BackupPromptKind.memoryImport,
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(find.text('选择要导入到的配置'), findsOneWidget);
      await tester.tap(find.text('其他配置'));
      await tester.pump();
      await mount(
        tester,
        BackupPresentation(
          profiles: [profiles[1], profiles[0]],
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'second',
      );
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await settle(tester);
      expect(find.text('选择导入策略'), findsOneWidget);
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        0,
      );
      await tester.tap(find.text('更新'));
      await tester.pump();
      await mount(
        tester,
        BackupPresentation(
          profiles: [profiles[0]],
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(find.text('选择导入策略'), findsNothing);
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile removal clears selection and reinsert does not select it',
    (tester) async {
      const prompt = BackupPrompt(
        id: 'import-2',
        kind: BackupPromptKind.memoryImport,
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: [],
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '确认'))
            .onPressed,
        isNull,
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '确认'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'prompt replacement closes old modal and host removal releases owned routes',
    (tester) async {
      await mount(
        tester,
        const BackupPresentation(
          prompt: BackupPrompt(id: 'one', kind: BackupPromptKind.chatImport),
          auditSummary: '已读取',
        ),
      );
      expect(find.text('选择导入格式'), findsOneWidget);
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        1,
      );
      await mount(
        tester,
        const BackupPresentation(
          prompt: BackupPrompt(id: 'two', kind: BackupPromptKind.rawRestart),
          auditSummary: '已读取',
        ),
      );
      expect(find.text('选择导入格式'), findsNothing);
      expect(find.text('需要重启应用'), findsOneWidget);
      await tester.tap(find.text('立即重启'));
      await settle(tester);
      expect(find.text('需要重启应用'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: Text('其他页面')),
        ),
      );
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('其他页面'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recent backup removal invalidates confirmation and never performs restore',
    (tester) async {
      await mount(
        tester,
        const BackupPresentation(recentBackups: [file], auditSummary: '已读取'),
      );
      final target = find.byKey(const ValueKey('backup-restore-file'));
      await revealBackup(tester, target);
      await tester.tap(target);
      await settle(tester);
      await tester.tap(find.text('确认恢复'));
      expect(find.text('确认恢复数据库'), findsOneWidget);
      expect(find.text('需要重启应用'), findsNothing);
      await mount(tester, const BackupPresentation(auditSummary: '已读取'));
      expect(find.text('确认恢复数据库'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden progress stops requesting frames and active profile changes reset selection',
    (tester) async {
      await mount(
        tester,
        const BackupPresentation(
          auditSummary: '已读取',
          rawOperation: BackupOperation(phase: BackupPhase.importing),
        ),
      );
      await revealBackup(tester, find.text('正在恢复文件快照备份...'));
      expect(tester.binding.hasScheduledFrame, isTrue);
      for (
        var i = 0;
        i < 80 && find.text('数据概览').hitTestable().evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 240));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('数据概览').hitTestable(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      const prompt = BackupPrompt(
        id: 'active',
        kind: BackupPromptKind.memoryImport,
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      await mount(
        tester,
        const BackupPresentation(
          profiles: profiles,
          activeProfileId: 'second',
          prompt: prompt,
          auditSummary: '已读取',
        ),
      );
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'second',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'operation progress clamps finite values and renders failures independently',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const BackupOperationView(
                  BackupOperation(phase: BackupPhase.exporting, progress: 2),
                  subject: '聊天记录',
                ),
                const BackupOperationView(
                  BackupOperation(
                    phase: BackupPhase.exporting,
                    progress: double.nan,
                  ),
                  subject: '聊天记录',
                ),
                const BackupOperationView(
                  BackupOperation(phase: BackupPhase.failed, message: '失败详情'),
                  subject: '数据库',
                  database: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .map((p) => p.value),
        [1, 0],
      );
      expect(find.text('操作失败'), findsOneWidget);
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
      testWidgets('backup populated states and modal flow $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        Future<void> show(BackupPresentation snapshot) async {
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
                home: BackupSettingsPage(snapshot: snapshot),
              ),
            ),
          );
          await settle(tester);
        }

        Future<void> capture(String name) async {
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              '$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
              animated: true,
            );
          }
          expect(tester.takeException(), isNull);
        }

        await show(populated);
        await revealBackup(tester, find.text('正在导出：42%（4200 / 10000 字符）'));
        await capture('chat-progress');
        await revealBackup(tester, find.text('无法读取备份文件'));
        await capture('backup-error');
        await revealBackup(tester, find.text('每日自动备份'));
        expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
        await revealBackup(
          tester,
          find.byKey(const ValueKey('backup-restore-file')),
        );
        await capture('recent-database');
        await tester.tap(find.byKey(const ValueKey('backup-restore-file')));
        await settle(tester);
        await capture('restore-confirm');
        await tester.binding.handlePopRoute();
        await settle(tester);
        await revealBackup(tester, find.text('正在解压... 42%'));
        await capture('raw-progress');
        for (final kind in BackupPromptKind.values) {
          await show(
            BackupPresentation(
              profiles: profiles,
              auditSummary: '已读取',
              prompt: BackupPrompt(
                id: kind.name,
                kind: kind,
                fileName: 'backup_20261003.zip',
              ),
            ),
          );
          await capture('prompt-${kind.name}');
          if (kind == BackupPromptKind.memoryImport) {
            await tester.tap(find.widgetWithText(TextButton, '确认'));
            await settle(tester);
            await capture('memory-strategy');
          }
          await tester.binding.handlePopRoute();
          await settle(tester);
        }
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
