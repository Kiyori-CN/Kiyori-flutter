import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/extensions/presentation/extension_import_dialog.dart';
import 'package:kiyori/features/extensions/presentation/extensions_controller.dart';
import 'package:kiyori/features/extensions/presentation/extensions_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/extension_fixture.dart';
import 'support/fake_runtime.dart';

class _Runtime extends FakeClient {
  final operation = _Operation();
  bool failChange = false;
  int writes = 0;
  List<ExtensionPackage> packages = [extensionFixture];
  @override
  Future<List<ExtensionPackage>> extensionPackages() async => packages;
  @override
  Future<ExtensionDetails> extensionDetails(String id, int revision) async =>
      const ExtensionDetails(
        package: extensionFixture,
        authors: [],
        category: '',
        apiVersion: '1.0',
      );
  @override
  Future<ExtensionImportRun> beginExtensionImport() async => operation;
  @override
  Future<int> changeExtension(String id, int revision, {bool? enabled}) async {
    ++writes;
    if (failChange) throw StateError('private failure');
    packages = [];
    return revision + 1;
  }
}

class _Operation implements ExtensionImportRun {
  final completion = Completer<ExtensionPackage>();
  bool closed = false, finishing = false;
  @override
  Future<BigInt> append(List<int> bytes) async => BigInt.from(bytes.length);
  @override
  Future<ExtensionPackage> finish() {
    finishing = true;
    return completion.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _Picker implements ModelFilePicker {
  _Picker(this.source);
  final _Source? source;
  @override
  Future<ModelFileSource?> select() async => source;
}

class _Source implements ModelFileSource {
  _Source({this.block = false});
  final bool block;
  final pending = Completer<Uint8List>();
  bool first = true, closed = false;
  @override
  String get name => 'fixture.toolpkg';
  @override
  Future<Uint8List> read() async {
    if (first) {
      first = false;
      return Uint8List.fromList([1, 2, 3]);
    }
    return block ? pending.future : Uint8List(0);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!pending.isCompleted) pending.complete(Uint8List(0));
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Runtime runtime,
    _Source? source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<ExtensionPackage>(
              context: context,
              barrierDismissible: false,
              builder: (_) => ExtensionImportDialog(
                connect: () async => runtime,
                picker: _Picker(source),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'import cancellation waits for source and staging release without finish',
    (tester) async {
      final runtime = _Runtime(), source = _Source(block: true);
      await open(tester, runtime, source);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(source.closed, isTrue);
      expect(runtime.operation.closed, isTrue);
      expect(runtime.operation.finishing, isFalse);
      expect(find.byType(ExtensionImportDialog), findsNothing);
    },
  );
  testWidgets(
    'failed finish releases handles and keeps original failure visible',
    (tester) async {
      final runtime = _Runtime(), source = _Source();
      await open(tester, runtime, source);
      runtime.operation.completion.completeError(
        const BridgeError(code: ErrorCode.invalidInput, message: '扩展ZIP路径无效'),
      );
      await tester.pumpAndSettle();
      expect(source.closed, isTrue);
      expect(runtime.operation.closed, isTrue);
      expect(find.text('扩展ZIP路径无效'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(ExtensionImportDialog), findsNothing);
    },
  );
  testWidgets('picker cancellation leaves package owner untouched', (
    tester,
  ) async {
    final runtime = _Runtime();
    await open(tester, runtime, null);
    await tester.pumpAndSettle();
    expect(runtime.operation.closed, isFalse);
    expect(runtime.operation.finishing, isFalse);
    expect(find.byType(ExtensionImportDialog), findsNothing);
  });
  testWidgets(
    'failed toggle restores facts and upgraded entity closes all old modals',
    (tester) async {
      final runtime = _Runtime()..failChange = true;
      final owner = ExtensionsController(() async => runtime);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: ExtensionsPage(controller: owner, onMenu: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('插件'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('extension-toggle-${extensionFixture.id}')),
      );
      await tester.pumpAndSettle();
      expect(owner.packages.single.enabled, isTrue);
      expect(find.text('扩展操作未完成，请重新加载后重试'), findsOneWidget);
      await tester.tap(find.text('合成包'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsOneWidget);
      runtime.packages = [
        ExtensionPackage(
          id: extensionFixture.id,
          revision: 2,
          version: '2.0.0',
          name: '新版',
          description: '',
          enabled: true,
          resourceId: 'new',
          archiveHash: 'new',
          sourceHash: 'new',
          cleanupPending: 0,
        ),
      ];
      await owner.load();
      await tester.pumpAndSettle();
      expect(find.text('确认删除'), findsNothing);
      expect(find.text('外部'), findsNothing);
      expect(find.text('新版'), findsOneWidget);
      expect(runtime.writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      owner.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
