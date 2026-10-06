import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_details.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/fake_runtime.dart';
import 'support/memory_audit_exchange.dart';
import 'support/ui_capture.dart';

// 故障只注入读取边界；目录、事件和正文始终来自真实SQLite。
class _PayloadClient extends FakeClient {
  _PayloadClient(this.inner);
  final RuntimeClient inner;
  bool failNext = false;
  Completer<void>? gate;
  final pages = <int>[];
  @override
  Future<String> conversationAudit(String id, int before, String query) =>
      inner.conversationAudit(id, before, query);
  @override
  Future<ConversationSnapshot> conversation(String id) =>
      inner.conversation(id);
  @override
  Future<String> conversationAuditPayload(
    String id,
    int sequence,
    int page,
  ) async {
    pages.add(page);
    if (failNext) {
      failNext = false;
      throw StateError('synthetic payload failure');
    }
    final value = await inner.conversationAuditPayload(id, sequence, page);
    if (gate != null) await gate!.future;
    return value;
  }
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  Future<void> showDetails(
    WidgetTester tester,
    ChatController owner,
    String id, {
    GlobalKey? boundary,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
          home: Scaffold(
            body: HistoryDetails(
              owner: owner,
              id: id,
              exchange: MemoryAuditExchange(),
            ),
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
    await tester.ensureVisible(find.text('已添加审计注释'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'message and raw text preserve tap and copy selection dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        final boundary = GlobalKey();
        final name = dark ? 'phone-dark' : 'phone-light';
        final f = ChatFixture();
        await tester.runAsync(() async {
          await f.open();
          await f.chat.send('可复制消息正文');
          await f.runtime.appendConversationNote(
            f.chat.snapshot!.conversation.id,
            '可复制原始事件',
          );
        });
        void expectCopy(Finder text) {
          final selected = tester.state<SelectionAreaState>(
            find.ancestor(of: text, matching: find.byType(SelectionArea)),
          );
          expect(
            selected.selectableRegion.contextMenuButtonItems.any(
              (item) => item.type == ContextMenuButtonType.copy,
            ),
            isTrue,
          );
        }

        try {
          await showDetails(
            tester,
            f.chat,
            f.chat.snapshot!.conversation.id,
            boundary: boundary,
            dark: dark,
          );
          await tester.tap(find.text('对话'));
          await tester.pumpAndSettle();
          final message = find.text('可复制消息正文');
          await tester.longPress(message);
          await tester.pumpAndSettle();
          expectCopy(message);
          expect(find.byTooltip('编辑消息'), findsNothing);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              '$name-message-selection',
            );
          }
          // 选择工具条会覆盖左侧标题；使用未被遮挡的行尾展开图标。
          await tester.tap(
            find.descendant(
              of: find
                  .ancestor(of: find.text('用户'), matching: find.byType(Row))
                  .first,
              matching: find.byIcon(Icons.expand_more),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byTooltip('编辑消息'), findsOneWidget);
          await tester.tap(message);
          await tester.pumpAndSettle();
          expect(find.byTooltip('编辑消息'), findsNothing);
          await tester.tap(message);
          await tester.pumpAndSettle();
          expect(find.byTooltip('编辑消息'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-message-expanded');
          }
          await tester.tap(find.text('原始事件'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '已添加审计注释');
          await tester.pumpAndSettle();
          final raw = find.byWidgetPredicate(
            (widget) =>
                widget is Text && (widget.data?.contains('已添加审计注释') ?? false),
          );
          expect(raw, findsOneWidget);
          await tester.tap(raw);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(raw).maxLines, isNull);
          await tester.tap(raw);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(raw).maxLines, 3);
          await tester.longPress(raw);
          await tester.pumpAndSettle();
          expectCopy(raw);
          expect(tester.widget<Text>(raw).maxLines, 3);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-raw-selection');
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(f.close);
        }
      },
    );

    testWidgets(
      'payload failure retains the row and has a separate legacy retry dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        final boundary = GlobalKey();
        final name = dark ? 'phone-dark' : 'phone-light';
        final f = ChatFixture();
        await tester.runAsync(() async {
          await f.open();
          await f.chat.create();
          await f.runtime.appendConversationNote(
            f.chat.snapshot!.conversation.id,
            '正文重试证据',
          );
        });
        final client = _PayloadClient(f.runtime)..failNext = true;
        final owner = ChatController(() async => client, () async => f.secrets)
          ..catalog = f.chat.catalog;
        try {
          await showDetails(
            tester,
            owner,
            f.chat.snapshot!.conversation.id,
            boundary: boundary,
            dark: dark,
          );
          final summary = find.text('已添加审计注释');
          expect(
            find.ancestor(of: summary, matching: find.byType(SelectionArea)),
            findsOneWidget,
          );
          await tester.tap(summary);
          await until(
            tester,
            () => find.textContaining('读取 payload 失败').evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(
            find.text('读取 payload 失败，可再次展开重试：\nStateError'),
            findsOneWidget,
          );
          expect(find.text('重新加载详情'), findsOneWidget);
          expect(find.textContaining('[0] 正文'), findsNothing);
          expect(client.pages, [0]);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-payload-failure');
          }
          await tester.ensureVisible(find.text('重新加载详情'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重新加载详情'));
          await until(
            tester,
            () => find.textContaining('正文重试证据').evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('读取 payload 失败'), findsNothing);
          expect(find.text('重新加载详情'), findsNothing);
          expect(
            find.textContaining('[0] 正文（application/json，字节：'),
            findsOneWidget,
          );
          expect(client.pages, [0, 0]);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              '$name-payload-recovered',
            );
          }
          await tester.ensureVisible(summary);
          await tester.pumpAndSettle();
          await tester.longPress(summary);
          await tester.pumpAndSettle();
          final selected = tester.state<SelectionAreaState>(
            find.ancestor(of: summary, matching: find.byType(SelectionArea)),
          );
          expect(
            selected.selectableRegion.contextMenuButtonItems.any(
              (item) => item.type == ContextMenuButtonType.copy,
            ),
            isTrue,
          );
          expect(client.pages, [0, 0]);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          owner.dispose();
          await tester.runAsync(f.close);
        }
      },
    );
  }

