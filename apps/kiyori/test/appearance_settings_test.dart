import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_basic.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_chat.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_bubble_editors.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_background.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_input.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_interface.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_color_picker.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> mount(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: KiyoriTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

Future<void> visible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('five appearance tabs and workspace header $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const AppearanceSettingsPage(),
          ),
        );
        await tester.pumpAndSettle();
        final nested = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        nested.outerController.jumpTo(72);
        await tester.pump();
        expect(
          tester
              .getSize(find.byKey(const Key('settings-workspace-header')))
              .height,
          64,
        );
        for (final tab in ['背景', '聊天', '输入栏', 'AI 界面', '主题']) {
          final label = find.text(tab).first;
          await visible(tester, label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await visible(tester, find.text('聊天').first);
        await tester.tap(find.text('聊天').first);
        await tester.pumpAndSettle();
        await visible(tester, find.text('对话框'));
        await tester.tap(find.text('对话框'));
        await tester.pumpAndSettle();
        await visible(tester, find.text('全局用户名称'));
        await visible(tester, find.byType(TextField));
        await tester.enterText(find.byType(TextField), '界面草稿');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        await visible(tester, find.text('显示对话浮点动画'));
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'appearance input conditional controls and mutually exclusive glass $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await mount(tester, const AppearanceInput());
        expect(find.text('水玻璃输入框'), findsNothing);
        await visible(tester, find.byType(Switch).first);
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        await visible(tester, find.byType(Switch).at(2));
        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();
        await visible(tester, find.byType(Switch).at(3));
        await tester.tap(find.byType(Switch).at(3));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch).at(2)).value, isFalse);
        expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'basic font and background drafts keep external selection empty',
    (tester) async {
      await mount(tester, const AppearanceBasic());
      await visible(tester, find.byType(Switch).last);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      await visible(tester, find.text('自定义文件'));
      await tester.tap(find.text('自定义文件'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('选择字体文件'));
      await tester.tap(find.text('选择字体文件'));
      expect(find.text('设置已保存'), findsNothing);
      await mount(tester, const AppearanceBackground());
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('视频'));
      await tester.pumpAndSettle();
      expect(find.text('选择视频'), findsOneWidget);
      await visible(tester, find.byType(Switch).last);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text('模糊半径: 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('color picker initializes exact color and returns manual draft', (
    tester,
  ) async {
    await mount(tester, const AppearanceInterface());
    await visible(tester, find.text('历史记录图标颜色'));
    await tester.tap(find.text('历史记录图标颜色'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceColorPicker), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#20242A',
    );
    await visible(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), '#F00');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#FF0000',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppearanceColorSelection>(
            find.byType(AppearanceColorSelection).first,
          )
          .color
          .toARGB32(),
      0xFFFF0000,
    );
    expect(find.text('设置已保存'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('bubble drafts update preview and survive style changes', (
    tester,
  ) async {
    await mount(tester, const AppearanceChat());
    await tester.tap(find.text('对话框'));
    await tester.pumpAndSettle();
    final fontEditor = find.byType(AppearanceBubbleFont).first;
    final fontSwitch = find.descendant(
      of: fontEditor,
      matching: find.byType(Switch),
    );
    await visible(tester, fontSwitch);
    await tester.tap(fontSwitch);
    await tester.pumpAndSettle();
    final mono = find.byWidgetPredicate(
      (widget) => widget is Radio<String> && widget.value == '等宽字体 (Monospace)',
    );
    await visible(tester, mono);
    await tester.tap(mono);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('这是用户消息预览')).style!.fontFamily,
      'monospace',
    );
    final imageEditor = find.byType(AppearanceBubbleImage).first;
    final imageSwitch = find.descendant(
      of: imageEditor,
      matching: find.byType(Switch),
    );
    await visible(tester, imageSwitch);
    await tester.tap(imageSwitch);
    await tester.pumpAndSettle();
    final paddingSlider = find
        .descendant(of: imageEditor, matching: find.byType(Slider))
        .at(9);
    await visible(tester, paddingSlider);
    tester.widget<Slider>(paddingSlider).onChanged!(24);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('appearance-user-preview')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 12, 12, 12),
    );
    await visible(tester, find.text('命令框'));
    await tester.tap(find.text('命令框'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('对话框'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('这是用户消息预览')).style!.fontFamily,
      'monospace',
    );
    expect(tester.widget<Switch>(imageSwitch).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
