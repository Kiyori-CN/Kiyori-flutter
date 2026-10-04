import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

class ChatFixture {
  late Directory directory;
  late NativeRuntimeClient runtime;
  late WindowsSecretStore secrets;
  late ModelsController models;
  late ChatController chat;
  late HttpServer server;
  final requests = <Map<String, dynamic>>[];
  Completer<void>? gate;
  bool fail = false;
  Map<String, Object?>? usage;
  List<String>? chunks;
  String answer = '合成回复：**你好**\n\n```dart\nprint("hello");\n```';
  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('kiyori-chat-ui-');
    runtime = await NativeRuntimeClient.open(dataDirectory: directory.path);
    secrets = WindowsSecretStore(Directory('${directory.path}/secrets'));
    models = ModelsController(() async => runtime, () async => secrets);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(
        Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        ),
      );
      expect(
        request.headers.value('authorization'),
        'Bearer synthetic-fixture',
      );
      expect(request.uri.path, '/v1/chat/completions');
      request.response.bufferOutput = false;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      if (fail) {
        request.response.statusCode = 401;
        await request.response.close();
        return;
      }
      if (requests.last['stream'] == false) {
        request.response.headers.contentType = ContentType.json;
        if (gate != null) await gate!.future;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': answer},
                'finish_reason': 'stop',
              },
            ],
            'usage': {
              'prompt_tokens': 7,
              'completion_tokens': 9,
              'total_tokens': 16,
            },
          }),
        );
        await request.response.close();
        return;
      }
      for (final chunk in chunks ?? [answer]) {
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': {'content': chunk},
                'finish_reason': null,
              },
            ],
          })}\n\n',
        );
        await request.response.flush();
        if (chunks != null) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      }
      if (gate != null) await gate!.future;
      if (usage != null) {
        request.response.write(
          'data: ${jsonEncode({'choices': [], 'usage': usage})}\n\n',
        );
      }
      request.response.write(
        'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
      );
      await request.response.close();
    });
    await models.load();
    final base = models.catalog!.configs.single;
    await models.save(
      base,
      ModelConfigDraft(
        name: '合成服务',
        provider: 'OPENAI_GENERIC',
        protocol: 'chat',
        endpoint: 'http://127.0.0.1:${server.port}',
        models: ['first-model', 'second-model'],
        options: base.draft.options,
      ),
      const ModelCredentials(),
      const ModelCredentials(apiKey: 'synthetic-fixture'),
      replacement: 'first-model',
    );
    await models.select('chat', 'default', 'second-model');
    chat = ChatController(() async => runtime, () async => secrets);
    await chat.load();
  }

  Future<void> close() async {
    if (gate != null && !gate!.isCompleted) gate!.complete();
    await chat.shutdown().timeout(const Duration(seconds: 5));
    chat.dispose();
    models.dispose();
    await runtime.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}

class GatedSecrets implements SecretStore {
  GatedSecrets(this.inner);
  final SecretStore inner;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<String?> read(String reference) async {
    entered.complete();
    await release.future;
    return inner.read(reference);
  }

  @override
  Future<void> writeNew(String reference, String value) =>
      inner.writeNew(reference, value);
  @override
  Future<void> delete(String reference) => inner.delete(reference);
}

Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    done(),
    isTrue,
    reason: 'native operation should reach the expected state',
  );
}

