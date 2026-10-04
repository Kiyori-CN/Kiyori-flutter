import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori/features/assistant/presentation/models/model_settings_components.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 只有显式注入授权凭据时执行；凭据仅进入正式安全存储，禁止截图/日志。
void main() {
  final key = Platform.environment['KIYORI_LIVE_KEY'];
  final summarize = Platform.environment['KIYORI_LIVE_SUMMARY'] == '1';
  final protocol = Platform.environment['KIYORI_LIVE_PROTOCOL'] ?? 'responses';
  final sol = Platform.environment['KIYORI_LIVE_MODEL'] == 'gpt-6.1-sol';
  final reasoning = protocol == 'responses'
      ? ModelParameter(
          name: 'reasoning',
          enabled: true,
          valueType: 'json',
          value: sol ? '{"effort":"low"}' : '{"effort":"none"}',
          category: 'custom',
        )
      : protocol == 'chat'
      ? ModelParameter(
          name: 'reasoning_effort',
          enabled: true,
          valueType: 'text',
          value: sol ? 'low' : 'none',
          category: 'custom',
        )
      : ModelParameter(
          name: sol ? 'reasoning_effort' : 'thinking',
          enabled: true,
          valueType: sol ? 'text' : 'json',
          value: sol ? 'low' : '{"type":"disabled"}',
          category: 'custom',
        );
  testWidgets(
    'authorized provider via configuration fields DPAPI and two UI conversation turns',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('kiyori-live-chat-'),
      );
      var runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory!.path),
      ))!;
      final secrets = WindowsSecretStore(
        Directory('${directory!.path}/secrets'),
      );
      final models = ModelsController(() async => runtime, () async => secrets);
      final chat = ChatController(() async => runtime, () async => secrets);
      ModelEditSession? editor;
      try {
        await tester.runAsync(models.load);
        final base = models.catalog!.configs.single;
        editor = ModelEditSession(models, base, const ModelCredentials());
        editor.update(
          provider: 'OPENAI_GENERIC',
          protocol: protocol,
          endpoint: protocol == 'messages' && !sol
              ? '${Platform.environment['KIYORI_LIVE_ENDPOINT']!.replaceAll(RegExp(r'/+$'), '')}/anthropic'
              : Platform.environment['KIYORI_LIVE_ENDPOINT']!,
          models: [Platform.environment['KIYORI_LIVE_MODEL']!],
          options: base.draft.options.copyWith(
            summaryEnabled: summarize,
            summaryByCount: true,
            summaryCount: 1,
            summaryRules: summarize
                ? '本次为合成测试。摘要只用一个简短句子，必须保留助手之前回答的确切口令 KIYORI_OK。'
                : base.draft.options.summaryRules,
            parameters: [
              reasoning,
              ModelParameter(
                name: 'max_tokens',
                enabled: true,
                valueType: 'integer',
                value: sol ? '4096' : '512',
                category: 'standard',
              ),
            ],
          ),
        );
        editor.replacement = Platform.environment['KIYORI_LIVE_MODEL'];
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(session: editor),
              ),
            ),
          ),
        );
        final secretField = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ModelSettingsField && w.title == 'API密钥',
          ),
          matching: find.byType(TextField),
        );
        expect(secretField, findsOneWidget);
        await tester.enterText(secretField, key!);
        await tester.pump();
        expect(
          await tester.runAsync(editor.flush),
          isTrue,
          reason: 'configuration should save without exposing credentials',
        );
        await tester.pumpWidget(const SizedBox());
        editor.dispose();
        editor = null;
        if (summarize) {
          await tester.runAsync(() async {
            final id = await models.create('独立总结合成测试');
            final summary = models.catalog!.configs.singleWhere(
              (c) => c.id == id,
            );
            final main = models.catalog!.configs.singleWhere(
              (c) => c.id == 'default',
            );
            await models.save(
              summary,
              ModelConfigDraft(
                name: summary.draft.name,
                provider: main.draft.provider,
                protocol: main.draft.protocol,
                endpoint: main.draft.endpoint,
                models: main.draft.models,
                options: main.draft.options.copyWith(
                  parameters: [
                    reasoning,
                    const ModelParameter(
                      name: 'max_tokens',
                      enabled: true,
                      valueType: 'integer',
                      value: '4096',
                      category: 'standard',
                    ),
                  ],
                ),
              ),
              const ModelCredentials(),
              ModelCredentials(apiKey: key),
              replacement: Platform.environment['KIYORI_LIVE_MODEL'],
            );
            await models.select(
              'summary',
              id,
              Platform.environment['KIYORI_LIVE_MODEL']!,
            );
          });
        }
        await tester.runAsync(() async {
          await runtime.close();
          runtime = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
          await models.load();
          if (Platform.environment['KIYORI_LIVE_NONSTREAM'] == '1') {
            final prefs = await runtime.chatPreferences();
            await runtime.changeChatPreference(
              prefs.revision,
              'disable_stream',
              'true',
            );
          }
          await chat.load();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(body: ChatPage(controller: chat)),
          ),
        );
        for (var i = 0; i < 200 && chat.loading; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        for (final text in [
          'This is a synthetic connectivity check. Reply with exactly KIYORI_OK.',
          'Repeat only the exact uppercase token you returned in your previous reply.',
        ]) {
          await tester.enterText(find.byKey(const Key('chat-draft')), text);
          await tester.pump();
          await tester.tap(
            find.byWidgetPredicate((w) => w is ShellAction && w.label == '发送'),
          );
          final count = text.startsWith('This') ? 2 : 4;
          for (
            var i = 0;
            i < 900 && (chat.busy || chat.snapshot?.messages.length != count);
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(chat.snapshot?.messages.length, count);
          expect(
            chat.snapshot!.messages.last.state,
            'completed',
            reason: 'turn=$count; ${chat.snapshot!.messages.last.error}',
          );
          expect(chat.snapshot!.messages.last.content.trim(), 'KIYORI_OK');
          if (summarize && count == 4) {
            expect(chat.snapshot!.summary, isNotNull);
            expect(chat.snapshot!.summary!.content, contains('KIYORI_OK'));
            expect(chat.snapshot!.summary!.throughPosition.toInt(), 1);
            expect(
              chat.snapshot!.messages.first.content,
              startsWith('This is a synthetic'),
            );
          }
        }
        final id = chat.snapshot!.conversation.id;
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await chat.shutdown();
          await runtime.close();
          runtime = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
          final restored = await runtime.conversation(id);
          expect(restored.messages.length, 4);
          expect(restored.messages.last.state, 'completed');
          if (summarize) {
            expect(restored.summary, isNotNull);
            expect(restored.summary!.content, contains('KIYORI_OK'));
            expect(
              restored.messages.first.content,
              startsWith('This is a synthetic'),
            );
          }
        });
        // 只输出合成验收结论，既不记录请求体也不记录安全引用/凭据。
        debugPrint(
          'LIVE_CHAT_OK: UI configuration -> DPAPI -> reopen -> two UI sends -> Rust/SQLite -> reopen; two completed KIYORI_OK replies; independent summary=${summarize ? 'verified' : 'disabled'}.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        editor?.dispose();
        await tester.runAsync(() async {
          await chat.shutdown();
          chat.dispose();
          models.dispose();
          await runtime.close();
          await directory.delete(recursive: true);
        });
      }
    },
    skip: key == null || key.isEmpty,
  );
}
