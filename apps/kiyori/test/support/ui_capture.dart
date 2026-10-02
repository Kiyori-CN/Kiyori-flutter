import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本机视觉证据共用字体与释放流程；输出不作为未经设备对照的黄金基线。
Future<void> loadCaptureFonts(WidgetTester tester) async {
  const configured = String.fromEnvironment('KIYORI_CAPTURE_FONT');
  final path = configured.isNotEmpty
      ? configured
      : Platform.isWindows
      ? 'C:/Windows/Fonts/msyh.ttc'
      : '';
  if (path.isEmpty || !File(path).existsSync()) {
    throw StateError('Set KIYORI_CAPTURE_FONT to an existing local CJK font.');
  }
  await tester.runAsync(() async {
    final bytes = ByteData.sublistView(await File(path).readAsBytes());
    final font = FontLoader('Roboto')..addFont(Future.value(bytes));
    if (Platform.isWindows) {
      for (final fallback in [
        'C:/Windows/Fonts/seguiemj.ttf',
        'C:/Windows/Fonts/malgun.ttf',
      ]) {
        final file = File(fallback);
        if (await file.exists()) {
          font.addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        }
      }
    }
    await font.load();
    await (FontLoader('monospace')..addFont(Future.value(bytes))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> captureUi(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String output,
  String name, {
  bool animated = false,
}) async {
  final previous = debugDisableShadows;
  debugDisableShadows = false;
  try {
    if (animated) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    // pumpAndSettle 只等待框架帧，不保证文件图片的异步解码完成。
    // 等待实际可见 Image 的首帧，避免首次截图漏掉设置页的 PNG 图标。
    final images = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in images) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('PNG encoding failed: $name');
        await Directory(output).create(recursive: true);
        await File('$output/$name.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
  } finally {
    debugDisableShadows = previous;
  }
}
