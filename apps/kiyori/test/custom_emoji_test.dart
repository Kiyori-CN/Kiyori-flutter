import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/replies/custom_emoji_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/emoji_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealEmoji(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 50; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final scroll = find.byType(CustomScrollView).last;
    final rect = tester.getRect(scroll);
    final up =
        target.evaluate().isNotEmpty &&
        tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      Offset(0, up ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'emoji category input and destructive actions stay local $size/$scale',
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
              home: const CustomEmojiPage(
                snapshot: EmojiLibraryPresentation(
                  categories: ['happy', 'custom_set'],
                  targetName: '角色名称',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await revealEmoji(tester, find.text('创建分组'));
          await tester.tap(find.text('创建分组'));
          await tester.pumpAndSettle();
          final input = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(input, 'BAD-name');
          await tester.pumpAndSettle();
          expect(find.text('类别名称只能包含小写字母、数字和下划线'), findsOneWidget);
          await tester.enterText(input, 'GOOD_name');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(input).controller!.text, 'good_name');
          expect(find.text('类别名称只能包含小写字母、数字和下划线'), findsNothing);
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('创建'));
          await tester.pumpAndSettle();
          expect(find.text('新建类别'), findsOneWidget);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await revealEmoji(tester, find.text('happy'));
          await tester.tap(find.text('happy'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('custom_set').last);
          await tester.pumpAndSettle();
          await revealEmoji(tester, find.text('删除分组'));
          await tester.tap(find.text('删除分组'));
          await tester.pumpAndSettle();
          expect(find.text('确认删除类别"custom_set"及其所有表情吗？'), findsOneWidget);
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();
          expect(find.text('删除类别'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await revealEmoji(tester, find.text('恢复默认'));
          await tester.tap(find.text('恢复默认'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('确定重置'));
          await tester.pumpAndSettle();
          expect(find.text('重置为默认表情'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('添加表情'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'all bundled source emoji images decode and preview deletion is inert',
    (tester) async {
      final library = EmojiLibraryPresentation.bundled;
      expect(library.emojis.length, 53);
      await tester.runAsync(() async {
        for (final emoji in library.emojis) {
          final asset = emoji.image as AssetImage;
          final bytes = await rootBundle.load(asset.assetName);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
            targetWidth: 64,
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, greaterThan(0));
          frame.image.dispose();
          codec.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: CustomEmojiPage(snapshot: library),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      final image = find.byType(Image).first;
      await tester.tap(image);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.text('确认删除此表情吗？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除表情'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
