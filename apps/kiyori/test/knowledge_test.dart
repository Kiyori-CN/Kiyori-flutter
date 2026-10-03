import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_controller.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_page.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

const sampleDraft = MemoryDraft(
  kind: 'memory',
  title: '记下偏好',
  content: '完整保存的正文',
  category: 'preference',
  source: 'user_input',
  folder: '',
  credibility: .8,
  importance: .5,
  tags: ['日常'],
);

class KnowledgeClient extends FakeClient {
  final records = <MemoryRecord>[];
  final folders = <String>[];
  final spaces = <KnowledgeSpace>[
    const KnowledgeSpace(id: 'default', name: '默认配置'),
  ];
  String active = 'default';
  bool failWrite = false;
  int writes = 0;
  Completer<void>? pending;
  Future<KnowledgeSnapshot> Function()? read;
  Future<MemoryRecord?> Function()? readDetail;
  @override
  Future<MemoryRecord?> getMemory(String space, String id) =>
      readDetail?.call() ?? super.getMemory(space, id);
  @override
  Future<KnowledgeSnapshot> knowledgeSnapshot() async => read != null
      ? read!()
      : KnowledgeSnapshot(
          hasMore: false,
          spaces: List.of(spaces),
          activeSpace: active,
          folders: List.of(folders),
          records: records.where((r) => r.spaceId == active).toList(),
        );
  @override
  Future<KnowledgeSnapshot> queryKnowledge(MemoryQuery query) async {
    final all = await knowledgeSnapshot();
    final subtree =
        query.text.isNotEmpty ||
        query.category != null ||
        query.tag != null ||
        query.archived;
    final matches = all.records
        .where(
          (r) =>
              r.draft.kind == query.kind &&
              r.archived == query.archived &&
              (query.category == null || query.category == r.draft.category) &&
              (query.tag == null || r.draft.tags.contains(query.tag)) &&
              (subtree
                  ? (query.folder.isEmpty ||
                        r.draft.folder == query.folder ||
                        r.draft.folder.startsWith('${query.folder}/'))
                  : r.draft.folder == query.folder) &&
              (query.text.isEmpty ||
                  '${r.draft.title}\n${r.draft.content}\n${r.draft.tags.join(' ')}'
                      .contains(query.text)),
        )
        .toList();
    if (query.sortTitle) {
      matches.sort((a, b) => a.draft.title.compareTo(b.draft.title));
    }
    return KnowledgeSnapshot(
      spaces: all.spaces,
      activeSpace: all.activeSpace,
      folders: all.folders,
      records: matches.skip(query.offset).take(100).toList(),
      hasMore: matches.length > query.offset + 100,
    );
  }

  @override
  Future<String> saveMemory(String space, String? id, MemoryDraft draft) async {
    writes++;
    await pending?.future;
    if (failWrite) throw StateError('write failure');
    final record = MemoryRecord(
      id: id ?? 'memory-$writes',
      spaceId: space,
      draft: draft,
      archived: false,
      createdAt: 1790980000000,
      updatedAt: 1790980000000 + writes,
    );
    records.removeWhere((r) => r.id == id);
    records.insert(0, record);
    return record.id;
  }

  @override
  Future<void> selectKnowledgeSpace(String id) async {
    active = id;
  }

  @override
  Future<String> saveKnowledgeSpace(String? id, String name) async {
    final value = id ?? 'space-${spaces.length}';
    spaces.removeWhere((s) => s.id == id);
    spaces.add(KnowledgeSpace(id: value, name: name));
    if (id == null) active = value;
    return value;
  }

  @override
  Future<void> createKnowledgeFolder(String space, String path) async {
    folders.add(path);
  }

  @override
  Future<void> renameKnowledgeFolder(
    String space,
    String old,
    String path,
  ) async {
    for (var i = 0; i < folders.length; i++) {
      if (folders[i] == old || folders[i].startsWith('$old/')) {
        folders[i] = path + folders[i].substring(old.length);
      }
    }
  }

