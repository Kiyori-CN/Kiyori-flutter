import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_messages.dart';
import 'package:kiyori/features/assistant/presentation/chat_copy_preview.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  test('plain copy keeps list and table boundaries', () {
    expect(chatPlainText('- one\n- two'), 'one\ntwo');
    expect(chatPlainText('a  \nb'), 'a\nb');
    expect(chatPlainText('| A | B |\n|---|---|\n| C | D |'), contains('C\tD'));
  });
  testWidgets(
    'cursor user text stays literal and long press opens ordered menu',
    (tester) async {
      String? selected;
      const text = '**原文**\n# 标题\n`code`';
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: ChatMessageTile(
              message: const ConversationMessage(
                variant: 0,
                variantCount: 1,
                id: 'one',
                runId: '',
                role: 'user',
                content: text,
                state: 'completed',
                error: '',
                model: 'hidden-model',
              ),
              enabled: true,
              onAction: (value) => selected = value,
            ),
          ),
        ),
      );
      expect(find.text(text), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.longPress(find.text('Prompt'));
      await tester.pumpAndSettle();
      expect(find.text('复制消息'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('编辑并重发')).dy,
        lessThan(tester.getTopLeft(find.text('回滚到此处')).dy),
      );
      await tester.tap(find.text('编辑并重发'));
      await tester.pumpAndSettle();
      expect(selected, 'resend');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('copy preview preserves source and selects complete text', (
    tester,
  ) async {
    const source = '**加粗**\n\n```dart\nprint(1);\n```\n\n结尾';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChatCopyPreview(context, source),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('chat-copy-text'));
    expect(tester.widget<TextField>(field).controller!.text, contains('结尾'));
    await tester.tap(find.text('Markdown 源码'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, source);
    await tester.tap(find.text('复制 Markdown 源码'));
    await tester.pumpAndSettle();
    expect(copied, source);
    expect(tester.takeException(), isNull);
  });
}
