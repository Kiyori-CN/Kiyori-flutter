import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_background.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_bubble_editors.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_chat.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_media_presentation.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_nine_slice.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<ui.Image> appearanceTestImage(
  WidgetTester tester, {
  int width = 9,
  int height = 9,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFF0000), BlendMode.src);
  canvas.drawRect(
    Rect.fromLTWH(width / 3, 0, width / 3, height.toDouble()),
    Paint()..color = Colors.green,
  );
  canvas.drawRect(
    Rect.fromLTWH(width / 3, height / 3, width / 9, height / 3),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final result = await tester.runAsync(() => picture.toImage(width, height));
  picture.dispose();
  return result!;
}

void main() {
  test(
    'bubble projection rejects invalid shape and bounds external parameters',
    () {
      final draft = BubbleImageDraft();
      expect(
        () => draft.read(const AppearanceBubblePresentation(values: [1])),
        throwsArgumentError,
      );
      draft.read(
        const AppearanceBubblePresentation(
          values: [-1, 1, -1, 1, .9, .1, .9, .1, 10, -20, 50],
        ),
      );
      expect(draft.values, [0, .45, 0, .45, .9, .91, .9, .91, 3, 0, 32]);
    },
  );
  const values = [0.0, 0.0, 0.0, 0.0, .35, .65, .35, .65, 1.0, 12.0, 12.0];
  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'nine slice keeps corners and distinguishes tiled from stretched center',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final image = await appearanceTestImage(tester);
      addTearDown(image.dispose);
      final boundary = GlobalKey();
      Future<List<int>> pixels(bool tiled) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 45,
                  height: 27,
                  child: AppearanceNineSlice(
                    image: image,
                    values: values,
                    tiled: tiled,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bytes = await tester.runAsync(() async {
          final rendered =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          rendered.dispose();
          return bytes!;
        });
        return bytes!.buffer.asUint8List().toList();
      }

      final tiled = await pixels(true);
      final stretched = await pixels(false);
      expect(tiled.take(4).toList(), [255, 0, 0, 255]);
      expect(stretched.take(4).toList(), [255, 0, 0, 255]);
      expect(tiled, isNot(stretched));
      List<int> pixel(List<int> bytes, int x, int y) =>
          bytes.sublist((y * 45 + x) * 4, (y * 45 + x + 1) * 4);
      expect(pixel(tiled, 3, 10), pixel(tiled, 6, 10));
      expect(pixel(tiled, 4, 10), isNot(pixel(tiled, 3, 10)));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('tiny image extreme crop and compressed caps stay bounded', (
    tester,
  ) async {
    final image = await appearanceTestImage(tester, width: 1, height: 1);
    addTearDown(image.dispose);
    final geometry = AppearanceSliceGeometry(image, [
      .45,
      .45,
      .45,
      .45,
      .9,
      .91,
      .9,
      .91,
      3,
      0,
      0,
    ]);
    expect(geometry.region(1, 1), const Rect.fromLTWH(0, 0, 1, 1));
    final destination = AppearanceSliceGeometry.destination(3, 40, 60, 3);
    expect(destination[2] - destination[1], greaterThanOrEqualTo(1));
    await mount(
      tester,
      SizedBox(
        width: 3,
        height: 3,
        child: AppearanceNineSlice(
          image: image,
          values: values,
          tiled: true,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'background media changes reset entity draft and keep selection side effect free',
    (tester) async {
      final image = await appearanceTestImage(tester);
      addTearDown(image.dispose);
      await mount(
        tester,
        AppearanceBackground(
          snapshot: AppearanceBackgroundPresentation(
            enabled: true,
            media: AppearanceImagePresentation('one', image: image),
          ),
        ),
      );
      expect(find.byTooltip('重新裁剪'), findsOneWidget);
      await tester.tap(find.byTooltip('重新裁剪'));
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsOneWidget);
      await mount(
        tester,
        AppearanceBackground(
          snapshot: AppearanceBackgroundPresentation(
            enabled: true,
            video: true,
            media: AppearanceImagePresentation('video', image: image),
          ),
        ),
      );
      expect(find.byTooltip('取消静音'), findsOneWidget);
      await tester.tap(find.byTooltip('取消静音'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('静音'), findsOneWidget);
      await mount(
        tester,
        const AppearanceBackground(
          snapshot: AppearanceBackgroundPresentation(enabled: true),
        ),
      );
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('点击选择按钮来添加背景'), findsOneWidget);
      expect(find.byTooltip('静音'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'bubble image removal resets parameters while unrelated snapshot preserves draft',
    (tester) async {
      final image = await appearanceTestImage(tester);
      addTearDown(image.dispose);
      final user = AppearanceBubblePresentation(
        enabled: true,
        media: AppearanceImagePresentation('bubble', image: image),
      );
      await mount(
        tester,
        AppearanceChat(
          snapshot: AppearanceMediaPresentation(bubble: true, userBubble: user),
        ),
      );
      expect(find.text('已选择图片'), findsOneWidget);
      expect(find.byType(AppearanceNineSlice), findsOneWidget);
      final draft = tester
          .widget<AppearanceBubbleImage>(
            find.byType(AppearanceBubbleImage).first,
          )
          .draft;
      draft.values[9] = 24;
      await mount(
        tester,
        AppearanceChat(
          snapshot: AppearanceMediaPresentation(
            bubble: true,
            userBubble: AppearanceBubblePresentation(
              enabled: true,
              media: AppearanceImagePresentation('bubble', image: image),
            ),
            background: const AppearanceBackgroundPresentation(enabled: true),
          ),
        ),
      );
      expect(
        tester
            .widget<AppearanceBubbleImage>(
              find.byType(AppearanceBubbleImage).first,
            )
            .draft
            .values[9],
        24,
      );
      await mount(
        tester,
        const AppearanceChat(
          snapshot: AppearanceMediaPresentation(bubble: true),
        ),
      );
      expect(find.byType(AppearanceNineSlice), findsNothing);
      expect(find.byType(AppearanceSourceGrid), findsNothing);
      expect(
        tester
            .widget<AppearanceBubbleImage>(
              find.byType(AppearanceBubbleImage).first,
            )
            .draft
            .values[9],
        12,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
