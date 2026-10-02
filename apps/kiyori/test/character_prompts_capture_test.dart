import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/prompts/model_prompts_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart' show reveal;
import 'support/prompt_fixtures.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets('capture character prompt vertical slice', skip: output.isEmpty, (
    tester,
  ) async {
    await loadCaptureFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    Future<void> show(
      Widget page, {
      bool dark = false,
      double scale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await captureUi(tester, boundary, output, name);
      expect(tester.takeException(), isNull);
    }

    for (final dark in [false, true]) {
      final suffix = dark ? 'dark' : 'light';
      await show(const ModelPromptsPage(), dark: dark);
      await capture('characters-phone-$suffix');
      await openCharacter(tester);
      await capture('character-editor-phone-$suffix');
      await revealPrompt(
        tester,
        find.byKey(const ValueKey('character-advanced')),
      );
      await tester.tap(find.byKey(const ValueKey('character-advanced')));
      await tester.pumpAndSettle();
      await revealPrompt(tester, find.byKey(const ValueKey('character-tools')));
      await capture('character-advanced-phone-$suffix');
      await tester.tap(find.byKey(const ValueKey('character-tools')));
      await tester.pumpAndSettle();
      await capture('character-tool-empty-$suffix');
    }
    await show(const ModelPromptsPage(snapshot: promptFixture));
    await capture('characters-populated-phone');
    await openCharacter(tester, '角色甲');
    await tester.enterText(
      find.byKey(const ValueKey('character-field-0')),
      '未保存的人设草稿',
    );
    await tester.tap(find.byKey(const ValueKey('expand-character-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expanded-prompt-input')),
      '非默认角色名称\n嵌套编辑只回填本次草稿',
    );
    await capture('character-expanded-nondefault');
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    await revealPrompt(
      tester,
      find.byKey(const ValueKey('character-advanced')),
    );
    await tester.tap(find.byKey(const ValueKey('character-advanced')));
    await tester.pumpAndSettle();
    await revealPrompt(tester, find.text('指定固定配置'));
    await tester.tap(find.text('指定固定配置'));
    await tester.pumpAndSettle();
    await revealPrompt(tester, find.byKey(const ValueKey('character-model')));
    await tester.tap(find.byKey(const ValueKey('character-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模型配置甲').last);
    await capture('character-model-picker');

    await show(const ModelPromptsPage());
    await tester.tap(find.byKey(const ValueKey('prompt-tab-1')));
    await capture('tags-empty-phone');
    await tester.tap(find.text('新建标签'));
    await capture('tag-new-phone');
    await show(const ModelPromptsPage(snapshot: promptFixture));
    await tester.tap(find.byKey(const ValueKey('prompt-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑测试标签'));
    await capture('tag-edit-phone');
    await show(const ModelPromptsPage());
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await capture('groups-empty-phone');
    await show(
      const ModelPromptsPage(
        snapshot: PromptsPresentation(cards: [], activeCardId: null),
      ),
    );
    await capture('characters-empty-phone');

    tester.view.physicalSize = const Size(1200, 800);
    await show(const ModelPromptsPage(), dark: true);
    await capture('characters-desktop-dark');
    await openCharacter(tester);
    await capture('character-editor-desktop-dark');
    tester.view.physicalSize = const Size(320, 600);
    await show(const ModelPromptsPage(), scale: 2);
    await openCharacter(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    await capture('character-editor-large-keyboard');
    tester.view.viewInsets = const FakeViewPadding();

    tester.view.physicalSize = const Size(390, 844);
    await show(const HomeShell());
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('AI 助手'));
    await tester.tap(find.text('AI 助手'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('角色卡和提示词'));
    await tester.tap(find.text('角色卡和提示词'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await capture('characters-return-assistant-settings');

    for (final dark in [false, true]) {
      final suffix = dark ? 'dark' : 'light';
      await show(const ModelPromptsPage(snapshot: groupFixture), dark: dark);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
      await capture('groups-phone-$suffix');
      await openGroup(tester);
      await capture('group-editor-phone-$suffix');
      await tester.tap(find.byKey(const ValueKey('group-member-selector')));
      await capture('group-member-menu-$suffix');
      await tester.tap(find.text('角色丙').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group-add-member')));
      await capture('group-member-added-$suffix');
    }
    await show(const ModelPromptsPage(snapshot: groupFixture));
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('讨论组甲菜单'));
    await capture('group-actions-phone');
    await tester.tap(find.text('删除'));
    await capture('group-delete-confirm');
    tester.view.physicalSize = const Size(1200, 800);
    await show(const ModelPromptsPage(snapshot: groupFixture), dark: true);
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await capture('groups-desktop-dark');
    await openGroup(tester);
    await capture('group-editor-desktop-dark');
    tester.view.physicalSize = const Size(844, 320);
    await show(const ModelPromptsPage(snapshot: groupFixture));
    await openGroup(tester);
    await capture('group-editor-landscape');
    tester.view.physicalSize = const Size(320, 600);
    await show(const ModelPromptsPage(snapshot: groupFixture), scale: 2);
    await openGroup(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    await revealPrompt(
      tester,
      find.byKey(const ValueKey('group-member-selector')),
    );
    await capture('group-editor-large-keyboard');
    tester.view.viewInsets = const FakeViewPadding();
    tester.view.physicalSize = const Size(390, 844);
    await show(const ModelPromptsPage(snapshot: groupFixture));
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prompt-tab-0')));
    await capture('groups-return-characters');
  });
}
