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
          protocol: 'responses',
          endpoint: Platform.environment['KIYORI_LIVE_ENDPOINT']!,
          models: [Platform.environment['KIYORI_LIVE_MODEL']!],
          options: base.draft.options.copyWith(
            parameters: [
              const ModelParameter(
                name: 'reasoning',
                enabled: true,
                valueType: 'json',
                value: '{"effort":"none"}',
                category: 'custom',
              ),
              const ModelParameter(
                name: 'max_tokens',
                enabled: true,
                valueType: 'integer',
                value: '512',
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
        await tester.runAsync(() async {
          await runtime.close();
          runtime = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
          await models.load();
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
          expect(chat.snapshot!.messages.last.state, 'completed');
          expect(chat.snapshot!.messages.last.content.trim(), 'KIYORI_OK');
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
        });
        // 只输出合成验收结论，既不记录请求体也不记录安全引用/凭据。
        debugPrint(
          'LIVE_CHAT_OK: UI configuration -> DPAPI -> reopen -> two UI sends -> Rust/SQLite -> reopen; two completed KIYORI_OK replies.',
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
