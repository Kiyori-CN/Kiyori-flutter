import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_management.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_menu.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';

const bindingField = Key('history-binding-field');
Finder option(String id) => find.byKey(ValueKey('history-binding-option-$id'));

Future<BuildContext> host(
  WidgetTester tester, {
  bool dark = false,
  double scale = 1,
  double keyboard = 0,
}) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (value) {
          context = value;
          return const Scaffold(body: Text('底层页面'));
        },
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets(
    'binding menu anchors below the field and only saves on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.runtime.savePromptGroup(
          null,
          null,
          const GroupDraft(
            name: '讨论',
            description: '',
            members: ['default_character'],
          ),
        );
        await f.chat.load();
      });
      try {
        final context = await host(tester);
        final item = f.chat.snapshot!.conversation;
        showHistoryMetadata(context, f.chat, item);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
        final field = tester.getRect(find.byKey(bindingField));
        final first = tester.getRect(option(''));
        expect(first.width, closeTo(field.width, .01));
        expect(first.left, closeTo(field.left, .01));
        expect(first.top, closeTo(field.bottom + 8, .01));
        expect(first.height, 48);
        final group = f.chat.prompts!.groups.single;
        expect(
          tester.getTopLeft(option('default_character')).dy,
          lessThan(tester.getTopLeft(option(group.id)).dy),
        );
        await tester.tap(option(''));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
        expect(find.text('未绑定'), findsOneWidget);
        expect(f.chat.snapshot!.conversation.characterId, item.characterId);
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.text('编辑标题'), findsOneWidget);
        expect(find.text('放弃未保存的修改？'), findsNothing);
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.text('放弃未保存的修改？'), findsNothing);
        final focus = tester
            .widget<FocusableActionDetector>(
              find
                  .descendant(
                    of: find.byType(HistoryBindingMenu),
                    matching: find.byType(FocusableActionDetector),
                  )
                  .first,
            )
            .focusNode!;
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(3));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();
        expect(find.text('未绑定'), findsOneWidget);
        await tester.tap(find.text('保存'));
        await tester.pump();
        expect(
          tester.widget<GestureDetector>(find.byKey(bindingField)).onTap,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('编辑标题'), findsOneWidget);
        await until(tester, () => !f.chat.changing);
        await tester.pumpAndSettle();
        expect(find.text('编辑标题'), findsNothing);
        expect(f.chat.snapshot!.conversation.characterId, '');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'open binding menu follows catalog changes without replacing title drafts',
    (tester) async {
      final f = ChatFixture();
      late String groupId;
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        groupId = await f.runtime.savePromptGroup(
          null,
          null,
          const GroupDraft(
            name: '原群聊',
            description: '',
            members: ['default_character'],
          ),
        );
        await f.chat.load();
      });
      try {
        final context = await host(tester);
        showHistoryMetadata(context, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '保留标题');
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        await tester.tap(option(groupId));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await f.runtime.savePromptGroup(
            groupId,
            f.chat.prompts!.groups.single.revision,
            const GroupDraft(
              name: '改名群聊',
              description: '',
              members: ['default_character'],
            ),
          );
          await f.chat.load();
        });
        await tester.pumpAndSettle();
        expect(find.text('群聊: 改名群聊'), findsNWidgets(2));
        expect(find.text('保留标题'), findsOneWidget);
        await tester.runAsync(() async {
          await f.runtime.deletePrompt(
            'group',
            groupId,
            f.chat.prompts!.groups.single.revision,
          );
          await f.chat.load();
        });
        await tester.pumpAndSettle();
        expect(option(groupId), findsNothing);
        expect(find.text('缺失角色群聊（$groupId）'), findsOneWidget);
        expect(find.text('保留标题'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.text('编辑标题'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'removing the conversation releases its open menu and preserves the host',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      try {
        final context = await host(tester);
        showHistoryMetadata(context, f.chat, f.chat.snapshot!.conversation);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(bindingField));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => f.chat.change(f.chat.snapshot!.conversation, 'delete', ''),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.text('编辑标题'), findsNothing);
        expect(find.text('底层页面'), findsOneWidget);
        expect(f.chat.catalog!.conversations, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'binding menu scrolls within narrow large-text keyboard and landscape viewports',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        for (var i = 0; i < 18; i++) {
          await f.runtime.savePromptGroup(
            null,
            null,
            GroupDraft(
              name: '第$i个用于换行的长名称群聊',
              description: '',
              members: ['default_character'],
            ),
          );
        }
        await f.chat.load();
      });
      try {
        for (final scenario in [
          (const Size(320, 740), 2.0, 180.0),
          (const Size(844, 390), 1.0, 0.0),
        ]) {
          tester.view.physicalSize = scenario.$1;
          final context = await host(
            tester,
            dark: true,
            scale: scenario.$2,
            keyboard: scenario.$3,
          );
          showHistoryMetadata(context, f.chat, f.chat.snapshot!.conversation);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(bindingField));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(bindingField));
          await tester.pumpAndSettle();
          final last = option(f.chat.prompts!.groups.last.id);
          final menu = tester.getRect(
            find.byKey(const Key('history-binding-menu')),
          );
          expect(menu.top, greaterThanOrEqualTo(48));
          expect(
            menu.bottom,
            lessThanOrEqualTo(scenario.$1.height - scenario.$3 - 48),
          );
          await tester.scrollUntilVisible(
            last,
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(last.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(last);
          expect(bounds.right, lessThanOrEqualTo(scenario.$1.width));
          expect(
            bounds.bottom,
            lessThanOrEqualTo(scenario.$1.height - scenario.$3),
          );
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(
            f.chat.snapshot!.conversation.characterId,
            'default_character',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
