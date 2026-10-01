import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';

import 'app_test.dart' show FakeClient;

// 可选人工视觉证据，字体只在本机加载，不分发系统字体或生成黄金图基线。
void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  const fontPath = String.fromEnvironment(
    'KIYORI_CAPTURE_FONT',
    defaultValue: 'C:/Windows/Fonts/msyh.ttc',
  );
  testWidgets(
    'capture actual Flutter shell for visual review',
    skip: output.isEmpty,
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await File(fontPath).readAsBytes();
        final font = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final boundaryKey = GlobalKey();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: KiyoriApp(connect: () async => FakeClient()),
        ),
      );
      await tester.runAsync(() async {
        final context = boundaryKey.currentContext!;
        await precacheImage(
          const AssetImage('assets/branding/kiyori-app-icon.png'),
          context,
        );
        for (final name in [
          'nav_home',
          'nav_globe',
          'nav_apps',
          'nav_folder',
          'tool_settings',
        ]) {
          for (final suffix in [
            '',
            '_selected_fill',
            if (name == 'tool_settings') '_selected_detail',
          ]) {
            await precacheImage(
              AssetImage('assets/navigation/$name$suffix.png'),
              context,
            );
          }
        }
      });
      await capture('home-phone');
      await tester.drag(find.byType(PageView), const Offset(330, 0));
      await capture('minus-one-phone');
      await tester.tap(find.bySemanticsLabel('关闭负一屏'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-330, 0));
      await capture('chat-phone');
      await tester.dragFrom(const Offset(180, 350), const Offset(330, 0));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 800);
      await capture('home-desktop');
      expect(tester.takeException(), isNull);
    },
  );
}
