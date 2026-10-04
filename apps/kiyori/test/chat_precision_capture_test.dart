import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/ui_capture.dart';

void main() {
  testWidgets('chat host panels respect toolbar and all viewport boundaries', (
    tester,
  ) async {
    const output = String.fromEnvironment('KIYORI_CAPTURE');
    final fixture = ChatFixture();
    await tester.runAsync(fixture.open);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    try {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      await tester.runAsync(
        () => fixture.chat.send('完整保留用户输入：\n**这是纯文本**\n第二行提问。'),
      );
      for (final entry in [
        ('light', const Size(390, 844), false, 1.0, 0.0),
        ('dark', const Size(390, 844), true, 1.0, 0.0),
        ('large-keyboard', const Size(320, 844), false, 2.0, 220.0),
        ('landscape', const Size(844, 390), false, 1.0, 0.0),
        ('desktop', const Size(1280, 800), false, 1.0, 0.0),
      ]) {
        tester.view.physicalSize = entry.$2;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: entry.$3 ? KiyoriTheme.dark() : KiyoriTheme.light(),
              scrollBehavior: const KiyoriScrollBehavior(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(entry.$4),
                  viewInsets: EdgeInsets.only(bottom: entry.$5),
                ),
                child: child!,
              ),
              home: Scaffold(body: ChatPage(controller: fixture.chat)),
            ),
          ),
        );
        await until(tester, () => !fixture.chat.loading);
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${entry.$1} $name');
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '${entry.$1}-$name');
          }
        }

        Future<void> close() async {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }

        await capture('messages-input');
        await tester.tap(find.bySemanticsLabel('显示历史'));
        await until(
          tester,
          () =>
              find.byKey(const Key('chat-history-panel')).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('chat-history-panel'))).dy,
          88.5,
        );
        await capture('history');
        await close();
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
          148.5,
        );
        await capture('characters');
        await close();
        await tester.tap(find.bySemanticsLabel('设置选项'));
        await capture('options');
        await tester.tap(find.byTooltip('记忆说明'));
        await capture('info');
        expect(find.byKey(const Key('chat-info-popup')), findsOneWidget);
        await close();
        await close();
        for (final group in ['记忆:', '工具', '行为']) {
          await tester.tap(find.bySemanticsLabel('设置选项'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(group));
          await capture(
            'options-${group == '记忆:'
                ? 'memory'
                : group == '工具'
                ? 'tools'
                : 'behavior'}',
          );
          await close();
        }
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await capture('attachments');
        await close();
        await tester.tap(find.bySemanticsLabel('对话统计'));
        await until(tester, () => find.text('对话数据统计').evaluate().isNotEmpty);
        await capture('statistics-top');
        await tester.drag(find.byType(ListView).last, const Offset(0, -700));
        await capture('statistics-bottom');
        await close();
        await tester.pumpWidget(const SizedBox());
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    }
  });
}
