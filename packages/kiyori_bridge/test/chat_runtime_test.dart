import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

ChatRequest request(int port, {int timeout = 3000}) => ChatRequest(
  protocol: 'chat',
  endpoint: 'http://127.0.0.1:$port',
  model: 'fixture',
  apiKey: 'local-fixture',
  headers: const [],
  messages: const [ChatMessage(role: 'user', content: 'Hi')],
  parameters: '{}',
  timeoutMs: timeout,
);

void main() {
  test(
    'real FFI sends stream request, delivers text usage and one terminal',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final runtime = await NativeRuntimeClient.open();
      final handled = Completer<void>();
      server.listen((incoming) async {
        expect(incoming.uri.path, '/v1/chat/completions');
        expect(incoming.headers.value('authorization'), 'Bearer local-fixture');
        final body =
            jsonDecode(await utf8.decoder.bind(incoming).join()) as Map;
        expect(body['stream'], true);
        incoming.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        for (final data in [
          {
            'choices': [
              {
                'index': 0,
                'delta': {'content': '真实流'},
                'finish_reason': null,
              },
            ],
          },
          {
            'choices': [
              {'index': 0, 'delta': {}, 'finish_reason': 'stop'},
            ],
          },
          {
            'choices': [],
            'usage': {
              'prompt_tokens': 1,
              'completion_tokens': 2,
              'total_tokens': 3,
            },
          },
        ]) {
          incoming.response.write('data: ${jsonEncode(data)}\n\n');
          await incoming.response.flush();
        }
        incoming.response.write('data: [DONE]\n\n');
        await incoming.response.close();
        handled.complete();
      });
      try {
        final run = await runtime.startChat(request(server.port));
        final events = await run.events.toList();
        expect(events.map((e) => e.phase), [
          ChatPhase.started,
          ChatPhase.text,
          ChatPhase.usage,
          ChatPhase.completed,
        ]);
        expect(events[1].text, '真实流');
        expect(events[2].totalTokens, BigInt.from(3));
        await run.cancel();
        await handled.future;
      } finally {
        await runtime.close();
        await server.close(force: true);
      }
    },
  );

  test(
    'cancel stalled stream and close never-subscribed run without hanging',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final runtime = await NativeRuntimeClient.open();
      final arrived = Completer<void>();
      server.listen((incoming) async {
        await incoming.drain<void>();
        if (!arrived.isCompleted) arrived.complete();
      });
      try {
        final run = await runtime.startChat(request(server.port));
        final events = run.events.toList();
        await arrived.future;
        await run.cancel();
        expect((await events).last.phase, ChatPhase.cancelled);
        await runtime.startChat(request(server.port));
        await runtime.close().timeout(const Duration(seconds: 3));
        expect(
          () => runtime.startChat(request(server.port)),
          throwsA(isA<BridgeError>()),
        );
      } finally {
        await runtime.close();
        await server.close(force: true);
      }
    },
  );

  test('timeout has a stable redacted error and does not retry', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final runtime = await NativeRuntimeClient.open();
    var count = 0;
    server.listen((incoming) async {
      count++;
      await incoming.drain<void>();
    });
    try {
      final run = await runtime.startChat(request(server.port, timeout: 100));
      final events = await run.events.toList();
      expect(events.last.phase, ChatPhase.failed);
      expect(events.last.errorKind, 'Timeout');
      expect(count, 1);
    } finally {
      await runtime.close();
      await server.close(force: true);
    }
  });
}
