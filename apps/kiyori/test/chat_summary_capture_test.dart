import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_messages.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(440, 956),
    const Size(320, 720),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'summary divider and long detail ${size.width} $dark $scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (output.isNotEmpty) await loadCaptureFonts(tester);
            final boundary = GlobalKey();
            final actions = <String>[];
            final message = ConversationMessage(
              variant: 0,
              variantCount: 1,
              id: 'checkpoint',
              runId: 'run',
              role: 'summary',
              content: List.filled(
                30,
                '保留对话中的重要事实、用户偏好和未完成事项。完整原文继续保存在历史中。',
              ).join('\n'),
              state: 'completed',
              error: '',
              model: 'summary',
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ChatMessageTile(
                            message: message,
                            onAction: actions.add,
                            enabled: true,
                            bubble: true,
                          ),
                          const Text('摘要之后的对话保持原样'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            final name =
                'summary-${size.width.toInt()}-${dark ? "dark" : "light"}-${scale.toInt()}';
            if (output.isNotEmpty) {
              await captureUi(tester, boundary, output, '$name-divider');
            }
            await tester.tap(find.byKey(const ValueKey('summary-checkpoint')));
            await tester.pumpAndSettle();
            expect(find.text('编辑'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (output.isNotEmpty) {
              await captureUi(tester, boundary, output, '$name-detail');
            }
            await tester.tap(find.text('编辑'));
            await tester.pumpAndSettle();
            expect(actions, ['edit']);
            await tester.tap(find.byKey(const ValueKey('summary-checkpoint')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('删除'));
            await tester.pumpAndSettle();
            expect(actions, ['edit', 'delete']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
