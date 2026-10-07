import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_button.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';
import 'support/ui_capture.dart';

void main() {
  testWidgets('history capsule follows real parallel runs and panel closure', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final f = ChatFixture();
    await tester.runAsync(f.open);
    final boundary = GlobalKey();
    const output = String.fromEnvironment('KIYORI_CAPTURE');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void>? first, second;
    try {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KiyoriTheme.light(),
            home: Scaffold(body: ChatPage(controller: f.chat)),
          ),
        ),
      );
      await until(tester, () => !f.chat.loading);
      final button = find.byType(ChatHistoryButton);
      expect(tester.getSize(button), const Size(32, 32));
      f.gate = Completer<void>();
      await tester.runAsync(() async {
        first = f.chat.send('第一项运行');
      });
      await until(
        tester,
        () =>
            f.requests.length == 1 &&
            tester.widget<ChatHistoryButton>(button).runningCount == 1,
      );
      expect(tester.widget<ChatHistoryButton>(button).runningCount, 1);
      expect(tester.getSize(button).width, 32);
      await tester.runAsync(f.chat.create);
      await tester.runAsync(() async {
        second = f.chat.send('第二项运行');
      });
      await until(
        tester,
        () =>
            f.requests.length == 2 &&
            tester.widget<ChatHistoryButton>(button).runningCount == 2,
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<ChatHistoryButton>(button).runningCount, 2);
      expect(tester.getSize(button).height, 32);
      expect(tester.getSize(button).width, greaterThan(42));
      expect(
        find.descendant(of: button, matching: find.text('2')),
        findsOneWidget,
      );
      final capsule = tester.widget<Material>(
        find.byKey(const Key('chat-history-button-surface')),
      );
      expect(capsule.borderRadius, BorderRadius.circular(12));
      expect(capsule.color, const Color(0xFFEBF4FD));
      if (output.isNotEmpty) {
        await captureUi(
          tester,
          boundary,
          output,
          'chat-header-parallel',
          animated: true,
        );
      }

      // 停止第二项只移除第二项计数；第一项继续生成，历史数量不参与运行计数。
      await tester.runAsync(f.chat.stop);
      await tester.runAsync(() => second!);
      await tester.pump();
      expect(tester.widget<ChatHistoryButton>(button).runningCount, 1);
      expect(tester.getSize(button).width, 32);
      await tester.tap(find.bySemanticsLabel('显示历史'));
      await until(
        tester,
        () => find.byKey(const Key('chat-history-panel')).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<ChatHistoryButton>(
              find.byType(ChatHistoryButton, skipOffstage: false),
            )
            .expanded,
        isTrue,
      );
      await tester.tap(find.byTooltip('收起对话历史'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widget<ChatHistoryButton>(button).expanded, isFalse);
      expect(
        tester
            .widget<Material>(
              find.byKey(const Key('chat-history-button-surface')),
            )
            .color,
        Colors.transparent,
      );
      await tester.runAsync(() async {
        f.gate!.complete();
        await first;
      });
      await tester.pump();
      expect(tester.widget<ChatHistoryButton>(button).runningCount, 0);
      expect(f.chat.catalog!.conversations.length, 2);

      await tester.pumpAndSettle();
      final semantics = tester.getSemantics(find.bySemanticsLabel('对话统计'));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.owner!.performAction(semantics.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('对话数据统计'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semanticsHandle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        if (f.gate?.isCompleted == false) f.gate!.complete();
        await first;
        await second;
        await f.close();
      });
    }
  });

  testWidgets('history expanded and dark capsule preserve old geometry', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final count in [0, 1, 2, 12]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
            home: Scaffold(
              body: Center(
                child: ChatHistoryButton(
                  runningCount: count,
                  expanded: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(ChatHistoryButton)).height, 32);
        final surface = tester.widget<Material>(
          find.byKey(const Key('chat-history-button-surface')),
        );
        expect(surface.color, Color(dark ? 0xFF27313D : 0xFFEBF4FD));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
