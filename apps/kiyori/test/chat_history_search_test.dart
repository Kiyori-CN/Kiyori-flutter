import 'dart:async';

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

// 仅在读取边界延迟/失败；事件、扫描游标、Unicode匹配和摘录来自真实SQLite。
class _SearchClient extends FakeClient {
  _SearchClient(this.inner);
  final RuntimeClient inner;
  final calls = <(int, String)>[];
  bool failSecond = false;
  Completer<void>? gate;
  @override
  Future<ConversationSnapshot> conversation(String id) =>
      inner.conversation(id);
  @override
  Future<String> conversationAuditPayload(String id, int sequence, int page) =>
      inner.conversationAuditPayload(id, sequence, page);
  @override
  Future<String> conversationAudit(String id, int before, String query) async {
    calls.add((before, query));
    if (failSecond && before == 106 && query == 'needle') {
      failSecond = false;
      throw StateError('synthetic search failure');
    }
    final value = await inner.conversationAudit(id, before, query);
    if (query == 'needle' && before == 0 && gate != null) await gate!.future;
    return value;
  }
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  Future<void> seed(ChatFixture f, {bool dense = false}) async {
    await f.open();
    await f.chat.create();
    final id = f.chat.snapshot!.conversation.id;
    await f.runtime.conversationAudit(id, 0, '');
    await f.runtime.appendConversationNote(
      id,
      '${'甲' * 80}needle Café ΟΣ ı ß %_${'乙' * 300}',
    );
    for (var i = 0; i < 203; i++) {
      await f.runtime.appendConversationNote(
        id,
        dense
            ? 'needle-$i'
            : i == 202
            ? 'needle recent'
            : 'irrelevant-$i',
      );
    }
  }

  Future<void> show(
    WidgetTester tester,
    ChatController owner,
    String id,
    GlobalKey boundary,
    bool dark,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (output.isNotEmpty) await loadCaptureFonts(tester);
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
          find.textContaining('205 条事件').evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dense search stops at the legacy batch threshold and tab return does not continue',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() => seed(f, dense: true));
      final client = _SearchClient(f.runtime);
      final owner = ChatController(() async => client, () async => f.secrets)
        ..catalog = f.chat.catalog;
      final boundary = GlobalKey();
      try {
        await show(
          tester,
          owner,
          f.chat.snapshot!.conversation.id,
          boundary,
          false,
        );
        await tester.enterText(find.byType(TextField), 'needle');
        await until(
          tester,
          () =>
              find.text('匹配 100 / 100').evaluate().isNotEmpty &&
              find.text('继续搜索').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(client.calls.where((call) => call.$2 == 'needle').length, 1);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'phone-light-search-continue',
          );
        }
        await tester.tap(find.text('对话'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('时间线'));
        await tester.pumpAndSettle();
        expect(client.calls.where((call) => call.$2 == 'needle').length, 1);
        await tester.tap(find.text('继续搜索'));
        await until(
          tester,
          () => find.text('匹配 200 / 200').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('继续搜索'));
        await until(
          tester,
          () => find.text('匹配 204 / 205').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('继续搜索'), findsNothing);
        expect(
          client.calls
              .where((call) => call.$2 == 'needle')
              .map((call) => call.$1),
          [0, 106, 6],
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        owner.dispose();
        await tester.runAsync(f.close);
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'bounded search retains sparse hits after failure and retries from scanned cursor dark=$dark',
      (tester) async {
        final f = ChatFixture();
        await tester.runAsync(() => seed(f));
        final client = _SearchClient(f.runtime)..failSecond = true;
        final owner = ChatController(() async => client, () async => f.secrets)
          ..catalog = f.chat.catalog;
        final boundary = GlobalKey();
        final name = dark ? 'phone-dark' : 'phone-light';
        try {
          await show(
            tester,
            owner,
            f.chat.snapshot!.conversation.id,
            boundary,
            dark,
          );
          await tester.enterText(find.byType(TextField), 'needle');
          await tester.pump(const Duration(milliseconds: 349));
          expect(client.calls.where((call) => call.$2 == 'needle'), isEmpty);
          await tester.pump(const Duration(milliseconds: 1));
          await until(tester, () => find.text('重新加载详情').evaluate().isNotEmpty);
          await tester.pumpAndSettle();
          expect(find.text('匹配 1 / 100'), findsOneWidget);
          expect(find.textContaining('needle recent'), findsOneWidget);
          expect(
            client.calls
                .where((call) => call.$2 == 'needle')
                .map((call) => call.$1),
            [0, 106],
          );
          await tester.tap(find.text('原始事件'));
          await tester.pumpAndSettle();
          expect(find.text('重新加载详情'), findsNothing);
          expect(find.textContaining('搜索未完成'), findsNothing);
          await tester.tap(find.text('时间线'));
          await tester.pumpAndSettle();
          expect(find.text('匹配 1 / 100'), findsOneWidget);
          expect(find.text('重新加载详情'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-search-failure');
          }
          await tester.tap(find.text('重新加载详情'));
          await until(
            tester,
            () => find.text('匹配 2 / 205').evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(
            client.calls
                .where((call) => call.$2 == 'needle')
                .map((call) => call.$1),
            [0, 106, 106, 6],
          );
          expect(find.text('继续搜索'), findsNothing);
          expect(find.textContaining('…'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-search-recovered');
          }
          await tester.enterText(find.byType(TextField), 'CAFÉ ος I');
          await until(
            tester,
            () => find.text('匹配 1 / 205').evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Café'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-search-unicode');
          }
          await tester.tap(find.textContaining('Café'));
          await until(
            tester,
            () => find.textContaining('[0] 正文').evaluate().isNotEmpty,
          );
          expect(find.textContaining('eventSha256='), findsOneWidget);
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
    'query and tab changes invalidate late search pages before scanning again',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() => seed(f));
      final gate = Completer<void>();
      final client = _SearchClient(f.runtime)..gate = gate;
      final owner = ChatController(() async => client, () async => f.secrets)
        ..catalog = f.chat.catalog;
      try {
        await show(
          tester,
          owner,
          f.chat.snapshot!.conversation.id,
          GlobalKey(),
          false,
        );
        await tester.enterText(find.byType(TextField), 'needle');
        await until(
          tester,
          () => client.calls.any((call) => call.$2 == 'needle'),
        );
        await tester.enterText(find.byType(TextField), 'CAFÉ ος I');
        await until(
          tester,
          () => find.text('匹配 1 / 205').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('原始事件'));
        await tester.pumpAndSettle();
        gate.complete();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(
          client.calls
              .where((call) => call.$2 == 'needle')
              .map((call) => call.$1),
          [0],
        );
        expect(find.textContaining('Café'), findsNothing);
        await tester.tap(find.text('时间线'));
        await tester.pumpAndSettle();
        expect(find.text('匹配 1 / 205'), findsOneWidget);
        expect(find.textContaining('Café'), findsOneWidget);
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
