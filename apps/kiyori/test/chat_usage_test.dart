import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';
import 'support/ui_capture.dart';

void main() {
  testWidgets(
    'request observations retain partial usage without failing chat',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      final boundary = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      try {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        f.chunks = ['合成', '回复'];
        f.usage = {'input_tokens': 13};
        await tester.runAsync(() => f.chat.send('仅报告输入'));
        expect(f.chat.error, isNull);
        expect(f.chat.snapshot!.messages.last.state, 'completed');
        final partial = f.chat.statistics!;
        expect(partial.reportedRequests, 0);
        expect(partial.recentInputTokens, 13);
        expect(partial.recentOutputTokens, isNull);
        expect(partial.tokensPerSecond, isNull);
        f.usage = {'input_tokens': 15, 'output_tokens': 6};
        await tester.runAsync(() => f.chat.send('完整用量'));
        final stats = f.chat.statistics!;
        expect(stats.tokensPerSecond, greaterThan(0));
        expect(stats.speedEstimated, isFalse);
        expect(stats.contextTokens, greaterThan(0));
        expect(stats.durationMs, greaterThan(stats.firstOutputMs!));
        expect(stats.reportedRequests, 1);
        expect(stats.inputTokens, 15);
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
        await tester.tap(find.bySemanticsLabel('对话统计'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('生成速度 · 当前 / 最近请求'),
          200,
          scrollable: find.descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          ),
        );
        await until(
          tester,
          () => find.text('已完成 · 根据供应商用量').evaluate().isNotEmpty,
        );
        expect(find.textContaining('token/s'), findsOneWidget);
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'chat-observation-speed');
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets('statistics total saturates instead of wrapping negative', (
    tester,
  ) async {
    final f = ChatFixture();
    await tester.runAsync(f.open);
    try {
      f.usage = {
        'prompt_tokens': 9223372036854775806,
        'completion_tokens': 100,
      };
      await tester.runAsync(() => f.chat.send('极值统计边界'));
      expect(f.chat.error, isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(body: ChatPage(controller: f.chat)),
        ),
      );
      await until(tester, () => !f.chat.loading);
      await tester.tap(find.bySemanticsLabel('对话统计'));
      await until(
        tester,
        () => find.text('9,223,372,036,854,775,806').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('总用量'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('9,223,372,036,854,775,807'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  });

  testWidgets(
    'provider detail survives FFI, branching, reopening and statistics UI',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      final boundary = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      try {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        f.usage = {
          'prompt_tokens': 1000,
          'completion_tokens': 100,
          'prompt_tokens_details': {
            'cached_tokens': 600,
            'cache_write_tokens': 100,
          },
          'completion_tokens_details': {'reasoning_tokens': 30},
        };
        await tester.runAsync(() => f.chat.send('有真实细分的本地合成回复'));
        final id = f.chat.draftId;
        final first = (await tester.runAsync(
          () => f.runtime.conversationStatistics(id),
        ))!;
        expect(first.cacheReadTokens, 600);
        expect(first.cacheWriteTokens, 100);
        expect(first.uncachedInputTokens, 300);
        expect(first.cacheInputTokens, 1000);
        expect(first.reasoningTokens, 30);
        expect(first.cacheReportedRequests, 1);
        expect(f.chat.snapshot!.messages.last.cacheReadTokens, 600);
        final source = f.chat.snapshot!;
        await tester.runAsync(
          () => f.chat.changeMessage(
            source.conversation,
            source.messages.last,
            'branch',
            '',
          ),
        );
        expect(f.chat.error, isNull);
        final branch = (await tester.runAsync(
          () => f.runtime.conversationStatistics(f.chat.draftId),
        ))!;
        expect(branch.inputTokens, first.inputTokens);
        expect(branch.cacheReadTokens, first.cacheReadTokens);
        expect(branch.recentInputTokens, isNull);
        expect(branch.contextTokens, isNull);
        final reopened = (await tester.runAsync(
          () => NativeRuntimeClient.open(dataDirectory: f.directory.path),
        ))!;
        try {
          final history = (await tester.runAsync(
            () => reopened.conversationStatistics(id),
          ))!;
          expect(history.inputTokens, first.inputTokens);
          expect(history.cacheReadTokens, first.cacheReadTokens);
          expect(history.recentInputTokens, isNull);
          expect(history.firstOutputMs, isNull);
          expect(history.contextTokens, isNull);
        } finally {
          await tester.runAsync(reopened.close);
        }
        await tester.runAsync(() => f.chat.select(id));
        // 第二个请求不报告缓存，不能用累计输入作为命中率分母。
        f.usage = {'prompt_tokens': 9000, 'completion_tokens': 200};
        await tester.runAsync(() => f.chat.send('无缓存指标的第二轮'));
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KiyoriTheme.light(),
              scrollBehavior: const KiyoriScrollBehavior(),
              home: Scaffold(body: ChatPage(controller: f.chat)),
            ),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.tap(find.bySemanticsLabel('对话统计'));
        await until(tester, () => find.text('60.0%').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('60.0%'), findsOneWidget);
        expect(find.text('600'), findsOneWidget);
        final total = (await tester.runAsync(
          () => f.runtime.conversationStatistics(id),
        ))!;
        expect(total.requests, 2);
        expect(total.reportedRequests, 2);
        expect(total.cacheReportedRequests, 1);
        expect(total.cacheInputTokens, 1000);
        expect(total.inputTokens, 10000);
        expect(total.uncachedInputTokens, 9300);
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'chat-usage-reported');
        }
        await tester.tap(find.text('最近请求'));
        await tester.pumpAndSettle();
        expect(find.text('60.0%'), findsNothing);
        expect(find.text('600'), findsNothing);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'chat-usage-unknown-recent',
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
