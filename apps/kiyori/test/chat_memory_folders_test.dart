import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets(
    'memory folder descendants select together and unsupported sending keeps the draft',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.runtime.createKnowledgeFolder(
          f.chat.knowledge!.activeSpace,
          '学习/基础',
        );
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ChatPage(controller: f.chat)),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('记忆'));
        await until(tester, () => find.text('学习').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();
        expect(find.text('确定 (2)'), findsOneWidget);
        await tester.tap(find.text('确定 (2)'));
        await tester.pumpAndSettle();
        expect(find.text('memory_context.xml'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('chat-draft')), '保留草稿');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('发送'));
        await tester.pumpAndSettle();
        expect(f.requests, isEmpty);
        expect(find.textContaining('记忆查询工具'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('chat-draft')))
              .controller!
              .text,
          '保留草稿',
        );
        await tester.tap(find.byTooltip('移除记忆附件'));
        await tester.pumpAndSettle();
        expect(f.chat.memoryFolders, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
