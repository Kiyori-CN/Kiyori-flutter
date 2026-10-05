import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_details.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_management.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_swipe.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_widgets.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_list.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/memory_audit_exchange.dart';

void main() {
  testWidgets(
    'legacy barrier taps dismiss idle confirmations and protect editor drafts',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold(body: Text('底层页面'));
              },
            ),
          ),
        );
        Future<void> barrier() async {
          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
        }

        showHistoryDelete(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        expect(find.text('确认删除聊天'), findsOneWidget);
        await barrier();
        expect(find.text('确认删除聊天'), findsNothing);
        expect(f.chat.catalog!.conversations, hasLength(1));
        showHistoryMetadata(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '保留的标题');
        await barrier();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.text('保留的标题'), findsOneWidget);
        await barrier();
        await tester.tap(find.text('放弃修改'));
        await tester.pumpAndSettle();
        expect(find.text('编辑标题'), findsNothing);
        showHistoryFolderEditor(host, f.chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '保留的分组');
        await barrier();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.text('保留的分组'), findsOneWidget);
        expect(find.text('底层页面'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'legacy text pages preserve UTF16 boundary and locate payload search',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      final first = List.filled(11999, '甲').join();
      final tail = '😀${List.filled(8000, '乙').join()}末页检索';
      final content = '$first$tail';
      late String id;
      await tester.runAsync(() async {
        await f.open();
        await f.chat.send('分页来源');
        id = f.chat.snapshot!.conversation.id;
        final source = f.chat.snapshot!;
        await f.runtime.changeMessage(
          id,
          source.conversation.revision,
          source.messages.first.id,
          'edit',
          content,
        );
        await f.runtime.appendConversationNote(id, content);
        await f.chat.load();
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: HistoryDetails(
                owner: f.chat,
                id: id,
                exchange: MemoryAuditExchange(),
              ),
            ),
          ),
        );
        await until(
          tester,
          () =>
              find.textContaining('条事件').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.tap(find.text('对话'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('用户'));
        await tester.pumpAndSettle();
        expect(find.text(first), findsOneWidget);
        expect(find.textContaining('第 1 / 2 页'), findsOneWidget);
        await tester.ensureVisible(find.text('下一页'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下一页'));
        await tester.pumpAndSettle();
        expect(find.text(tail), findsOneWidget);
        final page = tester.widget<Text>(find.text(tail)).data!;
        expect('$first$page', content);
        await tester.tap(find.text('时间线'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '末页检索');
        await tester.pump(const Duration(milliseconds: 450));
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('已添加审计注释'));
        await until(
          tester,
          () => find.textContaining('第 2 / 2 页').evaluate().isNotEmpty,
        );
        expect(
          find.textContaining('末页检索').evaluate().where((e) => e.widget is Text),
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'detail edit can clear content while keeping the message and audit',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.send('保留修订原文');
      });
      final source = f.chat.snapshot!;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: HistoryDetails(
                owner: f.chat,
                id: source.conversation.id,
                exchange: MemoryAuditExchange(),
              ),
            ),
          ),
        );
        await until(
          tester,
          () =>
              find.textContaining('条事件').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.tap(find.text('对话'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('用户'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('编辑消息'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '');
        await tester.pump();
        await tester.tap(find.text('保存修订'));
        await until(tester, () => find.text('编辑消息').evaluate().isEmpty);
        await tester.runAsync(() async {
          final next = await f.runtime.conversation(source.conversation.id);
          expect(next.messages.length, source.messages.length);
          expect(next.messages.first.id, source.messages.first.id);
          expect(next.messages.first.content, '');
          final exported = utf8.decode(
            await f.runtime.exportConversationAudit(
              source.conversation.id,
              'markdown',
            ),
          );
          expect(exported, contains('保留修订原文'));
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'detail tabs preserve queries loaded pages scroll and release expansion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      late String id;
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        id = f.chat.snapshot!.conversation.id;
        for (var i = 0; i < 105; i++) {
          await f.runtime.appendConversationNote(id, '正文关键词-$i');
        }
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: HistoryDetails(
                owner: f.chat,
                id: id,
                exchange: MemoryAuditExchange(),
              ),
            ),
          ),
        );
        await until(
          tester,
          () =>
              find.textContaining('条事件').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.tap(find.text('原始事件'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.enterText(find.byType(TextField), '$id/1"');
        await tester.pumpAndSettle();
        expect(find.text('已加载的事件中没有匹配结果，可继续加载更早的事件。'), findsOneWidget);
        expect(find.text('加载更早事件'), findsOneWidget);
        await tester.tap(find.text('加载更早事件'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('加载更早事件'), findsNothing);
        expect(find.text('HISTORY / BASIC_SNAPSHOT'), findsOneWidget);
        await tester.tap(find.text('HISTORY / BASIC_SNAPSHOT'));
        await tester.pumpAndSettle();
        expect(find.textContaining('"eventId":'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.textContaining('"eventId":'))
              .data!
              .contains('\n'),
          isTrue,
        );
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(
                  of: find.textContaining('"eventId":'),
                  matching: find.byType(RichText),
                ),
              )
              .didExceedMaxLines,
          isFalse,
        );
        await tester.tap(find.text('时间线'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        await tester.enterText(find.byType(TextField), '正文关键词-0');
        await tester.pump(const Duration(milliseconds: 450));
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('已添加审计注释'), findsOneWidget);
        await tester.tap(find.text('原始事件'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '$id/1"',
        );
        expect(find.textContaining('"eventId":'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.textContaining('"eventId":'))
              .data!
              .contains('\n'),
          isFalse,
        );
        expect(find.text('加载更早事件'), findsNothing);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        final list = tester.widget<ListView>(
          find.byKey(const ValueKey('history-details-list-2')),
        );
        list.controller!.jumpTo(180);
        await tester.pumpAndSettle();
        await tester.tap(find.text('对话'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.tap(find.text('原始事件'));
        await tester.pump();
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ListView>(
                find.byKey(const ValueKey('history-details-list-2')),
              )
              .controller!
              .offset,
          180,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'removed group releases rename and discard while history stays open',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        expect(
          await f.chat.setPreference(
            'history_group',
            '{"action":"create","name":"待删除","binding":"default_character"}',
          ),
          isTrue,
        );
      });
      late BuildContext host;
      try {
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
        showHistoryFolderEditor(
          host,
          f.chat,
          initial: '待删除',
          binding: 'default_character',
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '尚未保存');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        final members = {
          for (final c in f.chat.catalog!.conversations)
            if (c.folder == '待删除' && c.characterId == 'default_character')
              c.id: c.revision,
        };
        await tester.runAsync(() async {
          expect(
            await f.chat.setPreference(
              'history_group',
              jsonEncode({
                'action': 'dissolve',
                'name': '待删除',
                'binding': 'default_character',
                'members': members,
              }),
            ),
            isTrue,
          );
        });
        await tester.pumpAndSettle();
        expect(find.text('重命名分组'), findsNothing);
        expect(find.text('放弃未保存的修改？'), findsNothing);
        expect(find.byKey(const Key('chat-history-panel')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'reorder commits the actual adjusted target and quick scroll reaches final row',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.setPreference('history_mode', 'folder');
        for (var i = 0; i < 25; i++) {
          await f.chat.create();
          expect(
            await f.chat.change(
              f.chat.snapshot!.conversation,
              'rename',
              '会话 $i',
            ),
            isTrue,
          );
        }
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: f.chat,
                builder: (context, _) => ChatHistoryList(
                  owner: f.chat,
                  items: f.chat.catalog!.conversations,
                  searching: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final moving = f.chat.catalog!.conversations.first.id,
            anchor = f.chat.catalog!.conversations[2].id;
        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        // 调用真实列表最终索引契约，检查数据库结果，避免复制本地排序算法作为断言。
        list.onReorderItem!(1, 3);
        await until(tester, () => !f.chat.changing);
        expect(f.chat.error, isNull);
        expect(f.chat.catalog!.conversations[2].id, moving);
        expect(f.chat.catalog!.conversations[1].id, anchor);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('滚动到底部'));
        await tester.pumpAndSettle();
        await until(
          tester,
          () => find.text('会话 0').hitTestable().evaluate().isNotEmpty,
        );
        expect(find.text('会话 0').hitTestable(), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('滚动到顶部'));
        await tester.pumpAndSettle();
        expect(find.text('会话 24').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
        semantics.dispose();
      }
    },
  );
  test('relative history time preserves old date boundary', () {
    final now = DateTime(2026, 10, 5, 22);
    String label(Duration ago) =>
        historyTime(now.subtract(ago).millisecondsSinceEpoch, now);
    expect(label(const Duration(seconds: 59)), '刚刚');
    expect(label(const Duration(minutes: 1)), '1 分钟前');
    expect(label(const Duration(hours: 2)), '2 小时前');
    expect(label(const Duration(days: 6)), '6 天前');
    expect(label(const Duration(days: 7)), '09-28');
    expect(
      historyTime(DateTime(2025, 12, 31).millisecondsSinceEpoch, now),
      '2025-12-31',
    );
  });
  testWidgets(
    'swipe uses fixed 96 threshold and disabled direction resistance',
    (tester) async {
      var edits = 0, deletes = 0;
      Future<void> mount({bool locked = false}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: HistorySwipe(
                  edit: () => edits++,
                  delete: locked ? null : () => deletes++,
                  child: const SizedBox(
                    height: 52,
                    child: ColoredBox(color: Colors.white, child: Text('row')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await mount();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row')),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFF444444),
        ),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(edits, 0);
      await tester.drag(find.text('row'), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(edits, 1);
      await tester.drag(find.text('row'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      await mount(locked: true);
      await tester.pumpAndSettle();
      final disabled = await tester.startGesture(
        tester.getCenter(find.text('row')),
      );
      await disabled.moveBy(const Offset(-20, 0));
      await disabled.moveBy(const Offset(-200, 0));
      await tester.pump();
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(HistorySwipe),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.storage[12].abs(), lessThan(35));
      await disabled.up();
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'last deletion keeps history open with an actual selected replacement',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      final deleted = f.chat.snapshot!.conversation.id;
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
        await tester.pumpAndSettle();
        await tester.drag(find.text('新对话'), const Offset(-160, 0));
        await tester.pumpAndSettle();
        expect(find.text('确认删除聊天'), findsOneWidget);
        await tester.tap(find.text('确定删除'));
        await until(
          tester,
          () =>
              !f.chat.changing &&
              f.chat.catalog!.conversations.every((c) => c.id != deleted),
        );
        await tester.pumpAndSettle();
        expect(f.chat.catalog!.conversations.length, 1);
        expect(f.chat.snapshot!.conversation.id, f.chat.catalog!.activeId);
        expect(f.chat.snapshot!.conversation.id, isNot(deleted));
        expect(find.byKey(const Key('chat-history-panel')), findsOneWidget);
        expect(find.text('新对话'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'entity removal closes editor and its discard without removing host',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold(body: Text('底层页面'));
              },
            ),
          ),
        );
        showHistoryMetadata(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '保留草稿');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.runAsync(
          () => f.chat.change(f.chat.snapshot!.conversation, 'delete', ''),
        );
        await tester.pumpAndSettle();
        expect(find.text('编辑标题'), findsNothing);
        expect(find.text('放弃未保存的修改？'), findsNothing);
        expect(find.text('底层页面'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'settings keep compact cards and one actionable semantic switch',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      final semantics = tester.ensureSemantics();
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        showHistorySettings(host, f.chat);
        await tester.pumpAndSettle();
        expect(find.text('聊天记录设置'), findsOneWidget);
        expect(tester.widget<Text>(find.text('按角色卡分类')).style!.fontSize, 14);
        expect(
          tester.widget<Text>(find.text('角色卡-文件夹-对话三级分类')).style!.fontSize,
          12,
        );
        await tester.ensureVisible(find.text('自动切换角色卡'));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == '自动切换角色卡\n切换对话时自动匹配绑定的角色卡',
          ),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        await tester.tap(find.text('自动切换角色卡'));
        await until(tester, () => f.chat.preferences?.autoCharacter == true);
        await tester.pumpAndSettle();
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        expect(find.text('聊天记录设置'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets('details notes and signed export use real native persistence', (
    tester,
  ) async {
    final f = ChatFixture();
    await tester.runAsync(() async {
      await f.open();
      await f.chat.send('诊断消息');
      await f.runtime.conversationAudit(
        f.chat.snapshot!.conversation.id,
        0,
        '',
      );
    });
    final exchange = MemoryAuditExchange();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: HistoryDetails(
              owner: f.chat,
              id: f.chat.snapshot!.conversation.id,
              exchange: exchange,
            ),
          ),
        ),
      );
      await until(
        tester,
        () =>
            find.textContaining('条事件').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text('基础记录'), findsOneWidget);
      expect(find.text('时间线'), findsOneWidget);
      expect(find.text('原始事件'), findsOneWidget);
      await tester.tap(find.text('备注'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '稳定复现记录');
      await tester.pump();
      await tester.tap(find.text('追加注释'));
      await until(tester, () => find.text('添加诊断备注').evaluate().isEmpty);
      await until(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text('已添加审计注释'), findsOneWidget);
      await tester.ensureVisible(find.text('已添加审计注释'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已添加审计注释'));
      await until(
        tester,
        () => find.textContaining('稳定复现记录').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出'));
      await tester.pumpAndSettle();
      exchange.failNext = true;
      await tester.tap(find.text('导出完整审计包（签名 ZIP）'));
      await until(
        tester,
        () => find.textContaining('无法写入所选位置').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text('导出对话详情'), findsOneWidget);
      expect(exchange.bytes, isNull);
      await tester.tap(find.text('导出完整审计包（签名 ZIP）'));
      await until(tester, () => exchange.bytes != null);
      await until(tester, () => find.text('导出对话详情').evaluate().isEmpty);
      await until(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      expect(exchange.mime, 'application/zip');
      expect(exchange.name, endsWith('.kiyori-audit'));
      expect(exchange.bytes!.take(2), [0x50, 0x4b]);
      expect(find.text('导出对话详情'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  });
}
