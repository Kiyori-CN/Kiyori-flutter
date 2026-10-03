import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_sections.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/model_pool_test_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  test('pause joins an in-flight save and rejects queued results', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kiyori-pool-save-',
    );
    final runtime = await NativeRuntimeClient.open(
      dataDirectory: directory.path,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final controller = ModelPoolTestController(() async => runtime);
    final saving = Completer<void>(), release = Completer<void>();
    var results = 0, paused = false;
    server.listen((incoming) async {
      await incoming.drain<void>();
      incoming.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      incoming.response.write(
        'data: {"choices":[{"index":0,"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
      );
      await incoming.response.close();
    });
    try {
      final base = (await runtime.modelCatalog()).configs.single.draft;
      final operation = controller.start(
        ModelConfigDraft(
          name: base.name,
          provider: base.provider,
          protocol: 'chat',
          endpoint: 'http://127.0.0.1:${server.port}',
          models: base.models,
          options: base.options,
        ),
        ModelCredentials(
          keys: [
            ModelPoolKey.create('fixture-one'),
            ModelPoolKey.create('fixture-two'),
          ],
        ),
        (_, _) async {
          results++;
          if (!saving.isCompleted) saving.complete();
          await release.future;
        },
      );
      await saving.future.timeout(const Duration(seconds: 5));
      final pause = controller.pause().then((_) => paused = true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(paused, false);
      release.complete();
      await pause.timeout(const Duration(seconds: 5));
      await operation;
      expect(results, 1);
      expect(controller.running, false);
      expect(controller.error, isNull);
    } finally {
      if (!release.isCompleted) release.complete();
      controller.dispose();
      await runtime.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
  testWidgets(
    'pool UI saves real outcomes encrypted, skips tested IDs and clears marks',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Directory.systemTemp.createTempSync(
        'kiyori-pool-business-',
      );
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final server = (await tester.runAsync(
        () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      ))!;
      final catalog = (await tester.runAsync(runtime.modelCatalog))!;
      final store = WindowsSecretStore(Directory('${directory.path}/secrets'));
      final owner = ModelsController(() async => runtime, () async => store);
      final session = ModelEditSession(
        owner,
        catalog.configs.single,
        ModelCredentials(
          usePool: true,
          keys: [
            ModelPoolKey.create('fixture-good'),
            ModelPoolKey.create('fixture-bad'),
            ModelPoolKey.create('fixture-good'),
          ],
        ),
      );
      session.update(
        endpoint: 'http://127.0.0.1:${server.port}',
        protocol: 'chat',
      );
      var requests = 0;
      var stall = false;
      final held = <HttpResponse>[];
      await tester.runAsync(() async {
        server.listen((incoming) async {
          requests++;
          await incoming.drain<void>();
          if (stall) {
            held.add(incoming.response);
            return;
          }
          if (incoming.headers.value('authorization')!.endsWith('bad')) {
            incoming.response.statusCode = 401;
          } else {
            incoming.response.headers.contentType = ContentType(
              'text',
              'event-stream',
              charset: 'utf-8',
            );
            incoming.response.write(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'index': 0,
                    'delta': {'content': 'ok'},
                    'finish_reason': 'stop',
                  },
                ],
              })}\n\ndata: [DONE]\n\n',
            );
          }
          await incoming.response.close();
        });
      });
      Future<void> settleNative(bool Function() done) async {
        for (var i = 0; i < 300 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          done(),
          true,
          reason:
              'requests=$requests running=${session.poolTest.running} '
              'poolError=${session.poolTest.error} saveError=${session.error} '
              'states=${session.credentials.keys.map((k) => k.availability)}',
        );
      }

      try {
        const output = String.fromEnvironment('KIYORI_CAPTURE');
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: KiyoriTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ModelAdvancedCard(session: session),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('开始测试'));
        await settleNative(
          () =>
              requests == 3 &&
              !session.poolTest.running &&
              session.credentials.keys
                      .where((k) => k.availability != 'UNTESTED')
                      .length ==
                  3,
        );
        expect(session.poolTest.error, isNull);
        expect(find.text('可用 2 · 不可用 1 · 未测试 0'), findsOneWidget);
        final saved = (await tester.runAsync(runtime.modelCatalog))!
            .configs
            .single;
        final reopened = (await tester.runAsync(
          () => owner.readCredentials(saved),
        ))!;
        expect(reopened.keys.map((k) => k.availability), [
          'AVAILABLE',
          'UNAVAILABLE',
          'AVAILABLE',
        ]);
        expect(
          String.fromCharCodes(
            File('${directory.path}/secrets/${saved.secretReference}.dpapi')
                .readAsBytesSync(),
          ),
          isNot(contains('fixture-good')),
        );
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'pool-tested-dark');
        }
        await tester.tap(find.text('开始测试'));
        await tester.pump();
        await settleNative(() => !session.poolTest.running);
        expect(requests, 3);
        await tester.tap(find.text('清除测试标记'));
        await tester.pump();
        await tester.pump();
        expect(find.text('可用 0 · 不可用 0 · 未测试 3'), findsOneWidget);
        var flushed = false;
        final saving = session.flush().then((value) {
          flushed = true;
          return value;
        });
        await settleNative(() => flushed);
        expect(await saving, true);
        final cleared = (await tester.runAsync(runtime.modelCatalog))!
            .configs
            .single;
        expect(
          (await tester.runAsync(() => owner.readCredentials(cleared)))!.keys
              .every((k) => k.availability == 'UNTESTED'),
          true,
        );
        // 网络停滞时编辑输入立即使本次结果失效；暂停等待worker结束。
        stall = true;
        await tester.tap(find.text('开始测试'));
        await settleNative(() => requests == 6 && session.poolTest.running);
        session.update(endpoint: 'http://127.0.0.1:${server.port}/changed#');
        session.changed();
        await settleNative(() => !session.poolTest.running);
        expect(
          session.credentials.keys.every((k) => k.availability == 'UNTESTED'),
          true,
        );
        await tester.runAsync(() async {
          for (final response in held) {
            await response.close();
          }
          held.clear();
        });
        await tester.pump();
        expect(find.text('可用 0 · 不可用 0 · 未测试 3'), findsOneWidget);
        // 直接移除宿主也必须取消，不留下无法结束的网络或保存任务。
        await tester.tap(find.text('开始测试'));
        await settleNative(() => requests == 9 && session.poolTest.running);
        await tester.pumpWidget(const SizedBox.shrink());
        await settleNative(() => !session.poolTest.running);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        owner.dispose();
        await tester.runAsync(() async {
          await runtime.close();
          await server.close(force: true);
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
