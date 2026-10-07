import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_classic_input.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';
import 'support/ui_capture.dart';

const labels = ['照片', '拍照', '记忆', '文件', '屏幕内容', '当前通知', '当前位置', '包'];

void main() {
  testWidgets(
    'classic attachments expand below input and keep selection ownership',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.setPreference('input_style', 'classic');
        await f.runtime.createKnowledgeFolder(
          f.chat.knowledge!.activeSpace,
          '学习/基础',
        );
      });
      final boundary = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
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
        final panel = find.byKey(const Key('chat-classic-attachments'));
        expect(panel, findsNothing);
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        expect(find.byKey(const Key('chat-attachments')), findsNothing);
        expect(
          tester.getTopLeft(panel).dy,
          tester.getBottomLeft(find.byType(ChatClassicInput)).dy,
        );
        for (final label in labels) {
          expect(
            find.descendant(of: panel, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          tester.getTopLeft(find.text('照片')).dy,
          tester.getTopLeft(find.text('文件')).dy,
        );
        expect(
          tester.getTopLeft(find.text('屏幕内容')).dy,
          greaterThan(tester.getBottomLeft(find.text('照片')).dy),
        );
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'classic-attachments');
        }
        await tester.tap(find.text('包'));
        await tester.pumpAndSettle();
        expect(find.text('选择包'), findsOneWidget);
        expect(find.text('暂无可用包'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        await tester.tap(find.text('记忆'));
        await until(tester, () => find.text('学习').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定 (2)'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatPage), findsOneWidget);
        expect(f.chat.memoryFolders, ['学习', '学习/基础']);
        await tester.tap(find.byTooltip('移除记忆附件'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('chat-draft')), '正常发送后收起');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('发送'));
        await until(tester, () => f.requests.isNotEmpty && !f.chat.busy);
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        await tester.runAsync(f.chat.create);
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'attachment forms handle narrow dark keyboard and cancel stale selection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.setPreference('input_style', 'classic');
        await f.runtime.createKnowledgeFolder(
          f.chat.knowledge!.activeSpace,
          '旧草稿',
        );
      });
      final boundary = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      try {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KiyoriTheme.dark(),
              home: Scaffold(body: ChatPage(controller: f.chat)),
            ),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        final panel = find.byKey(const Key('chat-classic-attachments'));
        expect(tester.getBottomLeft(panel).dy, 564);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'classic-attachments-dark-keyboard',
          );
        }
        await tester.tap(find.text('记忆'));
        await until(tester, () => find.text('旧草稿').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox).first);
        await tester.runAsync(f.chat.create);
        await tester.pumpAndSettle();
        expect(find.text('选择记忆文件夹'), findsNothing);
        expect(f.chat.memoryFolders, isEmpty);
        expect(find.byType(ChatPage), findsOneWidget);
        await tester.runAsync(
          () => f.chat.setPreference('input_style', 'agent'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('添加附件'));
        await tester.pumpAndSettle();
        final popup = find.byKey(const Key('chat-attachments'));
        expect(tester.getSize(popup).width, 200);
        expect(panel, findsNothing);
        for (final label in labels) {
          expect(
            find.descendant(of: popup, matching: find.text(label)),
            findsOneWidget,
          );
        }
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'agent-attachments-dark-keyboard',
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
