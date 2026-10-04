import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_message_info.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

void main() {
  testWidgets('message output duration is not reduced by first output wait', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatMessageInfo(
          message: ConversationMessage(
            id: 'message',
            runId: 'run',
            role: 'assistant',
            content: 'reply',
            state: 'completed',
            error: '',
            model: 'model',
            variant: 0,
            variantCount: 1,
            firstOutputMs: 2000,
            durationMs: 5000,
          ),
        ),
      ),
    );
    expect(find.text('等待耗时'), findsOneWidget);
    expect(find.text('2.00 s (2000 ms)'), findsOneWidget);
    expect(find.text('输出耗时'), findsOneWidget);
    expect(find.text('5.00 s (5000 ms)'), findsOneWidget);
    expect(find.text('3.00 s (3000 ms)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
