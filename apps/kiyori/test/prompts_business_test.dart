import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/prompts/persistent_prompts_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompts_controller.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/character_card_editor.dart';
import 'package:kiyori/features/assistant/presentation/prompts/tag_market_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

Future<void> settlePrompts(
  WidgetTester tester,
  PromptsController controller,
) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (!controller.loading && !controller.saving && i > 20) break;
  }
  await tester.pumpAndSettle();
  expect(controller.loading || controller.saving, isFalse);
  expect(tester.takeException(), isNull);
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'real prompt forms create tag character group and recover persisted directory',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Directory.systemTemp.createTempSync(
        'kiyori-prompts-ui-',
      );
      final client = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final controller = PromptsController(() async => client);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          builder: (_, child) => RepaintBoundary(key: capture, child: child),
          home: PersistentPromptsPage(
            controller: controller,
            onOpenTagMarket: () {},
            onOpenPersona: () {},
          ),
        ),
      );
      await settlePrompts(tester, controller);
      expect(controller.snapshot.cards.single.name, 'Kiyori');
      await tester.tap(find.byKey(const ValueKey('prompt-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建标签'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('tag-field-0')), '持久标签');
      await tester.enterText(find.byKey(const ValueKey('tag-field-2')), '标签全文');
      await tester.tap(find.text('保存'));
      await settlePrompts(tester, controller);
      expect(controller.snapshot.tags.single.content, '标签全文');
      await tester.tap(find.byKey(const ValueKey('prompt-tab-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('character-field-0')),
        '持久角色',
      );
      await tester.tap(find.text('保存'));
      await settlePrompts(tester, controller);
      expect(find.byType(CharacterCardEditor), findsNothing);
      expect(controller.snapshot.cards.length, 2);
      if (output.isNotEmpty) {
        await captureUi(tester, capture, output, 'prompts-real-characters');
      }
      await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建群组'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('group-name')), '持久群组');
      await tester.tap(find.text('保存'));
      await settlePrompts(tester, controller);
      expect(controller.snapshot.groups.single.name, '持久群组');
      expect(
        controller.snapshot.activeGroupId,
        controller.snapshot.groups.single.id,
      );
      if (output.isNotEmpty) {
        await captureUi(tester, capture, output, 'prompts-real-group');
      }
      await tester.tap(find.byTooltip('持久群组菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制'));
      await settlePrompts(tester, controller);
      expect(controller.snapshot.groups.length, 2);
      await tester.tap(find.byTooltip('持久群组 (副本)菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为活跃'));
      await settlePrompts(tester, controller);
      expect(
        controller.snapshot.activeGroupId,
        controller.snapshot.groups
            .singleWhere((g) => g.name.endsWith('(副本)'))
            .id,
      );
      await tester.tap(find.byTooltip('持久群组 (副本)菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await settlePrompts(tester, controller);
      expect(controller.snapshot.groups.length, 1);
      expect(controller.snapshot.activeCardId, 'default_character');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        await client.close();
        final reopened = await NativeRuntimeClient.open(
          dataDirectory: directory.path,
        );
        expect((await reopened.promptCatalog()).characters.length, 2);
        expect(
          (await reopened.promptCatalog()).tags.single.draft.content,
          '标签全文',
        );
        await reopened.close();
        await directory.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'stale character keeps draft and failed save never overwrites new revision',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'kiyori-prompts-conflict-',
      );
      final client = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final controller = PromptsController(() async => client);
      await tester.pumpWidget(
        MaterialApp(
          home: PersistentPromptsPage(
            controller: controller,
            onOpenTagMarket: () {},
            onOpenPersona: () {},
          ),
        ),
      );
      await settlePrompts(tester, controller);
      await tester.tap(find.byTooltip('Kiyori菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('character-field-0')),
        '过期草稿',
      );
      await tester.runAsync(() => client.resetDefaultCharacter(1));
      await tester.tap(find.text('保存'));
      await settlePrompts(tester, controller);
      expect(find.text('内容已变化或已删除，请重新打开后再保存。'), findsOneWidget);
      expect(find.text('过期草稿'), findsOneWidget);
      final value = await tester.runAsync(client.promptCatalog);
      expect(value!.characters.single.draft.name, 'Kiyori');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        await client.close();
        await directory.delete(recursive: true);
      });
    },
  );

  testWidgets('market saves complete preset through same owner', (
    tester,
  ) async {
    PromptTagPresentation? saved;
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: TagMarketPage(
          onSave: (tag) async {
            saved = tag;
            await pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('添加标签').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();
    expect(saved!.content, isNotEmpty);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
