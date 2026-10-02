import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/assistant/presentation/avatar_settings_page.dart';
import 'package:kiyori/features/assistant/presentation/avatar/avatar_model_editor.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/avatar_fixtures.dart';
import 'support/fake_runtime.dart';
import 'support/ui_test_helpers.dart';

void main() {
  Future<void> mount(WidgetTester tester, AvatarPresentation snapshot) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: AvatarSettingsPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('empty avatar shows real source structure and complete guides', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, const AvatarPresentation());
    expect(find.text('没有可用的模型'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Mood 触发映射'), findsNothing);
    await tap(tester, find.byTooltip('收起'));
    expect(find.text('没有可用的模型'), findsNothing);
    await tap(tester, find.byTooltip('展开'));
    expect(find.text('没有可用的模型'), findsOneWidget);
    await tap(tester, find.byType(Switch));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tap(tester, find.text('如何制作和导入模型?（点击展开）'));
    await tap(tester, find.text('下载旧版编辑器'));
    expect(find.text('访问在线编辑器'), findsOneWidget);
    await tap(tester, find.text('导入结构指南（点击展开）'));
    await reveal(tester, find.textContaining('my_fbx.zip'));
    expect(find.textContaining('avatar.bin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'models switch drafts by identity and stale removal cannot revive values',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, avatarSnapshot);
      await reveal(tester, find.byKey(const ValueKey('avatar-scale')));
      tester
          .widget<Slider>(find.byKey(const ValueKey('avatar-scale')))
          .onChanged!(1.7);
      await tester.pumpAndSettle();
      await tap(tester, find.text('模型甲'));
      await tester.tap(find.text('模型乙').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('avatar-scale')));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('avatar-scale'))).value,
        1,
      );
      await tap(tester, find.text('模型乙'));
      await tester.tap(find.text('模型甲').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('avatar-scale')));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('avatar-scale'))).value,
        1.7,
      );
      await tap(tester, find.text('模型甲'));
      await tester.tap(find.byTooltip('重命名模型甲'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '丢弃草稿');
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await mount(
        tester,
        const AvatarPresentation(models: [avatarB], currentId: 'b'),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => input.addListener(() {}), throwsFlutterError);
      await mount(tester, avatarSnapshot);
      await reveal(tester, find.byKey(const ValueKey('avatar-scale')));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('avatar-scale'))).value,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mood mapping edits local draft and custom modal cancels', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, avatarSnapshot);
    await tester.ensureVisible(find.text('展开').last);
    await tester.tap(find.text('展开').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('生气'));
    final selector = find.byType(PopupMenuButton<String>).first;
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('idle').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AvatarModelEditor>(find.byType(AvatarModelEditor))
          .draft!
          .mappings['angry'],
      'idle',
    );
    await tap(tester, find.text('添加自定义类型'));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '添加'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).first, ' Hello World ');
    await tester.enterText(find.byType(TextField).last, '测试说明');
    await tester.pump();
    expect(find.textContaining('hello_world'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(avatarA.customMoods.length, 1);
    await tap(tester, find.byTooltip('编辑自定义类型'));
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'hello',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('删除自定义类型'));
    expect(find.textContaining('确定删除自定义情绪'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final type in AvatarModelType.values) {
    testWidgets(
      'parameters match ${type.label} and exclude unrelated camera controls',
      (tester) async {
        addTearDown(tester.view.reset);
        await mount(
          tester,
          AvatarPresentation(
            models: [
              AvatarModelPresentation(id: 'one', name: '模型', type: type),
            ],
            currentId: 'one',
          ),
        );
        await reveal(tester, find.byKey(const ValueKey('avatar-scale')));
        expect(
          tester
              .widget<Slider>(find.byKey(const ValueKey('avatar-scale')))
              .value,
          type == AvatarModelType.dragonbones ? .5 : 1,
        );
        final camera =
            type == AvatarModelType.mmd ||
            type == AvatarModelType.gltf ||
            type == AvatarModelType.fbx;
        expect(
          find.byKey(const ValueKey('avatar-pitch')),
          camera ? findsOneWidget : findsNothing,
        );
        if (camera) {
          final distance = tester.widget<Slider>(
            find.byKey(const ValueKey('avatar-distance')),
          );
          expect(distance.max, type == AvatarModelType.gltf ? 10 : 12);
          expect(distance.value, type == AvatarModelType.gltf ? .5 : 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'busy overlay intercepts changes without inventing import success',
    (tester) async {
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const AvatarSettingsPage(
            snapshot: AvatarPresentation(importing: true),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在导入模型...'), findsOneWidget);
      expect(find.text('操作成功'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('removing model closes its animation menu and nested mood form', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, avatarSnapshot);
    await revealAvatar(tester, find.widgetWithText(TextButton, '展开'));
    await tester.tap(find.widgetWithText(TextButton, '展开'));
    await tester.pumpAndSettle();
    final selector = find.byType(PopupMenuButton<String>).first;
    await revealAvatar(tester, selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    await mount(
      tester,
      const AvatarPresentation(models: [avatarB], currentId: 'b'),
    );
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    await mount(tester, avatarSnapshot);
    await revealAvatar(tester, find.widgetWithText(TextButton, '展开'));
    await tester.tap(find.widgetWithText(TextButton, '展开'));
    await tester.pumpAndSettle();
    await revealAvatar(tester, find.text('添加自定义类型'));
    await tester.tap(find.text('添加自定义类型'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'pending');
    final controller = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!;
    await mount(tester, const AvatarPresentation());
    expect(find.byType(AlertDialog), findsNothing);
    expect(() => controller.addListener(() {}), throwsFlutterError);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('avatar dialogs fit $size with large text and keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AvatarSettingsPage(snapshot: avatarSnapshot),
        ),
      );
      await tester.pumpAndSettle();
      await revealAvatar(tester, find.widgetWithText(TextButton, '展开'));
      await tester.tap(find.widgetWithText(TextButton, '展开'));
      await tester.pumpAndSettle();
      await revealAvatar(tester, find.text('添加自定义类型'));
      await tester.tap(find.text('添加自定义类型'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'abc');
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('settings avatar route returns to original assistant settings', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await tap(tester, find.text('AI 助手'));
    await tap(tester, find.text('虚拟形象'));
    expect(find.byType(AvatarSettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('个性化与交互'), findsOneWidget);
    expect(find.byType(AvatarSettingsPage), findsNothing);
  });
}
