import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_connection_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori/features/assistant/presentation/models/model_test_results.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

List<Map<String, Object?>> toolFrames(String protocol) => switch (protocol) {
  'chat' => [
    {
      'choices': [
        {
          'index': 0,
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': 'call-fixture',
                'function': {'name': 'echo', 'arguments': '{"text":"ping"}'},
              },
            ],
          },
          'finish_reason': 'tool_calls',
        },
      ],
    },
  ],
  'responses' => [
    {
      'type': 'response.output_item.added',
      'output_index': 0,
      'item': {
        'type': 'function_call',
        'id': 'item-fixture',
        'call_id': 'call-fixture',
        'name': 'echo',
        'arguments': '',
      },
    },
    {
      'type': 'response.function_call_arguments.delta',
      'output_index': 0,
      'item_id': 'item-fixture',
      'delta': '{"text":"ping"}',
    },
    {
      'type': 'response.completed',
      'response': {
        'status': 'completed',
        'output': [
          {
            'type': 'function_call',
            'id': 'item-fixture',
            'call_id': 'call-fixture',
            'name': 'echo',
            'arguments': '{"text":"ping"}',
          },
        ],
      },
    },
  ],
  'messages' => [
    {'type': 'message_start'},
    {
      'type': 'content_block_start',
      'index': 0,
      'content_block': {
        'type': 'tool_use',
        'id': 'call-fixture',
        'name': 'echo',
        'input': {'text': 'ping'},
      },
    },
    {'type': 'content_block_stop', 'index': 0},
    {
      'type': 'message_delta',
      'delta': {'stop_reason': 'tool_use'},
    },
    {'type': 'message_stop'},
  ],
  _ => [
    {
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'functionCall': {
                  'name': 'echo',
                  'args': {'text': 'ping'},
                },
              },
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    },
  ],
};

