import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/replies/reply_preferences_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/custom_emoji_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/emoji_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealReply(
  WidgetTester tester,
  Finder target, {
  bool reverse = false,
}) async {
  for (var i = 0; i < 160; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final rect = tester.getRect(
      find.byKey(const PageStorageKey('reply-preferences')),
    );
    final up = target.evaluate().isEmpty
        ? reverse
        : tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      Offset(0, up ? 120 : -120),
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
        'reply drafts survive scrolling, selfie toggle and nested emoji $size/$scale',
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
                builder: (context) => ReplyPreferencesPage(
                  onCustomEmoji: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomEmojiPage(
                        snapshot: EmojiLibraryPresentation(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final merge = find.byKey(const ValueKey('merge-delay'));
          await revealReply(tester, merge);
          await tester.drag(merge, const Offset(60, 0));
          await tester.pumpAndSettle();
          final value = tester.widget<Slider>(merge).value;
          expect(value, isNot(5000));
          final prompt = find.byKey(const ValueKey('reply-prompt'));
          await revealReply(tester, prompt);
          await tester.enterText(prompt, '回复草稿');
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          final selfie = find
              .ancestor(of: find.text('启用自拍功能'), matching: find.byType(Row))
              .first;
          await revealReply(tester, find.text('启用自拍功能'));
          final selfieSwitch = find.descendant(
            of: selfie,
            matching: find.byType(Switch),
          );
          await revealReply(tester, selfieSwitch);
          await tester.tap(selfieSwitch);
          await tester.pumpAndSettle();
          final appearance = find.byKey(const ValueKey('selfie-prompt'));
          await revealReply(tester, appearance);
          await tester.enterText(appearance, 'portrait draft');
          await tester.pumpAndSettle();
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await revealReply(tester, selfieSwitch);
          await tester.tap(selfieSwitch);
          await tester.pumpAndSettle();
          await tester.tap(selfieSwitch);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(appearance).controller!.text,
            'portrait draft',
          );
          await revealReply(tester, find.text('自定义表情'), reverse: true);
          await tester.tap(find.text('自定义表情'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('添加表情'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await revealReply(tester, prompt, reverse: true);
          expect(tester.widget<TextField>(prompt).controller!.text, '回复草稿');
          await revealReply(tester, merge, reverse: true);
          expect(tester.widget<Slider>(merge).value, value);
          expect(find.text('设置已保存'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
