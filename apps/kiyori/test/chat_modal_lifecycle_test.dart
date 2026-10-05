import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets('removing host removes model popup and its nested explanation', (
    tester,
  ) async {
    final fixture = ChatFixture();
    await tester.runAsync(fixture.open);
    final visible = ValueNotifier(true);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: visible,
              builder: (_, show, _) => show
                  ? ChatPage(controller: fixture.chat)
                  : const Text('仍在当前页面'),
            ),
          ),
        ),
      );
      await until(tester, () => !fixture.chat.loading);
      await tester.tap(find.text('second-model'));
      await until(
        tester,
        () => find.byKey(const Key('chat-model-popup')).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('模型说明'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-info-popup')), findsOneWidget);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-info-popup')), findsNothing);
      expect(find.byKey(const Key('chat-model-popup')), findsNothing);
      expect(find.text('仍在当前页面'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      visible.dispose();
      await tester.runAsync(fixture.close);
    }
  });
  testWidgets(
    'conversation switch closes fullscreen draft and preserves host-owned history',
    (tester) async {
      final fixture = ChatFixture();
      await tester.runAsync(fixture.open);
      try {
        await tester.runAsync(fixture.chat.create);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ChatPage(controller: fixture.chat)),
          ),
        );
        await until(tester, () => !fixture.chat.loading);
        await tester.tap(find.widgetWithIcon(ShellAction, Icons.fullscreen));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('chat-fullscreen-draft')),
          '旧会话草稿',
        );
        final previous = fixture.chat.draftId;
        await tester.runAsync(fixture.chat.create);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat-fullscreen-draft')), findsNothing);
        expect(fixture.chat.drafts[previous], '旧会话草稿');
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('chat-draft')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.tap(find.widgetWithIcon(ShellAction, Icons.history));
        await until(tester, () => find.text('对话历史').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.runAsync(fixture.chat.create);
        await tester.pumpAndSettle();
        expect(find.text('对话历史'), findsOneWidget);
        expect(find.text('共 3 个对话'), findsOneWidget);
        expect(find.byType(ChatPage), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(find.text('对话历史'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      }
    },
  );
}
