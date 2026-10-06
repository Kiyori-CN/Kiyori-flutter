import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_management.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets(
    'history keeps Unicode title and folder matches after body search',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.change(
          f.chat.snapshot!.conversation,
          'rename',
          'ÉCOLE 标题',
        );
        await f.chat.create();
        await f.chat.setPreference('create_folder', 'ÉCOLE');
        await f.chat.change(
          f.chat.snapshot!.conversation,
          'metadata',
          jsonEncode({'title': '目录会话', 'folder': 'ÉCOLE'}),
        );
        await f.chat.create();
        await f.chat.send('正文中的 éco 关键字');
        await f.chat.change(f.chat.snapshot!.conversation, 'rename', '正文会话');
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        showChatHistory(host, f.chat);
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('chat-history-search'));
        await tester.enterText(field, 'éco');
        await tester.pump(const Duration(milliseconds: 399));
        expect(find.text('ÉCOLE 标题'), findsOneWidget);
        expect(find.text('目录会话'), findsOneWidget);
        expect(find.text('正文会话'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('ÉCOLE 标题'), findsOneWidget);
        expect(find.text('目录会话'), findsOneWidget);
        expect(find.text('正文会话'), findsOneWidget);
        expect(find.text('匹配 3 / 共 3'), findsOneWidget);
        // 重读等值目录只刷新宿主状态，不重新隐藏正文命中或进入防抖。
        await tester.runAsync(f.chat.load);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('正文会话'), findsOneWidget);
        // 目录值确实变化时仍按旧源重新搜索，并即时更新标题匹配。
        await tester.runAsync(() async {
          final item = f.chat.catalog!.conversations.firstWhere(
            (c) => c.title == 'ÉCOLE 标题',
          );
          await f.chat.change(item, 'rename', '已改名');
        });
        await tester.pump(const Duration(milliseconds: 400));
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('已改名'), findsNothing);
        expect(find.text('匹配 2 / 共 3'), findsOneWidget);
        await tester.runAsync(() async {
          final item = f.chat.catalog!.conversations.firstWhere(
            (c) => c.title == '已改名',
          );
          await f.chat.change(item, 'rename', 'ΟΣ İI ß');
        });
        for (final text in ['ος', 'ıi']) {
          await tester.enterText(field, text);
          await tester.pump(const Duration(milliseconds: 400));
          await until(
            tester,
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
          );
          expect(find.text('ΟΣ İI ß'), findsOneWidget);
        }
        // 旧比较为单字符大小写映射，不能把ß扩展为两个S。
        await tester.enterText(field, 'SS');
        await tester.pump(const Duration(milliseconds: 400));
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('ΟΣ İI ß'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'history debounce survives unrelated notifications and single emoji searches body',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.send('正文独立样本 🧭');
        await f.chat.change(f.chat.snapshot!.conversation, 'rename', '正文会话');
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        showChatHistory(host, f.chat);
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('chat-history-search'));
        await tester.enterText(field, '正文独立样本');
        for (var i = 0; i < 6; i++) {
          f.chat.dismissError();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.text('正文会话'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.enterText(field, '🧭');
        await tester.pump(const Duration(milliseconds: 400));
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('正文会话'), findsOneWidget);
        // 改词及清空取消上一代搜索，迟到结果不能覆盖完整目录。
        await tester.enterText(field, '不存在');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byTooltip('清空搜索'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.text('共 1 个对话'), findsOneWidget);
        expect(find.text('正文会话'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

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
        await until(tester, () => find.text('空目录').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('空目录'), findsOneWidget);
        await tester.runAsync(f.chat.create);
        final title = f.chat.snapshot!.conversation.title;
        expect(
          title,
          matches(r'^新对话 (?:[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$'),
        );
        await until(tester, () => find.text(title).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.drag(find.text(title), const Offset(170, 0));
        await tester.pumpAndSettle();
        expect(find.text('绑定角色卡'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '改后标题');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
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
        await until(tester, () => find.text('学习').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsOneWidget);
        await tester.tap(find.text('学习'));
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsNothing);
        await tester.tap(find.text('学习'));
        await tester.pumpAndSettle();
        expect(find.text('分组中的对话'), findsOneWidget);
        await tester.tap(find.byTooltip('收起对话历史'));
        await tester.pumpAndSettle();
        showHistoryFolderEditor(host, f.chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '学习');
        await tester.tap(find.text('创建'));
        await until(tester, () => !f.chat.savingPreference);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, '学习'), findsOneWidget);
        expect(find.text('新建分组'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('放弃修改'));
        await tester.pumpAndSettle();
        expect(find.text('新建分组'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
