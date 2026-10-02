import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_page.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/toolbox_settings_fixtures.dart';
import 'support/ui_test_helpers.dart' show reveal;

void main() {
  Future<void> mount(
    WidgetTester tester,
    ToolboxSettingsPresentation snapshot, {
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: ToolboxSettingsPage(snapshot: snapshot),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> groups(WidgetTester tester) async {
    await reveal(tester, find.text('管理分组'));
    await tester.tap(find.text('管理分组'));
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('管理学习'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  test('group names use NFKC, case, whitespace, UTF16 limit and controls', () {
    const group = ToolboxGroupPresentation('custom:a', 'Café 组', []);
    expect(toolboxGroupNameError('  ＣＡＦＥ\u0301   组  ', [group]), '已存在同名分组');
    expect(toolboxGroupNameError('常用工具', []), '已存在同名分组');
    expect(toolboxGroupNameError('😀' * 21, []), '分组名称不能超过 40 个字符');
    expect(toolboxGroupNameError('a\u0000b', []), '分组名称不能包含控制字符');
    expect(toolboxGroupNameError('学习', []), isNull);
  });
  testWidgets(
    'rename draft follows stable identity and removal releases modal',
    (tester) async {
      await mount(tester, toolboxFixture);
      await groups(tester);
      await action(tester, '重命名');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.text, '学习');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
            .onPressed,
        isNotNull,
      );
      await tester.enterText(find.byType(TextField), '学习草稿');
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [toolboxOther, toolboxCustom],
        ),
      );
      expect(controller.text, '学习草稿');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('重命名分组'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(groups: [toolboxOther]),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, toolboxFixture);
      await action(tester, '重命名');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '学习',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saving blocks name input, Back and barrier; error preserves draft',
    (tester) async {
      await mount(tester, toolboxFixture);
      await groups(tester);
      await action(tester, '重命名');
      await tester.enterText(find.byType(TextField), '新草稿');
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [toolboxCustom, toolboxOther],
          saving: true,
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('重命名分组'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [toolboxCustom, toolboxOther],
          error: '保存失败',
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('保存失败'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '新草稿',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [toolboxCustom, toolboxOther],
          saving: true,
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.drag(find.bySemanticsLabel('展开 / 收起'), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('新建分组'), findsOneWidget);
      await mount(tester, toolboxFixture);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('新建分组'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'delete has exact consequence and updates current title and error',
    (tester) async {
      await mount(tester, toolboxFixture);
      await groups(tester);
      await action(tester, '删除分组');
      expect(find.text('删除学习？'), findsOneWidget);
      expect(find.text('该组的工具（包括暂时停用的工具）会移入未分组，不会卸载插件。'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [ToolboxGroupPresentation('custom:learn', '新名称', [])],
          error: '写入失败',
        ),
      );
      expect(find.text('删除新名称？'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('写入失败'),
        ),
        findsOneWidget,
      );
      await mount(tester, const ToolboxSettingsPresentation(groups: []));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'moving searches keywords, filters removed IDs and invalidates targets',
    (tester) async {
      await mount(tester, toolboxFixture);
      await groups(tester);
      await tester.tap(find.text('批量移动工具'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pdf 阅读');
      await tester.pumpAndSettle();
      expect(find.text('文档工作台').hitTestable(), findsOneWidget);
      expect(find.text('命令终端'), findsNothing);
      await tester.tap(find.text('文档工作台').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步 · 1 项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开发调试').hitTestable());
      await tester.pumpAndSettle();
      await mount(
        tester,
        const ToolboxSettingsPresentation(groups: [toolboxCustom]),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '移动 1 项'))
            .onPressed,
        isNull,
      );
      await mount(
        tester,
        const ToolboxSettingsPresentation(groups: [toolboxOther]),
      );
      expect(find.text('移动 0 项'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('新建分组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('open menu is released on removal and host disposal', (
    tester,
  ) async {
    await mount(tester, toolboxFixture);
    await groups(tester);
    await tester.tap(find.byTooltip('管理学习'));
    await tester.pumpAndSettle();
    await mount(
      tester,
      const ToolboxSettingsPresentation(groups: [toolboxOther]),
    );
    expect(find.text('重命名'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(theme: KiyoriTheme.light(), home: const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(find.text('新建分组'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'favorites empty and all-added branches follow catalog and loading',
    (tester) async {
      await mount(
        tester,
        const ToolboxSettingsPresentation(
          groups: [toolboxCustom],
          favorites: [toolboxDocument],
        ),
      );
      await reveal(tester, find.text('常用工具'));
      await tester.tap(find.text('常用工具'));
      await tester.pumpAndSettle();
      expect(find.text('所有可用工具都已添加。'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(groups: [], favorites: []),
      );
      expect(find.text('还没有常用工具，从下方添加。'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(loaded: false),
        settle: false,
      );
      await tester.pump();
      expect(find.text('还没有常用工具，从下方添加。'), findsNothing);
      expect(find.text('所有可用工具都已添加。'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await mount(tester, toolboxFixture);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'clear colors and loading notice project state without mutation',
    (tester) async {
      await mount(
        tester,
        const ToolboxSettingsPresentation(loaded: false, error: '读取失败'),
      );
      expect(find.text('重新读取'), findsOneWidget);
      await mount(tester, toolboxFixture);
      await reveal(tester, find.text('清除自定义颜色'));
      await tester.tap(find.text('清除自定义颜色'));
      await tester.pumpAndSettle();
      expect(find.text('清除所有自定义颜色？'), findsOneWidget);
      await mount(
        tester,
        const ToolboxSettingsPresentation(hasCustomColors: true, saving: true),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('清除所有自定义颜色？'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '清除颜色'))
            .onPressed,
        isNull,
      );
      await mount(
        tester,
        const ToolboxSettingsPresentation(hasCustomColors: true, error: '保存失败'),
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('保存失败'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
