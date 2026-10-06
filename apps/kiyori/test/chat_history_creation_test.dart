import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_controller.dart';
import 'package:kiyori/features/assistant/presentation/chat_dialogs.dart';
import 'package:kiyori/features/assistant/presentation/chat_history_groups.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_business_test.dart' show ChatFixture, until;
import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

// 只延迟提交或制造读取故障；相关事实全部委派给真实Runtime/SQLite。
class _CreationClient extends FakeClient {
  _CreationClient(this.inner);
  final RuntimeClient inner;
  Completer<void>? beforeCommit, afterCatalog;
  final catalogHeld = Completer<void>();
  bool failBeforeCommit = false, failCatalog = false, failSnapshot = false;
  bool committed = false;
  int writes = 0;

  @override
  Future<ChatPreferences> changeChatPreference(
    int revision,
    String key,
    String value,
  ) async {
    writes++;
    if (beforeCommit != null) await beforeCommit!.future;
    if (failBeforeCommit) throw StateError('synthetic precommit failure');
    final result = await inner.changeChatPreference(revision, key, value);
    committed = true;
    return result;
  }

  @override
  Future<ConversationCatalog> conversationCatalog() async {
    if (committed && failCatalog) throw StateError('synthetic catalog failure');
    final value = await inner.conversationCatalog();
    if (committed && afterCatalog != null) {
      final gate = afterCatalog!;
      if (!catalogHeld.isCompleted) catalogHeld.complete();
      await gate.future;
    }
    return value;
  }

  @override
  Future<ConversationSnapshot> conversation(String id) {
    if (committed && failSnapshot) {
      throw StateError('synthetic snapshot failure');
    }
    return inner.conversation(id);
  }

  @override
  Future<void> selectConversation(String id) => inner.selectConversation(id);
  @override
  Future<ConversationStatistics> conversationStatistics(String id) =>
      inner.conversationStatistics(id);
  @override
  Future<ChatPreferences> chatPreferences() => inner.chatPreferences();
  @override
  Future<ModelCatalog> modelCatalog() => inner.modelCatalog();
  @override
  Future<PromptCatalog> promptCatalog() => inner.promptCatalog();
  @override
  Future<KnowledgeSnapshot> knowledgeSnapshot() => inner.knowledgeSnapshot();
}

ChatController _owner(ChatFixture f, _CreationClient client) =>
    ChatController(() async => client, () async => f.secrets)
      ..catalog = f.chat.catalog
      ..snapshot = f.chat.snapshot
      ..preferences = f.chat.preferences
      ..prompts = f.chat.prompts;

