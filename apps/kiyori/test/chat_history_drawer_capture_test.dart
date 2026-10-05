import 'package:flutter/material.dart';
// 对话左抽屉专项捕获；设置中的历史管理捕获保持独立。
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_management.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_details.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_swipe.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/memory_audit_exchange.dart';
import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets('history drawers dialogs and audit across five viewports', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadCaptureFonts(tester);
    final f = ChatFixture();
    await tester.runAsync(() async {
      await f.open();
      await f.chat.send('对话历史视觉验证');
      await f.chat.change(f.chat.snapshot!.conversation, 'rename', '分支来源对话');
      await f.chat.changeMessage(
        f.chat.snapshot!.conversation,
        f.chat.snapshot!.messages.last,
        'branch',
        '',
      );
      await f.chat.change(f.chat.snapshot!.conversation, 'pinned', 'true');
      await f.chat.setPreference(
        'history_group',
        '{"action":"create","name":"学习资料","binding":"default_character"}',
      );
      await f.chat.create();
      await f.chat.change(f.chat.snapshot!.conversation, 'pinned', 'true');
      for (var i = 0; i < 10; i++) {
        await f.chat.create();
      }
      await f.chat.change(f.chat.snapshot!.conversation, 'locked', 'true');
      await f.chat.setPreference('history_mode', 'character');
      await f.runtime.appendConversationNote(
        f.chat.snapshot!.conversation.id,
        '原始事件与展开视觉样本：保留完整中文、Emoji 😀 和诊断字段。',
      );
    });
    try {
      for (final scenario in [
        ('phone-light', const Size(390, 844), false, 1.0, 0.0),
        ('phone-dark', const Size(390, 844), true, 1.0, 0.0),
        ('narrow-large', const Size(320, 740), false, 2.0, 180.0),
        ('landscape', const Size(844, 390), true, 1.0, 0.0),
        ('desktop', const Size(1280, 900), false, 1.0, 0.0),
      ]) {
        tester.view.physicalSize = scenario.$2;
        final boundary = GlobalKey();
        late BuildContext host;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: scenario.$3 ? KiyoriTheme.dark() : KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scenario.$4),
                  viewInsets: EdgeInsets.only(bottom: scenario.$5),
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) {
                  host = context;
                  return const Scaffold(body: Text('AI 对话'));
                },
              ),
            ),
          ),
        );
        showChatHistory(host, f.chat);
        await until(
          tester,
          () =>
              find.byKey(const Key('chat-history-panel')).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-history');
        await tester.enterText(
          find.byKey(const Key('chat-history-search')),
          '历史视觉验证',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('匹配 2 / 共 14'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('分支来源对话'),
          80,
          scrollable: find.descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('分支来源对话').hitTestable(), findsOneWidget);
        await captureUi(tester, boundary, output, '${scenario.$1}-search');
        await tester.tap(find.byTooltip('清空搜索'));
        await tester.pumpAndSettle();
        if (scenario.$1.startsWith('phone-')) {
          for (final direction in [1.0, -1.0]) {
            final pointer = await tester.startGesture(
              tester.getCenter(find.byType(HistorySwipe).first),
            );
            await pointer.moveBy(Offset(20 * direction, 0));
            await tester.pump();
            await pointer.moveBy(Offset(140 * direction, 0));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 90));
            await captureUi(
              tester,
              boundary,
              output,
              '${scenario.$1}-swipe-${direction > 0 ? 'edit' : 'delete'}',
            );
            await pointer.cancel();
            await tester.pumpAndSettle();
            expect(find.text('确认删除聊天'), findsNothing);
            expect(find.text('编辑标题'), findsNothing);
          }
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        showHistorySettings(host, f.chat);
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-settings');
        if (scenario.$1 == 'narrow-large' || scenario.$1 == 'landscape') {
          await tester.scrollUntilVisible(
            find.text('自动切换聊天'),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(find.text('自动切换聊天').hitTestable(), findsOneWidget);
          expect(find.text('完成').hitTestable(), findsOneWidget);
          await captureUi(
            tester,
            boundary,
            output,
            '${scenario.$1}-settings-scrolled',
          );
        }
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        showHistoryManagement(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-menu');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        showHistoryDelete(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-delete');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        showHistoryMetadata(host, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-editor');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        showHistoryFolderEditor(host, f.chat);
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-new-group');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        showHistoryFolderManagement(
          host,
          f.chat,
          '学习资料',
          binding: 'default_character',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除分组'));
        await tester.pumpAndSettle();
        await captureUi(
          tester,
          boundary,
          output,
          '${scenario.$1}-group-delete',
        );
        if (scenario.$1 == 'narrow-large' || scenario.$1 == 'landscape') {
          await tester.scrollUntilVisible(
            find.text('删除分组和所有对话'),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(find.text('删除分组和所有对话').hitTestable(), findsOneWidget);
          expect(find.text('取消').hitTestable(), findsOneWidget);
          await captureUi(
            tester,
            boundary,
            output,
            '${scenario.$1}-group-delete-scrolled',
          );
        }
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: scenario.$3 ? KiyoriTheme.dark() : KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$4)),
                child: child!,
              ),
              home: Scaffold(
                body: HistoryDetails(
                  owner: f.chat,
                  id: f.chat.snapshot!.conversation.id,
                  exchange: MemoryAuditExchange(),
                ),
              ),
            ),
          ),
        );
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-details');
        await tester.tap(find.text('原始事件'));
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-raw');
        await tester.tap(find.text('全部展开'));
        await tester.pumpAndSettle();
        await captureUi(
          tester,
          boundary,
          output,
          '${scenario.$1}-raw-expanded',
        );
        await tester.tap(find.text('时间线'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('备注'));
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-note');
        await tester.tap(find.text('取消'));
        // Dialog完成退场后才开始重载；先推进退场，再等待真实FFI，不能在弹窗仍在时判空。
        await tester.pump(const Duration(milliseconds: 400));
        await until(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('导出'));
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, '${scenario.$1}-export');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  }, skip: output.isEmpty);
}
