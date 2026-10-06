import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_groups.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_menu.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_widgets.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;

void main() {
  testWidgets(
    'binding animation reverses continuously and releases all frames',
    (tester) async {
      final controller = MenuController();
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 48,
                child: HistoryBindingMenu(
                  controller: controller,
                  focus: focus,
                  onOpen: () {},
                  onClose: () {},
                  builder: (_, _, _) => TextButton(
                    onPressed: controller.open,
                    child: const Text('打开'),
                  ),
                  children: [
                    MenuItemButton(
                      onPressed: controller.close,
                      child: const Text('选项'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      double menuScale() => tester
          .widget<Transform>(
            find.byKey(const Key('history-binding-menu-transform')),
          )
          .transform
          .entry(0, 0);
      controller.open();
      await tester.pump();
      expect(menuScale(), .8);
      await tester.pump(const Duration(milliseconds: 32));
      expect(menuScale(), inExclusiveRange(.8, 1));
      final opening = menuScale();
      controller.close();
      await tester.pump();
      expect(menuScale(), opening);
      await tester.pump(const Duration(milliseconds: 32));
      final reversing = menuScale();
      controller.open();
      await tester.pump();
      expect(menuScale(), reversing);
      await tester.pumpAndSettle();
      expect(menuScale(), 1);
      expect(controller.isOpen, isTrue);
      controller.close();
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    },
  );

  testWidgets(
    'history alerts keep heading and actions fixed while body scrolls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final scenario in [
        (const Size(390, 844), 1.0, 0.0, false),
        (const Size(320, 740), 2.0, 180.0, false),
        (const Size(844, 390), 1.0, 0.0, true),
      ]) {
        tester.view.physicalSize = scenario.$1;
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            theme: scenario.$4 ? KiyoriTheme.dark() : KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scenario.$2),
                viewInsets: EdgeInsets.only(bottom: scenario.$3),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        showDialog<void>(
          context: host,
          builder: (context) => HistoryAlert(
            title: '确认删除聊天',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 20; i++) Text('完整正文第$i行：长名称与失败说明仍然可以读取。'),
                const Text('正文末尾'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text('确认删除聊天'));
        final action = tester.getRect(find.text('取消'));
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(
          dialog.backgroundColor,
          Theme.of(host).colorScheme.surfaceContainerHigh,
        );
        await tester.scrollUntilVisible(
          find.text('正文末尾'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('正文末尾').hitTestable(), findsOneWidget);
        expect(tester.getRect(find.text('确认删除聊天')), title);
        expect(tester.getRect(find.text('取消')), action);
        expect(
          action.bottom,
          lessThanOrEqualTo(scenario.$1.height - scenario.$3),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'binding placement tries below above centered and window margins',
    (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // 三项总160高；末项情形让前两个位置越过48dp，第三候选仍可完整容纳。
      for (final scenario in [
        (100.0, 3, 148.0),
        (680.0, 3, 520.0),
        (140.0, 14, 48.0),
        (275.0, 9, 51.0),
      ]) {
        final controller = MenuController();
        final focus = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    top: scenario.$1,
                    left: 100,
                    width: 200,
                    height: 48,
                    child: HistoryBindingMenu(
                      controller: controller,
                      focus: focus,
                      onOpen: () {},
                      onClose: () {},
                      builder: (_, _, _) => TextButton(
                        focusNode: focus,
                        onPressed: controller.open,
                        child: const Text('打开'),
                      ),
                      children: [
                        for (var i = 0; i < scenario.$2; i++)
                          MenuItemButton(
                            autofocus: i == 0,
                            onPressed: controller.close,
                            style: MenuItemButton.styleFrom(
                              minimumSize: const Size(200, 48),
                            ),
                            child: Text('选项$i'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const Key('history-binding-menu')),
        );
        expect(rect.left, 100);
        expect(rect.width, 200);
        expect(rect.top, closeTo(scenario.$3, .01));
        expect(rect.bottom, lessThanOrEqualTo(752));
        final material = tester.widget<Material>(
          find.byKey(const Key('history-binding-menu')),
        );
        expect(material.borderRadius, BorderRadius.circular(12));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(focus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
      }
    },
  );

  testWidgets(
    'blank group dismissal and trim-equal rename preserve SQLite revisions',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.setPreference('create_folder', '学习');
        await f.chat.change(f.chat.snapshot!.conversation, 'folder', '学习');
      });
      try {
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        showHistoryFolderEditor(host, f.chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsNothing);
        expect(find.text('新建分组'), findsNothing);
        showHistoryFolderEditor(host, f.chat, initial: '学习');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '  学习  ');
        // 打开后增加成员：相同名称保存不应进行事务或报成员快照冲突。
        await tester.runAsync(() async {
          await f.chat.create();
          await f.chat.change(f.chat.snapshot!.conversation, 'folder', '学习');
        });
        final preferenceRevision = f.chat.preferences!.revision;
        final revisions = {
          for (final c in f.chat.catalog!.conversations) c.id: c.revision,
        };
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await until(tester, () => !f.chat.savingPreference);
        await tester.pumpAndSettle();
        expect(find.text('重命名分组'), findsNothing);
        await tester.runAsync(f.chat.load);
        expect(f.chat.error, isNull);
        expect(f.chat.preferences!.revision, preferenceRevision);
        expect({
          for (final c in f.chat.catalog!.conversations) c.id: c.revision,
        }, revisions);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
