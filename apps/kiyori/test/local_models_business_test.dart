import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/persistent_local_models_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/fake_runtime.dart';

/// 市场条目是注入的合成目录；下载、Range、文件校验、SQLite重开全部走正式Rust/FFI。
class FixtureClient extends FakeClient {
  FixtureClient(this.runtime, this.spec);
  final NativeRuntimeClient runtime;
  final TransferSpec spec;
  bool failRefresh = false;
  @override
  Future<List<LocalModel>> localModels() async => [
    const LocalModel(
      name: '合成模型',
      sizeGb: .1,
      tags: ['测试'],
      description: '真实传输夹具',
      hasSource: true,
    ),
  ];
  @override
  Future<List<LocalModel>> refreshLocalModels() async {
    if (failRefresh) {
      throw const BridgeError(code: ErrorCode.invalidInput, message: '合成目录失败');
    }
    return localModels();
  }

  @override
  Future<List<TransferSnapshot>> transfers() => runtime.transfers();
  @override
  Future<TransferRun> downloadLocalModel(String name) async =>
      runtime.startTransfer(await runtime.createTransfer(spec));
  @override
  Future<void> deleteTransfer(String id) => runtime.deleteTransfer(id);
}

void main() {
  testWidgets(
    'local model page pauses resumes verifies reopens and confirms deletion through real FFI',
    (tester) async {
      late Directory directory;
      late NativeRuntimeClient runtime;
      late HttpServer server;
      final gate = Completer<void>();
      final requests = <String?>[];
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'kiyori-local-transfer-ui-',
        );
        runtime = await NativeRuntimeClient.open(dataDirectory: directory.path);
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          await request.drain<void>();
          requests.add(request.headers.value('range'));
          request.response.bufferOutput = false;
          request.response.headers.set('etag', '"same"');
          if (requests.length == 1) {
            request.response.contentLength = 6;
            request.response.add(utf8.encode('abc'));
            await request.response.flush();
            await gate.future;
            try {
              await request.response.close();
            } catch (_) {
              /* 客户端已暂停 */
            }
          } else {
            expect(request.headers.value('if-range'), '"same"');
            request.response.statusCode = 206;
            request.response.headers.set('content-range', 'bytes 3-5/6');
            request.response.contentLength = 3;
            request.response.add(utf8.encode('def'));
            await request.response.close();
          }
        });
      });
      final spec = TransferSpec(
        owner: 'mnn:合成模型',
        name: '合成模型',
        files: [
          TransferFile(
            path: 'model.bin',
            url: 'http://127.0.0.1:${server.port}/file',
            size: BigInt.from(6),
            sha256: 'bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721',
          ),
        ],
      );
      var client = FixtureClient(runtime, spec);
      Future<void> waitFor(bool Function() condition) async {
        for (var i = 0; i < 100 && !condition(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(condition(), isTrue);
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: PersistentLocalModelsPage(connect: () async => client),
          ),
        );
        await waitFor(() => find.text('合成模型').evaluate().isNotEmpty);
      }

      try {
        await mount();
        await tester.tap(find.text('开始下载'));
        await waitFor(
          () =>
              requests.length == 1 &&
              find.byTooltip('暂停下载').evaluate().isNotEmpty,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.tap(find.byTooltip('暂停下载'));
        await waitFor(() => find.text('继续下载').evaluate().isNotEmpty);
        final paused = await tester.runAsync(() => runtime.transfers());
        expect(paused!.single.transferred, BigInt.from(3));
        expect(paused.single.phase, 'paused');
        gate.complete();
        await tester.tap(find.text('继续下载'));
        await waitFor(() => find.text('下载完成').evaluate().isNotEmpty);
        expect(requests, [null, 'bytes=3-']);
        // 页面收到completed快照时，事件流的关闭与dispose仍在后续回调中。
        // 让真实FFI与widget虚拟事件循环均结算后，再关闭并重开整个runtime。
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.runAsync(
          () => runtime.close().timeout(const Duration(seconds: 3)),
        );
        await tester.runAsync(() async {
          runtime = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
        });
        client = FixtureClient(runtime, spec)..failRefresh = true;
        await mount();
        expect(find.text('下载完成'), findsOneWidget);
        await tester.tap(find.byTooltip('刷新模型列表'));
        await waitFor(() => find.text('合成目录失败').evaluate().isNotEmpty);
        expect(find.text('合成模型'), findsOneWidget);
        expect(find.text('下载完成'), findsOneWidget);
        await tester.tap(find.byTooltip('删除模型'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '删除'));
        await waitFor(() => find.text('开始下载').evaluate().isNotEmpty);
        expect(await tester.runAsync(() => runtime.transfers()), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await runtime.close().timeout(const Duration(seconds: 3));
          await server.close(force: true);
          await directory.delete(recursive: true);
        });
      }
    },
    skip: !Platform.isWindows,
  );
}