  testWidgets(
    'collapsing a pending payload stops further pages and reopen reads anew',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      final boundary = GlobalKey();
      final f = ChatFixture();
      final content = '${List.filled(10000, '甲').join()}完整末尾';
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.runtime.appendConversationNote(
          f.chat.snapshot!.conversation.id,
          content,
        );
      });
      final gate = Completer<void>();
      final client = _PayloadClient(f.runtime)..gate = gate;
      final owner = ChatController(() async => client, () async => f.secrets)
        ..catalog = f.chat.catalog;
      try {
        await showDetails(
          tester,
          owner,
          f.chat.snapshot!.conversation.id,
          boundary: boundary,
        );
        await tester.tap(find.text('已添加审计注释'));
        await until(tester, () => client.pages.isNotEmpty);
        expect(find.textContaining('[0] 正文'), findsNothing);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'phone-light-payload-loading',
            animated: true,
          );
        }
        await tester.tap(find.text('已添加审计注释'));
        await tester.pumpAndSettle();
        gate.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(client.pages, [0]);
        expect(find.textContaining('完整末尾'), findsNothing);
        client.gate = null;
        await tester.tap(find.text('已添加审计注释'));
        await until(
          tester,
          () => find.textContaining('完整末尾').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(client.pages, [0, 0, 1]);
        final rendered = tester.widget<Text>(find.textContaining('完整末尾')).data!;
        expect((jsonDecode(rendered) as Map)['note'], content);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        owner.dispose();
        await tester.runAsync(f.close);
      }
    },
  );
}
