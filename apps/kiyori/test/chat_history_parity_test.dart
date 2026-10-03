import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_management.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets(
    'empty folders remain reachable and swipe editing preserves draft',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.setPreference('create_folder', '空目录');
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showChatHistory(context, f.chat),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await until(tester, () => find.text('空目录 (0)').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('空目录 (0)'), findsOneWidget);
        await tester.runAsync(f.chat.create);
        await until(tester, () => find.text('新对话').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.drag(find.text('新对话'), const Offset(170, 0));
        await tester.pumpAndSettle();
        expect(find.text('绑定角色'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '改后标题');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, '改后标题'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'history groups persisted conversations and failed folder edits keep drafts',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.setPreference('create_folder', '学习');
        await f.chat.change(
          f.chat.snapshot!.conversation,
          'metadata',
          jsonEncode({'title': '分组中的对话', 'folder': '学习'}),
        );
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return Scaffold(
                  body: TextButton(
                    onPressed: () => showChatHistory(context, f.chat),
                    child: const Text('打开'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await until(tester, () => find.text('学习 (1)').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsOneWidget);
        await tester.tap(find.text('学习 (1)'));
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsNothing);
        await tester.tap(find.text('学习 (1)'));
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsOneWidget);
        await tester.tap(find.byTooltip('收起对话历史'));
        await tester.pumpAndSettle();
        showHistoryFolderEditor(host, f.chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '学习');
        await tester.tap(find.text('保存'));
        await until(tester, () => !f.chat.savingPreference);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, '学习'), findsOneWidget);
        expect(find.text('新建文件夹'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃修改？'), findsOneWidget);
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(find.text('新建文件夹'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
