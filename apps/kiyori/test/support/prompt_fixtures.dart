import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';

const promptCardA = CharacterPresentation(
  id: 'a',
  name: '角色甲',
  setting: '甲的设定',
  updatedAt: 1,
);
const promptCardB = CharacterPresentation(
  id: 'b',
  name: '角色乙',
  setting: '乙的设定',
  updatedAt: 2,
);
const promptFixture = PromptsPresentation(
  cards: [promptCardA, promptCardB],
  tags: [PromptTagPresentation(id: 't1', name: '测试标签', content: '完整提示词内容')],
  models: [
    ModelConfigPresentation(id: 'm1', name: '模型配置甲', models: ['模型一', '模型二']),
    ModelConfigPresentation(id: 'm2', name: '模型配置乙', models: ['模型三']),
  ],
  memories: [PromptOption('s1', '记忆空间甲'), PromptOption('s2', '记忆空间乙')],
  tools: [
    CharacterToolOption(
      'use_package',
      'use_package',
      CharacterToolKind.builtin,
    ),
    CharacterToolOption(
      'read_file',
      '读取文件',
      CharacterToolKind.builtin,
      '读取已授权的文件',
    ),
    CharacterToolOption('demo', '演示包', CharacterToolKind.package),
  ],
  activeCardId: 'a',
);

Future<void> openCharacter(
  WidgetTester tester, [
  String name = 'Kiyori',
]) async {
  await tester.ensureVisible(find.byTooltip('$name菜单'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('$name菜单'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();
}

Future<void> revealPrompt(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) fail('Missing prompt control: $target');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}
