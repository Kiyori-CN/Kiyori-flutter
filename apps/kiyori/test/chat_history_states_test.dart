import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
    'pointer drag gives start and move feedback and cancel restores order',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final feedback = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          feedback.add(call.arguments);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('kiyori/haptics'),
        (call) async {
          feedback.add(call.method);
          return true;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('kiyori/haptics'),
          null,
        );
      });
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        for (var i = 0; i < 4; i++) {
          await f.chat.create();
          await f.chat.change(f.chat.snapshot!.conversation, 'rename', '拖排 $i');
        }
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: f.chat,
                builder: (_, _) => ChatHistoryList(
                  owner: f.chat,
                  items: f.chat.catalog!.conversations,
                  searching: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = await tester.runAsync(f.runtime.conversationCatalog);
        final handle = find.byTooltip('拖动项目 拖排 3');
        final pointer = await tester.startGesture(tester.getCenter(handle));
        await pointer.moveBy(const Offset(0, 22));
        await tester.pump();
        expect(feedback, contains(null));
        final proxySwipe = tester.widget<HistorySwipe>(
          find.byType(HistorySwipe).last,
        );
        expect(proxySwipe.edit, isNull);
        expect(proxySwipe.delete, isNull);
        await pointer.moveBy(const Offset(0, 108));
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(feedback, contains('textHandleMove'));
        final beforeSideways = tester.getTopLeft(
          find.byKey(const Key('history-drag-proxy')),
        );
        await pointer.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const Key('history-drag-proxy'))).dx,
          beforeSideways.dx + 30,
        );
        await pointer.moveBy(const Offset(-30, 0));
        await tester.pump();
        final during = await tester.runAsync(f.runtime.conversationCatalog);
        expect(during!.conversations, original!.conversations);
        final proxyPosition = tester.getTopLeft(
          find.byKey(const Key('history-drag-proxy')),
        );
        final second = await tester.startGesture(
          tester.getCenter(handle.first),
          pointer: 2,
        );
        await second.moveBy(const Offset(0, -120));
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const Key('history-drag-proxy'))),
          proxyPosition,
        );
        await second.cancel();
        await tester.pump();
        expect(find.byKey(const Key('history-drag-proxy')), findsOneWidget);
        await pointer.cancel();
        await tester.pumpAndSettle();
        expect(find.byTooltip('拖动项目 拖排 3'), findsOneWidget);
        final cancelled = await tester.runAsync(f.runtime.conversationCatalog);
        expect(cancelled!.conversations, original.conversations);
        // 取消后新拖动仍可真实保存，不能残留拖动或忙状态。
        final next = await tester.startGesture(tester.getCenter(handle));
        await next.moveBy(const Offset(0, 22));
        await tester.pump();
        await next.moveBy(const Offset(0, 108));
        await tester.pumpAndSettle();
        await next.up();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byKey(const Key('history-drag-proxy')), findsOneWidget);
        await until(tester, () => !f.chat.changing);
        await tester.pumpAndSettle();
        final saved = await tester.runAsync(f.runtime.conversationCatalog);
        expect(saved!.conversations[2].title, '拖排 3');
        expect(
          saved.conversations[2].revision,
          original.conversations.first.revision + 1,
        );
        expect(f.chat.error, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'dragging into collapsed character or empty folder persists resolved scope',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      late String movingId;
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        movingId = f.chat.snapshot!.conversation.id;
        await f.chat.change(f.chat.snapshot!.conversation, 'rename', '移动作用域');
        await f.chat.create();
        expect(
          await f.chat.change(
            f.chat.snapshot!.conversation,
            'metadata',
            jsonEncode({'title': '未绑定目标', 'folder': '', 'character': ''}),
          ),
          isTrue,
        );
        await f.chat.setPreference('history_mode', 'character');
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: f.chat,
                builder: (_, _) => ChatHistoryList(
                  owner: f.chat,
                  items: f.chat.catalog!.conversations,
                  searching: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('未绑定'));
        await tester.pumpAndSettle();
        expect(find.text('未绑定目标'), findsNothing);
        final pointer = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 移动作用域')),
        );
        await pointer.moveBy(const Offset(0, -22));
        await tester.pump();
        final proxy = tester.getRect(
          find.byKey(const Key('history-drag-proxy')),
        );
        await pointer.moveBy(
          // 向上移到后一角色头的槽位，落在已收起的未绑定头之后。
          Offset(0, tester.getCenter(find.text('Kiyori')).dy - proxy.center.dy),
        );
        await tester.pumpAndSettle();
        await pointer.up();
        await until(tester, () => !f.chat.changing);
        await tester.pumpAndSettle();
        final moved = f.chat.catalog!.conversations.firstWhere(
          (c) => c.id == movingId,
        );
        expect(f.chat.error, isNull);
        expect(moved.characterId, '');
        expect(moved.folder, '');
        expect(f.chat.error, isNull);
        await tester.runAsync(() async {
          await f.chat.setPreference('history_mode', 'folder');
          await f.chat.setPreference('create_folder', '空落点');
        });
        await tester.pumpAndSettle();
        final folder = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 移动作用域')),
        );
        await folder.moveBy(const Offset(0, 22));
        await tester.pump();
        final folderProxy = tester.getRect(
          find.byKey(const Key('history-drag-proxy')),
        );
        await folder.moveBy(
          Offset(
            0,
            tester.getCenter(find.text('空落点')).dy - folderProxy.center.dy,
          ),
        );
        await tester.pumpAndSettle();
        await folder.up();
        await until(tester, () => !f.chat.changing);
        await tester.pumpAndSettle();
        expect(
          f.chat.catalog!.conversations
              .firstWhere((c) => c.id == movingId)
              .folder,
          '空落点',
        );
        expect(f.chat.error, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'drag edge scroll and search or directory changes revoke draft without writing',
    (tester) async {
      tester.view.physicalSize = const Size(600, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        for (var i = 0; i < 20; i++) {
          await f.chat.create();
          await f.chat.change(f.chat.snapshot!.conversation, 'rename', '滚动 $i');
        }
      });
      var searching = false;
      late StateSetter refresh;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  refresh = setState;
                  return AnimatedBuilder(
                    animation: f.chat,
                    builder: (_, _) => ChatHistoryList(
                      owner: f.chat,
                      items: f.chat.catalog!.conversations,
                      searching: searching,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = await tester.runAsync(f.runtime.conversationCatalog);
        final list = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final pointer = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 滚动 19')),
        );
        await pointer.moveBy(const Offset(0, 22));
        await tester.pump();
        await pointer.moveTo(
          Offset(
            tester.getCenter(find.byKey(const Key('history-drag-proxy'))).dx,
            475,
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(list.position.pixels, greaterThan(100));
        expect(find.byKey(const Key('history-drag-proxy')), findsOneWidget);
        final during = await tester.runAsync(f.runtime.conversationCatalog);
        expect(during!.conversations, original!.conversations);
        await pointer.cancel();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history-drag-proxy')), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(
          (await tester.runAsync(f.runtime.conversationCatalog))!.conversations,
          original.conversations,
        );
        list.position.jumpTo(0);
        await tester.pumpAndSettle();
        final pending = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 滚动 19')),
        );
        await pending.moveBy(const Offset(0, 22));
        await tester.pump();
        await pending.moveBy(const Offset(0, 108));
        await tester.pumpAndSettle();
        refresh(() => searching = true);
        await tester.pumpAndSettle();
        await pending.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history-drag-proxy')), findsNothing);
        expect(
          (await tester.runAsync(f.runtime.conversationCatalog))!.conversations,
          original.conversations,
        );
        refresh(() => searching = false);
        await tester.pumpAndSettle();
        final external = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 滚动 19')),
        );
        await external.moveBy(const Offset(0, 22));
        await tester.pump();
        await external.moveBy(const Offset(0, 108));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => f.chat.change(
            f.chat.catalog!.conversations.last,
            'rename',
            '外部变更',
          ),
        );
        final afterExternal = await tester.runAsync(
          f.runtime.conversationCatalog,
        );
        await tester.pumpAndSettle();
        await external.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history-drag-proxy')), findsNothing);
        expect(f.chat.catalog!.conversations, afterExternal!.conversations);
        expect(tester.takeException(), isNull);
        final disposing = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 滚动 19')),
        );
        await disposing.moveBy(const Offset(0, 22));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await disposing.cancel();
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'pointer drag rejects pinned position before drop without move feedback',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        for (var i = 0; i < 3; i++) {
          await f.chat.create();
          await f.chat.change(
            f.chat.snapshot!.conversation,
            'rename',
            '置顶约束 $i',
          );
        }
        await f.chat.change(f.chat.snapshot!.conversation, 'pinned', 'true');
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: f.chat,
                builder: (_, _) => ChatHistoryList(
                  owner: f.chat,
                  items: f.chat.catalog!.conversations,
                  searching: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final normalBefore = tester.getTopLeft(find.text('置顶约束 1')).dy;
        final pointer = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 置顶约束 2')),
        );
        await pointer.moveBy(const Offset(0, 22));
        await tester.pump();
        await pointer.moveBy(const Offset(0, 72));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('置顶约束 1')).dy, normalBefore);
        await pointer.up();
        await tester.pumpAndSettle();
        final saved = await tester.runAsync(f.runtime.conversationCatalog);
        expect(saved!.conversations.first.title, '置顶约束 2');
        expect(
          saved.conversations.first.revision,
          f.chat.catalog!.conversations.first.revision,
        );
        expect(f.chat.changing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'current default shares unbound list sorting and frozen group scope',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final f = ChatFixture();
      late String unbound, bound;
      await tester.runAsync(() async {
        await f.open();
        await f.chat.setPreference('create_folder', '共同分组');
        await f.chat.create();
        unbound = f.chat.snapshot!.conversation.id;
        await f.chat.change(
          f.chat.snapshot!.conversation,
          'metadata',
          jsonEncode({'title': '遗留未绑定', 'folder': '共同分组', 'character': ''}),
        );
        await f.chat.create();
        bound = f.chat.snapshot!.conversation.id;
        await f.chat.change(
          f.chat.snapshot!.conversation,
          'metadata',
          jsonEncode({'title': '默认卡对话', 'folder': '共同分组'}),
        );
        await f.chat.setPreference('history_mode', 'current');
      });
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
        showChatHistory(host, f.chat);
        await tester.pumpAndSettle();
        expect(find.text('遗留未绑定'), findsOneWidget);
        expect(find.text('默认卡对话'), findsOneWidget);
        expect(find.bySemanticsLabel('共同分组, 已展开'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('共同分组, 已展开'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('共同分组, 已收起'), findsOneWidget);
        expect(find.text('遗留未绑定'), findsNothing);
        await tester.tap(find.bySemanticsLabel('共同分组, 已收起'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('管理对话 默认卡对话'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('置底'));
        await until(tester, () => !f.chat.changing);
        await tester.pumpAndSettle();
        expect(f.chat.error, isNull);
        expect(f.chat.catalog!.conversations.map((c) => c.id), [
          unbound,
          bound,
        ]);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        showHistoryFolderEditor(
          host,
          f.chat,
          initial: '共同分组',
          binding: 'default_character',
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '已改名');
        await tester.runAsync(() async {
          await f.chat.setPreference('history_mode', 'character');
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await until(tester, () => !f.chat.savingPreference);
        await tester.pumpAndSettle();
        expect(find.text('重命名分组'), findsNothing);
        expect(
          f.chat.catalog!.conversations.every((c) => c.folder == '已改名'),
          isTrue,
        );
        expect(find.bySemanticsLabel('未绑定, 已展开'), findsOneWidget);
        await tester.runAsync(() async {
          await f.chat.setPreference('history_mode', 'current');
        });
        await tester.pumpAndSettle();
        showHistoryFolderEditor(
          host,
          f.chat,
          initial: '已改名',
          binding: 'default_character',
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '冲突不能保存');
        await tester.runAsync(() async {
          await f.chat.create();
          await f.chat.change(f.chat.snapshot!.conversation, 'folder', '已改名');
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await until(tester, () => !f.chat.savingPreference);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HistoryAlert),
            matching: find.textContaining('分组内容已变化'),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, '冲突不能保存'), findsOneWidget);
        expect(
          f.chat.catalog!.conversations.every((c) => c.folder == '已改名'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
        semantics.dispose();
      }
    },
  );
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
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
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
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
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
        // 真正从手柄拖到第三项，松手后检查业务结果，而非直接调用列表回调。
        final pointer = await tester.startGesture(
          tester.getCenter(find.byTooltip('拖动项目 会话 24')),
        );
        await pointer.moveBy(const Offset(0, 22));
        await tester.pump();
        await pointer.moveBy(const Offset(0, 108));
        await tester.pumpAndSettle();
        await pointer.up();
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
    'branch history keeps one metadata line and announces exact row states',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.send('真实分支来源');
        expect(
          await f.chat.change(f.chat.snapshot!.conversation, 'rename', '来源对话'),
          isTrue,
        );
        expect(
          await f.chat.changeMessage(
            f.chat.snapshot!.conversation,
            f.chat.snapshot!.messages.last,
            'branch',
            '',
          ),
          isTrue,
        );
        expect(
          await f.chat.change(f.chat.snapshot!.conversation, 'pinned', 'true'),
          isTrue,
        );
        expect(
          await f.chat.change(f.chat.snapshot!.conversation, 'locked', 'true'),
          isTrue,
        );
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatHistoryList(
                owner: f.chat,
                items: f.chat.catalog!.conversations,
                searching: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final branch = f.chat.snapshot!.conversation;
        final parent = f.chat.catalog!.conversations.singleWhere(
          (item) => item.id == branch.parentId,
        );
        expect(branch.parentTitle, '来源对话');
        expect(find.byIcon(Icons.account_tree), findsOneWidget);
        expect(find.text('刚刚 · 来源对话'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(ValueKey('swipe-${branch.id}'))).height,
          tester.getSize(find.byKey(ValueKey('swipe-${parent.id}'))).height,
        );
        final label = '${branch.title}, 刚刚, 未分组, 当前对话, 已置顶, 已锁定';
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasLongPressAction: true,
          ),
        );
        expect(find.byTooltip('拖动项目 ${branch.title}'), findsOneWidget);
        await tester.tap(find.byTooltip('管理对话 ${branch.title}'));
        await tester.pumpAndSettle();
        expect(find.text('管理对话'), findsOneWidget);
        expect(find.text('解锁对话'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'triggered swipe keeps action color during reset and cancel never triggers',
    (tester) async {
      var edits = 0, deletes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: HistorySwipe(
                  edit: () => edits++,
                  delete: () => deletes++,
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
      final scheme = Theme.of(tester.element(find.byType(HistorySwipe)))
          .colorScheme;
      Future<void> gesture(double direction, {bool cancel = false}) async {
        final pointer = await tester.startGesture(
          tester.getCenter(find.text('row')),
        );
        await pointer.moveBy(Offset(20 * direction, 0));
        await tester.pump();
        await pointer.moveBy(Offset(140 * direction, 0));
        await tester.pump();
        if (cancel) {
          await pointer.cancel();
        } else {
          await pointer.up();
        }
        await tester.pump();
      }

      for (final direction in [1.0, -1.0]) {
        await gesture(direction);
        await tester.pump(const Duration(milliseconds: 200));
        final translated = tester.widget<Transform>(
          find
              .descendant(
                of: find.byType(HistorySwipe),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(translated.transform.storage[12].abs(), lessThan(96));
        expect(translated.transform.storage[12].abs(), greaterThan(0));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is ColoredBox &&
                w.color == (direction > 0 ? scheme.primary : scheme.error),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFF444444),
          ),
          findsNothing,
        );
        await tester.pumpAndSettle();
      }
      expect(edits, 1);
      expect(deletes, 1);
      await gesture(1, cancel: true);
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(deletes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'swipe colors animate across thresholds and reverse continuously',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: HistorySwipe(
                  edit: () => actions++,
                  delete: () => actions++,
                  child: const SizedBox(
                    height: 52,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Text('color row'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(HistorySwipe)))
          .colorScheme;
      Color background() => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(HistorySwipe),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('color row')),
      );
      await pointer.moveBy(const Offset(20, 0));
      await tester.pump();
      await pointer.moveBy(const Offset(140, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(background(), isNot(scheme.primary));
      expect(background(), isNot(const Color(0xFF444444)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(background(), scheme.primary);
      await pointer.moveBy(const Offset(-300, 0));
      await tester.pump();
      expect(background(), isNot(scheme.error));
      await tester.pump(const Duration(milliseconds: 32));
      expect(background(), isNot(scheme.primary));
      expect(background(), isNot(scheme.error));
      await tester.pump(const Duration(milliseconds: 250));
      expect(background(), scheme.error);
      await pointer.cancel();
      await tester.pumpAndSettle();
      expect(actions, 0);
      expect(background(), Colors.transparent);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
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
        await tester.drag(
          find.text(f.chat.snapshot!.conversation.title),
          const Offset(-160, 0),
        );
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
        expect(find.text(f.chat.snapshot!.conversation.title), findsOneWidget);
        expect(
          f.chat.snapshot!.conversation.title,
          matches(r'^新对话 (?:[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$'),
        );
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
