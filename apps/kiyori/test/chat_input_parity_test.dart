import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  testWidgets('fullscreen close and system back preserve complete draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const Scaffold(body: ChatPage()),
      ),
    );
    final draft = find.byKey(const Key('chat-draft'));
    await tester.enterText(draft, '第一行\n**保持原文**');
    await tester.tap(find.widgetWithIcon(ShellAction, Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const Key('chat-fullscreen-draft')),
      '修改后\n完整草稿',
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(draft).controller!.text, '修改后\n完整草稿');
    await tester.tap(find.widgetWithIcon(ShellAction, Icons.fullscreen));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat-fullscreen-draft')),
      '系统返回保留',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(draft).controller!.text, '系统返回保留');
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing chat host removes only its fullscreen editor', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: visible,
            builder: (_, show, _) =>
                show ? const ChatPage() : const Text('保留页面'),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithIcon(ShellAction, Icons.fullscreen));
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-fullscreen-draft')), findsNothing);
    expect(find.text('保留页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
