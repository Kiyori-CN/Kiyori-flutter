import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_basic.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_bubble_editors.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_chat.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_chat_details.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_media_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  const font = AppearanceFontPresentation(
    enabled: true,
    file: true,
    fileName: '示例字体.ttf',
    family: 'monospace',
  );
  Future<void> visible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'font labels and preview families follow snapshot without font IO',
    (tester) async {
      Future<void> mount(Widget child) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(const AppearanceBasic(snapshot: font));
      expect(find.text('当前字体文件:\n示例字体.ttf'), findsOneWidget);
      await visible(tester, find.text('清除字体'));
      await tester.tap(find.text('清除字体'));
      await tester.pumpAndSettle();
      expect(find.text('当前字体文件:\n示例字体.ttf'), findsOneWidget);
      await mount(
        const AppearanceBasic(
          snapshot: AppearanceFontPresentation(enabled: true, file: true),
        ),
      );
      expect(find.text('清除字体'), findsNothing);
      await mount(
        const AppearanceChat(
          snapshot: AppearanceMediaPresentation(bubble: true, userFont: font),
        ),
      );
      expect(
        tester.widget<Text>(find.text('这是用户消息预览')).style!.fontFamily,
        'monospace',
      );
      final draft = tester
          .widget<AppearanceBubbleFont>(find.byType(AppearanceBubbleFont).first)
          .draft;
      draft.file = false;
      draft.font = '衬线体 (Serif)';
      await mount(
        const AppearanceChat(
          snapshot: AppearanceMediaPresentation(
            bubble: true,
            userFont: font,
            background: AppearanceBackgroundPresentation(enabled: true),
          ),
        ),
      );
      expect(draft.file, isFalse);
      await mount(
        const AppearanceChat(
          snapshot: AppearanceMediaPresentation(bubble: true),
        ),
      );
      expect(
        tester.widget<Text>(find.text('这是用户消息预览')).style!.fontFamily,
        isNull,
      );
      expect(find.text('当前字体文件:\n示例字体.ttf'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'avatar name controller survives media update and accepts changed owner value',
    (tester) async {
      Future<void> mount(AppearanceAvatarPresentation snapshot) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppearanceAvatars(snapshot: snapshot),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(const AppearanceAvatarPresentation(name: '原名称'));
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await visible(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), '草稿名称');
      await mount(
        const AppearanceAvatarPresentation(
          name: '原名称',
          user: AppearanceImagePresentation('avatar'),
        ),
      );
      expect(controller.text, '草稿名称');
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '重置').first,
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '重置').last,
            )
            .onPressed,
        isNull,
      );
      await mount(const AppearanceAvatarPresentation(name: '更新名称'));
      expect(controller.text, '更新名称');
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '重置').first,
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(() => controller.addListener(() {}), throwsFlutterError);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('populated fonts and avatars $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xff90caf9), BlendMode.src);
        final picture = recorder.endRecording();
        final image = (await tester.runAsync(() => picture.toImage(40, 40)))!;
        picture.dispose();
        addTearDown(image.dispose);
        final media = AppearanceImagePresentation('avatar', image: image);
        final boundary = GlobalKey();
        Future<void> mount(Widget child) async {
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
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name, Finder target) async {
          await visible(tester, target);
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

        await mount(const AppearanceBasic(snapshot: font));
        await capture('global-font-file', find.text('自定义字体文件'));
        await mount(
          AppearanceChat(
            snapshot: AppearanceMediaPresentation(
              bubble: true,
              userFont: font,
              avatars: AppearanceAvatarPresentation(
                globalUser: media,
                ai: media,
                name: '已设置名称',
                square: true,
                radius: 12,
              ),
            ),
          ),
        );
        await capture('bubble-font-file', find.text('当前字体文件:\n示例字体.ttf'));
        expect(
          tester.widget<Text>(find.text('这是用户消息预览')).style!.fontFamily,
          'monospace',
        );
        final previews = tester.widgetList<CircleAvatar>(
          find.byType(CircleAvatar),
        );
        expect(previews.every((avatar) => avatar.child is ClipOval), isTrue);
        await capture('selected-avatars', find.byType(AppearanceAvatars));
        final resets = find.descendant(
          of: find.byType(AppearanceAvatars),
          matching: find.widgetWithText(OutlinedButton, '重置'),
        );
        expect(tester.widget<OutlinedButton>(resets.first).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(resets.last).onPressed, isNotNull);
        await visible(tester, resets.last);
        await tester.tap(resets.last);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(resets.last).onPressed, isNotNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
