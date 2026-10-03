import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

void main() {
  test(
    'pool tests only enabled untested IDs with bounded real concurrency',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kiyori-pool-ffi-',
      );
      final runtime = await NativeRuntimeClient.open(
        dataDirectory: directory.path,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var active = 0, peak = 0;
      final seen = <String>[];
      server.listen((incoming) async {
        await incoming.drain<void>();
        final key = incoming.headers.value('authorization')!;
        seen.add(key);
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (key.endsWith('bad')) {
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
        active--;
      });
      try {
        final base = (await runtime.modelCatalog()).configs.single.draft;
        final draft = ModelConfigDraft(
          name: base.name,
          provider: base.provider,
          protocol: 'chat',
          endpoint: 'http://127.0.0.1:${server.port}',
          models: const ['fixture'],
          options: base.options,
        );
        final run = await runtime.startPoolTest(
          draft,
          [
            const PoolKey(
              id: 'one',
              key: 'same',
              enabled: true,
              availability: 'UNTESTED',
            ),
            const PoolKey(
              id: 'two',
              key: 'same',
              enabled: true,
              availability: 'UNTESTED',
            ),
            const PoolKey(
              id: 'bad',
              key: 'bad',
              enabled: true,
              availability: 'UNTESTED',
            ),
            const PoolKey(
              id: 'disabled',
              key: 'disabled',
              enabled: false,
              availability: 'UNTESTED',
            ),
            const PoolKey(
              id: 'marked',
              key: 'marked',
              enabled: true,
              availability: 'AVAILABLE',
            ),
          ],
          const [],
          2,
        );
        final events = await run.events.toList();
        final results = {
          for (final event in events.where(
            (e) => e.phase == ChatPhase.poolResult,
          ))
            event.keyId: event.verified,
        };
        expect(results, {'one': true, 'two': true, 'bad': false});
        expect(events.last.phase, ChatPhase.completed);
        expect(seen.length, 3);
        expect(peak, 2);
        expect(active, 0);
      } finally {
        await runtime.close();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test('pool cancellation waits for workers and never labels pending keys unavailable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kiyori-pool-cancel-',
    );
    final runtime = await NativeRuntimeClient.open(
      dataDirectory: directory.path,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final entered = Completer<void>();
    var requests = 0;
    server.listen((incoming) async {
      await incoming.drain<void>();
      requests++;
      if (requests == 2) entered.complete();
    });
    try {
      final base = (await runtime.modelCatalog()).configs.single.draft;
      final draft = ModelConfigDraft(
        name: base.name,
        provider: base.provider,
        protocol: 'chat',
        endpoint: 'http://127.0.0.1:${server.port}',
        models: const ['fixture'],
        options: base.options,
      );
      final run = await runtime.startPoolTest(
        draft,
        [
          for (var i = 0; i < 10; i++)
            PoolKey(
              id: '$i',
              key: 'fixture-$i',
              enabled: true,
              availability: 'UNTESTED',
            ),
        ],
        const [],
        2,
      );
      final events = run.events.toList();
      await entered.future;
      await run.cancel().timeout(const Duration(seconds: 2));
      expect((await events).map((e) => e.phase), [
        ChatPhase.started,
        ChatPhase.cancelled,
      ]);
      expect(requests, 2);
    } finally {
      await runtime.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