  @override
  Future<void> deleteKnowledgeFolder(String space, String path) async {
    folders.removeWhere((p) => p == path || p.startsWith('$path/'));
  }

  @override
  Future<bool> deleteMemory(String space, String id) async {
    records.removeWhere((r) => r.id == id && r.spaceId == space);
    return true;
  }

  @override
  Future<void> archiveMemory(String space, String id, bool archived) async {
    final i = records.indexWhere((r) => r.id == id);
    final r = records[i];
    records[i] = MemoryRecord(
      id: r.id,
      spaceId: r.spaceId,
      draft: r.draft,
      archived: archived,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }
}

Future<void> host(
  WidgetTester tester,
  KnowledgeController state, {
  Size size = const Size(400, 800),
  double scale = 1,
  Brightness brightness = Brightness.light,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: KnowledgePage(controller: state, onMenu: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> release(WidgetTester tester, KnowledgeController state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  state.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  expect(tester.takeException(), isNull);
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
void main() {
  test('late detail failure cannot publish into another space', () async {
    final client = KnowledgeClient();
    await client.saveMemory('default', null, sampleDraft);
    final state = KnowledgeController(() async => client);
    await state.load();
    final pending = Completer<MemoryRecord?>();
    client.readDetail = () => pending.future;
    final reading = state.open(client.records.single);
    await Future<void>.delayed(Duration.zero);
    await state.saveSpace(null, '新空间');
    pending.completeError(StateError('old detail failed'));
    expect(await reading, isNull);
    expect(state.error, isNull);
    expect(state.snapshot!.activeSpace, 'space-1');
    state.dispose();
  });

  testWidgets(
    'controller replacement releases the former editor and listener',
    (tester) async {
      final first = KnowledgeController(() async => KnowledgeClient());
      final secondClient = KnowledgeClient();
      final second = KnowledgeController(() async => secondClient);
      await host(tester, first);
      await tester.tap(find.text('新建记忆').first);
      await tester.pumpAndSettle();
      expect(field('标题'), findsOneWidget);
      await host(tester, second);
      expect(field('标题'), findsNothing);
      await first.load();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      first.dispose();
      await release(tester, second);
    },
  );

  testWidgets(
    'AI drawer opens knowledge and Back consumes folders before home',
    (tester) async {
      final client = KnowledgeClient()..folders.add('项目');
      final state = KnowledgeController(() async => client);
      await tester.pumpWidget(MaterialApp(home: HomeShell(knowledge: state)));
      await tester.pumpAndSettle();
      tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main.memory_base')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('项目'));
      await tester.pumpAndSettle();
      expect(
        tester.state<KnowledgePageState>(find.byType(KnowledgePage)).folder,
        '项目',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.state<KnowledgePageState>(find.byType(KnowledgePage)).folder,
        '',
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      await release(tester, state);
    },
  );
  test('query pagination appends summaries and full details remain independently available', () async {
    final client = KnowledgeClient();
    for (var i = 0; i < 105; i++) {
      await client.saveMemory(
        'default',
        null,
        MemoryDraft(
          kind: 'memory',
          title: '记录$i',
          content: '正文${'完整原文' * 200}',
          category: 'other',
          source: 'user_input',
          folder: '',
          credibility: .8,
          importance: .5,
          tags: const [],
        ),
      );
    }
    final state = KnowledgeController(() async => client);
    addTearDown(state.dispose);
    await state.load();
    expect(state.snapshot!.records.length, 100);
    expect(state.snapshot!.hasMore, isTrue);
    await state.load(more: true);
    expect(state.snapshot!.records.length, 105);
    expect(state.snapshot!.hasMore, isFalse);
    expect(
      (await state.open(state.snapshot!.records.last))!.draft.content.length,
      greaterThan(400),
    );
    state.setQuery(
      const MemoryQuery(
        kind: 'memory',
        folder: '',
        text: '记录104',
        archived: false,
        sortTitle: false,
        offset: 0,
      ),
    );
    await state.load();
    expect(state.snapshot!.records.single.draft.title, '记录104');
  });
  testWidgets(
    'space creation and directory rename/delete use confirmed targets',
    (tester) async {
      final client = KnowledgeClient();
      final state = KnowledgeController(() async => client);
      await host(tester, state);
      await tester.tap(find.text('默认配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('管理记忆空间'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建记忆空间'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byType(TextField),
        ),
        '新空间',
      );
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(client.spaces.last.name, '新空间');
      await tester.tap(find.text('新空间'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byType(TextField),
        ),
        '项目',
      );
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(client.folders, ['项目']);
      await tester.tap(find.byTooltip('项目 的文件夹操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.byType(TextField),
        ),
        '资料',
      );
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(client.folders, ['资料']);
      await tester.tap(find.byTooltip('资料 的文件夹操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('保留正文，移到根目录'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(client.folders, isEmpty);
      await release(tester, state);
    },
  );
  testWidgets('entity deletion removes editor and its open category menu', (
    tester,
  ) async {
    final client = KnowledgeClient();
    await client.saveMemory('default', null, sampleDraft);
    final state = KnowledgeController(() async => client);
    await host(tester, state);
    await tester.tap(find.text('记下偏好'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('主题 · 偏好'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题 · 偏好'));
    await tester.pumpAndSettle();
    expect(find.text('决策'), findsOneWidget);
    client.records.clear();
    await state.load();
    await tester.pumpAndSettle();
    expect(find.text('决策'), findsNothing);
    expect(find.text('编辑记忆'), findsNothing);
    expect(find.text('让有用的信息留下来'), findsOneWidget);
    await release(tester, state);
  });
  testWidgets(
    'root host disposal before drawer first frame does not retain a route',
    (tester) async {
      final client = KnowledgeClient();
      final state = KnowledgeController(() async => client);
      await host(tester, state);
      await tester.tap(find.text('新建记忆'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  test('late read cannot overwrite a committed snapshot', () async {
    final client = KnowledgeClient();
    final state = KnowledgeController(() async => client);
    addTearDown(state.dispose);
    final old = Completer<KnowledgeSnapshot>();
    client.read = () => old.future;
    final loading = state.load();
    await Future<void>.delayed(Duration.zero);
    client.read = null;
    expect(await state.save('default', null, sampleDraft), isTrue);
    old.complete(
      const KnowledgeSnapshot(
        hasMore: false,
        spaces: [],
        activeSpace: 'old',
        folders: [],
        records: [],
      ),
    );
    await loading;
    expect(state.snapshot!.records.single.draft, sampleDraft);
  });
  test(
    'duplicate save is ignored and refresh failure preserves commit',
    () async {
      final client = KnowledgeClient()..pending = Completer<void>();
      final state = KnowledgeController(() async => client);
      addTearDown(state.dispose);
      final save = state.save('default', null, sampleDraft);
      expect(await state.save('default', null, sampleDraft), isFalse);
      client.read = () async => throw StateError('refresh');
      client.pending!.complete();
      expect(await save, isTrue);
      expect(client.writes, 1);
      expect(state.error, contains('操作已保存'));
    },
  );
  testWidgets(
    'create failures retain draft and successful save shows persisted record',
    (tester) async {
      final client = KnowledgeClient()..failWrite = true;
      final state = KnowledgeController(() async => client);
      await host(tester, state);
      await tester.tap(find.text('新建记忆'));
      await tester.pumpAndSettle();
      await tester.enterText(field('标题'), '真实标题');
      await tester.enterText(field('内容'), '正文保存');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('无法保存记忆库，请重试。'), findsWidgets);
      expect(find.text('真实标题'), findsOneWidget);
      client.failWrite = false;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(client.records.single.draft.content, '正文保存');
      expect(find.text('真实标题'), findsOneWidget);
      await release(tester, state);
    },
  );
  testWidgets('discard confirmation cancels only the edit session', (
    tester,
  ) async {
    final client = KnowledgeClient();
    final state = KnowledgeController(() async => client);
    await host(tester, state);
    await tester.tap(find.text('新建记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(field('标题'), '未保存');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('未保存'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('让有用的信息留下来'), findsOneWidget);
    expect(client.writes, 0);
    await release(tester, state);
  });
  testWidgets('space switch clears old location and owned dialogs', (
    tester,
  ) async {
    final client = KnowledgeClient()
      ..spaces.add(const KnowledgeSpace(id: 'other', name: '第二空间'));
    final state = KnowledgeController(() async => client);
    await host(tester, state);
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择记忆空间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二空间'));
    await tester.pumpAndSettle();
    expect(client.active, 'other');
    expect(find.text('空间与文件夹'), findsNothing);
    expect(find.text('第二空间'), findsOneWidget);
    await release(tester, state);
  });
  testWidgets(
    'archive filtering and confirmed deletion operate on the same record',
    (tester) async {
      final client = KnowledgeClient();
      await client.saveMemory('default', null, sampleDraft);
      final state = KnowledgeController(() async => client);
      await host(tester, state);
      await tester.tap(find.text('记下偏好'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档'));
      await tester.pumpAndSettle();
      expect(client.records.single.archived, isTrue);
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(client.records, isEmpty);
      expect(find.text('让有用的信息留下来'), findsOneWidget);
      await release(tester, state);
    },
  );
  testWidgets('leaving during pending save does not reopen a released editor', (
    tester,
  ) async {
    final client = KnowledgeClient()..pending = Completer<void>();
    final state = KnowledgeController(() async => client);
    await host(tester, state);
    await tester.tap(find.text('新建记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(field('标题'), '迟到');
    await tester.enterText(field('内容'), '正文');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    client.pending!.complete();
    await tester.pumpAndSettle();
    expect(client.records.single.draft.title, '迟到');
    state.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(tester.takeException(), isNull);
  });
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'search applies only on submit and archive filter returns archived records',
    (tester) async {
      final client = KnowledgeClient();
      await client.saveMemory('default', null, sampleDraft);
      final state = KnowledgeController(() async => client);
      await host(tester, state);
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '搜索记忆',
      );
      await tester.enterText(search, '不存在');
      await tester.pumpAndSettle();
      expect(find.text('查找需要的内容'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('没有找到内容'), findsOneWidget);
      await tester.tap(find.text('重置筛选'));
      await tester.pumpAndSettle();
      await client.archiveMemory('default', client.records.single.id, true);
      await state.load();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is ShellAction && w.label == '筛选'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('只看已归档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('只看已归档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('记下偏好'), findsOneWidget);
      await release(tester, state);
    },
  );
  testWidgets('knowledge representative viewports and editor captures', (
    tester,
  ) async {
    if (output.isNotEmpty) await loadCaptureFonts(tester);
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1280, 800),
    ]) {
      for (final brightness in Brightness.values) {
        final client = KnowledgeClient();
        final state = KnowledgeController(() async => client);
        final key = GlobalKey();
        final name = '${size.width.toInt()}-${brightness.name}';
        await host(
          tester,
          state,
          size: size,
          scale: size.width == 320 ? 2 : 1,
          brightness: brightness,
          capture: key,
        );
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, '$name-empty');
        }
        await tester.ensureVisible(find.text('新建记忆'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('新建记忆'));
        await tester.pumpAndSettle();
        await tester.enterText(field('标题'), '保留的偏好与事实');
        await tester.enterText(field('内容'), '第一行正文\n第二行完整保存');
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, '$name-editor');
        }
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, '$name-list');
        }
        await tester.tap(find.text('默认配置'));
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, '$name-folders');
        }
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate((w) => w is ShellAction && w.label == '筛选'),
        );
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, '$name-filters');
        }
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await release(tester, state);
      }
    }
  });
}
