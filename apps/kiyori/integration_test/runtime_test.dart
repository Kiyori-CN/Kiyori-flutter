import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
