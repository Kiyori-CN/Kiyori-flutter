import 'dart:async';
import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

void main() {
  test(
    'search preferences and real ranking cross FFI and survive reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kiyori-search-ffi-',
      );
      final client = await NativeRuntimeClient.open(
        dataDirectory: directory.path,
      );
      try {
        const draft = MemoryDraft(
          kind: 'memory',
          title: '桥接检索',
          content: '全文事实',
          category: 'other',
          source: 'user_input',
          folder: '',
          credibility: .8,
          importance: .5,
          tags: ['测试'],
        );
        final id = await client.saveMemory('default', null, draft);
        await client.setMemoryGraphVisible('default', true);
        await client.saveMemorySearchSettings(
          'default',
          const MemorySearchSettings(
            graphVisible: false,
            scoreMode: 'keyword_first',
            keywordWeight: 10,
            tagWeight: 4,
            vectorWeight: 0,
            edgeWeight: .4,
            autoInterval: 8,
            extractionRules: '保留事实',
          ),
        );
        final settings = await client.memorySearchSettings('default');
        expect(settings.graphVisible, isTrue);
        expect(settings.autoInterval, 8);
        final report = await client.simulateMemorySearch(
          'default',
          const MemoryQuery(
            kind: 'memory',
            folder: '',
            text: '全文事实',
            archived: false,
            sortTitle: false,
            offset: 0,
          ),
        );
        expect(report.candidates.single.id, id);
        expect(report.candidates.single.keywordScore, greaterThan(0));
        expect(report.keywordWeight, 13);
        await client.close();
        final reopened = await NativeRuntimeClient.open(
          dataDirectory: directory.path,
        );
        try {
          expect(
            (await reopened.memorySearchSettings('default')).extractionRules,
            '保留事实',
          );
        } finally {
          await reopened.close();
        }
        await expectLater(
          () => client.memorySearchSettings('default'),
          throwsA(isA<BridgeError>()),
        );
      } finally {
        await client.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('graph relationships persist descriptions, isolate spaces and cascade across FFI', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kiyori-graph-ffi-',
    );
    NativeRuntimeClient? client;
    try {
      client = await NativeRuntimeClient.open(dataDirectory: directory.path);
      const draft = MemoryDraft(
        kind: 'memory',
        title: '端点',
        content: '完整内容',
        category: 'other',
        source: 'user_input',
        folder: '',
        credibility: .8,
        importance: .5,
        tags: [],
      );
      final a = await client.saveMemory('default', null, draft);
      final b = await client.saveMemory('default', null, draft);
      final id = await client.saveMemoryLink(
        'default',
        null,
        MemoryLinkDraft(
          sourceId: a,
          targetId: b,
          relation: 'explains',
          weight: .6,
          description: '关联说明',
        ),
      );
      await client.close();
      client = await NativeRuntimeClient.open(dataDirectory: directory.path);
      const query = MemoryQuery(
        kind: 'memory',
        folder: '',
        text: '',
        archived: false,
        sortTitle: false,
        offset: 0,
      );
      final graph = await client.memoryGraph(query);
      expect(graph.nodes.length, 2);
      expect(graph.edges.single.draft.description, '关联说明');
      expect(graph.edges.single.id, id);
      expect(await client.deleteMemoryLink('other', id), isFalse);
      await expectLater(
        client.deleteMemories('default', [a, 'missing']),
        throwsA(isA<BridgeError>()),
      );
      expect((await client.memoryGraph(query)).nodes.length, 2);
      expect(await client.deleteMemories('default', [a, b]), 2);
      expect((await client.memoryGraph(query)).edges, isEmpty);
    } finally {
      await client?.close();
      await directory.delete(recursive: true);
    }
  });
  test(
    'diary seed append close and reopen preserve full history across FFI',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kiyori-diary-ffi-',
      );
      NativeRuntimeClient? client;
      try {
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        const draft = MemoryDraft(
          kind: 'diary',
          title: '推进记录',
          content: '开篇计划',
          category: 'other',
          source: 'user_input',
          folder: '',
          credibility: .8,
          importance: .5,
          tags: ['进展'],
        );
        final id = await client.createDiary(
          'default',
          draft,
          'plan',
          '2026-10-03 09:40',
        );
        await client.appendDiary(
          'default',
          id,
          '新增证据',
          'evidence',
          '2026-10-03 09:41',
        );
        await client.appendDiary(
          'default',
          id,
          '',
          'closed',
          '2026-10-03 09:42',
        );
        await client.close();
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        final list = await client.queryKnowledge(
          const MemoryQuery(
            kind: 'diary',
            folder: '',
            text: '',
            archived: false,
            sortTitle: false,
            offset: 0,
          ),
        );
        expect(list.records.single.draft.content, '新增证据');
        expect(list.records.single.diary!.closed, isTrue);
        expect(list.records.single.diary!.entryCount, 3);
        final activeOnly = await client.queryKnowledge(
          const MemoryQuery(
            kind: 'diary',
            folder: '',
            text: '',
            archived: false,
            sortTitle: false,
            offset: 0,
            diaryClosed: false,
          ),
        );
        expect(activeOnly.records, isEmpty);
        final full = (await client.getMemory('default', id))!;
        final parsed = await client.parseDiary(full.draft.content);
        expect(parsed.entries.map((e) => e.phase), [
          'plan',
          'evidence',
          'closed',
        ]);
        expect(parsed.entries.first.body, '开篇计划');
        await client.archiveMemory('default', id, true);
        await expectLater(
          client.appendDiary('default', id, '拒绝', 'note', '2026-10-03 09:43'),
          throwsA(isA<BridgeError>()),
        );
        await client.archiveMemory('default', id, false);
        await client.appendDiary(
          'default',
          id,
          '继续推进',
          'progress',
          '2026-10-03 09:44',
        );
        expect((await client.getMemory('default', id))!.diary!.closed, isFalse);
      } finally {
        await client?.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'knowledge DTOs preserve space identity, Unicode and committed state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kiyori-ffi-knowledge-',
      );
      NativeRuntimeClient? client;
      try {
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        final space = await client.saveKnowledgeSpace(null, '阅读资料');
        await client.selectKnowledgeSpace(space);
        await client.createKnowledgeFolder(space, '读书/小说');
        const draft = MemoryDraft(
          kind: 'knowledge',
          title: '原文 🐱',
          content: '第一行\n第二行',
          category: 'other',
          source: '手工',
          folder: '读书/小说',
          credibility: .8,
          importance: .5,
          tags: ['中文', '中文'],
        );
        final id = await client.saveMemory(space, null, draft);
        await client.close();
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        final snapshot = await client.knowledgeSnapshot();
        expect(snapshot.activeSpace, space);
        expect(snapshot.records.single.draft.content, draft.content);
        expect(snapshot.records.single.draft.tags, ['中文']);
        final query = await client.queryKnowledge(
          const MemoryQuery(
            kind: 'knowledge',
            folder: '',
            text: '第二行',
            archived: false,
            sortTitle: false,
            offset: 0,
          ),
        );
        expect(query.records.single.id, id);
        expect(query.hasMore, isFalse);
        expect(query.availableTags, ['中文']);
        expect(
          (await client.getMemory(space, id))!.draft.content,
          draft.content,
        );
        await client.renameKnowledgeFolder(space, '读书', '资料');
        expect(
          (await client.knowledgeSnapshot()).records.single.draft.folder,
          '资料/小说',
        );
        await client.deleteKnowledgeFolder(space, '资料');
        expect(
          (await client.knowledgeSnapshot()).records.single.draft.folder,
          '',
        );
        await expectLater(
          client.saveMemory('default', id, draft),
          throwsA(
            isA<BridgeError>().having(
              (e) => e.code,
              'identity',
              ErrorCode.invalidInput,
            ),
          ),
        );
        await client.archiveMemory(space, id, true);
        expect(
          (await client.knowledgeSnapshot()).records.single.archived,
          isTrue,
        );
        await client.deleteKnowledgeSpace(space);
        expect((await client.knowledgeSnapshot()).activeSpace, 'default');
        await client.close();
        expect(() => client!.knowledgeSnapshot(), throwsA(isA<BridgeError>()));
      } finally {
        await client?.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'real SQLite bridge persists Unicode records, deletes and closes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kiyori-ffi-workflows-',
      );
      NativeRuntimeClient? client;
      try {
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        expect(await client.listWorkflows(), isEmpty);
        final first = await client.createWorkflow('中文工作流', '第一行\n第二行');
        final second = await client.createWorkflow('另一个工作流', '');
        expect((await client.listWorkflows()).map((w) => w.id), [
          second.id,
          first.id,
        ]);
        await client.close();
        await expectLater(
          client.listWorkflows(),
          throwsA(
            isA<BridgeError>().having(
              (e) => e.code,
              'closed',
              ErrorCode.runtimeClosed,
            ),
          ),
        );
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        final restored = await client.listWorkflows();
        expect(restored.last, first);
        final edited = await client.updateWorkflow(
          id: second.id,
          name: '重命名',
          description: '保存描述',
          enabled: false,
        );
        expect(edited.createdAt, second.createdAt);
        expect(edited.enabled, isFalse);
        expect(await client.deleteWorkflow(first.id), isTrue);
        expect(await client.deleteWorkflow(first.id), isFalse);
        await expectLater(
          client.createWorkflow('  ', ''),
          throwsA(
            isA<BridgeError>().having(
              (e) => e.code,
              'invalid',
              ErrorCode.invalidInput,
            ),
          ),
        );
        await client.close();
        client = await NativeRuntimeClient.open(dataDirectory: directory.path);
        expect((await client.listWorkflows()).single, edited);
        final third = await client.createWorkflow('批量删除', '');
        expect(
          await client.deleteWorkflows([edited.id, third.id, edited.id]),
          2,
        );
        expect(await client.listWorkflows(), isEmpty);
      } finally {
        await client?.close();
        await directory.delete(recursive: true);
      }
    },
  );
  late NativeRuntimeClient runtime;
  setUp(() async {
    runtime = await NativeRuntimeClient.open();
  });
  tearDown(() async {
    await runtime.close();
  });

  test(
    'native initialization reports real host and only implemented capabilities',
    () async {
      final info = await runtime.info();
      expect(info.hostPlatform, isNotEmpty);
      expect(info.coreVersion, '0.1.0');
      expect(
        info.capabilities
            .singleWhere((c) => c.id == 'kiyori.runtime.diagnostics')
            .available,
        isTrue,
      );
      expect(
        info.capabilities
            .singleWhere((c) => c.id == 'kiyori.browser')
            .available,
        isFalse,
      );
    },
  );

  test('real FFI delivers ordered completion', () async {
    final run = await runtime.startDiagnostic(steps: 2, intervalMs: 10);
    final events = await run.events.toList();
    expect(events.map((e) => e.revision), [0, 1, 2]);
    expect(events.last.phase, TaskPhase.completed);
    await run.cancel(); // Cancellation after resource release is safe.
  });

  test('native typed errors survive the boundary', () async {
    await expectLater(
      runtime.startDiagnostic(steps: 0),
      throwsA(
        isA<BridgeError>().having(
          (e) => e.code,
          'code',
          ErrorCode.invalidInput,
        ),
      ),
    );
  });

  test('explicit cancellation wakes a waiting native event', () async {
    final run = await runtime.startDiagnostic(steps: 100, intervalMs: 1000);
    final started = Completer<void>();
    final eventsFuture = run.events.map((event) {
      if (!started.isCompleted) started.complete();
      return event;
    }).toList();
    await started.future;
    await run.cancel();
    final events = await eventsFuture.timeout(const Duration(seconds: 2));
    expect(events.last.phase, TaskPhase.cancelled);
    expect(events.last.completedSteps, 0);
  });

  test(
    'subscription cancellation and paused stream close do not deadlock',
    () async {
      final run = await runtime.startDiagnostic(steps: 100, intervalMs: 1000);
      final started = Completer<void>();
      final subscription = run.events.listen((_) {
        if (!started.isCompleted) started.complete();
      });
      await started.future;
      subscription.pause();
      await subscription.cancel().timeout(const Duration(seconds: 2));
      await runtime.close().timeout(const Duration(seconds: 2));
    },
  );

  test(
    'closing releases an unconsumed run and rejects subsequent work',
    () async {
      final run = await runtime.startDiagnostic();
      await runtime.close().timeout(const Duration(seconds: 2));
      expect(await run.events.toList(), isEmpty);
      await expectLater(
        runtime.startDiagnostic(),
        throwsA(
          isA<BridgeError>().having(
            (e) => e.code,
            'code',
            ErrorCode.runtimeClosed,
          ),
        ),
      );
    },
  );
}
