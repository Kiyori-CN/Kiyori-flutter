import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_page.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori/features/browser/presentation/browser_settings_page.dart';
import 'package:kiyori/features/speech/presentation/tts_presentation.dart';
import 'package:kiyori/features/speech/presentation/tts_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart';

void main() {
  testWidgets('removing a TTS profile ignores its pending voice selection', (
    tester,
  ) async {
    const a = TtsProfilePresentation(id: 'a', name: '配置甲');
    const b = TtsProfilePresentation(id: 'b', name: '配置乙');
    final profiles = ValueNotifier<List<TtsProfilePresentation>>([a, b]);
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: ValueListenableBuilder(
          valueListenable: profiles,
          builder: (_, value, _) => TtsSettingsPage(
            profiles: value,
            activeId: 'a',
            catalog: const TtsCatalogPresentation(
              systemVoices: [SpeechVoiceOption('v1', '音色甲', locale: 'zh-CN')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await revealStt(tester, find.byTooltip('选择系统音色'));
    await tester.tap(find.byTooltip('选择系统音色'));
    await tester.pumpAndSettle();
    profiles.value = [b];
    await tester.pump();
    await tester.tap(find.text('音色甲 (zh-CN)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('音色甲 (zh-CN)'), findsNothing);
    await revealStt(tester, find.text('配置乙'), reverse: true);
    expect(find.text('配置乙'), findsOneWidget);
  });

  testWidgets(
    'reordering and removing configurations preserves only retained drafts',
    (tester) async {
      const a = ModelConfigPresentation(id: 'a', name: '配置甲');
      const b = ModelConfigPresentation(id: 'b', name: '配置乙');
      final catalog = ValueNotifier<List<ModelConfigPresentation>>([a, b]);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: ValueListenableBuilder(
            valueListenable: catalog,
            builder: (_, value, _) => ModelApiPage(configurations: value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final endpoint = find.byKey(const ValueKey('API端点'));
      await revealModel(tester, endpoint);
      await tester.enterText(endpoint, 'https://draft.example.com');
      final controller = tester.widget<TextField>(endpoint).controller!;
      catalog.value = [b, a];
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(endpoint).controller, same(controller));
      expect(controller.text, 'https://draft.example.com');
      catalog.value = [b];
      await tester.pumpAndSettle();
      catalog.value = [a, b];
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('选择配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('配置甲'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(endpoint).controller,
        isNot(same(controller)),
      );
      expect(
        tester.widget<TextField>(endpoint).controller!.text,
        isNot('https://draft.example.com'),
      );
    },
  );
  testWidgets(
    'hidden shell pages cannot reclaim keyboard focus and retain draft',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const HomeShell()),
      );
      await tester.pumpAndSettle();
      final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
      pager.jumpToPage(2);
      await tester.pumpAndSettle();
      final input = find.byType(TextField).first;
      await tester.enterText(input, '保留输入');
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      pager.jumpToPage(1);
      await tester.pumpAndSettle();
      editable.focusNode.requestFocus();
      await tester.pump();
      expect(editable.focusNode.canRequestFocus, isFalse);
      expect(editable.focusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      editable.focusNode.requestFocus();
      await tester.pump();
      expect(editable.focusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      pager.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '保留输入',
      );
      expect(editable.focusNode.canRequestFocus, isTrue);
    },
  );

  for (final removed in [false, true]) {
    testWidgets('open model menu resolves current identity removed=$removed', (
      tester,
    ) async {
      const a = ModelConfigPresentation(id: 'a', name: '配置甲');
      const b = ModelConfigPresentation(id: 'b', name: '配置乙');
      final catalog = ValueNotifier<List<ModelConfigPresentation>>([a, b]);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: ValueListenableBuilder(
            valueListenable: catalog,
            builder: (_, value, _) => ModelApiPage(configurations: value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('选择配置'));
      await tester.pumpAndSettle();
      catalog.value = removed ? [a] : [b, a];
      await tester.pump();
      await tester.tap(find.text('配置乙').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(removed ? '配置甲' : '配置乙'), findsOneWidget);
    });
  }

  testWidgets('cached model forms suspend hidden focus and ticker activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const ModelApiPage(
          configurations: [
            ModelConfigPresentation(id: 'a', name: '配置甲'),
            ModelConfigPresentation(id: 'b', name: '配置乙'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final old = find.byKey(const ValueKey('API端点'));
    final element = tester.element(old);
    final editable = tester.widget<EditableText>(
      find.descendant(of: old, matching: find.byType(EditableText)),
    );
    await tester.tap(find.byTooltip('选择配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配置乙'));
    await tester.pumpAndSettle();
    editable.focusNode.requestFocus();
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.focusNode.canRequestFocus, isFalse);
    expect(TickerMode.valuesOf(element).enabled, isFalse);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'settings surfaces and selection follow old palette dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
            home: BrowserSettingsPage(onOpen: (_) {}),
          ),
        );
        await tester.pumpAndSettle();
        final expected = dark ? PrimaryPalette.dark : PrimaryPalette.light;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, expected.background);
        final card = find.byType(PrimaryCard).first;
        final material = tester.widget<Material>(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        expect(material.color, expected.card);
        final label = tester.element(find.text('网页浏览器'));
        expect(DefaultTextStyle.of(label).style.color, expected.text);
        expect(
          tester
              .getSize(find.byKey(const Key('settings-detail-header')))
              .height,
          128,
        );
        final badgeKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
            home: Scaffold(
              body: ToneBadge(Icons.person, IconTone.account, key: badgeKey),
            ),
          ),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.person)).color,
          Color(dark ? 0xFF8BDC87 : 0xFF34974E),
        );
        final result = showSettingsSelection(
          badgeKey.currentContext!,
          title: '测试选择',
          current: '甲',
          options: const [SettingsOption('甲', selected: true)],
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check)).color,
          expected.accent,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(await result, isNull);
      },
    );
  }
}