void main() {
  testWidgets('model picker and message edit menus execute real commands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = ChatFixture();
    await tester.runAsync(f.open);
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(body: ChatPage(controller: f.chat)),
        ),
      );
      await until(tester, () => !f.chat.loading);
      await tester.tap(find.text('second-model'));
      await until(
        tester,
        () => find.byKey(const Key('chat-model-popup')).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('chat-model-popup'))).width,
        300,
      );
      final oldReference = f.chat.modelConfig!.secretReference;
      await tester.tap(find.byType(Switch));
      await until(tester, () => !f.chat.changing);
      expect(f.chat.modelConfig!.draft.options.maxContextMode, isTrue);
      expect(f.chat.modelConfig!.secretReference, oldReference);
      await tester.runAsync(() async {
        expect(await f.secrets.read(oldReference!), isNotNull);
        expect(
          (await f.runtime.modelCatalog())
              .configs
              .single
              .draft
              .options
              .maxContextMode,
          isTrue,
        );
      });
      await tester.tap(find.text('合成服务'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('first-model'));
      await until(
        tester,
        () => f.chat.modelName == 'first-model' && !f.chat.changing,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => f.chat.send('menu test'));
      await tester.pumpAndSettle();
      expect(f.requests.single['model'], 'first-model');
      await tester.longPress(find.text('Response').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('纯文本'));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('message-editor-raw'));
      await tester.enterText(field, '菜单编辑后的回复');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await until(tester, () => !f.chat.changing);
      expect(f.chat.snapshot!.messages.last.content, '菜单编辑后的回复');
      await tester.tap(
        find.byWidgetPredicate((w) => w is ShellAction && w.label == '显示历史'),
      );
      await until(tester, () => find.text('聊天历史').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('会话操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑标题'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '菜单重命名',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await until(tester, () => !f.chat.changing);
      expect(f.chat.snapshot!.conversation.title, '菜单重命名');
      await tester.enterText(
        find.byKey(const Key('chat-history-search')),
        '菜单编辑后的回复',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await until(tester, () => find.text('匹配 1 / 共 1').evaluate().isNotEmpty);
      expect(find.text('菜单重命名'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('chat-history-search')),
        '%_missing',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await until(tester, () => find.text('没有匹配的对话').evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pumpAndSettle();
      expect(find.text('共 1 个对话'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(f.close);
    }
  });
  testWidgets(
    'native secret read lease blocks replacement and disposal sends no request',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      final gated = (await tester.runAsync(
        () async => GatedSecrets(f.secrets),
      ))!;
      final pending = ChatController(() async => f.runtime, () async => gated);
      Future<void>? sending;
      try {
        await tester.runAsync(pending.load);
        await tester.runAsync(() async {
          sending = pending.send('synthetic');
          await gated.entered.future;
        });
        await tester.runAsync(() async {
          final current = (await f.runtime.modelCatalog()).configs.single;
          await expectLater(
            f.models.save(
              current,
              current.draft,
              const ModelCredentials(apiKey: 'synthetic-fixture'),
              const ModelCredentials(apiKey: 'replacement-fixture'),
            ),
            throwsA(isA<BridgeError>()),
          );
        });
        pending.dispose();
        gated.release.complete();
        await tester.runAsync(() => sending!);
        expect(f.requests, isEmpty);
        await tester.runAsync(() async {
          final lease = await f.runtime.beginModelSecrets();
          await lease.close();
          expect(
            (await f.runtime.conversationCatalog())
                .conversations
                .single
                .messageCount,
            0,
          );
        });
      } finally {
        if (!gated.release.isCompleted) gated.release.complete();
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'real UI sends selected model twice, persists history and restores after reopening',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(f.open);
      final boundary = GlobalKey();
      try {
        const output = String.fromEnvironment('KIYORI_CAPTURE');
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: KiyoriTheme.light(),
              home: Scaffold(body: ChatPage(controller: f.chat)),
            ),
          ),
        );
        await until(tester, () => !f.chat.loading);
        for (final text in ['第一轮合成提问', '第二轮继续']) {
          await tester.enterText(find.byKey(const Key('chat-draft')), text);
          await tester.pump();
          await tester.tap(
            find.byWidgetPredicate((w) => w is ShellAction && w.label == '发送'),
          );
          await until(
            tester,
            () =>
                f.chat.snapshot?.messages.length ==
                    (text.startsWith('第一') ? 2 : 4) &&
                !f.chat.busy,
          );
        }
        expect(f.requests.length, 2);
        expect(f.requests.last['model'], 'second-model');
        final messages = f.requests.last['messages'] as List;
        expect(messages.length, 4);
        expect(messages[2]['content'], f.answer);
        expect(
          f.chat.snapshot!.messages.every((m) => m.state == 'completed'),
          isTrue,
        );
        final id = f.chat.snapshot!.conversation.id;
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'chat-two-turns-light');
        }
        await tester.tap(
          find.byWidgetPredicate((w) => w is ShellAction && w.label == '显示历史'),
        );
        await until(tester, () => find.text('聊天历史').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, boundary, output, 'chat-history');
        }
        await tester.tap(find.text('新建对话'));
        await until(
          tester,
          () => f.chat.snapshot?.conversation.id != id && !f.chat.changing,
        );
        await tester.runAsync(() => f.chat.select(id));
        await tester.pumpAndSettle();
        expect(f.chat.snapshot!.messages.length, 4);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await f.chat.shutdown();
          f.chat.dispose();
          await f.runtime.close();
          f.runtime = await NativeRuntimeClient.open(
            dataDirectory: f.directory.path,
          );
          f.chat = ChatController(() async => f.runtime, () async => f.secrets);
          await f.chat.load();
        });
        expect(f.chat.snapshot!.conversation.id, id);
        expect(f.chat.snapshot!.messages.length, 4);
        expect(
          (await tester.runAsync(
            () => f.models.readCredentials(f.models.catalog!.configs.single),
          ))!.apiKey,
          'synthetic-fixture',
        );
        await tester.runAsync(
          () =>
              f.chat.change(f.chat.snapshot!.conversation, 'rename', '已恢复的会话'),
        );
        expect(f.chat.snapshot!.conversation.title, '已恢复的会话');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'stream cancel preserves partial text, switching isolates late events and duplicate send',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      try {
        f.gate = Completer<void>();
        await tester.runAsync(() async {
          unawaited(f.chat.send('流式合成输入'));
        });
        await until(
          tester,
          () => f.chat.execution?.text.value.isNotEmpty == true,
        );
        final id = f.chat.snapshot!.conversation.id;
        await tester.runAsync(() => f.chat.send('duplicate'));
        expect(f.requests.length, 1);
        await tester.runAsync(f.chat.create);
        expect(f.chat.snapshot!.messages, isEmpty);
        f.gate!.complete();
        await until(tester, () => !f.chat.executions[id]!.active);
        expect(f.chat.snapshot!.messages, isEmpty);
        await tester.runAsync(() => f.chat.select(id));
        expect(f.chat.snapshot!.messages.last.content, f.answer);
        f.gate = Completer<void>();
        await tester.runAsync(() async {
          unawaited(f.chat.send('停止测试'));
        });
        await until(
          tester,
          () => f.chat.execution?.text.value.isNotEmpty == true,
        );
        await tester.runAsync(f.chat.stop);
        expect(f.chat.snapshot!.messages.last.state, 'cancelled');
        expect(f.chat.snapshot!.messages.last.content, f.answer);
        f.gate!.complete();
        f.gate = null;
        f.fail = true;
        await tester.runAsync(() => f.chat.send('错误测试'));
        expect(f.chat.snapshot!.messages.last.state, 'failed');
        expect(f.chat.snapshot!.messages.last.error, isNotEmpty);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.dark(),
            home: Scaffold(body: ChatPage(controller: f.chat)),
          ),
        );
        await until(tester, () => !f.chat.loading);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'message edits delete and rollback are persisted with revision conflict protection',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      try {
        await tester.runAsync(() => f.chat.send('合成提问'));
        final stale = f.chat.snapshot!.conversation;
        final assistant = f.chat.snapshot!.messages.last;
        expect(
          await tester.runAsync(
            () => f.chat.changeMessage(stale, assistant, 'edit', '编辑后的回复'),
          ),
          true,
        );
        expect(
          await tester.runAsync(
            () => f.chat.changeMessage(stale, assistant, 'delete', ''),
          ),
          false,
        );
        expect(f.chat.snapshot!.messages.last.content, '编辑后的回复');
        expect(
          await tester.runAsync(
            () => f.chat.changeMessage(
              f.chat.snapshot!.conversation,
              f.chat.snapshot!.messages.first,
              'deleteFrom',
              '',
            ),
          ),
          true,
        );
        expect(f.chat.snapshot!.messages, isEmpty);
        expect(
          await tester.runAsync(
            () => f.chat.change(f.chat.snapshot!.conversation, 'delete', ''),
          ),
          true,
        );
        expect(f.chat.catalog!.conversations, isEmpty);
      } finally {
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'atomic resend validates before replacing history and keeps only preceding context',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      try {
        await tester.runAsync(() => f.chat.send('original'));
        final saved = f.chat.snapshot!;
        await tester.runAsync(
          () => f.chat.send(
            'replacement',
            replaceFrom: saved.messages.first.id,
            revision: saved.conversation.revision - 1,
          ),
        );
        expect(f.chat.snapshot!.messages, saved.messages);
        expect(f.requests.length, 1);
        await tester.runAsync(
          () => f.chat.send(
            'replacement',
            replaceFrom: saved.messages.first.id,
            revision: saved.conversation.revision,
          ),
        );
        expect(f.requests.length, 2);
        expect((f.requests.last['messages'] as List).length, 2);
        expect(f.chat.snapshot!.messages.length, 2);
        expect(f.chat.snapshot!.messages.first.content, 'replacement');
      } finally {
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'chat layouts retain long content across dark narrow large text keyboard and desktop',
    (tester) async {
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(f.open);
      try {
        f.answer = List.generate(
          20,
          (i) => '第${i + 1}段合成内容。**重点**与长文本保持完整。',
        ).join('\n\n');
        await tester.runAsync(() => f.chat.send('请给出长回复'));
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        for (final entry in [
          ('light', const Size(390, 844), false, 1.0, 0.0),
          ('dark', const Size(390, 844), true, 1.0, 0.0),
          ('narrow-keyboard', const Size(320, 640), true, 2.0, 160.0),
          ('landscape', const Size(844, 390), false, 1.0, 0.0),
          ('desktop', const Size(1280, 800), false, 1.0, 0.0),
        ]) {
          await tester.pumpWidget(const SizedBox());
          tester.view.physicalSize = entry.$2;
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                theme: entry.$3 ? KiyoriTheme.dark() : KiyoriTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(entry.$4),
                    viewInsets: EdgeInsets.only(bottom: entry.$5),
                  ),
                  child: child!,
                ),
                home: Scaffold(body: ChatPage(controller: f.chat)),
              ),
            ),
          );
          await until(tester, () => !f.chat.loading);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (output.isNotEmpty) {
            await captureUi(tester, key, output, 'chat-${entry.$1}');
          }
        }
        expect(f.chat.snapshot!.messages.last.content, f.answer);
        f.fail = true;
        await tester.runAsync(() => f.chat.send('错误示例'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
