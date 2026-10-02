import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/prompts/model_prompts_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/character_card_editor.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_dialog.dart';
import 'package:kiyori/features/assistant/presentation/prompts/character_defaults.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/prompt_fixtures.dart';
import 'support/ui_test_helpers.dart' show reveal;

Future<void> showPrompts(
  WidgetTester tester, {
  PromptsPresentation snapshot = const PromptsPresentation(),
  ValueNotifier<PromptsPresentation>? source,
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: source == null
          ? ModelPromptsPage(snapshot: snapshot)
          : ValueListenableBuilder(
              valueListenable: source,
              builder: (_, value, _) => ModelPromptsPage(snapshot: value),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings entry and Back restore exact source after modal dismissal',
    (tester) async {
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
      expect(find.text('角色卡管理'), findsOneWidget);
      await openCharacter(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CharacterCardEditor), findsNothing);
      expect(find.text('角色卡管理'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('模型与生成'), findsOneWidget);
      expect(find.text('角色卡管理'), findsNothing);
    },
  );

  testWidgets(
    'default data, empty tabs and new drafts never claim persistence',
    (tester) async {
      await showPrompts(tester);
      expect(find.text('Kiyori'), findsOneWidget);
      expect(find.text('当前激活'), findsOneWidget);
      await openCharacter(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('character-field-5')))
            .controller!
            .text,
        CharacterDefaults.voiceZh,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterCardEditor), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('character-field-0')))
            .controller!
            .text,
        '',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('character-field-5')))
            .controller!
            .text,
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('character-field-0')),
        '未创建角色',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('未创建角色'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('标签管理'), findsOneWidget);
      expect(find.text('测试标签'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('暂无群组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested edit applies only on confirm and outer cancel discards it',
    (tester) async {
      await showPrompts(tester);
      await openCharacter(tester);
      final input = find.byKey(const ValueKey('character-field-0'));
      final original = tester.widget<TextField>(input).controller!;
      await tester.tap(find.byKey(const ValueKey('expand-character-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expanded-prompt-input')),
        '放大草稿',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      expect(original.text, '放大草稿');
      await tester.tap(find.byKey(const ValueKey('expand-character-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expanded-prompt-input')),
        '应丢弃',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(original.text, '放大草稿');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await openCharacter(tester);
      expect(tester.widget<TextField>(input).controller, isNot(same(original)));
      expect(tester.widget<TextField>(input).controller!.text, 'Kiyori');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open menu follows ID across reorder and rejects removed incarnation',
    (tester) async {
      final source = ValueNotifier(
        const PromptsPresentation(cards: [promptCardA, promptCardB]),
      );
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await tester.tap(find.byTooltip('角色甲菜单'));
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [promptCardB, promptCardA],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('character-field-0')))
            .controller!
            .text,
        '角色甲',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('角色甲菜单'));
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(cards: [promptCardB]);
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [promptCardA, promptCardB],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterCardEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reorder retains controller; removal dismisses nested edit and releases focus',
    (tester) async {
      final source = ValueNotifier(
        const PromptsPresentation(cards: [promptCardA, promptCardB]),
      );
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openCharacter(tester, '角色甲');
      final input = find.byKey(const ValueKey('character-field-0'));
      await tester.enterText(input, '只属于甲');
      final controller = tester.widget<TextField>(input).controller!;
      source.value = const PromptsPresentation(
        cards: [promptCardB, promptCardA],
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller, same(controller));
      expect(controller.text, '只属于甲');
      await tester.tap(find.byKey(const ValueKey('expand-character-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('expanded-prompt-input')),
        '迟到编辑',
      );
      source.value = const PromptsPresentation(cards: [promptCardB]);
      await tester.pumpAndSettle();
      expect(find.byType(PromptTextEditor), findsNothing);
      expect(find.byType(CharacterCardEditor), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      source.value = const PromptsPresentation(
        cards: [promptCardA, promptCardB],
      );
      await tester.pumpAndSettle();
      await openCharacter(tester, '角色甲');
      expect(
        tester.widget<TextField>(input).controller,
        isNot(same(controller)),
      );
      expect(tester.widget<TextField>(input).controller!.text, '角色甲');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'model picker uses current config and model identity after directory change',
    (tester) async {
      final source = ValueNotifier(promptFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openCharacter(tester, '角色甲');
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
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [promptCardA],
        models: [
          ModelConfigPresentation(id: 'm2', name: '模型配置乙', models: ['模型三']),
          ModelConfigPresentation(
            id: 'm1',
            name: '模型配置甲',
            models: ['模型二', '模型一'],
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('model-m1-模型二')));
      await tester.pumpAndSettle();
      expect(find.text('固定配置 · 模型配置甲 · 模型二'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tag edit and delete confirmation remain drafts and cancel cleanly',
    (tester) async {
      await showPrompts(tester, snapshot: promptFixture);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('编辑测试标签'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-field-0')),
        '未保存标签',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('编辑标签'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('测试标签'), findsOneWidget);
      await tester.tap(find.byTooltip('删除测试标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(find.text('删除标签'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('测试标签'), findsOneWidget);
    },
  );

  testWidgets(
    'tool picker search, cancel, confirmation and current-directory pruning',
    (tester) async {
      final source = ValueNotifier(promptFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openCharacter(tester, '角色甲');
      await revealPrompt(
        tester,
        find.byKey(const ValueKey('character-advanced')),
      );
      await tester.tap(find.byKey(const ValueKey('character-advanced')));
      await tester.pumpAndSettle();
      await revealPrompt(tester, find.text('启用角色卡级工具白名单'));
      await tester.tap(find.text('启用角色卡级工具白名单'));
      await tester.pumpAndSettle();
      await revealPrompt(tester, find.byKey(const ValueKey('character-tools')));
      await tester.tap(find.byKey(const ValueKey('character-tools')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(KiyoriSearchField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('未找到匹配的工具'), findsOneWidget);
      await tester.enterText(find.byType(KiyoriSearchField), 'read_file');
      await tester.pumpAndSettle();
      await tester.tap(find.text('读取文件'));
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(find.text('内建工具 1 · 包 0 · Skill 0 · MCP 0'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('character-tools')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('读取文件'));
      source.value = const PromptsPresentation(
        cards: [promptCardA],
        tools: [
          CharacterToolOption(
            'use_package',
            'use_package',
            CharacterToolKind.builtin,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('读取文件'), findsNothing);
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      expect(find.text('内建工具 1 · 包 0 · Skill 0 · MCP 0'), findsNothing);
      expect(find.text('当前未允许任何内建工具或外部来源'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external tool selection validates use_package without claiming saved',
    (tester) async {
      await showPrompts(tester, snapshot: promptFixture);
      await openCharacter(tester, '角色甲');
      await revealPrompt(
        tester,
        find.byKey(const ValueKey('character-advanced')),
      );
      await tester.tap(find.byKey(const ValueKey('character-advanced')));
      await tester.pumpAndSettle();
      await revealPrompt(tester, find.text('启用角色卡级工具白名单'));
      await tester.tap(find.text('启用角色卡级工具白名单'));
      await tester.pumpAndSettle();
      await revealPrompt(tester, find.byKey(const ValueKey('character-tools')));
      await tester.tap(find.byKey(const ValueKey('character-tools')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('包'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('演示包'));
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请先在内建工具中开启 use_package'), findsOneWidget);
      expect(find.byType(CharacterCardEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty catalog, sort and export preserve snapshot facts', (
    tester,
  ) async {
    await showPrompts(
      tester,
      snapshot: const PromptsPresentation(cards: [], activeCardId: null),
    );
    expect(find.text('Kiyori'), findsNothing);
    expect(find.text('当前激活'), findsNothing);
    await showPrompts(tester, snapshot: promptFixture);
    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按最近更新时间'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('角色乙')).dy,
      lessThan(tester.getTopLeft(find.text('角色甲')).dy),
    );
    await tester.tap(find.byTooltip('角色甲菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();
    expect(find.text('酒馆 JSON'), findsOneWidget);
    await tester.tap(find.text('酒馆 JSON'));
    await tester.pumpAndSettle();
    expect(find.text('酒馆 JSON'), findsOneWidget);
    expect(find.text('保存成功'), findsNothing);
    await tester.tap(find.text('多维码'));
    await tester.pumpAndSettle();
    expect(find.text('酒馆 JSON'), findsNothing);
    expect(find.text('8色'), findsOneWidget);
    await tester.tap(find.text('16色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('角色卡管理'), findsOneWidget);
    expect(find.text('酒馆 JSON'), findsNothing);
  });

  testWidgets('removing the host disposes every nested modal and text focus', (
    tester,
  ) async {
    await showPrompts(tester);
    await openCharacter(tester);
    await tester.tap(find.byKey(const ValueKey('expand-character-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expanded-prompt-input')),
      '退出前',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
    await showPrompts(tester);
    await openCharacter(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('character-field-0')))
          .controller!
          .text,
      'Kiyori',
    );
  });

  testWidgets('memory binding and tag chips follow live directory IDs', (
    tester,
  ) async {
    final source = ValueNotifier(promptFixture);
    addTearDown(source.dispose);
    await showPrompts(tester, source: source);
    await openCharacter(tester, '角色甲');
    await revealPrompt(tester, find.byKey(const ValueKey('attached-tag-t1')));
    await tester.tap(find.byKey(const ValueKey('attached-tag-t1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('attached-tag-t1')))
          .selected,
      isTrue,
    );
    await revealPrompt(
      tester,
      find.byKey(const ValueKey('character-advanced')),
    );
    await tester.tap(find.byKey(const ValueKey('character-advanced')));
    await tester.pumpAndSettle();
    await revealPrompt(tester, find.text('指定固定记忆配置'));
    await tester.tap(find.text('指定固定记忆配置'));
    await tester.pumpAndSettle();
    await revealPrompt(tester, find.byKey(const ValueKey('character-memory')));
    await tester.tap(find.byKey(const ValueKey('character-memory')));
    await tester.pumpAndSettle();
    source.value = const PromptsPresentation(
      cards: [promptCardA],
      memories: [PromptOption('s2', '记忆空间乙')],
    );
    await tester.pumpAndSettle();
    expect(find.text('记忆空间甲').hitTestable(), findsNothing);
    await tester.tap(find.text('记忆空间乙'));
    await tester.pumpAndSettle();
    expect(find.text('固定配置 · 记忆空间乙'), findsOneWidget);
    expect(find.byKey(const ValueKey('attached-tag-t1')), findsNothing);
    expect(find.text('没有可用标签。请在设置中创建。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape editor keeps cancellation reachable', (tester) async {
    tester.view.physicalSize = const Size(844, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await showPrompts(tester);
    await openCharacter(tester);
    expect(find.text('取消').hitTestable(), findsOneWidget);
    await revealPrompt(tester, find.byKey(const ValueKey('character-field-5')));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'bounded editor with keyboard, large text and ${dark ? 'dark' : 'light'} host',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await showPrompts(tester, dark: dark, scale: 2);
        await openCharacter(tester);
        final context = tester.element(find.byType(CharacterCardEditor));
        expect(
          Theme.of(context).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await revealPrompt(
          tester,
          find.byKey(const ValueKey('character-field-0')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('character-field-0')),
          '大字草稿',
        );
        expect(find.text('取消').hitTestable(), findsOneWidget);
        expect(find.text('保存').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CharacterCardEditor), findsNothing);
      },
    );
  }
}