Future<BuildContext> host(
  WidgetTester tester,
  GlobalKey boundary,
  bool dark,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('对话历史'));
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'history new chat inherits folder and active card in folder mode',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.setPreference('create_folder', '当前分组');
        await f.chat.change(f.chat.snapshot!.conversation, 'folder', '当前分组');
      });
      final origin = f.chat.snapshot!.conversation.id;
      try {
        final context = await host(tester, GlobalKey(), false);
        showChatHistory(context, f.chat);
        await tester.pumpAndSettle();
        await tester.tap(find.text('新建对话'));
        await until(
          tester,
          () =>
              !f.chat.savingPreference &&
              f.chat.snapshot!.conversation.id != origin,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat-history-panel')), findsNothing);
        expect(f.chat.snapshot!.conversation.folder, '当前分组');
        expect(f.chat.snapshot!.conversation.characterId, 'default_character');
        final title = f.chat.snapshot!.conversation.title;
        expect(
          title,
          matches(r'^新对话 (?:[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$'),
        );
        await tester.runAsync(f.chat.load);
        expect(f.chat.snapshot!.conversation.title, title);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'history creation closes its own route after commit read failure without duplicate',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      final client = _CreationClient(f.runtime)..failCatalog = true;
      final chat = _owner(f, client);
      try {
        final context = await host(tester, GlobalKey(), false);
        showChatHistory(context, chat);
        await tester.pumpAndSettle();
        final before = f.chat.catalog!.conversations.length;
        await tester.tap(find.text('新建对话'));
        await until(
          tester,
          () =>
              !chat.savingPreference &&
              find.byKey(const Key('chat-history-panel')).evaluate().isEmpty,
        );
        expect(chat.error, isNotNull);
        expect(client.writes, 1);
        await tester.runAsync(() async {
          expect(
            (await f.runtime.conversationCatalog()).conversations.length,
            before + 1,
          );
          client.failCatalog = false;
          expect(await chat.load(followActive: true), isTrue);
        });
        expect(
          chat.snapshot!.conversation.id,
          isNot(f.chat.snapshot!.conversation.id),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets(
    'late new-chat completion removes history route and preserves later modal',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      final client = _CreationClient(f.runtime)
        ..beforeCommit = Completer<void>();
      final chat = _owner(f, client);
      try {
        final context = await host(tester, GlobalKey(), false);
        showChatHistory(context, chat);
        await tester.pumpAndSettle();
        await tester.tap(find.text('新建对话'));
        await tester.pump();
        expect(chat.savingPreference, isTrue);
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('后开的窗口')),
        );
        await tester.pumpAndSettle();
        client.beforeCommit!.complete();
        await until(
          tester,
          () =>
              !chat.savingPreference &&
              find
                  .byKey(const Key('chat-history-panel'), skipOffstage: false)
                  .evaluate()
                  .isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('后开的窗口'), findsOneWidget);
        expect(client.writes, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!client.beforeCommit!.isCompleted) client.beforeCommit!.complete();
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'late group creation preserves concurrent selection in SQLite and UI',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
      });
      final client = _CreationClient(f.runtime)
        ..beforeCommit = Completer<void>();
      final chat = _owner(f, client);
      final boundary = GlobalKey();
      try {
        final context = await host(tester, boundary, false);
        showHistoryFolderEditor(context, chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '迟到分组');
        await tester.pump();
        await tester.tap(find.text('创建'));
        await tester.pump();
        expect(chat.savingPreference, isTrue);
        await tester.tapAt(const Offset(2, 2));
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('新建分组'), findsOneWidget);
        late String other;
        await tester.runAsync(() async {
          other = await f.runtime.createConversation();
          expect(await chat.select(other), isTrue);
          client.beforeCommit!.complete();
        });
        await until(tester, () => !chat.savingPreference);
        // 原生提示是独立异步边界，事务结束后还需等待模态关闭。
        await until(tester, () => find.text('新建分组').evaluate().isEmpty);
        await tester.pumpAndSettle();
        expect(find.text('新建分组'), findsNothing);
        expect(find.text('分组已创建。当前聊天已从其他入口切换，已保留你的新选择。'), findsOneWidget);
        expect(chat.snapshot!.conversation.id, other);
        await tester.runAsync(() async {
          final directory = await f.runtime.conversationCatalog();
          expect(directory.activeId, other);
          expect(
            directory.conversations
                .where((c) => c.folder == '迟到分组')
                .single
                .characterId,
            '',
          );
        });
        expect(client.writes, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!client.beforeCommit!.isCompleted) client.beforeCommit!.complete();
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        await tester.runAsync(f.close);
      }
    },
  );

  testWidgets('selection after commit wins over delayed directory projection', (
    tester,
  ) async {
    final f = ChatFixture();
    await tester.runAsync(() async {
      await f.open();
      await f.chat.create();
    });
    final gate = Completer<void>();
    final client = _CreationClient(f.runtime)..afterCatalog = gate;
    final chat = _owner(f, client);
    try {
      HistoryGroupCreation? result;
      await tester.runAsync(() async {
        unawaited(
          chat
              .createHistoryGroup('目录延迟', includeUnbound: false)
              .then((value) => result = value),
        );
      });
      await until(tester, () => client.catalogHeld.isCompleted);
      late String other;
      await tester.runAsync(() async {
        other = await f.runtime.createConversation();
        client.afterCatalog = null;
        expect(await chat.select(other), isTrue);
      });
      // 原目录读取不能再把旧active投影回UI。
      gate.complete();
      expect(chat.snapshot!.conversation.id, other);
      await until(tester, () => result != null);
      expect(result, HistoryGroupCreation.selectionChanged);
      expect(chat.snapshot!.conversation.id, other);
      expect(
        chat.catalog!.conversations.where((c) => c.folder == '目录延迟').length,
        1,
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
      chat.dispose();
      await tester.runAsync(f.close);
    }
  });

  for (final snapshotFailure in [false, true]) {
    testWidgets(
      'committed ${snapshotFailure ? 'snapshot' : 'catalog'} failure becomes close-only dialog',
      (tester) async {
        final f = ChatFixture();
        await tester.runAsync(() async {
          await f.open();
          await f.chat.create();
        });
        final client = _CreationClient(f.runtime)
          ..failCatalog = !snapshotFailure
          ..failSnapshot = snapshotFailure;
        final chat = _owner(f, client);
        final boundary = GlobalKey();
        try {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          if (output.isNotEmpty) await loadCaptureFonts(tester);
          final context = await host(tester, boundary, snapshotFailure);
          showHistoryFolderEditor(context, chat);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '已保存分组');
          await tester.pump();
          await tester.tap(find.text('创建'));
          await until(tester, () => !chat.savingPreference);
          await tester.pumpAndSettle();
          expect(find.text('创建'), findsNothing);
          expect(find.text('取消'), findsNothing);
          expect(find.text('关闭'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            isFalse,
          );
          expect(
            find.text('分组已创建，但切换聊天失败。请关闭此窗口，从历史列表打开新分组；不要重复创建。'),
            findsOneWidget,
          );
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              snapshotFailure
                  ? 'dark-group-created-failed'
                  : 'light-group-created-failed',
            );
          }
          if (snapshotFailure) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.text('关闭'));
          }
          await tester.pumpAndSettle();
          expect(find.text('放弃未保存的修改？'), findsNothing);
          await tester.runAsync(() async {
            final directory = await f.runtime.conversationCatalog();
            expect(
              directory.conversations.where((c) => c.folder == '已保存分组').length,
              1,
            );
            client.failCatalog = client.failSnapshot = false;
            expect(await chat.load(followActive: true), isTrue);
          });
          expect(chat.snapshot!.conversation.folder, '已保存分组');
          expect(client.writes, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          chat.dispose();
          await tester.runAsync(f.close);
        }
      },
    );
  }

  testWidgets(
    'precommit failure keeps draft retryable and binding frozen at dialog opening',
    (tester) async {
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.create();
        await f.chat.setPreference('history_mode', 'current');
      });
      final client = _CreationClient(f.runtime)..failBeforeCommit = true;
      final chat = _owner(f, client);
      final boundary = GlobalKey();
      try {
        final context = await host(tester, boundary, false);
        showHistoryFolderEditor(context, chat);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '可重试');
        await tester.pump();
        await tester.tap(find.text('创建'));
        await until(tester, () => !chat.savingPreference);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        expect(find.text('分组操作未完成，输入和确认已保留。请核对列表后重试。'), findsOneWidget);
        await tester.runAsync(() async {
          final directory = await f.runtime.conversationCatalog();
          expect(
            directory.conversations.where((c) => c.folder == '可重试'),
            isEmpty,
          );
          final original = f.chat.prompts!.characters.single;
          final other = await f.runtime.saveCharacter(
            null,
            null,
            original.draft,
          );
          await f.runtime.selectChatCharacter(other);
          await chat.load(followActive: true);
        });
        client.failBeforeCommit = false;
        await tester.tap(find.text('创建'));
        await until(tester, () => !chat.savingPreference);
        await tester.pumpAndSettle();
        expect(find.text('新建分组'), findsNothing);
        expect(chat.snapshot!.conversation.folder, '可重试');
        expect(chat.snapshot!.conversation.characterId, 'default_character');
        expect(client.writes, 2);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        await tester.runAsync(f.close);
      }
    },
  );
}
