import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/chat_message_editor.dart';
import 'package:kiyori/features/assistant/presentation/chat_markdown.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/ui_capture.dart';

void main() {
  testWidgets(
    'statistics unknown usage, role selector and model popup are reachable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = ChatFixture();
      await tester.runAsync(fixture.open);
      final key = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      try {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        await tester.runAsync(() => fixture.chat.send('统计合成提问'));
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KiyoriTheme.light(),
              home: Scaffold(body: ChatPage(controller: fixture.chat)),
            ),
          ),
        );
        await until(tester, () => !fixture.chat.loading);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('对话统计'));
        await until(tester, () => find.text('对话数据统计').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('对话数据统计'), findsOneWidget);
        final stats = (await tester.runAsync(
          () => fixture.runtime.conversationStatistics(fixture.chat.draftId),
        ))!;
        expect(stats.requests, 1);
        expect(stats.reportedRequests, 0);
        expect(stats.inputTokens, isNull);
        expect(stats.firstOutputMs, isNotNull);
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-statistics');
        }
        await tester.tap(find.text('最近请求'));
        await tester.pumpAndSettle();
        expect(find.text('second-model'), findsWidgets);
        await tester.tap(find.byTooltip('关闭统计'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(fixture.chat.character!.draft.name).first);
        await until(
          tester,
          () => find
              .byKey(const Key('chat-character-panel'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('chat-character-panel'))).dy,
          60,
        );
        await tester.tap(find.byTooltip('角色排序'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('按名称排序'));
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-characters');
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('second-model'));
        await until(
          tester,
          () => find.byKey(const Key('chat-model-popup')).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('合成服务'));
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-models');
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.longPress(find.text('Response'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑消息'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatMessageEditor), findsOneWidget);
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-message-editor');
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(fixture.close);
      }
    },
  );

  testWidgets(
    'continuous stream renders before completion and latest tail survives',
    (tester) async {
      final source = ValueNotifier('**first**');
      final streaming = ValueNotifier(true);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: Listenable.merge([source, streaming]),
                builder: (_, _) => ChatMarkdown(
                  text: source.value,
                  streaming: streaming.value,
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          source.value += '\n\npart$i';
          await tester.pump(const Duration(milliseconds: 32));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(find.textContaining('part', findRichText: true), findsWidgets);
        source.value += '\n\n**final-tail**';
        streaming.value = false;
        await until(
          tester,
          () => find
              .textContaining('final-tail', findRichText: true)
              .evaluate()
              .isNotEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        source.dispose();
        streaming.dispose();
      }
    },
  );
}
