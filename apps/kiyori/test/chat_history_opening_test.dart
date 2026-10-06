import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_messages.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';
import 'support/ui_capture.dart';

CharacterDraft draft(CharacterDraft base, String opening, String name) =>
    CharacterDraft(
      name: name,
      description: base.description,
      setting: base.setting,
      opening: opening,
      chat: base.chat,
      voice: base.voice,
      custom: base.custom,
      marks: base.marks,
      tagIds: base.tagIds,
      modelConfig: base.modelConfig,
      modelName: base.modelName,
      memorySpace: base.memorySpace,
      toolsEnabled: base.toolsEnabled,
      tools: base.tools,
    );

Future<void> update(ChatFixture f, String text, String name) async {
  final card = (await f.runtime.promptCatalog()).characters.single;
  await f.runtime.saveCharacter(
    card.id,
    card.revision,
    draft(card.draft, text, name),
  );
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final dark in [false, true]) {
    testWidgets(
      'history creation and selection synchronize real opening dark=$dark',
      (tester) async {
        final f = ChatFixture();
        final boundary = GlobalKey();
        late BuildContext context;
        await tester.runAsync(() async {
          await f.open();
          await update(f, '欢迎继续这段对话。', '历史角色');
          await f.chat.create();
        });
        try {
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
                home: Builder(
                  builder: (value) {
                    context = value;
                    return Scaffold(
                      body: AnimatedBuilder(
                        animation: f.chat,
                        builder: (_, _) => Text(
                          f.chat.snapshot?.messages.firstOrNull?.content ??
                              '没有消息',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final previous = f.chat.snapshot!.conversation.id;
          showChatHistory(context, f.chat);
          await tester.pumpAndSettle();
          await tester.tap(find.text('新建对话'));
          await until(
            tester,
            () =>
                !f.chat.savingPreference &&
                f.chat.snapshot!.conversation.id != previous,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('chat-history-panel')), findsNothing);
          final opened = f.chat.snapshot!;
          final message = opened.messages.single;
          expect(message.roleName, '历史角色');
          expect(message.createdAt, greaterThan(0));
          expect(message.sentAt, isNull);
          expect(message.runId, isEmpty);
          expect(message.model, isEmpty);
          expect(f.chat.statistics!.requests, 0);
          await tester.runAsync(() async {
            await update(f, '更新后的角色开场白。', '新的角色名');
            expect(await f.chat.select(previous), isTrue);
            expect(await f.chat.select(opened.conversation.id), isTrue);
          });
          await tester.pumpAndSettle();
          final updated = f.chat.snapshot!.messages.single;
          expect(updated.id, message.id);
          expect(updated.createdAt, message.createdAt);
          expect(updated.roleName, '新的角色名');
          expect(updated.content, '更新后的角色开场白。');
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                home: Scaffold(
                  body: ChatMessageTile(
                    message: updated,
                    enabled: true,
                    roleName: updated.roleName!,
                    onAction: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('新的角色名'), findsOneWidget);
          await until(
            tester,
            () => find
                .text('更新后的角色开场白。', findRichText: true)
                .evaluate()
                .isNotEmpty,
          );
          expect(find.text('更新后的角色开场白。', findRichText: true), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'opening-${dark ? 'dark' : 'light'}',
            );
          }
          await tester.runAsync(() async {
            await update(f, ' \n\t', '新的角色名');
            expect(await f.chat.load(), isTrue);
            expect(f.chat.snapshot!.messages, isEmpty);
            expect(f.chat.statistics!.requests, 0);
          });
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(f.close);
        }
      },
    );
  }
  testWidgets(
    'opening persists across history load after first user and model reply',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await update(f, '首次开场', '发送前角色');
        await f.chat.create();
      });
      try {
        final opening = f.chat.snapshot!.messages.single;
        await tester.runAsync(() async {
          await f.chat.send('独立的用户消息');
          final before = f.chat.snapshot!;
          expect(before.messages.length, 3);
          expect(before.conversation.title, anyOf('新对话', f.titleAnswer));
          await update(f, '不应覆盖原消息', '后来角色');
          expect(await f.chat.load(), isTrue);
          expect(f.chat.snapshot!.messages, before.messages);
          expect(f.chat.snapshot!.messages.first.createdAt, opening.createdAt);
          expect(f.chat.statistics!.requests, 1);
          expect(f.requests.single['messages'][1]['content'], '首次开场');
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(f.close);
      }
    },
  );
}
