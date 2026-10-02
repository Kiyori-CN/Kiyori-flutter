import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/history/chat_history_page.dart';
import 'package:kiyori/features/assistant/presentation/history/chat_history_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealHistory(
  WidgetTester tester,
  Finder target, {
  bool up = false,
}) async {
  var towardTop = up;
  for (var i = 0; i < 100; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final list = find.byKey(const PageStorageKey('chat-history-management'));
    final rect = tester.getRect(list);
    if (target.evaluate().isNotEmpty) {
      towardTop = tester.getRect(target).center.dy < rect.center.dy;
    } else if (towardTop) {
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      if (tester.state<ScrollableState>(scrollable).position.pixels <= 0) {
        towardTop = false;
      }
    }
    await tester.dragFrom(
      Offset(rect.left + 5, rect.center.dy),
      Offset(0, towardTop ? 90 : -90),
    );
    await tester.pumpAndSettle();
  }
  fail(
    'Unable to reach $target; scrolls: ${tester.widgetList<Scrollable>(find.byType(Scrollable)).map((w) => '${w.axisDirection}: ${w.controller?.positions.map((p) => '${p.pixels}/${p.maxScrollExtent}')}')}',
  );
}

const snapshot = ChatHistoryPresentation(
  chats: [
    ChatHistoryItem(id: 'a', title: '第一条记录', character: '林', group: '工作'),
    ChatHistoryItem(
      id: 'b',
      title: '第二条记录',
      characterGroupId: 'g',
      group: '生活',
    ),
  ],
  characters: [HistoryIdentity('c', '林')],
  groups: [HistoryIdentity('g', '讨论组')],
  characterStats: [HistoryStatistic('已删除角色', 1, 3)],
  groupStats: [HistoryStatistic('lost', 1, 2)],
  workspaces: [HistoryWorkspace('/preview/workspace', '草稿', '内部存储')],
);

void main() {
  testWidgets('history date range, clearing and missing group assignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const ChatHistoryPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
    await revealHistory(tester, find.text('点击处理缺失角色群聊条目'));
    await tester.tap(find.text('点击处理缺失角色群聊条目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归类到角色群聊'));
    await tester.pumpAndSettle();
    expect(find.text('讨论组'), findsOneWidget);
    await tester.tap(find.text('归类'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await revealHistory(tester, find.byKey(const ValueKey('history-b')));
    await tester.tap(find.byKey(const ValueKey('history-b')));
    await tester.pumpAndSettle();
    await revealHistory(tester, find.text('为已选 1 条聊天重建记忆'));
    await tester.tap(find.text('为已选 1 条聊天重建记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部日期（点击选择范围）'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    for (final day in [1, 3]) {
      await tester.tap(
        find.byKey(ValueKey('history-date-${now.year}-${now.month}-$day')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    final month = now.month.toString().padLeft(2, '0');
    expect(
      find.text('${now.year}-$month-01 — ${now.year}-$month-03'),
      findsOneWidget,
    );
    await tester.tap(find.text('全部日期（点击选择范围）'));
    await tester.pumpAndSettle();
    expect(
      find.text('${now.year}-$month-01 — ${now.year}-$month-03'),
      findsNothing,
    );
    await tester.tap(find.text('全部日期（点击选择范围）'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换到文本输入模式'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byKey(const ValueKey('history-date-dialog')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, '2026/10/4');
    await tester.enterText(fields.last, '2026/10/2');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('结束日期不得早于开始日期'), findsOneWidget);
    await tester.enterText(fields.last, '2026/10/6');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-04 — 2026-10-06'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'history filtering, choices and empty mutations $size/$scale',
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
              home: const ChatHistoryPage(snapshot: snapshot),
            ),
          );
          await tester.pumpAndSettle();
          await revealHistory(tester, find.text('点击处理缺失角色卡条目'));
          await tester.tap(find.text('点击处理缺失角色卡条目'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('归类到角色卡'));
          await tester.pumpAndSettle();
          expect(find.text('归类到角色卡'), findsOneWidget);
          await tester.tap(find.text('归类'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.text('取消'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          await revealHistory(tester, find.byType(KiyoriSearchField));
          final search = find.descendant(
            of: find.byType(KiyoriSearchField),
            matching: find.byType(TextField),
          );
          await tester.enterText(search, '讨论组');
          await tester.pumpAndSettle();
          await revealHistory(tester, find.byKey(const ValueKey('history-b')));
          expect(find.byKey(const ValueKey('history-a')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('history-b')));
          await tester.pumpAndSettle();
          await revealHistory(tester, find.text('为已选 1 条聊天重建记忆'));
          await tester.tap(find.text('为已选 1 条聊天重建记忆'));
          await tester.pumpAndSettle();
          expect(find.text('按窗口重建聊天记忆'), findsOneWidget);
          final dates = find.text('全部日期（点击选择范围）');
          await tester.ensureVisible(dates);
          await tester.pumpAndSettle();
          await tester.tap(dates);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('history-date-dialog')),
            findsOneWidget,
          );
          expect(find.text('记忆重建日期范围'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('按窗口重建聊天记忆'), findsOneWidget);
          await tester.tap(find.text('开始重建'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.text('取消'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          await revealHistory(tester, find.text('删除选中的聊天记录 (1)'));
          await tester.tap(find.text('删除选中的聊天记录 (1)'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();
          expect(find.text('确认删除'), findsOneWidget);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.text('取消'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          await revealHistory(tester, find.byKey(const ValueKey('目标角色卡（可选）')));
          await tester.tap(find.byKey(const ValueKey('目标角色卡（可选）')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('移除角色卡绑定').last);
          await tester.pumpAndSettle();
          await revealHistory(tester, find.byKey(const ValueKey('目标角色群聊（可选）')));
          await tester.tap(find.byKey(const ValueKey('目标角色群聊（可选）')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('讨论组').last);
          await tester.pumpAndSettle();
          expect(find.text('移除角色卡绑定'), findsNothing);
          await revealHistory(tester, find.text('应用角色群聊'));
          await tester.tap(find.text('应用角色群聊'));
          await tester.pumpAndSettle();
          await revealHistory(tester, find.text('草稿'));
          await tester.tap(find.text('草稿'));
          await tester.pumpAndSettle();
          await revealHistory(tester, find.text('删除选中的工作区 (1)'));
          await tester.tap(find.text('删除选中的工作区 (1)'));
          await tester.pumpAndSettle();
          expect(find.textContaining('删除后将无法恢复所有文件和数据'), findsOneWidget);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.text('取消'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await revealHistory(tester, find.byType(KiyoriSearchField), up: true);
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: find.byType(KiyoriSearchField),
                    matching: find.byType(TextField),
                  ),
                )
                .controller!
                .text,
            '讨论组',
          );
        },
      );
    }
  }
}
