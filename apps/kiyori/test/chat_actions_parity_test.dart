import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/chat_message_editor.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets(
    'classic settings, regeneration versions and back from selection',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.send('第一问');
        await f.chat.send('后续问题');
        await f.chat.setPreference('input_style', 'classic');
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ChatPage(controller: f.chat)),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('设置选项'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const Key('chat-input-options'))).width,
          280,
        );
        await tester.tap(find.text('模型:'));
        await tester.pumpAndSettle();
        expect(find.textContaining('思考'), findsWidgets);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final original = f.chat.snapshot!.messages;
        await tester.longPress(find.text('Response').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('单条重新生成'));
        await until(
          tester,
          () => !f.chat.busy && f.chat.snapshot!.messages[1].variantCount == 2,
        );
        await tester.pumpAndSettle();
        expect(
          f.chat.snapshot!.messages.skip(2).toList(),
          original.skip(2).toList(),
        );
        await tester.tap(find.byTooltip('上一个回复'));
        await until(tester, () => f.chat.snapshot!.messages[1].variant == 0);
        expect(f.chat.snapshot!.messages[1].runId, original[1].runId);
        await tester.longPress(find.text('Response').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('多选'));
        await tester.tap(find.text('多选'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('已选 1'), findsNothing);
        expect(find.byKey(const Key('chat-draft')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets('reply, branch and selection delete use persisted identities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = ChatFixture();
    await tester.runAsync(() async {
      await f.open();
      await f.chat.send('源提问');
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatPage(controller: f.chat)),
        ),
      );
      await until(tester, () => !f.chat.loading);
      await tester.pumpAndSettle();
      final original = f.chat.draftId;
      await tester.longPress(find.text('Response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('回复消息'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消回复'), findsOneWidget);
      await tester.runAsync(() => f.chat.send('引用提问'));
      await tester.pumpAndSettle();
      expect(
        f.requests.last['messages'].last['content'],
        contains('<reply_to'),
      );
      expect(f.chat.replyTo, isNull);
      await tester.longPress(find.text('Response').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('创建分支'));
      await tester.tap(find.text('创建分支'));
      await until(tester, () => f.chat.draftId != original);
      await tester.pumpAndSettle();
      expect(f.chat.snapshot!.messages.length, 4);
      await tester.longPress(find.text('Response').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('多选'));
      await tester.tap(find.text('多选'));
      await tester.pumpAndSettle();
      expect(find.text('已选 1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('全选消息'));
      await tester.pumpAndSettle();
      expect(find.text('已选 4'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('删除选中消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await until(tester, () => f.chat.snapshot!.messages.isEmpty);
      await tester.pumpAndSettle();
      final source = await tester.runAsync(
        () => f.runtime.conversation(original),
      );
      expect(source!.messages.length, 4);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  });

  testWidgets('accepted resend closes editor before response finishes', (
    tester,
  ) async {
    final f = ChatFixture();
    await tester.runAsync(() async {
      await f.open();
      await f.chat.send('提问');
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatPage(controller: f.chat)),
        ),
      );
      await until(tester, () => !f.chat.loading);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑并重发'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatMessageEditor), findsOneWidget);
      f.gate = Completer<void>();
      await tester.tap(find.text('保存并重发'));
      await until(
        tester,
        () => find.byType(ChatMessageEditor).evaluate().isEmpty,
      );
      expect(f.chat.execution!.active, isTrue);
      f.gate!.complete();
      await until(tester, () => !f.chat.execution!.active);
      // 重发首轮也独立生成标题；继续泵送真实FFI事件后才进入清理的runAsync。
      await until(
        tester,
        () =>
            !f.chat.generatingTitle &&
            f.chat.snapshot!.conversation.title == f.titleAnswer,
      );
      expect(f.chat.snapshot!.conversation.title, f.titleAnswer);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  });
}
