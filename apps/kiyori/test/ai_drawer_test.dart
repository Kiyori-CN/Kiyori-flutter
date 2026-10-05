import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/ai_drawer.dart';
import 'package:kiyori/features/extensions/presentation/extensions_controller.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/fake_runtime.dart';

void main() {
  testWidgets(
    'drawer opens resident extension page and returns to preserved chat draft',
    (tester) async {
      final extensions = ExtensionsController(() async => FakeClient());
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: HomeShell(extensions: extensions),
        ),
      );
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
      pager.jumpToPage(2);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-draft')), '保留草稿');
      await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main.packages')));
      await tester.pumpAndSettle();
      expect(find.text('脚本').hitTestable(), findsOneWidget);
      await tester.tap(find.text('插件'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).hitTestable(), '插件查询');
      await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main.ai_chat')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-draft')))
            .controller!
            .text,
        '保留草稿',
      );
      await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main.packages')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).hitTestable())
            .controller!
            .text,
        '插件查询',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      extensions.dispose();
    },
  );
  testWidgets(
    'AI drawer system Back, scrim, same entry, toolbox and settings preserve chat draft',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const HomeShell()),
      );
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
      pager.jumpToPage(2);
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('chat-draft'));
      await tester.enterText(input, '未发送的草稿');
      Future<void> open() async {
        await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('ai-drawer-surface')), findsOneWidget);
      }

      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-drawer-surface')), findsNothing);
      expect(pager.page, 2);
      await open();
      await tester.tap(find.byKey(const ValueKey('main.ai_chat')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '未发送的草稿');
      await open();
      await tester.tap(find.byKey(const ValueKey('main.toolbox')));
      await tester.pumpAndSettle();
      expect(find.text('工具箱').hitTestable(), findsWidgets);
      expect(
        tester.widget<Opacity>(find.byKey(const Key('bar-opacity'))).opacity,
        0,
      );
      await open();
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      expect(find.text('我的账号'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await open();
      await tester.tap(find.byKey(const ValueKey('main.ai_chat')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '未发送的草稿');
      await open();
      await tester.tapAt(const Offset(790, 120));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-drawer-surface')), findsNothing);
      await open();
      await tester.tap(find.byTooltip('关闭AI对话并返回软件首页'));
      await tester.pumpAndSettle();
      expect(pager.page, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(700, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('AI drawer geometry and dynamic plugins $size/$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const capture = String.fromEnvironment('KIYORI_CAPTURE');
        if (capture.isNotEmpty) await loadCaptureFonts(tester);
        final boundary = GlobalKey();
        final visible = ValueNotifier(true);
        final entries = ValueNotifier<List<AiDrawerEntry>>([
          for (var i = 0; i < 12; i++)
            AiDrawerEntry(
              id: 'plugin-$i',
              label: '动态插件 $i',
              icon: Icons.extension,
              tone: IconTone.memory,
              kind: AiDrawerEntryKind.plugin,
            ),
        ]);
        String? selection;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
                child: child!,
              ),
              home: Scaffold(
                body: ListenableBuilder(
                  listenable: Listenable.merge([visible, entries]),
                  builder: (_, _) => AiDrawer(
                    open: visible.value,
                    selected: 'main.ai_chat',
                    toolboxCount: 20,
                    packageCount: 2,
                    workflowCount: 4,
                    networkAvailable: false,
                    networkType: '无网络连接',
                    plugins: entries.value,
                    onDismiss: () => visible.value = false,
                    onClose: () => visible.value = false,
                    onSelect: (entry) => selection = entry.id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('ai-drawer-surface'))).width,
          AiDrawer.widthFor(size.width),
        );
        if (capture.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            capture,
            'drawer-${size.width.toInt()}-$dark',
          );
        }
        final plugin = find.byKey(const ValueKey('plugin-11'));
        await tester.scrollUntilVisible(
          plugin,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(plugin);
        expect(selection, 'plugin-11');
        entries.value = [];
        await tester.pumpAndSettle();
        expect(find.text('插件'), findsNothing);
        visible.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('ai-drawer-surface')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        visible.dispose();
        entries.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
