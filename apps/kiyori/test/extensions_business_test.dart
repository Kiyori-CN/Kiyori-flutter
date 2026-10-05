import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/extensions/presentation/extensions_controller.dart';
import 'package:kiyori/features/extensions/presentation/extensions_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_model_file.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/extension_fixture.dart';

void main() {
  testWidgets(
    'product plugin import toggle details uninstall and reopen use actual Rust owner',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'kiyori-extension-product-',
      );
      final file = File('${root.path}/provider.toolpkg');
      file.writeAsBytesSync(base64Decode(extensionFixtureBytes));
      var runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: '${root.path}/data'),
      ))!;
      var refreshes = 0;
      final owner = ExtensionsController(
        () async => runtime,
        onChanged: () async => refreshes++,
      );
      Future<void> waitUntil(bool Function() ready) async {
        for (var i = 0; i < 600 && !ready(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(ready(), isTrue, reason: owner.error);
        await tester.pump(const Duration(milliseconds: 300));
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: ExtensionsPage(
                controller: owner,
                onMenu: () {},
                picker: WindowsModelFilePicker(
                  extensionPackage: true,
                  select: () async => file.path,
                ),
              ),
            ),
          ),
        );
        await waitUntil(() => owner.loaded);
        expect(find.text('脚本'), findsOneWidget);
        await tester.tap(find.text('插件'));
        await tester.pumpAndSettle();
        expect(find.text('暂无可用插件'), findsOneWidget);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is ShellAction && w.label == '导入外部插件',
          ),
        );
        await waitUntil(() => owner.packages.isNotEmpty);
        expect(owner.packages.single.enabled, isTrue);
        expect(refreshes, 1);
        await tester.tap(
          find.byKey(const ValueKey('extension-toggle-com.kiyori.fixture')),
        );
        await waitUntil(() => !owner.busy && !owner.packages.single.enabled);
        expect((await tester.runAsync(runtime.extensionProviders))!, isEmpty);
        await tester.tap(
          find.byKey(const ValueKey('extension-toggle-com.kiyori.fixture')),
        );
        await waitUntil(() => !owner.busy && owner.packages.single.enabled);
        expect(
          (await tester.runAsync(runtime.extensionProviders))!,
          hasLength(1),
        );
        await tester.tap(find.text('合成包'));
        await waitUntil(
          () => find.textContaining('ToolPkg API：').evaluate().isNotEmpty,
        );
        expect(find.text('外部'), findsOneWidget);
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(find.text('确认删除'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(owner.packages, hasLength(1));
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除').last);
        await waitUntil(() => !owner.busy && owner.packages.isEmpty);
        expect(find.text('暂无可用插件'), findsOneWidget);
        expect(find.text('外部'), findsNothing);
        expect(refreshes, 4);
        expect(file.readAsBytesSync(), base64Decode(extensionFixtureBytes));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(runtime.close);
        runtime = (await tester.runAsync(
          () => NativeRuntimeClient.open(dataDirectory: '${root.path}/data'),
        ))!;
        expect((await tester.runAsync(runtime.extensionPackages))!, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        owner.dispose();
        await tester.runAsync(runtime.close);
        root.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
