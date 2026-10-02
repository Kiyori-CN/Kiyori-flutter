import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_capture.dart';

import 'package:kiyori/features/assistant/presentation/history/chat_history_page.dart';
import 'package:kiyori/features/assistant/presentation/history/chat_history_presentation.dart';
import 'package:kiyori/features/assistant/presentation/context/context_summary_page.dart';
import 'package:kiyori/features/assistant/presentation/models/function_models_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart' show revealHistory;
import 'support/assistant_fixtures.dart' show snapshot;
import 'support/ui_test_helpers.dart' show revealContext;
import 'support/assistant_fixtures.dart' show functionSnapshot;
import 'support/ui_test_helpers.dart' show revealFunction;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture history states from injected snapshot',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      Future<void> mount(ChatHistoryPresentation data) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KiyoriTheme.light(),
              home: ChatHistoryPage(key: ValueKey(data), snapshot: data),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name, {bool animated = false}) =>
          captureUi(tester, boundaryKey, output, name, animated: animated);

      await mount(const ChatHistoryPresentation());
      await capture('history-empty-phone');
      await mount(snapshot);
      await capture('history-stats-phone');
      await revealHistory(tester, find.text('点击处理缺失角色群聊条目'));
      await tester.tap(find.text('点击处理缺失角色群聊条目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归类到角色群聊'));
      await capture('history-assign-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await revealHistory(tester, find.byKey(const ValueKey('history-b')));
      await tester.tap(find.byKey(const ValueKey('history-b')));
      await tester.pumpAndSettle();
      await capture('history-batch-phone');
      await revealHistory(tester, find.text('为已选 1 条聊天重建记忆'));
      await tester.tap(find.text('为已选 1 条聊天重建记忆'));
      await capture('history-rebuild-phone');
      await tester.tap(find.text('全部日期（点击选择范围）'));
      await capture('history-date-phone');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KiyoriTheme.light(),
            home: const ContextSummaryPage(),
          ),
        ),
      );
      await capture('context-summary-phone');
      await revealContext(tester, find.byKey(const ValueKey('summary-rules')));
      await capture('context-summary-rules-phone');
      await revealContext(tester, find.text('恢复历史媒体默认值'));
      await tester.tap(find.text('恢复历史媒体默认值'));
      await capture('context-summary-reset-phone');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KiyoriTheme.light(),
            home: const FunctionModelsPage(snapshot: functionSnapshot),
          ),
        ),
      );
      await capture('function-models-phone');
      final expand = find.byKey(const ValueKey('function-expand-chat'));
      await revealFunction(tester, expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final multi = find.byKey(const ValueKey('function-config-chat-multi'));
      await revealFunction(tester, multi);
      await tester.tap(multi);
      await capture('function-models-expanded-phone');
      expect(tester.takeException(), isNull);
    },
  );
}
