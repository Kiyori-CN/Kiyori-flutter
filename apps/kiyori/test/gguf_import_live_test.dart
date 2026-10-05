import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_model_file.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  final file = Platform.environment['KIYORI_GGUF_TEST_FILE'];
  testWidgets(
    'real GGUF import banner to Transfer, local directory, chat, cancellation and reopen',
    (tester) async {
      final data = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('kiyori-gguf-ui-'),
      ))!;
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: data.path),
      ))!;
      final secrets = WindowsSecretStore(Directory('${data.path}/secrets'));
      final models = ModelsController(() async => runtime, () async => secrets);
      final chat = ChatController(() async => runtime, () async => secrets);
      ModelEditSession? editing;
      final name = file!.replaceAll('\\', '/').split('/').last;
      try {
        await tester.runAsync(() async {
          await models.load();
          final base = models.catalog!.configs.first;
          await runtime.saveModelConfig(
            base.id,
            base.revision,
            ModelConfigDraft(
              name: 'GGUF验收',
              provider: 'LLAMA_CPP',
              protocol: 'native',
              endpoint: '',
              models: [name],
              options: base.draft.options.copyWith(
                summaryEnabled: false,
                toolCall: false,
                llamaThreads: 2,
                llamaContext: 2048,
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
            name,
          );
          await models.load();
          editing = ModelEditSession(
            models,
            models.catalog!.configs.first,
            const ModelCredentials(),
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(
                  session: editing,
                  modelFilePicker: WindowsModelFilePicker(
                    select: () async => file,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final banner = find.textContaining('点击此处选择模型文件');
        await tester.ensureVisible(banner);
        await tester.tap(banner);
        // 磁盘和FFI在真实event loop推进；保留界面完成/错误断言。
        for (var i = 0; i < 3000; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text('模型已导入，可以从本地模型目录选择').evaluate().isNotEmpty) break;
          expect(find.text('关闭'), findsNothing);
        }
        expect(
          find.text('模型已导入，可以从本地模型目录选择'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data ?? w.textSpan?.toPlainText())
              .join(' | '),
        );
        await tester.runAsync(() async {
          final transfers = await runtime.transfers();
          expect(transfers.single.phase, 'completed');
          expect(transfers.single.total.toInt(), 428730208);
          final config = (await runtime.modelCatalog()).configs.first;
          final run = await runtime.startConfiguredModelDirectory(
            config.id,
            config.revision,
            const ModelCredentials().encode(),
          );
          final events = await run.events.toList();
          expect(events.last.phase, ChatPhase.completed);
          expect(
            events
                .firstWhere((e) => e.phase == ChatPhase.models)
                .models
                .single
                .id,
            name,
          );
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
          await runtime.selectFunctionModel('chat', config.id, name);
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
        expect(chat.snapshot!.messages.last.content.trim(), '5');
        expect(chat.snapshot!.messages.last.outputTokens, greaterThan(0));
        final answer = find.text('5', findRichText: true);
        for (var i = 0; i < 100 && answer.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(answer, findsWidgets);
        final id = chat.snapshot!.conversation.id;
        await tester.runAsync(() async {
          final prepared = await runtime.prepareConversation(id);
          final cancelled = await prepared.start(
            'Count from one to a thousand.',
            const ModelCredentials().encode(),
          );
          await prepared.close();
          final events = <ChatEvent>[];
          await for (final event in cancelled.events) {
            events.add(event);
            if (event.phase == ChatPhase.text) await cancelled.cancel();
          }
          expect(events.last.phase, ChatPhase.cancelled);
          await chat.shutdown();
          await runtime.close();
          final reopened = await NativeRuntimeClient.open(
            dataDirectory: data.path,
          );
          try {
            expect(
              (await reopened.conversation(id)).messages[1].content.trim(),
              '5',
            );
            expect(
              (await reopened.conversation(id)).messages.last.state,
              'cancelled',
            );
            expect((await reopened.transfers()).single.phase, 'completed');
          } finally {
            await reopened.close();
          }
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        editing?.dispose();
        chat.dispose();
        models.dispose();
        await tester.runAsync(() async {
          await chat.shutdown();
          await runtime.close();
          await data.delete(recursive: true);
        });
      }
    },
    skip: file == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
