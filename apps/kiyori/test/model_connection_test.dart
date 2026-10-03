import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_connection_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_test_results.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  for (final protocol in ['chat', 'responses']) {
    testWidgets(
      'real $protocol probes show independent chat and system results',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final directory = Directory.systemTemp.createTempSync('kiyori-probe-');
        final runtime = (await tester.runAsync(
          () => NativeRuntimeClient.open(dataDirectory: directory.path),
        ))!;
        final server = (await tester.runAsync(
          () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        ))!;
        final catalog = (await tester.runAsync(runtime.modelCatalog))!;
        final test = ModelConnectionTest(() async => runtime);
        var requests = 0;
        await tester.runAsync(() async {
          server.listen((incoming) async {
            requests++;
            final body =
                jsonDecode(await utf8.decoder.bind(incoming).join()) as Map;
            final messages =
                body[protocol == 'chat' ? 'messages' : 'input'] as List;
            expect(
              incoming.uri.path,
              protocol == 'chat' ? '/v1/chat/completions' : '/v1/responses',
            );
            final answer = messages.first['role'] == 'system'
                ? (messages.first['content'] as String).split(' ')[3]
                : '你好';
            incoming.response.headers.contentType = ContentType(
              'text',
              'event-stream',
              charset: 'utf-8',
            );
            if (protocol == 'responses') {
              expect(body['store'], false);
              expect(body['background'], false);
              incoming.response.write(
                'data: ${jsonEncode({'type': 'response.output_text.delta', 'output_index': 0, 'content_index': 0, 'item_id': 'fixture', 'delta': answer})}\n\n',
              );
              incoming.response.write(
                'data: ${jsonEncode({
                  'type': 'response.completed',
                  'response': {
                    'status': 'completed',
                    'output': [
                      {
                        'type': 'message',
                        'role': 'assistant',
                        'id': 'fixture',
                        'content': [
                          {'type': 'output_text', 'text': answer},
                        ],
                      },
                    ],
                  },
                })}\n\n',
              );
            } else {
              incoming.response.write(
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'index': 0,
                      'delta': {'content': answer},
                      'finish_reason': null,
                    },
                  ],
                })}\n\n',
              );
              incoming.response.write(
                'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
              );
            }
            await incoming.response.close();
          });
        });
        try {
          final draft = ModelConfigDraft(
            name: '测试',
            provider: 'OPENAI_GENERIC',
            protocol: protocol,
            endpoint: 'http://127.0.0.1:${server.port}',
            models: const ['fixture'],
            options: catalog.configs.single.draft.options,
          );
          await tester.runAsync(
            () => test.start(draft, const ModelCredentials()),
          );
          expect(requests, 2);
          expect(test.running, false);
          expect(
            test.results!
                .where((item) => item.outcome == ModelTestOutcome.passed)
                .map((item) => item.label),
            ['聊天', '系统指令遵循'],
          );
          expect(
            test.results!
                .singleWhere(
                  (item) =>
                      item.label ==
                      (draft.options.toolCall ? 'Tool Call' : '内置工具调用'),
                )
                .outcome,
            ModelTestOutcome.unverified,
          );
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ModelTestResults(test),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('系统指令遵循'), findsOneWidget);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'model-test-results-$protocol-dark',
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          test.dispose();
          await tester.runAsync(() async {
            await runtime.close();
            await server.close(force: true);
            await directory.delete(recursive: true);
          });
        }
      },
    );
  }
}
