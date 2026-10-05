import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

const payload =
    '{"version":3,"apiKey":"","headers":{},"usePool":false,"keys":[],"rotation":"ROUND_ROBIN"}';

void main() {
  final directory = Platform.environment['KIYORI_NATIVE_TEST_DATA'];
  test(
    'real MNN FFI configuration conversation usage cancel and reopen',
    () async {
      final runtime = await NativeRuntimeClient.open(dataDirectory: directory!);
      var closed = false;
      try {
        final base = (await runtime.modelCatalog()).configs.first;
        final o = base.draft.options;
        await runtime.saveModelConfig(
          base.id,
          base.revision,
          ModelConfigDraft(
            name: '本地推理验收',
            provider: 'MNN',
            protocol: 'native',
            endpoint: '',
            models: const ['Qwen3.5-0.8B-MNN'],
            options: ModelOptions(
              contextLength: 64,
              maxContextLength: 64,
              maxContextMode: false,
              summaryEnabled: false,
              summaryThreshold: o.summaryThreshold,
              summaryByCount: o.summaryByCount,
              summaryCount: o.summaryCount,
              summaryRules: '',
              image: false,
              audio: false,
              video: false,
              googleSearch: false,
              claudeCache: false,
              toolCall: false,
              requestLimit: 0,
              concurrentLimit: 1,
              mnnForward: 0,
              mnnThreads: 4,
              llamaThreads: o.llamaThreads,
              llamaContext: o.llamaContext,
              llamaBatch: o.llamaBatch,
              llamaMicroBatch: o.llamaMicroBatch,
              llamaGpuLayers: 0,
              llamaMmap: o.llamaMmap,
              llamaFlashAttention: o.llamaFlashAttention,
              llamaKvUnified: o.llamaKvUnified,
              llamaOffloadKqv: false,
              parameters: const [
                ModelParameter(
                  name: 'max_tokens',
                  enabled: true,
                  valueType: 'integer',
                  value: '48',
                  category: 'generation',
                ),
                ModelParameter(
                  name: 'temperature',
                  enabled: true,
                  valueType: 'decimal',
                  value: '0',
                  category: 'creativity',
                ),
              ],
            ),
          ),
          null,
          'Qwen3.5-0.8B-MNN',
        );
        await runtime.selectFunctionModel('chat', base.id, 'Qwen3.5-0.8B-MNN');
        final id = await runtime.createConversation();
        final prepared = await runtime.prepareConversation(id);
        final run = await prepared.start(
          'What is 2 + 3? Reply with only the digit.',
          payload,
        );
        await prepared.close();
        final events = await run.events.toList();
        expect(events.last.phase, ChatPhase.completed);
        expect(
          events
              .where((e) => e.phase == ChatPhase.text)
              .map((e) => e.text)
              .join()
              .trim(),
          '5',
        );
        final saved = await runtime.conversation(id);
        expect(saved.messages.length, 2);
        expect(saved.messages.last.state, 'completed');
        expect(saved.messages.last.outputTokens, greaterThan(0));
        final cancellation = await runtime.prepareConversation(id);
        final stopped = await cancellation.start(
          'Count from 1 to 100.',
          payload,
        );
        await cancellation.close();
        final stoppedEvents = <ChatEvent>[];
        var cancelled = false;
        await for (final event in stopped.events) {
          stoppedEvents.add(event);
          if (event.phase == ChatPhase.text && !cancelled) {
            cancelled = true;
            await stopped.cancel();
          }
        }
        expect(cancelled, isTrue);
        expect(stoppedEvents.last.phase, ChatPhase.cancelled);
        expect(
          (await runtime.conversation(id)).messages.last.state,
          'cancelled',
        );
        await runtime.close();
        closed = true;
        final reopened = await NativeRuntimeClient.open(
          dataDirectory: directory,
        );
        try {
          final history = await reopened.conversation(id);
          expect(history.messages[1].content.trim(), '5');
          expect(history.messages[1].inputTokens, greaterThan(0));
          expect(history.messages.last.state, 'cancelled');
          final config = (await reopened.modelCatalog()).configs.first;
          final directoryRun = await reopened.startConfiguredModelDirectory(
            config.id,
            config.revision,
            payload,
          );
          final directoryEvents = await directoryRun.events.toList();
          expect(directoryEvents.last.phase, ChatPhase.completed);
          expect(
            directoryEvents
                .firstWhere((e) => e.phase == ChatPhase.models)
                .models
                .map((e) => e.name),
            contains('Qwen3.5-0.8B-MNN'),
          );
        } finally {
          await reopened.close();
        }
      } finally {
        if (!closed) await runtime.close();
      }
    },
    skip: directory == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
