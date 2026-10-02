import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/prompts/model_prompts_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/character_card_editor.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_dialog.dart';
import 'package:kiyori/features/assistant/presentation/prompts/character_defaults.dart';
import 'package:kiyori/features/assistant/presentation/prompts/group_card_editor.dart';
import 'package:kiyori/features/assistant/presentation/prompts/group_card_tile.dart';
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
  groupTests();
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

void groupTests() {
  final selector = find.byKey(const ValueKey('group-member-selector'));
  final add = find.byKey(const ValueKey('group-add-member'));
  final name = find.byKey(const ValueKey('group-name'));
  Future<void> choose(WidgetTester tester, String label) async {
    await revealPrompt(tester, selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> addMember(WidgetTester tester) async {
    await revealPrompt(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  testWidgets('group tab top Back restores assistant settings source', (
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
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is ShellAction && widget.label == '返回',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('模型与生成'), findsOneWidget);
    expect(find.byType(ModelPromptsPage), findsNothing);
  });

  testWidgets('group menu from an old incarnation cannot edit reinserted ID', (
    tester,
  ) async {
    final source = ValueNotifier(groupFixture);
    addTearDown(source.dispose);
    await showPrompts(tester, source: source);
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('讨论组甲菜单'));
    await tester.pumpAndSettle();
    source.value = const PromptsPresentation(groups: [promptGroupB]);
    await tester.pumpAndSettle();
    source.value = groupFixture;
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupCardEditor), findsNothing);
  });

  for (final beforeFirstFrame in [false, true]) {
    testWidgets(
      'removing group host with dropdown releases resources beforeFirstFrame=$beforeFirstFrame',
      (tester) async {
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: ValueListenableBuilder(
              valueListenable: visible,
              builder: (_, value, _) => value
                  ? const ModelPromptsPage(snapshot: groupFixture)
                  : const Scaffold(body: Text('替换宿主')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await openGroup(tester);
        final controller = tester.widget<TextField>(name).controller!;
        await tester.enterText(name, '释放焦点');
        await tester.tap(selector);
        if (!beforeFirstFrame) await tester.pumpAndSettle();
        visible.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(GroupCardEditor), findsNothing);
        expect(find.byType(PopupMenuItem<String>), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(find.text('替换宿主'), findsOneWidget);
        expect(() => controller.addListener(() {}), throwsFlutterError);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'member dropdown uses IDs after role reorder and blank name has no fabricated error',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openGroup(tester);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [promptCardC, promptCardB, promptCardA],
        groups: [promptGroupA],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('角色丙').last);
      await tester.pumpAndSettle();
      await addMember(tester);
      expect(find.byTooltip('移除角色丙'), findsOneWidget);
      expect(find.byTooltip('移除角色乙'), findsNothing);
      await tester.enterText(name, '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupCardEditor), findsOneWidget);
      expect(tester.widget<TextField>(name).decoration!.errorText, isNull);
    },
  );

  testWidgets(
    'group empty creation and active snapshots never invent business facts',
    (tester) async {
      await showPrompts(tester);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建群组'));
      await tester.pumpAndSettle();
      expect(find.text('暂无群组'), findsOneWidget);
      expect(find.byType(GroupCardEditor), findsNothing);
      await showPrompts(tester, snapshot: groupFixture);
      expect(find.byType(GroupCardTile), findsNWidgets(2));
      expect(find.text('当前激活'), findsOneWidget);
      for (final action in ['复制', '设为活跃']) {
        await tester.tap(find.byTooltip('讨论组乙菜单'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
          tester.widget<GroupCardTile>(find.byKey(const ValueKey('g1'))).active,
          isTrue,
        );
        expect(
          tester.widget<GroupCardTile>(find.byKey(const ValueKey('g2'))).active,
          isFalse,
        );
        expect(find.byType(GroupCardTile), findsNWidgets(2));
      }
      await tester.tap(find.byKey(const ValueKey('prompt-tab-0')));
      await tester.pumpAndSettle();
      expect(find.text('当前激活'), findsNothing);
    },
  );

  testWidgets(
    'group name description save remains draft and cancellation releases controllers',
    (tester) async {
      await showPrompts(tester, snapshot: groupFixture);
      await openGroup(tester);
      final controller = tester.widget<TextField>(name).controller!;
      await tester.enterText(name, '临时名称');
      await tester.enterText(
        find.byKey(const ValueKey('group-description')),
        '临时描述',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupCardEditor), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await openGroup(tester, '讨论组乙');
      expect(tester.widget<TextField>(name).controller!.text, '讨论组乙');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await openGroup(tester);
      expect(tester.widget<TextField>(name).controller!.text, '讨论组甲');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group dropdown Back cancels selection then selection and add update only parent draft',
    (tester) async {
      await showPrompts(tester, snapshot: groupFixture);
      await openGroup(tester);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GroupCardEditor), findsOneWidget);
      expect(
        find.descendant(of: selector, matching: find.text('角色乙')),
        findsOneWidget,
      );
      await choose(tester, '角色丙');
      expect(find.byTooltip('移除角色丙'), findsNothing);
      await addMember(tester);
      expect(find.byTooltip('移除角色丙'), findsOneWidget);
      await revealPrompt(tester, find.byTooltip('移除角色甲'));
      await tester.tap(find.byTooltip('移除角色甲'));
      await tester.pumpAndSettle();
      await choose(tester, '角色甲');
      await addMember(tester);
      expect(
        tester.getTopLeft(find.byTooltip('移除角色丙')).dy,
        lessThan(tester.getTopLeft(find.byTooltip('移除角色甲')).dy),
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await openGroup(tester);
      expect(find.byTooltip('移除角色甲'), findsOneWidget);
      expect(find.byTooltip('移除角色丙'), findsNothing);
    },
  );

  testWidgets(
    'group orderIndex and duplicate occurrence removal follow old storage',
    (tester) async {
      await showPrompts(
        tester,
        snapshot: const PromptsPresentation(
          cards: [promptCardA, promptCardB],
          groups: [
            GroupPresentation(
              id: 'g1',
              name: '讨论组甲',
              members: [
                GroupMemberPresentation('a', orderIndex: 2),
                GroupMemberPresentation('b', orderIndex: 0),
                GroupMemberPresentation('a', orderIndex: 1),
              ],
            ),
          ],
        ),
      );
      await openGroup(tester);
      expect(
        tester.getTopLeft(find.byTooltip('移除角色乙')).dy,
        lessThan(tester.getTopLeft(find.byTooltip('移除角色甲').first).dy),
      );
      await tester.tap(find.byTooltip('移除角色甲').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('移除角色甲'), findsOneWidget);
      expect(selector, findsNothing); // 已加入角色不可重复添加；旧数据中的重复项仍可逐项删除。
    },
  );

  testWidgets('open group menu survives reorder with the correct entity host', (
    tester,
  ) async {
    final source = ValueNotifier(groupFixture);
    addTearDown(source.dispose);
    await showPrompts(tester, source: source);
    await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('讨论组甲菜单'));
    await tester.pumpAndSettle();
    source.value = const PromptsPresentation(
      cards: [promptCardA],
      groups: [
        GroupPresentation(id: 'g2', name: '讨论组乙', updatedAt: 9),
        promptGroupA,
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, '讨论组甲');
    await tester.enterText(name, '保留草稿');
    source.value = groupFixture;
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, '保留草稿');
  });

  testWidgets(
    'removed group closes owned dropdown and reincarnation cannot revive drafts',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openGroup(tester);
      final controller = tester.widget<TextField>(name).controller!;
      await tester.enterText(name, '旧草稿');
      await tester.tap(selector);
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(groups: [promptGroupB]);
      await tester.pumpAndSettle();
      expect(find.byType(GroupCardEditor), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      expect(find.byType(ModelPromptsPage), findsOneWidget);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      source.value = groupFixture;
      await tester.pumpAndSettle();
      await openGroup(tester);
      expect(tester.widget<TextField>(name).controller!.text, '讨论组甲');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale role dropdown rejects removed ID even if a new entity reuses it',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openGroup(tester);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [promptCardA, promptCardC],
        groups: [promptGroupA],
      );
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(
        cards: [
          promptCardA,
          CharacterPresentation(id: 'b', name: '重入乙'),
          promptCardC,
        ],
        groups: [promptGroupA],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('角色乙').last);
      await tester.pumpAndSettle();
      await addMember(tester);
      expect(find.byTooltip('移除角色丙'), findsOneWidget);
      expect(find.byTooltip('移除重入乙'), findsNothing);
    },
  );

  testWidgets(
    'role removal prunes draft members and same ID reentry does not restore them',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openGroup(tester);
      source.value = const PromptsPresentation(
        cards: [promptCardB, promptCardC],
        groups: [promptGroupA],
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('移除角色甲'), findsNothing);
      source.value = groupFixture;
      await tester.pumpAndSettle();
      expect(find.byTooltip('移除角色甲'), findsNothing);
      expect(find.text('请先添加至少一个角色卡成员'), findsOneWidget);
    },
  );

  testWidgets(
    'group deletion confirmation preserves snapshot and closes on catalog removal',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await tester.tap(find.byKey(const ValueKey('prompt-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('讨论组甲菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('确定删除群组「讨论组甲」吗？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      source.value = const PromptsPresentation(groups: [promptGroupB]);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ModelPromptsPage), findsOneWidget);
    },
  );

  testWidgets(
    'unrelated route stays open when group session and its menu are removed',
    (tester) async {
      final source = ValueNotifier(groupFixture);
      addTearDown(source.dispose);
      await showPrompts(tester, source: source);
      await openGroup(tester);
      final context = tester.element(find.byType(GroupCardEditor));
      await tester.tap(selector);
      await tester.pumpAndSettle();
      final navigator = Navigator.of(context);
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('独立页面'))),
      );
      await tester.pumpAndSettle();
      source.value = const PromptsPresentation(groups: [promptGroupB]);
      await tester.pumpAndSettle();
      expect(find.text('独立页面'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(GroupCardEditor), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      expect(find.byType(ModelPromptsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'group small large-text keyboard ${dark ? 'dark' : 'light'} reachability and release',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await showPrompts(tester, snapshot: groupFixture, scale: 2, dark: dark);
        await openGroup(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await revealPrompt(tester, name);
        await tester.enterText(name, '大字群组');
        await choose(tester, '角色丙');
        await addMember(tester);
        await revealPrompt(tester, find.byTooltip('移除角色丙'));
        expect(find.text('保存').hitTestable(), findsOneWidget);
        expect(find.text('取消').hitTestable(), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(GroupCardEditor))).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(GroupCardEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'group landscape scrolling and initial missing reference keep old semantics',
    (tester) async {
      tester.view.physicalSize = const Size(844, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await showPrompts(
        tester,
        snapshot: const PromptsPresentation(
          groups: [
            GroupPresentation(
              id: 'g1',
              name: '讨论组甲',
              members: [GroupMemberPresentation('missing')],
            ),
          ],
        ),
      );
      await openGroup(tester);
      await revealPrompt(tester, find.byTooltip('移除missing'));
      await tester.tap(find.byTooltip('移除missing'));
      await tester.pumpAndSettle();
      expect(find.text('请先添加至少一个角色卡成员'), findsOneWidget);
      expect(find.text('取消').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
