import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  final directory = Platform.environment['KIYORI_NATIVE_TEST_DATA'];
  testWidgets(
    'real native chat uses automatic summary and manual checkpoints with reopen',
    (tester) async {
      final provider = Platform.environment['KIYORI_NATIVE_PROVIDER'] ?? 'MNN';
      final model =
          Platform.environment['KIYORI_NATIVE_MODEL'] ?? 'Qwen3.5-0.8B-MNN';
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory!),
      ))!;
      final secrets = WindowsSecretStore(Directory('$directory/secrets'));
      final chat = ChatController(() async => runtime, () async => secrets);
      try {
        await tester.runAsync(() async {
          final base = (await runtime.modelCatalog()).configs.first;
          await runtime.saveModelConfig(
            base.id,
            base.revision,
            ModelConfigDraft(
              name: '本地总结验收',
              provider: provider,
              protocol: 'native',
              endpoint: '',
              models: [model],
              options: base.draft.options.copyWith(
                summaryEnabled: true,
                summaryByCount: true,
                summaryCount: 1,
                summaryRules: '准确保留数字2、3、5，禁止重复段落。',
                contextLength: 64,
                maxContextMode: false,
                requestLimit: 0,
                concurrentLimit: 1,
                mnnForward: 0,
                mnnThreads: 2,
                llamaThreads: 2,
                llamaContext: 4096,
                llamaGpuLayers: 0,
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
            model,
          );
          await runtime.selectFunctionModel('chat', base.id, model);
          final summaryId = await runtime.createModelConfig('独立本地总结');
          final summary = (await runtime.modelCatalog()).configs.singleWhere(
            (c) => c.id == summaryId,
          );
          final chatConfig = (await runtime.modelCatalog()).configs.singleWhere(
            (c) => c.id == base.id,
          );
          await runtime.saveModelConfig(
            summary.id,
            summary.revision,
            ModelConfigDraft(
              name: summary.draft.name,
              provider: provider,
              protocol: 'native',
              endpoint: '',
              models: [model],
              options: chatConfig.draft.options.copyWith(
                parameters: const [
                  ModelParameter(
                    name: 'max_tokens',
                    enabled: true,
                    valueType: 'integer',
                    value: '4096',
                    category: 'generation',
                  ),
                  ModelParameter(
                    name: 'temperature',
                    enabled: true,
                    valueType: 'decimal',
                    value: '0.6',
                    category: 'creativity',
                  ),
                  ModelParameter(
                    name: 'top_p',
                    enabled: true,
                    valueType: 'decimal',
                    value: '0.8',
                    category: 'creativity',
                  ),
                  ModelParameter(
                    name: 'repetition_penalty',
                    enabled: true,
                    valueType: 'decimal',
                    value: '1.1',
                    category: 'creativity',
                  ),
                ],
              ),
            ),
            null,
            model,
          );
          await runtime.selectFunctionModel('summary', summaryId, model);
          var prefs = await runtime.chatPreferences();
          prefs = await runtime.changeChatPreference(
            prefs.revision,
            'thinking',
            'false',
          );
          await runtime.changeChatPreference(
            prefs.revision,
            'disable_stream',
            'false',
          );
          await chat.load();
          expect(await chat.create(), isTrue);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(body: ChatPage(controller: chat)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await chat.load();
          await chat.send('What is 2 + 3? Reply with only the digit.');
        });
        await tester.pumpAndSettle();
        expect(chat.error, isNull);
        expect(chat.snapshot!.messages.last.state, 'completed');
        expect(chat.snapshot!.messages.last.content.trim(), '5');
        await tester.runAsync(
          () => chat.send('新的独立问题：计算3加4。只回答格式如1+2=3的一行算式，不要重复旧问题。'),
        );
        await tester.pumpAndSettle();
        expect(chat.error, isNull);
        final before = chat.snapshot!;
        expect(before.messages.length, 4);
        expect(before.summary, isNotNull);
        expect(before.summary!.content.trim(), isNotEmpty);
        expect(before.messages.every((m) => m.state == 'completed'), isTrue);
        final arithmetic = before.messages.last.content.trim();
        await tester.runAsync(() => chat.insertSummary(before.messages.last));
        await tester.pumpAndSettle();
        expect(chat.error, isNull);
        final after = chat.snapshot!;
        expect(after.messages.length, 5);
        expect(after.messages.last.role, 'summary');
        expect(after.messages.last.content.trim(), isNotEmpty);
        expect(
          after.messages.take(4).map((m) => m.content),
          before.messages.map((m) => m.content),
        );
        final id = after.conversation.id;
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await chat.shutdown();
          await runtime.close();
          final reopened = await NativeRuntimeClient.open(
            dataDirectory: directory,
          );
          try {
            final history = await reopened.conversation(id);
            expect(
              history.messages.map((m) => m.content),
              after.messages.map((m) => m.content),
            );
            expect(history.messages.last.outputTokens, greaterThan(0));
            final stats = await reopened.conversationStatistics(id);
            // 两次聊天、一次自动总结、一次手动总结，各有独立真实用量。
            expect(stats.requests, 4);
            expect(stats.reportedRequests, 4);
          } finally {
            await reopened.close();
          }
        });
        // 先完成资源/原文/摘要重开核验，再报告模型质量；正确性断言始终保留。
        expect(
          arithmetic,
          '3+4=7',
          reason: 'synthetic summary: ${before.summary!.content}',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        await tester.runAsync(() async {
          await chat.shutdown();
          await runtime.close();
        });
      }
    },
    skip: directory == null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
