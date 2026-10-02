import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/prompts/model_prompts_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/tag_export_dialog.dart';
import 'package:kiyori/features/assistant/presentation/prompts/tag_market_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/tag_market_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/tag_market_presets.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

const tags = [
  PromptTagPresentation(id: 'b', name: 'Beta', description: '第二个标签'),
  PromptTagPresentation(id: 'a', name: 'Alpha', description: '第一个标签'),
];

void main() {
  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> showPrompts(
    WidgetTester tester,
    PromptsPresentation snapshot,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: ModelPromptsPage(snapshot: snapshot),
      ),
    );
    await tick(tester);
  }

  Finder action(String text) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, text),
  );
  testWidgets(
    'tag export selects current catalog and prunes removed entity generations',
    (tester) async {
      await showPrompts(tester, const PromptsPresentation(tags: tags));
      await tester.tap(find.text('标签').first);
      await tick(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
      await tick(tester);
      expect(find.byType(TagExportDialog), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((c) => c.value == true),
        isTrue,
      );
      await showPrompts(tester, PromptsPresentation(tags: [tags[0]]));
      await showPrompts(tester, const PromptsPresentation(tags: tags));
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.map((c) => c.value), [false, true]);
      await tester.tap(find.text('清空'));
      await tester.pump();
      expect(tester.widget<FilledButton>(action('导出')).onPressed, isNull);
      await tester.tap(find.text('全选'));
      await tester.pump();
      await showPrompts(
        tester,
        const PromptsPresentation(tags: tags, tagsExporting: true),
      );
      expect(tester.widget<FilledButton>(action('导出')).onPressed, isNull);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((c) => c.onChanged == null),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tick(tester);
      expect(find.byType(TagExportDialog), findsNothing);
      final export = find.widgetWithText(OutlinedButton, '导出');
      expect(tester.widget<OutlinedButton>(export).onPressed, isNull);
      await tester.tap(find.text('角色卡').first);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty tag export shows legacy message and populated export does not fake a file',
    (tester) async {
      await showPrompts(tester, const PromptsPresentation());
      await tester.tap(find.text('标签').first);
      await tick(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
      await tick(tester);
      expect(find.text('没有可导出的标签'), findsOneWidget);
      await showPrompts(tester, const PromptsPresentation(tags: tags));
      await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
      await tick(tester);
      await tester.tap(action('导出'));
      await tick(tester);
      expect(find.byType(TagExportDialog), findsOneWidget);
      expect(find.text('导出成功'), findsNothing);
    },
  );

  testWidgets(
    'market draft survives reorder but is released with removed preset and host',
    (tester) async {
      Future<void> market(List<TagMarketPreset> presets) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: TagMarketPage(presets: presets),
          ),
        );
        await tick(tester);
      }

      final first = tagMarketPresets.first;
      await market(tagMarketPresets);
      await revealBackup(
        tester,
        find.byKey(ValueKey('market-add-${first.id}')),
      );
      await tester.tap(find.byKey(ValueKey('market-add-${first.id}')));
      await tick(tester);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.text, first.name);
      await tester.enterText(find.byType(TextField), '草稿');
      await market(tagMarketPresets.reversed.toList());
      expect(controller.text, '草稿');
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tick(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await market(tagMarketPresets.skip(1).toList());
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await market(tagMarketPresets);
      expect(find.byType(AlertDialog), findsNothing);
      await revealBackup(
        tester,
        find.byKey(ValueKey('market-add-${first.id}')),
      );
      await tester.tap(find.byKey(ValueKey('market-add-${first.id}')));
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: Text('外部页面')),
        ),
      );
      await tick(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings tag market navigation returns to the same tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KiyoriTheme.light(), home: const HomeShell()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('AI 助手'));
    await tester.tap(find.text('AI 助手'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('角色卡和提示词'));
    await tester.tap(find.text('角色卡和提示词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签市场'));
    await tester.pumpAndSettle();
    expect(find.byType(TagMarketPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('标签管理'), findsOneWidget);
    expect(find.byType(TagMarketPage), findsNothing);
  });

  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'tag export and market large text keyboard $size dark=$dark',
        (tester) async {
          if (output.isNotEmpty) await loadCaptureFonts(tester);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          Future<void> mount(Widget child) async {
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
                  home: child,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<void> capture(String name) async {
            if (output.isNotEmpty) {
              await captureUi(
                tester,
                boundary,
                output,
                '$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
              );
            }
            expect(tester.takeException(), isNull);
          }

          await mount(
            const ModelPromptsPage(snapshot: PromptsPresentation(tags: tags)),
          );
          await tester.tap(find.text('标签').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
          await tester.pumpAndSettle();
          await capture('tag-export');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await mount(const TagMarketPage());
          await capture('tag-market');
          final last = tagMarketPresets.last;
          await revealBackup(
            tester,
            find.byKey(ValueKey('market-add-${last.id}')),
          );
          await capture('tag-market-story');
          await tester.tap(find.byKey(ValueKey('market-add-${last.id}')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '剧情草稿');
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          await tester.pumpAndSettle();
          await capture('tag-market-add-keyboard');
          await tester.tap(find.widgetWithText(FilledButton, '添加'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
