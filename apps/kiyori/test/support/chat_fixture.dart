import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';

class ChatFixture {
  late Directory directory;
  late NativeRuntimeClient runtime;
  late WindowsSecretStore secrets;
  late ModelsController models;
  late ChatController chat;
  late HttpServer server;
  final requests = <Map<String, dynamic>>[];
  Completer<void>? gate;
  bool fail = false;
  Map<String, Object?>? usage;
  List<String>? chunks;
  String answer = '合成回复：**你好**\n\n```dart\nprint("hello");\n```';
  String? summaryModel;
  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('kiyori-chat-ui-');
    runtime = await NativeRuntimeClient.open(dataDirectory: directory.path);
    secrets = WindowsSecretStore(Directory('${directory.path}/secrets'));
    models = ModelsController(() async => runtime, () async => secrets);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(
        Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        ),
      );
      expect(
        request.headers.value('authorization'),
        requests.last['model'] == summaryModel
            ? 'Bearer summary-fixture'
            : 'Bearer synthetic-fixture',
      );
      expect(request.uri.path, '/v1/chat/completions');
      request.response.bufferOutput = false;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      if (fail) {
        request.response.statusCode = 401;
        await request.response.close();
        return;
      }
      if (requests.last['stream'] == false) {
        request.response.headers.contentType = ContentType.json;
        if (gate != null) await gate!.future;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': answer},
                'finish_reason': 'stop',
              },
            ],
            'usage': {
              'prompt_tokens': 7,
              'completion_tokens': 9,
              'total_tokens': 16,
            },
          }),
        );
        await request.response.close();
        return;
      }
      for (final chunk in chunks ?? [answer]) {
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': {'content': chunk},
                'finish_reason': null,
              },
            ],
          })}\n\n',
        );
        await request.response.flush();
        if (chunks != null) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      }
      if (gate != null) await gate!.future;
      if (usage != null) {
        request.response.write(
          'data: ${jsonEncode({'choices': [], 'usage': usage})}\n\n',
        );
      }
      request.response.write(
        'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
      );
      await request.response.close();
    });
    await models.load();
    final base = models.catalog!.configs.single;
    await models.save(
      base,
      ModelConfigDraft(
        name: '合成服务',
        provider: 'OPENAI_GENERIC',
        protocol: 'chat',
        endpoint: 'http://127.0.0.1:${server.port}',
        models: ['first-model', 'second-model'],
        options: base.draft.options,
      ),
      const ModelCredentials(),
      const ModelCredentials(apiKey: 'synthetic-fixture'),
      replacement: 'first-model',
    );
    await models.select('chat', 'default', 'second-model');
    chat = ChatController(() async => runtime, () async => secrets);
    await chat.load();
  }

  Future<void> close() async {
    if (gate != null && !gate!.isCompleted) gate!.complete();
    await chat.shutdown().timeout(const Duration(seconds: 5));
    chat.dispose();
    models.dispose();
    await runtime.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}

Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    done(),
    isTrue,
    reason: 'native operation should reach the expected state',
  );
}
