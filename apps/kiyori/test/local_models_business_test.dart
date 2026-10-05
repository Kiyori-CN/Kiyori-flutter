import 'dart:async';
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
      const partSize = 1024 * 1024;
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
            request.response.contentLength = partSize * 2;
            request.response.add(List<int>.filled(partSize, 97));
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
            request.response.headers.set(
              'content-range',
              'bytes $partSize-${partSize * 2 - 1}/${partSize * 2}',
            );
            request.response.contentLength = partSize;
            request.response.add(List<int>.filled(partSize, 98));
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
            size: BigInt.from(partSize * 2),
            sha256: 'b8f0684e02a2902e2bba1fc2bcf37ee37efd818ed6943fa77faa7580da0a1bfc',
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
        // 服务端flush只证明写出；Rust每1 MiB落盘一次。夹具首段达到真实检查点，
        // 以正式进度同步再暂停，避免固定延迟在并行负载下抢先中断首段读取。
        await tester.runAsync(() async {
          final elapsed = Stopwatch()..start();
          while ((await runtime.transfers()).single.transferred !=
              BigInt.from(partSize)) {
            if (elapsed.elapsed > const Duration(seconds: 10)) {
              throw StateError('首段传输未确认');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        await tester.tap(find.byTooltip('暂停下载'));
        await waitFor(() => find.text('继续下载').evaluate().isNotEmpty);
        final paused = await tester.runAsync(() => runtime.transfers());
        expect(paused!.single.transferred, BigInt.from(partSize));
        expect(paused.single.phase, 'paused');
        gate.complete();
        await tester.tap(find.text('继续下载'));
        await waitFor(() => find.text('下载完成').evaluate().isNotEmpty);
        expect(requests, [null, 'bytes=$partSize-']);
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
