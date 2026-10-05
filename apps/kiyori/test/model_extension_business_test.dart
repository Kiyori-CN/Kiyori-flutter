import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_pool_test_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

// 与桥集成测试同一合成ZIP：schema1、四handler、中文名称，无网络和实际凭据。
const _package =
    'UEsDBBQAAAAAANBYRV1cGMmqmgAAAJoAAAANAAAAbWFuaWZlc3QuanNvbnsic2NoZW1hX3ZlcnNpb24iOjEsInRvb2xwa2dfaWQiOiJjb20ua2l5b3JpLmZpeHR1cmUiLCJ2ZXJzaW9uIjoiMS4wLjAiLCJtYWluIjoiZGlzdC9tYWluLmpzIiwiZGlzcGxheV9uYW1lIjp7InpoIjoi5ZCI5oiQ5YyFIn0sImVuYWJsZWRfYnlfZGVmYXVsdCI6dHJ1ZX1QSwMEFAAAAAAA0FhFXU+ZjLPTAQAA0wEAAAwAAABkaXN0L21haW4uanNleHBvcnRzLnJlZ2lzdGVyVG9vbFBrZz0oKT0+VG9vbFBrZy5yZWdpc3RlckFpUHJvdmlkZXIoe2lkOidmaXh0dXJlJyxkaXNwbGF5TmFtZTon5ZCI5oiQ5L6b5bqU5ZWGJyxkZXNjcmlwdGlvbjon55yf5a6e5a6J6KOF6aqM5pS2JyxsaXN0TW9kZWxzOntmdW5jdGlvbjooKT0+WydmaXh0dXJlLW1vZGVsJ119LHNlbmRNZXNzYWdlOntmdW5jdGlvbjooe2V2ZW50UGF5bG9hZH0pPT57aWYoZXZlbnRQYXlsb2FkLndhaXQpd2hpbGUodHJ1ZSl7fTtzZW5kSW50ZXJtZWRpYXRlUmVzdWx0KHt0ZXh0OifkvaAnfSk7c2VuZEludGVybWVkaWF0ZVJlc3VsdCh7dGV4dDon5aW9J30pO3JldHVybiB7Y29udGVudDon5L2g5aW9Jyx1c2FnZTp7aW5wdXQ6MixvdXRwdXQ6MX19O319LHRlc3RDb25uZWN0aW9uOntmdW5jdGlvbjooKT0+KHtzdWNjZXNzOnRydWV9KX0sY2FsY3VsYXRlSW5wdXRUb2tlbnM6e2Z1bmN0aW9uOigpPT43fX0pO1BLAQIUABQAAAAAANBYRV1cGMmqmgAAAJoAAAANAAAAAAAAAAAAAAAAAAAAAABtYW5pZmVzdC5qc29uUEsBAhQAFAAAAAAA0FhFXU+ZjLPTAQAA0wEAAAwAAAAAAAAAAAAAAAAAxQAAAGRpc3QvbWFpbi5qc1BLBQYAAAAAAgACAHUAAADCAgAAAAA=';

