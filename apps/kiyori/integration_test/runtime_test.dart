import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'packaged chat UI sends two persisted turns with native credentials and restores history',
    (tester) async {
      // Integration binding默认不接管键盘；显式模拟文本通道，避免原生IME与enterText互相覆盖。
      // 此用例证明打包后的UI/FFI/DPAPI链路，不把模拟输入称为物理键盘验收。
      tester.testTextInput.register();
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp('kiyori-integration-chat-');
      var runtime = await NativeRuntimeClient.open(
        dataDirectory: directory.path,
      );
      final store = WindowsSecretStore(Directory('${directory.path}/secrets'));
      final models = ModelsController(() async => runtime, () async => store);
      final chat = ChatController(() async => runtime, () async => store);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Map>[];
      final authentications = <String?>[];
      final titleRequests = <Map>[];
      final titleAuthentications = <String?>[];
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if ((body['messages'] as List).first['content'].toString().contains(
          '你负责生成简短的对话标题。',
        )) {
          titleRequests.add(body);
          titleAuthentications.add(request.headers.value('authorization'));
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'index': 0,
                  'message': {'role': 'assistant', 'content': 'DESKTOP_TITLE'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 3,
                'completion_tokens': 2,
                'total_tokens': 5,
              },
            }),
          );
          await request.response.close();
          return;
        }
        requests.add(body);
        authentications.add(request.headers.value('authorization'));
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"index":0,"delta":{"content":"DESKTOP_OK"},"finish_reason":null}]}\n\ndata: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
        );
        await request.response.close();
      });
      try {
        await models.load();
        final base = models.catalog!.configs.single;
        await models.save(
          base,
          ModelConfigDraft(
            name: 'Desktop fixture',
            provider: 'OPENAI_GENERIC',
            protocol: 'chat',
            endpoint: 'http://127.0.0.1:${server.port}',
            models: ['desktop-model'],
            options: base.draft.options,
          ),
          const ModelCredentials(),
          const ModelCredentials(apiKey: 'desktop-fixture'),
          replacement: 'desktop-model',
        );
        await chat.load();
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(body: ChatPage(controller: chat)),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 100 && chat.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        for (var turn = 1; turn <= 2; turn++) {
          await tester.enterText(
            find.byKey(const Key('chat-draft')),
            'Synthetic turn $turn',
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate((w) => w is ShellAction && w.label == '发送'),
          );
          for (
            var i = 0;
            i < 200 &&
                (chat.busy || chat.snapshot?.messages.length != turn * 2);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
          expect(chat.snapshot!.messages.last.state, 'completed');
          expect(chat.snapshot!.messages.last.content, 'DESKTOP_OK');
          await tester.pumpAndSettle();
        }
        expect(requests.length, 2);
        expect(authentications, [
          'Bearer desktop-fixture',
          'Bearer desktop-fixture',
        ]);
        expect(requests.last['model'], 'desktop-model');
        expect((requests.last['messages'] as List).length, 4);
        for (
          var i = 0;
          i < 200 &&
              (chat.generatingTitle ||
                  chat.snapshot!.conversation.title != 'DESKTOP_TITLE');
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        expect(titleRequests.length, 1);
        expect(titleAuthentications, ['Bearer desktop-fixture']);
        expect(titleRequests.single['stream'], false);
        expect(titleRequests.single['model'], 'desktop-model');
        expect(chat.snapshot!.conversation.title, 'DESKTOP_TITLE');
        expect(chat.statistics!.requests, 2);
        final id = chat.snapshot!.conversation.id;
        await tester.pumpWidget(const SizedBox());
        await chat.shutdown();
        await runtime.close();
        runtime = await NativeRuntimeClient.open(dataDirectory: directory.path);
        expect((await runtime.conversation(id)).messages.length, 4);
        expect(
          (await runtime.conversation(id)).conversation.title,
          'DESKTOP_TITLE',
        );
        expect((await runtime.conversationCatalog()).activeId, id);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await chat.shutdown();
        chat.dispose();
        models.dispose();
        await runtime.close();
        await server.close(force: true);
        await directory.delete(recursive: true);
        tester.testTextInput.unregister();
      }
    },
    skip: !Platform.isWindows,
  );

  testWidgets(
    'packaged model configuration uses native DPAPI and reopens the same reference',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp('kiyori-integration-models-');
      final runtime = await NativeRuntimeClient.open(
        dataDirectory: directory.path,
      );
      final store = WindowsSecretStore(Directory('${directory.path}/secrets'));
      final owner = ModelsController(() async => runtime, () async => store);
      try {
        await owner.load();
        final base = owner.catalog!.configs.single;
        final saved = await owner.save(
          base,
          base.draft,
          const ModelCredentials(),
          const ModelCredentials(apiKey: 'integration-model-fixture'),
        );
        expect(
          (await owner.readCredentials(saved)).apiKey,
          'integration-model-fixture',
        );
        await runtime.close();
        final reopened = await NativeRuntimeClient.open(
          dataDirectory: directory.path,
        );
        try {
          expect(
            (await reopened.modelCatalog()).configs.single.secretReference,
            saved.secretReference,
          );
        } finally {
          await reopened.close();
        }
      } finally {
        owner.dispose();
        await runtime.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  testWidgets(
    'platform support directory and packaged SQLite survive runtime reopening',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      expect(support.isAbsolute, isTrue);
      final directory = await support.createTemp(
        'kiyori-integration-workflow-',
      );
      NativeRuntimeClient? client;
      try {
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        final record = await client.createWorkflow('本机引擎验证', '真实SQLite');
        final memory = await client.saveMemory(
          'default',
          null,
          const MemoryDraft(
            kind: 'memory',
            title: '真实记忆',
            content: 'Windows引擎与SQLite',
            category: 'fact',
            source: 'user_input',
            folder: '集成',
            credibility: .8,
            importance: .5,
            tags: ['本机'],
          ),
        );
        await client.close();
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        expect((await client.listWorkflows()).single, record);
        expect(
          (await client.getMemory('default', memory))!.draft.content,
          'Windows引擎与SQLite',
        );
        expect(
          (await client.queryKnowledge(
            const MemoryQuery(
              kind: 'memory',
              folder: '',
              text: 'SQLite',
              archived: false,
              sortTitle: false,
              offset: 0,
            ),
          )).records.single.id,
          memory,
        );
        await client.deleteMemory('default', memory);
        await client.deleteWorkflow(record.id);
        expect(await client.listWorkflows(), isEmpty);
      } finally {
        await client?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'packaged engine loads Rust and completes and cancels real work',
    (tester) async {
      await tester.pumpWidget(
        KiyoriApp(connect: NativeRuntimeClient.open, diagnostics: true),
      );
      Future<void> waitFor(String label) async {
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (find.text(label).evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(label), findsOneWidget);
      }

      await waitFor('应用核心已连接');
      await tester.ensureVisible(find.text('开始检查'));
      await tester.tap(find.text('开始检查'));
      await waitFor('检查完成，运行正常');
      await tester.tap(find.text('开始检查'));
      await waitFor('取消检查');
      await tester.tap(find.text('取消检查'));
      await waitFor('检查已取消');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'product shell loads packaged icons and preserves empty actions',
    (tester) async {
      await tester.pumpWidget(KiyoriApp(connect: NativeRuntimeClient.open));
      await tester.pumpAndSettle();
      expect(find.text('搜索网页或输入网址'), findsOneWidget);
      final images = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(images.length, greaterThanOrEqualTo(6));
      expect(images.every((image) => image.image != null), isTrue);
      await tester.tapAt(tester.getCenter(find.byKey(const Key('nav-4'))));
      await tester.pumpAndSettle();
      expect(find.text('我的账号'), findsOneWidget);
      await tester.tap(find.text('我的账号'));
      await tester.pumpAndSettle();
      expect(find.text('我的账号'), findsOneWidget);
      // 账号入口已接入详情；先验证来源返回，不能在模态页面下点击壳层底栏。
      expect(find.byKey(const Key('nav-0')), findsNothing);
      await tester.tap(find.bySemanticsLabel('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nav-4')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      expect(find.text('搜索网页或输入网址'), findsOneWidget);
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('把问题和任务发给AI'));
      await tester.pumpAndSettle();
      expect(find.text('AI 对话'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-draft')), '本地草稿');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('发送'));
      await tester.pumpAndSettle();
      expect(find.text('本地草稿'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
