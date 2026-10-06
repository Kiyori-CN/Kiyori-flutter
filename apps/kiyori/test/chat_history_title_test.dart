import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_options_editing.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'support/chat_fixture.dart';

Future<void> waitFor(Future<bool> Function() done) async {
  for (var i = 0; i < 300; i++) {
    if (await done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('title execution did not reach the expected terminal state');
}

Future<List<Map<String, dynamic>>> events(ChatFixture f, String id) async {
  final page = jsonDecode(await f.runtime.conversationAudit(id, 0, '')) as Map;
  return (page['events'] as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> payload(
  ChatFixture f,
  String id,
  String type,
) async {
  final event = (await events(f, id)).lastWhere((e) => e['eventType'] == type);
  return jsonDecode(
    await f.runtime.conversationAuditPayload(id, event['sequence'] as int, 0),
  ) as Map<String, dynamic>;
}

class TitleSecrets implements SecretStore {
  TitleSecrets(this.inner, this.reference);
  final SecretStore inner;
  final String reference;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<String?> read(String id) async {
    if (id == reference) {
      entered.complete();
      await release.future;
    }
    return inner.read(id);
  }

  @override
  Future<void> writeNew(String id, String text) => inner.writeNew(id, text);
  @override
  Future<void> delete(String id) => inner.delete(id);
}

Future<String> titleModel(ChatFixture f) async {
  final id = await f.models.create('标题专用');
  final config = f.models.catalog!.configs.singleWhere((c) => c.id == id);
  await f.models.save(
    config,
    ModelConfigDraft(
      name: '标题专用',
      provider: 'OPENAI_GENERIC',
      protocol: 'chat',
      endpoint: 'http://127.0.0.1:${f.server.port}',
      models: ['title-model'],
      options: config.draft.options,
    ),
    const ModelCredentials(),
    const ModelCredentials(apiKey: 'title-fixture'),
    replacement: 'title-model',
  );
  await f.models.select('titleGeneration', id, 'title-model');
  f.titleCredential = 'title-fixture';
  return f.models.catalog!.configs
      .singleWhere((c) => c.id == id)
      .secretReference!;
}

void main() {
  testWidgets('title shares a single provider slot without holding chat open', (
    tester,
  ) async {
    final f = ChatFixture();
    await tester.runAsync(f.open);
    try {
      await tester.runAsync(() async {
        final c = (await f.runtime.modelCatalog()).configs.single;
        await f.runtime.saveModelConfig(
          c.id,
          c.revision,
          ModelConfigDraft(
            name: c.draft.name,
            provider: c.draft.provider,
            protocol: c.draft.protocol,
            endpoint: c.draft.endpoint,
            models: c.draft.models,
            options: c.draft.options.copyWith(concurrentLimit: 1),
          ),
          c.secretReference,
          null,
        );
        await f.chat.create();
        f.gate = Completer<void>();
        final sending = f.chat.send('单并发首轮');
        await waitFor(() async => f.requests.length == 1);
        expect(f.titleRequests, isEmpty);
        f.gate!.complete();
        await sending.timeout(const Duration(seconds: 5));
        await waitFor(
          () async => f.chat.snapshot!.conversation.title == f.titleAnswer,
        );
        expect(f.titleRequests.length, 1);
        expect(f.chat.statistics!.requests, 1);
        expect(f.chat.error, isNull);
      });
    } finally {
      await tester.runAsync(f.close);
    }
  });
  testWidgets(
    'independent title uses its own credentials and actual audit usage',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      try {
        await tester.runAsync(() async {
          await titleModel(f);
          f.titleAnswer = '<THINK>隐藏</THINK>\n# “安排旅行。”<meta>不显示</meta>\n第二行';
          await f.chat.create();
          await f.chat.send('请帮我安排旅行');
          final id = f.chat.snapshot!.conversation.id;
          await waitFor(
            () async => f.chat.snapshot!.conversation.title == '安排旅行',
          );
          expect(f.titleRequests.single['model'], 'title-model');
          expect(f.titleRequests.single['stream'], false);
          expect(
            (f.titleRequests.single['messages'] as List)[1]['content'],
            contains('请帮我安排旅行'),
          );
          expect(f.requests.single['model'], 'second-model');
          expect(f.chat.statistics!.requests, 1);
          expect(f.chat.snapshot!.messages.length, 2);
          final finished = await payload(f, id, 'TITLE_FINISHED');
          expect(finished['state'], 'completed');
          expect(finished['usage'], containsPair('inputTokens', 3));
          expect(finished['usage'], containsPair('outputTokens', 4));
          final semantic = (await events(
            f,
            id,
          )).where((e) => e['eventType'] == 'FINAL_PROVIDER_SEMANTIC_REQUEST');
          expect(semantic.length, 2);
          final raw = await f.runtime.conversationAuditPayload(
            id,
            semantic.last['sequence'] as int,
            0,
          );
          expect(raw, isNot(contains('title-fixture')));
          await f.chat.send('第二轮');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(f.titleRequests.length, 1);
        });
      } finally {
        await tester.runAsync(f.close);
      }
    },
  );

  for (final action in ['rename', 'select', 'delete', 'cancel', 'failure']) {
    testWidgets(
      'late title $action keeps the current conversation and fallback',
      (tester) async {
        final f = ChatFixture();
        await tester.runAsync(f.open);
        try {
          await tester.runAsync(() async {
            await f.chat.create();
            final id = f.chat.snapshot!.conversation.id;
            f.titleGate = Completer<void>();
            f.titleFail = action == 'failure';
            await f.chat.send('第一轮');
            await waitFor(() async => f.titleRequests.isNotEmpty);
            expect(f.chat.snapshot!.conversation.title, '新对话');
            expect(
              jsonDecode(
                await f.runtime.conversationAudit(id, 0, ''),
              )['status'],
              'IN_PROGRESS',
            );
            if (action == 'rename') {
              await f.chat.change(
                f.chat.snapshot!.conversation,
                'rename',
                '我的标题',
              );
            } else if (action == 'select') {
              await f.chat.create();
            } else if (action == 'delete') {
              expect(
                await f.chat.change(
                  f.chat.snapshot!.conversation,
                  'delete',
                  '',
                ),
                isTrue,
              );
            } else if (action == 'cancel') {
              await f.chat.stop();
            }
            final selected = f.chat.snapshot!.conversation.id;
            f.titleGate!.complete();
            if (action == 'delete') {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              expect(
                f.chat.catalog!.conversations.any((c) => c.id == id),
                isFalse,
              );
              expect(f.chat.catalog!.conversations.length, 1);
            } else {
              await waitFor(
                () async => (await events(
                  f,
                  id,
                )).any((e) => e['eventType'] == 'TITLE_FINISHED'),
              );
              final finished = await payload(f, id, 'TITLE_FINISHED');
              expect(
                finished['state'],
                action == 'cancel'
                    ? 'cancelled'
                    : action == 'failure'
                    ? 'failed'
                    : 'completed',
              );
              expect(
                (await f.runtime.conversation(id)).conversation.title,
                action == 'rename'
                    ? '我的标题'
                    : action == 'cancel' || action == 'failure'
                    ? '新对话'
                    : f.titleAnswer,
              );
            }
            expect(f.chat.snapshot!.conversation.id, selected);
            expect(f.chat.error, isNull);
            expect(f.titleRequests.length, 1);
          });
        } finally {
          await tester.runAsync(f.close);
        }
      },
    );
  }

  testWidgets(
    'cancel while reading title credentials records no provider request and never retries',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(f.open);
      TitleSecrets? gated;
      try {
        await tester.runAsync(() async {
          final reference = await titleModel(f);
          gated = TitleSecrets(f.secrets, reference);
          await f.chat.shutdown();
          f.chat.dispose();
          f.chat = ChatController(() async => f.runtime, () async => gated!);
          await f.chat.load();
          await f.chat.create();
          final sending = f.chat.send('准备中取消');
          await gated!.entered.future;
          final stopping = f.chat.stop();
          gated!.release.complete();
          await stopping;
          await sending;
          final id = f.chat.snapshot!.conversation.id;
          await waitFor(
            () async => (await events(
              f,
              id,
            )).any((e) => e['eventType'] == 'TITLE_PREPARATION_FINISHED'),
          );
          final cancelled = await payload(f, id, 'TITLE_PREPARATION_FINISHED');
          expect(cancelled['state'], 'cancelled');
          expect(cancelled['providerRequestStarted'], false);
          expect(f.titleRequests, isEmpty);
          await f.chat.send('继续聊天');
          expect(f.titleRequests, isEmpty);
          expect(f.chat.snapshot!.conversation.title, '新对话');
        });
      } finally {
        if (gated != null && !gated!.release.isCompleted) {
          gated!.release.complete();
        }
        await tester.runAsync(f.close);
      }
    },
  );
}
