import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/profile/markdown_syntax.dart';
import 'package:kiyori/features/assistant/presentation/profile/profile_markdown_preview.dart';
import 'package:kiyori/features/assistant/presentation/profile/user_profile_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  testWidgets(
    'profile preserves over-limit Unicode source and disables saving',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const UserProfilePage()),
      );
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();
      expect(find.text('user.md 目前为空，填写内容后可在这里预览。'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('user-md-editor'));
      final source = '${'中' * 11999}😀尾';
      await tester.enterText(editor, source);
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(editor).controller!;
      expect(controller.text, source);
      expect(find.text('12002 / 12000'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('保存'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      controller.text = '中😀';
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('保存'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'profile preview renders nested lists, irregular tables and code without I/O',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const source =
          '# 标题\n\n> 引用 **加粗**\n\n- [x] 项目\n  - 嵌套\n\n| A | B |\n| - | - |\n| 短 |\n| 一 | 二 | 多余 |\n\n```dart\nfinal example = "code";\n```\n\n![示例图片](https://example.invalid/a.png)\n\n[链接](https://example.invalid)';
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: ProfileMarkdownPreview(text: source)),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -240));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: ProfileMarkdownPreview(text: '新的正文')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('新的正文'), findsOneWidget);
      expect(find.text('标题'), findsNothing);
    },
  );
  test('markdown source offsets cover fences, comments, links and malformed runs', () {
    const source =
        '# 标题\r\n- [x] **重点** [链接](https://example.com/a(b))\n```dart\n*raw*\n```\n<!-- comment\nend --> `code`\nfoo_bar_baz\n';
    final ranges = scanMarkdownSyntax(source);
    final selected = {
      for (final range in ranges)
        source.substring(range.start, range.end): range.kind,
    };
    expect(selected['标题'], MarkdownSyntaxKind.heading);
    expect(selected['[x]'], MarkdownSyntaxKind.marker);
    expect(selected['**重点**'], MarkdownSyntaxKind.emphasis);
    expect(selected['[链接](https://example.com/a(b))'], MarkdownSyntaxKind.link);
    expect(selected['*raw*'], MarkdownSyntaxKind.code);
    expect(selected['end -->'], MarkdownSyntaxKind.comment);
    expect(selected['`code`'], MarkdownSyntaxKind.code);
    expect(selected.containsKey('_bar_'), isFalse);
    final hostile = '${'[' * 12000}\n${'`' * 12000}\n<!--\n${'x' * 12000}';
    final result = scanMarkdownSyntax(hostile);
    var end = 0;
    for (final range in result) {
      expect(range.start, greaterThanOrEqualTo(end));
      expect(range.end, lessThanOrEqualTo(hostile.length));
      end = range.end;
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'profile draft preview reset keyboard and discard $size/$scale',
        (tester) async {
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const UserProfilePage(
                          snapshot: UserProfilePresentation(
                            archive: '# 旧资料\n内容',
                          ),
                        ),
                      ),
                    ),
                    child: const Text('打开资料'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开资料'));
          await tester.pumpAndSettle();
          final editor = find.byKey(const ValueKey('user-md-editor'));
          await tester.ensureVisible(editor);
          await tester.pumpAndSettle();
          await tester.enterText(
            editor,
            '# 关于我\n\n**喜欢阅读**，请用中文回答。\n\n- 习惯一\n- 习惯二',
          );
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.ensureVisible(find.text('预览'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('预览'));
          await tester.pumpAndSettle();
          expect(find.text('未保存'), findsOneWidget);
          await tester.ensureVisible(find.text('保存'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(find.text('未保存'), findsOneWidget);
          await tester.ensureVisible(find.text('编辑'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('编辑'));
          await tester.pumpAndSettle();
          final controller = tester.widget<TextField>(editor).controller!;
          expect(controller.text, contains('喜欢阅读'));
          controller.value = controller.value.copyWith(
            selection: const TextSelection.collapsed(offset: 3),
            composing: const TextRange(start: 2, end: 4),
          );
          await tester.pumpAndSettle();
          expect(
            controller
                .buildTextSpan(
                  context: tester.element(editor),
                  withComposing: true,
                )
                .toPlainText(),
            controller.text,
          );
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(editor);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('放弃未保存的修改？'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('更多'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('更多'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('旧档案'));
          await tester.pumpAndSettle();
          expect(find.text('legacy-user-profiles.md'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'archive drawer');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('更多'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('更多'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('恢复默认模板'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'reset dialog');
          await tester.tap(find.text('恢复默认模板'));
          await tester.pumpAndSettle();
          expect(controller.text, isEmpty);
          await tester.ensureVisible(editor);
          await tester.pumpAndSettle();
          await tester.enterText(editor, '修改');
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.text('放弃修改'));
          await tester.pumpAndSettle();
          expect(find.text('打开资料'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