void main() {
  testWidgets(
    'product pool and chat project real provider connection and input count through FFI',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'kiyori-provider-checks-ui-',
      );
      late NativeRuntimeClient runtime;
      late ModelsController models;
      ChatController? chat;
      ModelPoolTestController? pool;
      try {
        await tester.runAsync(() async {
          runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
          final secrets = WindowsSecretStore(Directory('${root.path}/secrets'));
          models = ModelsController(() async => runtime, () async => secrets);
          final importer = await runtime.beginExtensionImport();
          try {
            await importer.append(base64Decode(_package));
            await importer.finish();
          } finally {
            await importer.close();
          }
          await models.load();
          final base = models.catalog!.configs.single;
          final draft = ModelConfigDraft(
            name: base.draft.name,
            provider: models.extensionProviders.single.id,
            protocol: 'native',
            endpoint: 'http://127.0.0.1:1/v1/chat/completions',
            models: const ['fixture-model'],
            options: base.draft.options.copyWith(summaryEnabled: false),
          );
          expect(
            await models.save(
              base,
              draft,
              const ModelCredentials(),
              const ModelCredentials(apiKey: 'synthetic-fixture-key'),
              replacement: 'fixture-model',
            ),
            isA<ModelConfig>(),
          );
          await models.select('chat', base.id, 'fixture-model');
          pool = ModelPoolTestController(() async => runtime);
          final results = <String>[];
          await pool!.start(
            draft,
            ModelCredentials(
              keys: [ModelPoolKey.create('synthetic-fixture-key')],
            ),
            (_, availability) async => results.add(availability),
          );
          expect(results, ['AVAILABLE']);
          expect(pool!.error, isNull);
          chat = ChatController(() async => runtime, () async => secrets);
          await chat!.load();
          await chat!.send('最终消息😀');
          expect(chat!.error, isNull);
          expect(chat!.snapshot!.messages.last.content, '你好');
          expect(chat!.statistics!.contextTokens, 7);
          expect(chat!.statistics!.recentInputTokens, 2);
          expect(chat!.statistics!.recentOutputTokens, 1);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(body: ChatPage(controller: chat)),
          ),
        );
        final answer = find.textContaining('你好', findRichText: true);
        for (var i = 0; i < 200 && answer.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(answer, findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        pool?.dispose();
        if (chat != null) await tester.runAsync(chat!.shutdown);
        chat?.dispose();
        models.dispose();
        await tester.runAsync(runtime.close);
        root.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
  testWidgets(
    'installed provider appears in original drawer, saves, reopens and revokes without fallback',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('kiyori-provider-ui-');
      var runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: root.path),
      ))!;
      final secrets = WindowsSecretStore(Directory('${root.path}/secrets'));
      var owner = ModelsController(() async => runtime, () async => secrets);
      // 构造时创建的Future链位于widget fake zone，先结算再进入真实native I/O zone。
      await tester.pump();
      ModelEditSession? session;
      try {
        await tester.runAsync(() async {
          final import = await runtime.beginExtensionImport();
          try {
            await import.append(base64Decode(_package));
            await import.finish();
          } finally {
            await import.close();
          }
        });
        Future<void> loadOwner() async {
          var loaded = false;
          final load = owner.load().then((_) => loaded = true);
          for (var i = 0; i < 150 && !loaded; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(loaded, isTrue);
          await load;
        }

        await loadOwner();
        final provider = owner.extensionProviders.single;
        expect(owner.providers.last.id, provider.id);
        var base = owner.catalog!.configs.single;
        session = ModelEditSession(owner, base, const ModelCredentials());
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(session: session),
              ),
            ),
          ),
        );
        await tester.tap(find.text('API提供方'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(KiyoriSearchField),
            matching: find.byType(TextField),
          ),
          provider.displayName,
        );
        await tester.pumpAndSettle();
        expect(find.text('ToolPkg Provider'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(ValueKey('provider-${provider.id}')),
        );
        await tester.tap(find.byKey(ValueKey('provider-${provider.id}')));
        await tester.pumpAndSettle();
        expect(find.text(provider.displayName), findsOneWidget);
        bool? saved;
        final save = session.flush().then((value) => saved = value);
        for (var i = 0; i < 150 && saved == null; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(saved, isTrue);
        await save;
        base = (await tester.runAsync(runtime.modelCatalog))!.configs.single;
        expect(base.draft.provider, provider.id);
        expect(base.draft.protocol, 'native');
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        session = null;
        owner.dispose();
        await tester.runAsync(runtime.close);
        runtime = (await tester.runAsync(
          () => NativeRuntimeClient.open(dataDirectory: root.path),
        ))!;
        owner = ModelsController(() async => runtime, () async => secrets);
        await tester.pump();
        await loadOwner();
        expect(owner.providers.last.name, provider.displayName);
        expect(owner.catalog!.configs.single.draft.provider, provider.id);
        await tester.runAsync(
          () => runtime.changeExtension(
            provider.packageId,
            provider.revision,
            enabled: false,
          ),
        );
        await loadOwner();
        expect(owner.extensionProviders, isEmpty);
        expect(owner.catalog!.configs.single.draft.provider, provider.id);
        session = ModelEditSession(
          owner,
          owner.catalog!.configs.single,
          const ModelCredentials(),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(session: session),
              ),
            ),
          ),
        );
        await tester.tap(find.text('API提供方'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('provider-${provider.id}')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        session?.dispose();
        owner.dispose();
        await tester.runAsync(runtime.close);
        root.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
