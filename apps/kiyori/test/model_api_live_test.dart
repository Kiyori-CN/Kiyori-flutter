import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

/// 显式授权后只用进程环境中的凭据与合成素材，不输出正文、端点或安全payload。
void main() {
  final key = Platform.environment['KIYORI_LIVE_KEY'];
  test(
    'authorized model directory and protocol capability matrix',
    () async {
      final root = await Directory.systemTemp.createTemp('kiyori-live-model-');
      final runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
      final results = <Map<String, Object?>>[];
      final endpoint = Platform.environment['KIYORI_LIVE_ENDPOINT']!;
      final model = Platform.environment['KIYORI_LIVE_MODEL']!;
      final provider = Platform.environment['KIYORI_LIVE_PROVIDER']!;
      final credentials = ModelCredentials(apiKey: key!);
      final levels = Platform.environment['KIYORI_LIVE_THINKING_LEVELS']
          ?.split(',')
          .map(int.parse)
          .toList();
      var thinkingLevel = 0;
      try {
        for (final protocol
            in (Platform.environment['KIYORI_LIVE_PROTOCOLS']?.split(',') ??
                ['chat', 'responses', 'messages'])) {
          var config = (await runtime.modelCatalog()).configs.single;
          final path = protocol == 'chat'
              ? 'v1/chat/completions'
              : protocol == 'responses'
              ? 'v1/responses'
              : provider == 'DEEPSEEK'
              ? 'anthropic/v1/messages'
              : 'v1/messages';
          final draft = ModelConfigDraft(
            name: 'Authorized synthetic test',
            provider: provider,
            protocol: protocol,
            endpoint: '${endpoint.replaceAll(RegExp(r'/+$'), '')}/$path',
            models: [model],
            options: config.draft.options.copyWith(
              image: true,
              audio: true,
              video: true,
              parameters: [
                ModelParameter(
                  name: 'max_tokens',
                  enabled: true,
                  valueType: 'integer',
                  value: levels == null ? '512' : '4096',
                  category: 'generation',
                ),
                if (protocol == 'responses' && levels == null)
                  const ModelParameter(
                    name: 'reasoning',
                    enabled: true,
                    valueType: 'json',
                    value: '{"effort":"none"}',
                    category: 'custom',
                  ),
              ],
            ),
          );
          await runtime.saveModelConfig(
            config.id,
            config.revision,
            draft,
            null,
            model,
          );
          config = (await runtime.modelCatalog()).configs.single;
          Future<bool> record(
            String kind,
            bool stream,
            Future<ChatRun> Function() start,
          ) async {
            var passed = false;
            String? failure;
            int? status;
            ChatRun? run;
            try {
              run = await start();
              await for (final event in run.events) {
                if (event.phase == ChatPhase.completed) {
                  passed = kind == 'directory' || event.verified == true;
                  if (!passed) failure = 'unverified';
                }
                if (event.phase == ChatPhase.failed) {
                  failure = event.errorMessage;
                  status = event.httpStatus;
                }
                if (event.phase == ChatPhase.models) {
                  passed = event.models.any((entry) => entry.id == model);
                  results.add({
                    'protocol': protocol,
                    'kind': 'model-listed',
                    'passed': passed,
                    'count': event.models.length,
                  });
                }
              }
            } catch (_) {
              failure = 'configuration or protocol rejected';
            } finally {
              await run?.cancel();
            }
            final row = <String, Object?>{
              'protocol': protocol,
              'kind': kind,
              'stream': stream,
              'thinkingLevel': thinkingLevel,
              'passed': passed,
              'status': status,
              'failure': failure,
            };
            results.add(row);
            // 仅核心脱敏错误；断言和报告都不携带输入凭据或供应商响应。
            debugPrint('LIVE_CAPABILITY ${jsonEncode(row)}');
            return passed;
          }

          await record(
            'directory',
            false,
            () => runtime.startConfiguredModelDirectory(
              config.id,
              config.revision,
              credentials.encode(),
            ),
          );
          for (final level in levels ?? [0]) {
            thinkingLevel = level;
            var preferences = await runtime.chatPreferences();
            preferences = await runtime.changeChatPreference(
              preferences.revision,
              'thinking',
              (level > 0).toString(),
            );
            if (level > 0) {
              await runtime.changeChatPreference(
                preferences.revision,
                'thinking_quality',
                level.toString(),
              );
            }
            for (final stream in [true, false]) {
              final preferences = await runtime.chatPreferences();
              await runtime.changeChatPreference(
                preferences.revision,
                'disable_stream',
                (!stream).toString(),
              );
              final chat = await record(
                'chat',
                stream,
                () => runtime.startConfiguredProbe(
                  config.id,
                  config.revision,
                  credentials.encode(),
                  'chat',
                ),
              );
              if (!chat) continue;
              for (final kind
                  in (Platform.environment['KIYORI_LIVE_KINDS']?.split(',') ??
                      [
                        'system',
                        'tool',
                        'xml_tool',
                        if (stream) ...['image', 'audio', 'video'],
                      ])) {
                await record(
                  kind,
                  stream,
                  () => runtime.startConfiguredProbe(
                    config.id,
                    config.revision,
                    credentials.encode(),
                    kind,
                  ),
                );
              }
            }
          }
        }
        final output = Platform.environment['KIYORI_LIVE_REPORT'];
        if (output != null) {
          await File(output).writeAsString(
            '${const JsonEncoder.withIndent('  ').convert({'provider': provider, 'model': model, 'results': results})}\n',
          );
        }
        expect(
          results.where(
            (row) => row['kind'] == 'chat' && row['passed'] == true,
          ),
          isNotEmpty,
          reason: 'No protocol completed a real synthetic chat',
        );
        if (Platform.environment['KIYORI_LIVE_REQUIRE_ALL'] == '1') {
          expect(
            results.where((row) => row['passed'] != true),
            isEmpty,
            reason: 'Authorized selected capability matrix has failed rows',
          );
        }
      } finally {
        await runtime.close();
        await root.delete(recursive: true);
      }
    },
    skip: key == null || key.isEmpty,
    timeout: const Timeout(Duration(minutes: 45)),
  );
}
