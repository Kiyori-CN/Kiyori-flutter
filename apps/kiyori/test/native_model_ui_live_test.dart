import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  final directory = Platform.environment['KIYORI_NATIVE_TEST_DATA'];
  testWidgets(
    'saved MNN settings drive the real chat page and persist tokens',
    (tester) async {
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory!),
      ))!;
      final secrets = WindowsSecretStore(Directory('$directory/secrets'));
      final models = ModelsController(() async => runtime, () async => secrets);
      final chat = ChatController(() async => runtime, () async => secrets);
      ModelEditSession? editing;
      try {
        await tester.runAsync(() async {
          await models.load();
          final config = models.catalog!.configs.first;
          expect(config.draft.provider, 'MNN');
          editing = ModelEditSession(models, config, const ModelCredentials());
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(session: editing),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('线程数'), findsOneWidget);
        expect(find.text('计算类型'), findsOneWidget);
        expect(find.text('本地模型下载'), findsOneWidget);
        final thread = find
            .byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.controller?.text ==
                      editing!.base.draft.options.mnnThreads.toString(),
            )
            .first;
        await tester.enterText(thread, '2');
        await tester.pump();
        await tester.runAsync(() async {
          expect(await editing!.flush(), isTrue);
          final saved = (await runtime.modelCatalog()).configs.first;
          expect(saved.draft.options.mnnThreads, 2);
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
          expect(chat.loading, isFalse);
          await chat.send('What is 2 + 3? Reply with only the digit.');
        });
        await tester.pumpAndSettle();
        expect(chat.error, isNull);
        expect(chat.snapshot!.messages.last.state, 'completed');
        expect(chat.snapshot!.messages.last.content.trim(), '5');
        expect(chat.snapshot!.messages.last.outputTokens, greaterThan(0));
        // Markdown在真实isolate解析；pumpAndSettle只结算帧，不等待isolate返回。
        final renderedAnswer = find.text('5', findRichText: true);
        for (
          var attempt = 0;
          attempt < 100 && renderedAnswer.evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(renderedAnswer, findsWidgets);
        expect(tester.getSize(renderedAnswer.first).height, greaterThan(0));
        final id = chat.snapshot!.conversation.id;
        await tester.runAsync(() async {
          await chat.shutdown();
          await runtime.close();
          final reopened = await NativeRuntimeClient.open(
            dataDirectory: directory,
          );
          try {
            final history = await reopened.conversation(id);
            expect(history.messages.last.content.trim(), '5');
            expect(history.messages.last.inputTokens, greaterThan(0));
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
        });
      }
    },
    skip: directory == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
