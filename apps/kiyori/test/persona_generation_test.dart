import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/prompts/persona_generation_page.dart';
import 'package:kiyori/features/assistant/presentation/prompts/persona_presentation.dart';
import 'package:kiyori/features/assistant/presentation/prompts/prompt_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

const cards = [
  CharacterPresentation(id: 'a', name: '角色A', description: '介绍A'),
  CharacterPresentation(id: 'b', name: '角色B', description: '介绍B'),
];
const messages = {
  'a': [
    PersonaMessage(
      id: 'intro',
      content: '请告诉我你想创建什么角色，或者想修改哪个部分？',
      time: '12:30:00',
    ),
    PersonaMessage(
      id: 'user',
      content: '请补充这个角色的性格和经历。',
      time: '12:30:05',
      user: true,
    ),
  ],
};
void main() {
  Future<void> mount(WidgetTester tester, PersonaPresentation snapshot) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: PersonaGenerationPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(TextButton, name));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('persona-card-selector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        PopupMenuItem<({bool forCreate, String id, Object token})>,
        name,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty persona fields stay editable without leaking into a later card',
    (tester) async {
      const empty = PersonaPresentation(
        catalog: PromptsPresentation(cards: [], activeCardId: ''),
      );
      await mount(tester, empty);
      await open(tester, '无角色卡');
      expect(find.byType(TextField), findsNWidgets(9));
      await tester.enterText(
        find.byKey(const ValueKey('persona-field-0')),
        '未绑定名称',
      );
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
            .controller!
            .text,
        '角色A',
      );
      await mount(tester, empty);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
            .controller!
            .text,
        '',
      );
      final field = find.byKey(const ValueKey('persona-field-7'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(field.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long histories reach the actual tail on initial load and card change',
    (tester) async {
      final histories = {
        for (final id in ['a', 'b'])
          id: [
            for (var i = 0; i < 35; i++)
              PersonaMessage(
                id: '$id-$i',
                content: i == 34
                    ? '$id末条消息'
                    : List.filled(i % 5 + 1, '长消息测试' * 30).join('\n'),
                time: '12:00:00',
              ),
          ],
      };
      await mount(
        tester,
        PersonaPresentation(
          catalog: const PromptsPresentation(cards: cards, activeCardId: 'a'),
          messages: histories,
        ),
      );
      expect(find.text('a末条消息').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      final readingOffset = controller.offset;
      await mount(
        tester,
        PersonaPresentation(
          catalog: const PromptsPresentation(cards: cards, activeCardId: 'a'),
          messages: histories,
        ),
      );
      expect(controller.offset, readingOffset);
      await open(tester, '角色A');
      await choose(tester, '角色B');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('b末条消息').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'persona card switching keeps drafts isolated and removed cards release controllers',
    (tester) async {
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
          messages: messages,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('persona-input')),
        '输入A',
      );
      await open(tester, '角色A');
      final a = tester
          .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
          .controller!;
      await tester.enterText(
        find.byKey(const ValueKey('persona-field-0')),
        '名称草稿A',
      );
      await choose(tester, '角色B');
      final b = tester
          .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
          .controller!;
      expect(b.text, '角色B');
      expect(identical(a, b), isFalse);
      await choose(tester, '角色A');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
            .controller,
        a,
      );
      expect(a.text, '名称草稿A');
      await mount(
        tester,
        PersonaPresentation(
          catalog: PromptsPresentation(cards: [cards[1]], activeCardId: 'b'),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
            .controller,
        b,
      );
      expect(() => a.addListener(() {}), throwsFlutterError);
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-field-0')))
            .controller!
            .text,
        '角色A',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer).hitTestable(), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-input')))
            .controller!
            .text,
        '',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'clear and limit dialogs only project facts and disappear when changing cards',
    (tester) async {
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
          messages: messages,
          limitPromptId: 'limit1',
        ),
      );
      expect(find.text('对话数量已达上限'), findsOneWidget);
      await tester.tap(find.text('去清空'));
      await tester.pumpAndSettle();
      expect(find.text('确定要清空当前角色卡的对话记录吗？此操作不可撤销。'), findsOneWidget);
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'b'),
          messages: messages,
          limitPromptId: 'limit1',
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'generation and message limit disable input without altering the input draft',
    (tester) async {
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('persona-input')),
        '保留输入',
      );
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
          generating: {'a'},
        ),
      );
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('persona-input')),
      );
      expect(input.enabled, isFalse);
      expect(input.controller!.text, '保留输入');
      expect(find.byTooltip('生成中'), findsOneWidget);
      await mount(
        tester,
        PersonaPresentation(
          catalog: const PromptsPresentation(cards: cards, activeCardId: 'a'),
          messages: {
            'a': [
              for (var i = 0; i < 40; i++)
                PersonaMessage(id: '$i', content: '消息$i', time: '12:00:00'),
            ],
          },
        ),
      );
      expect(find.text('40/40'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('persona-input')))
            .enabled,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(() => input.controller!.addListener(() {}), throwsFlutterError);
    },
  );
  testWidgets(
    'host removal dismisses a new character modal while the drawer is open',
    (tester) async {
      await mount(
        tester,
        const PersonaPresentation(
          catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
        ),
      );
      await open(tester, '角色A');
      await choose(tester, '+ 新建角色卡');
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final controller = tester.widget<TextField>(field).controller!;
      await tester.enterText(field, '新角色草稿');
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: Text('外部页面')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('外部页面'), findsOneWidget);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      expect(tester.takeException(), isNull);
    },
  );
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('persona messages drawer and keyboard $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
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
              home: const PersonaGenerationPage(
                snapshot: PersonaPresentation(
                  catalog: PromptsPresentation(cards: cards, activeCardId: 'a'),
                  messages: messages,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
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

        await capture('persona-chat');
        await open(tester, '角色A');
        await capture('persona-drawer');
        final field = find.byKey(const ValueKey('persona-field-7'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, '私人备注草稿');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await capture('persona-fields-keyboard');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('persona-input')),
          '请补充角色的经历',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await capture('persona-input-keyboard');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