void main() {
  for (final (protocol, nativeTools) in [
    for (final protocol in ['chat', 'responses', 'messages', 'native'])
      for (final nativeTools in [true, false]) (protocol, nativeTools),
  ]) {
    testWidgets(
      'real $protocol/$nativeTools probes verify chat tool continuation and system',
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
        final keys = <String>[];
        await tester.runAsync(() async {
          server.listen((incoming) async {
            requests++;
            keys.add(
              incoming.headers.value(switch (protocol) {
                    'messages' => 'x-api-key',
                    'native' => 'x-goog-api-key',
                    _ => 'authorization',
                  }) ??
                  '',
            );
            final body =
                jsonDecode(await utf8.decoder.bind(incoming).join()) as Map;
            final messages =
                body[switch (protocol) {
                      'responses' => 'input',
                      'native' => 'contents',
                      _ => 'messages',
                    }]
                    as List;
            expect(incoming.uri.path, switch (protocol) {
              'chat' => '/v1/chat/completions',
              'messages' => '/v1/messages',
              'native' =>
                '/v1beta/models/${catalog.configs.single.draft.models.first}:streamGenerateContent',
              _ => '/v1/responses',
            });
            String? system;
            if (protocol == 'native' && body['systemInstruction'] != null) {
              system =
                  body['systemInstruction']['parts'].first['text'] as String;
            } else if (protocol == 'messages' && body['system'] != null) {
              system = body['system'].first['text'] as String;
            } else if (!['messages', 'native'].contains(protocol) &&
                messages.first['role'] == 'system') {
              system = messages.first['content'] as String;
            }
            final toolTest = system?.startsWith('Call echo') == true;
            String? toolResult;
            if (toolTest) {
              final last = messages.last;
              if (nativeTools) {
                toolResult = switch (protocol) {
                  'chat' =>
                    last['role'] == 'tool' ? last['content'] as String : null,
                  'responses' =>
                    last['type'] == 'function_call_output'
                        ? last['output'] as String
                        : null,
                  'messages' =>
                    last['content'].first['type'] == 'tool_result'
                        ? last['content'].first['content'] as String
                        : null,
                  _ =>
                    last['parts']
                            .first['functionResponse']?['response']['result']
                        as String?,
                };
              } else {
                final text = switch (protocol) {
                  'native' => last['parts'].first['text'] as String,
                  'messages' => last['content'].first['text'] as String,
                  _ => last['content'] as String,
                };
                if (text.startsWith('<tool_result')) {
                  toolResult = text.split('>')[1].split('<').first;
                }
              }
            }
            final answer =
                toolResult ??
                (toolTest && !nativeTools
                    ? '<tool name="echo"><param name="text">ping</param></tool>'
                    : protocol == 'native' && body['systemInstruction'] != null
                    ? (body['systemInstruction']['parts'].first['text']
                              as String)
                          .split(' ')[3]
                    : protocol == 'messages' && body['system'] != null
                    ? (body['system'].first['text'] as String).split(' ')[3]
                    : messages.first['role'] == 'system'
                    ? (messages.first['content'] as String).split(' ')[3]
                    : '你好');
            incoming.response.headers.contentType = ContentType(
              'text',
              'event-stream',
              charset: 'utf-8',
            );
            if (toolTest && nativeTools && toolResult == null) {
              for (final event in toolFrames(protocol)) {
                incoming.response.write('data: ${jsonEncode(event)}\n\n');
              }
              if (protocol == 'chat') {
                incoming.response.write('data: [DONE]\n\n');
              }
            } else if (protocol == 'responses') {
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
            } else if (protocol == 'native') {
              expect(incoming.uri.query, 'alt=sse');
              expect(incoming.headers.value('authorization'), isNull);
              expect(body.containsKey('stream'), false);
              incoming.response.write(
                'data: ${jsonEncode({
                  'candidates': [
                    {
                      'index': 0,
                      'content': {
                        'parts': [
                          {'text': answer},
                        ],
                      },
                      'finishReason': 'STOP',
                    },
                  ],
                })}\n\n',
              );
            } else if (protocol == 'messages') {
              expect(body['max_tokens'], 4096);
              expect(incoming.headers.value('anthropic-version'), '2023-06-01');
              expect(incoming.headers.value('authorization'), isNull);
              for (final event in [
                {
                  'type': 'message_start',
                  'message': {
                    'usage': {'input_tokens': 3, 'output_tokens': 0},
                  },
                },
                {
                  'type': 'content_block_start',
                  'index': 0,
                  'content_block': {'type': 'text', 'text': ''},
                },
                {
                  'type': 'content_block_delta',
                  'index': 0,
                  'delta': {'type': 'text_delta', 'text': answer},
                },
                {'type': 'content_block_stop', 'index': 0},
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': 'end_turn'},
                  'usage': {'output_tokens': 2},
                },
                {'type': 'message_stop'},
              ]) {
                incoming.response.write('data: ${jsonEncode(event)}\n\n');
              }
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
            provider: protocol == 'native' ? 'GOOGLE' : 'OPENAI_GENERIC',
            protocol: protocol,
            endpoint: 'http://127.0.0.1:${server.port}',
            models: catalog.configs.single.draft.models,
            options: catalog.configs.single.draft.options.copyWith(
              toolCall: nativeTools,
            ),
          );
          await tester.runAsync(
            () => runtime.saveModelConfig(
              catalog.configs.single.id,
              catalog.configs.single.revision,
              draft,
              null,
              null,
            ),
          );
          final saved = (await tester.runAsync(runtime.modelCatalog))!
              .configs
              .single;
          await tester.runAsync(
            () => test.start(
              draft,
              ModelCredentials(
                usePool: true,
                keys: [
                  ModelPoolKey.create('fixture-first'),
                  ModelPoolKey.create('fixture-second'),
                ],
              ),
              config: saved,
            ),
          );
          expect(requests, 4);
          expect(
            keys,
            protocol == 'messages' || protocol == 'native'
                ? [
                    'fixture-first',
                    'fixture-second',
                    'fixture-first',
                    'fixture-second',
                  ]
                : [
                    'Bearer fixture-first',
                    'Bearer fixture-second',
                    'Bearer fixture-first',
                    'Bearer fixture-second',
                  ],
          );
          expect(test.running, false);
          expect(
            test.results!
                .where((item) => item.outcome == ModelTestOutcome.passed)
                .map((item) => item.label),
            ['聊天', nativeTools ? 'Tool Call' : '内置工具调用', '系统指令遵循'],
          );
          expect(
            test.results!
                .singleWhere(
                  (item) =>
                      item.label ==
                      (draft.options.toolCall ? 'Tool Call' : '内置工具调用'),
                )
                .outcome,
            ModelTestOutcome.passed,
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
              'model-test-results-$protocol-$nativeTools-dark',
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
