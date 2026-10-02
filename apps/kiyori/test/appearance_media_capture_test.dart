import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_background.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_chat.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_media_presentation.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_nine_slice.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('selected appearance media and slices $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xffd8ecff), BlendMode.src);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 90, 60),
          Paint()
            ..color = const Color(0xff12324a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8,
        );
        for (var x = 8.0; x < 90; x += 12) {
          canvas.drawCircle(
            Offset(x, 30),
            3,
            Paint()..color = const Color(0xff498cb2),
          );
        }
        final picture = recorder.endRecording();
        final image = (await tester.runAsync(() => picture.toImage(90, 60)))!;
        picture.dispose();
        addTearDown(image.dispose);
        final media = AppearanceImagePresentation('fixture', image: image);
        final boundary = GlobalKey();
        final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
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
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          if (output.isNotEmpty) {
            await captureUi(tester, boundary, output, '$name-$suffix');
          }
          expect(tester.takeException(), isNull);
        }

        await mount(
          AppearanceBackground(
            snapshot: AppearanceBackgroundPresentation(
              enabled: true,
              media: media,
            ),
          ),
        );
        await capture('background-image', find.byType(RawImage));
        expect(find.byTooltip('重新裁剪'), findsOneWidget);
        await mount(
          AppearanceBackground(
            snapshot: AppearanceBackgroundPresentation(
              enabled: true,
              video: true,
              media: media,
              opacity: .65,
            ),
          ),
        );
        await capture('background-video', find.byType(RawImage));
        await tester.tap(find.byTooltip('取消静音'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('静音'), findsOneWidget);
        final bubble = AppearanceBubblePresentation(
          media: media,
          enabled: true,
        );
        await mount(
          AppearanceChat(
            snapshot: AppearanceMediaPresentation(
              bubble: true,
              userBubble: bubble,
              aiBubble: bubble,
            ),
          ),
        );
        await capture(
          'bubble-source-grid',
          find.byType(AppearanceSourceGrid).first,
        );
        await capture('bubble-tiled', find.text('样式预览'));
        await mount(
          AppearanceChat(
            snapshot: AppearanceMediaPresentation(
              bubble: true,
              tiled: false,
              userBubble: bubble,
              aiBubble: bubble,
            ),
          ),
        );
        await capture('bubble-stretched', find.text('样式预览'));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
