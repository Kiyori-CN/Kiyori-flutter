import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/gguf_import_dialog.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'support/fake_runtime.dart';

class _Import extends FakeClient {
  final operation = _Operation();
  @override
  Future<ModelImportRun> beginModelImport(String name) async => operation;
}

class _Operation implements ModelImportRun {
  int bytes = 0;
  bool closed = false;
  final finishGate = Completer<String>();
  @override
  Future<BigInt> append(List<int> chunk) async =>
      BigInt.from(bytes += chunk.length);
  @override
  Future<String> finish() => finishGate.future;
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
  bool closed = false, first = true;
  final waiting = Completer<Uint8List>();
  @override
  String get name => 'fixture.gguf';
  @override
  Future<Uint8List> read() async {
    if (first) {
      first = false;
      return Uint8List.fromList([1, 2, 3]);
    }
    return block ? waiting.future : Uint8List(0);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (block && !waiting.isCompleted) waiting.complete(Uint8List(0));
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Import runtime,
    _Source? source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (_) => GgufImportDialog(
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
    'cancelled selection and partial read release resources before closing',
    (tester) async {
      await open(tester, _Import(), null);
      await tester.pumpAndSettle();
      expect(find.text('导入 GGUF 模型'), findsNothing);
      final runtime = _Import(), source = _Source(block: true);
      await open(tester, runtime, source);
      expect(find.text('正在导入 fixture.gguf'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(source.closed, isTrue);
      expect(runtime.operation.closed, isTrue);
      expect(runtime.operation.bytes, 3);
      expect(find.text('导入 GGUF 模型'), findsNothing);
    },
  );
  testWidgets('atomic completion cannot report cancellation during commit', (
    tester,
  ) async {
    final runtime = _Import(), source = _Source();
    await open(tester, runtime, source);
    expect(find.text('正在校验并保存模型'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('导入 GGUF 模型'), findsOneWidget);
    runtime.operation.finishGate.complete('fixture.gguf');
    await tester.pumpAndSettle();
    expect(source.closed, isTrue);
    expect(runtime.operation.closed, isTrue);
    expect(find.text('导入 GGUF 模型'), findsNothing);
  });
}
