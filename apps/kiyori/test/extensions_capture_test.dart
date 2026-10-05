import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/extensions/presentation/extensions_controller.dart';
import 'package:kiyori/features/extensions/presentation/extensions_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/extension_fixture.dart';
import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

class _Client extends FakeClient {
  @override
  Future<List<ExtensionPackage>> extensionPackages() async => [
    extensionFixture,
  ];
  @override
  Future<ExtensionDetails> extensionDetails(String id, int revision) async =>
      const ExtensionDetails(
        package: extensionFixture,
        authors: ['Kiyori'],
        category: 'AI',
        apiVersion: '1.0',
      );
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(844, 390), 1.0),
    (const Size(1440, 900), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'extensions source geometry and dialogs $size/$scale dark=$dark',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          if (output.isNotEmpty) await loadCaptureFonts(tester);
          final owner = ExtensionsController(() async => _Client());
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: ExtensionsPage(controller: owner, onMenu: () {}),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('插件'));
          await tester.pumpAndSettle();
          expect(find.text('合成包'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'extensions-${size.width}-$scale-$dark',
            );
          }
          await tester.tap(find.text('合成包'));
          await tester.pumpAndSettle();
          expect(find.text('作者：Kiyori'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'extension-details-${size.width}-$scale-$dark',
            );
          }
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'absent');
          await tester.pumpAndSettle();
          expect(find.text('未找到匹配的插件'), findsOneWidget);
          await tester.tap(find.text('Skill'));
          await tester.pumpAndSettle();
          expect(
            (tester.widget(
              find.byType(TextField),
            ) as TextField).controller!.text,
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          owner.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
