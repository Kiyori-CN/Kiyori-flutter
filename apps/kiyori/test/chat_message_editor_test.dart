import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_message_editor.dart';

void main() {
  const original =
      ' before\n<think a="x">one\n two</think>\n\n<tool>three</tool>\n';
  test('message parts preserve whitespace attributes and nested content', () {
    for (final source in [original, '', '<x><x>nested</x></x>', '<unclosed>']) {
      expect(parseChatMessage(source).map((p) => p.source).join(), source);
    }
  });
  testWidgets('editor keeps failed save and requires explicit discard', (
    tester,
  ) async {
    final submissions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ChatMessageEditor(
                  initial: original,
                  onSave: (value) async {
                    submissions.add(value);
                    return false;
                  },
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯文本'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('message-editor-raw')))
          .controller!
          .text,
      original,
    );
    await tester.enterText(
      find.byKey(const Key('message-editor-raw')),
      '$original末尾',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(submissions, ['$original末尾']);
    expect(find.text('保存失败，修改仍保留，请重试'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭编辑'));
    await tester.pumpAndSettle();
    expect(find.text('放弃更改？'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatMessageEditor), findsNothing);
  });
}
