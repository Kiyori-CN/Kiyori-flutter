import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_capture.dart';

import 'package:kiyori/features/assistant/presentation/models/model_api_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart' show revealModel;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture model API default and expanded surfaces',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      Future<void> capture(String name, {bool animated = false}) =>
          captureUi(tester, boundaryKey, output, name, animated: animated);

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KiyoriTheme.light(),
            home: const ModelApiPage(),
          ),
        ),
      );
      await capture('model-api-phone');
      await tester.tap(find.text('API提供方'));
      await capture('model-providers-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await revealModel(tester, find.text('上下文设置'));
      await capture('model-sections-phone');
      await tester.tap(find.text('上下文设置'));
      await capture('model-context-phone');
      await revealModel(tester, find.text('模型参数设置'));
      await tester.tap(find.text('模型参数设置'));
      await tester.pumpAndSettle();
      await revealModel(tester, find.byTooltip('展开最大生成Token数'));
      await tester.tap(find.byTooltip('展开最大生成Token数'));
      await capture('model-parameters-phone');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KiyoriTheme.dark(),
            home: const ModelApiPage(),
          ),
        ),
      );
      await capture('model-api-dark-phone');
      expect(tester.takeException(), isNull);
    },
  );
}
