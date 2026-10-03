import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/knowledge/presentation/graph_layout.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_controller.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_graph.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_page.dart';
import 'package:kiyori/features/knowledge/presentation/memory_link_editor.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/fake_runtime.dart';

const memory = MemoryDraft(
  kind: 'memory',
  title: '原始记录',
  content: '完整内容',
  category: 'other',
  source: 'user_input',
  folder: '',
  credibility: .8,
  importance: .5,
  tags: [],
);

class GraphController extends KnowledgeController {
  GraphController() : super(() async => FakeClient());
  bool succeeds = false;
  MemoryLinkDraft? lastDraft;
  @override
  Future<bool> saveLink(String space, String? id, MemoryLinkDraft draft) async {
    lastDraft = draft;
    error = succeeds ? null : '无法保存记忆库，请重试。';
    notifyListeners();
    return succeeds;
  }
}

Future<void> settleNative(
  WidgetTester tester,
  KnowledgeController state,
) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (!state.loading && !state.saving && attempt > 20) break;
  }
  await tester.pumpAndSettle();
  expect(state.error, isNull);
  expect(state.loading || state.saving, isFalse);
  expect(tester.takeException(), isNull);
}

Finder canvasFinder() => find.descendant(
  of: find.byType(KnowledgeGraphView),
  matching: find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter?.semanticsBuilder != null,
  ),
);
Offset nodePoint(WidgetTester tester, String title) {
  final finder = canvasFinder();
  final paint = tester.widget<CustomPaint>(finder);
  final nodes = paint.painter!.semanticsBuilder!(tester.getSize(finder));
  return tester.getTopLeft(finder) +
      nodes.singleWhere((n) => n.properties.label == title).rect.center;
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  test(
    'bounded force layout is deterministic and separates coincident nodes',
    () {
      final ids = List.generate(200, (i) => 'node$i');
      final input = GraphLayoutInput(
        ids,
        [for (var i = 1; i < ids.length; i++) (ids[i - 1], ids[i], .7, false)],
        {},
        const Size(1280, 800),
      );
      final result = layoutMemoryGraph(input);
      expect(result.length, 200);
      expect(result, layoutMemoryGraph(input));
      expect(
        result.values.every((p) => p.dx.isFinite && p.dy.isFinite),
        isTrue,
      );
      final separated = layoutMemoryGraph(
        const GraphLayoutInput(
          ['a', 'b'],
          [],
          {'a': Offset.zero, 'b': Offset.zero},
          Size(400, 800),
        ),
      );
      expect((separated['a']! - separated['b']!).distance, greaterThan(1));
    },
  );

  testWidgets(
    'native graph links, edits preserved descriptions, zooms and deletes a selected batch',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('kiyori-graph-ui-'),
      ))!;
      final client = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final state = KnowledgeController(() async => client);
      final capture = GlobalKey();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.runAsync(() async {
          await client.saveMemory('default', null, memory);
          await client.saveMemory(
            'default',
            null,
            const MemoryDraft(
              kind: 'memory',
              title: '参考记录',
              content: '第二条内容',
              category: 'other',
              source: 'user_input',
              folder: '',
              credibility: .8,
              importance: .5,
              tags: [],
            ),
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => RepaintBoundary(key: capture, child: child!),
            home: Scaffold(
              body: KnowledgePage(controller: state, onMenu: () {}),
            ),
          ),
        );
        await settleNative(tester, state);
        await tester.tap(
          find.byWidgetPredicate((w) => w is ShellAction && w.label == '图谱'),
        );
        await settleNative(tester, state);
        expect(state.graph!.nodes.length, 2);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'graph-before-link');
        }
        await tester.tap(find.byTooltip('连接节点'));
        await tester.pumpAndSettle();
        await tester.tapAt(nodePoint(tester, '原始记录'));
        await tester.pumpAndSettle();
        await tester.tapAt(nodePoint(tester, '参考记录'));
        await tester.pumpAndSettle();
        expect(find.byType(MemoryLinkEditor), findsOneWidget);
        final description = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '描述',
        );
        await tester.enterText(description, '不丢失的关系说明');
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'graph-link-editor');
        }
        await tester.tap(find.text('创建关联'));
        await settleNative(tester, state);
        expect(state.graph!.edges.single.draft.description, '不丢失的关系说明');
        final midpoint =
            (nodePoint(tester, '原始记录') + nodePoint(tester, '参考记录')) / 2;
        final beforeEdit = nodePoint(tester, '原始记录');
        await tester.tapAt(midpoint);
        await tester.pumpAndSettle();
        expect(find.text('关联详情'), findsOneWidget);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'graph-link-details');
        }
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(description).controller!.text,
          '不丢失的关系说明',
        );
        await tester.enterText(description, '修订后描述');
        await tester.tap(find.text('保存'));
        await settleNative(tester, state);
        expect(state.graph!.edges.single.draft.description, '修订后描述');
        expect(
          nodePoint(tester, '原始记录'),
          beforeEdit,
          reason: 'Description-only edits must not rerun physical layout.',
        );
        await tester.drag(canvasFinder(), const Offset(30, 20));
        await tester.pumpAndSettle();
        final beforeZoom =
            (nodePoint(tester, '原始记录') - nodePoint(tester, '参考记录')).distance;
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(canvasFinder()),
            scrollDelta: const Offset(0, -120),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          (nodePoint(tester, '原始记录') - nodePoint(tester, '参考记录')).distance,
          greaterThan(beforeZoom),
        );
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'graph-linked');
        }
        await tester.tapAt(
          (nodePoint(tester, '原始记录') + nodePoint(tester, '参考记录')) / 2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await settleNative(tester, state);
        expect(state.graph!.edges, isEmpty);
        expect(state.graph!.nodes.length, 2);
        await tester.tap(find.byTooltip('框选节点'));
        await tester.pumpAndSettle();
        final a = nodePoint(tester, '原始记录'), b = nodePoint(tester, '参考记录');
        final box = Rect.fromPoints(a, b).inflate(40);
        final gesture = await tester.startGesture(box.topLeft);
        await gesture.moveTo(box.bottomRight);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byTooltip('删除选中节点'), findsOneWidget);
        await tester.tap(find.byTooltip('删除选中节点'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(state.graph!.nodes.length, 2);
        await tester.tap(find.byTooltip('删除选中节点'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认删除').last);
        await settleNative(tester, state);
        expect(state.graph!.nodes, isEmpty);
        expect(find.text('新建记忆'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        state.dispose();
        await tester.runAsync(() async {
          await client.close();
          await directory.delete(recursive: true);
        });
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets(
    'long relation editor remains usable with large text and keyboard',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      for (final size in [const Size(320, 720), const Size(844, 390)]) {
        final state = GraphController()..succeeds = true;
        final capture = GlobalKey();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => RepaintBoundary(
              key: capture,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: EdgeInsets.only(
                    bottom: size.width == 320 ? 220 : 100,
                  ),
                ),
                child: child!,
              ),
            ),
            home: SettingsTheme(
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => MemoryLinkEditor(
                        controller: state,
                        space: 'default',
                        source: GraphNode(
                          id: 'a',
                          title: '很长的来源记忆标题' * 12,
                          nodeType: 'other',
                        ),
                        target: GraphNode(
                          id: 'b',
                          title: '很长的目标记忆标题' * 12,
                          nodeType: 'other',
                        ),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final description = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '描述',
        );
        await tester.ensureVisible(description);
        await tester.pumpAndSettle();
        await tester.enterText(description, '窄屏键盘仍可编辑');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            capture,
            output,
            '${size.width.toInt()}-link-keyboard',
          );
        }
        await tester.tap(find.text('创建关联'));
        await tester.pumpAndSettle();
        expect(state.lastDraft?.description, '窄屏键盘仍可编辑');
        expect(find.byType(MemoryLinkEditor), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'graph relation failure retains draft and host removal releases its modal',
    (tester) async {
      final state = GraphController()
        ..graph = const MemoryGraph(
          spaceId: 'default',
          hasMore: false,
          nodes: [
            GraphNode(id: 'a', title: '源节点', nodeType: 'other'),
            GraphNode(id: 'b', title: '目标节点', nodeType: 'other'),
          ],
          edges: [],
        );
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeGraphView(controller: state, onNode: (_, _) {}),
          ),
        ),
      );
      await settleNative(tester, state);
      await tester.tap(find.byTooltip('连接节点'));
      await tester.pumpAndSettle();
      await tester.tapAt(nodePoint(tester, '源节点'));
      await tester.pumpAndSettle();
      await tester.tapAt(nodePoint(tester, '目标节点'));
      await tester.pumpAndSettle();
      final description = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '描述',
      );
      await tester.enterText(description, '失败仍保留');
      await tester.tap(find.text('创建关联'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(description).controller!.text, '失败仍保留');
      expect(find.text('无法保存记忆库，请重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'graph node hit targets and toolbar fit light dark narrow and large text',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      for (final size in [
        const Size(320, 640),
        const Size(844, 390),
        const Size(1280, 800),
      ]) {
        for (final brightness in Brightness.values) {
          final state = GraphController()
            ..graph = const MemoryGraph(
              spaceId: 'default',
              hasMore: false,
              nodes: [GraphNode(id: 'a', title: '学习与实践', nodeType: 'other')],
              edges: [],
            );
          final capture = GlobalKey();
          String? opened;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => RepaintBoundary(
                key: capture,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: SettingsTheme(
                  child: KnowledgeGraphView(
                    controller: state,
                    onNode: (_, id) => opened = id,
                  ),
                ),
              ),
            ),
          );
          await settleNative(tester, state);
          await tester.tapAt(nodePoint(tester, '学习与实践'));
          await tester.pumpAndSettle();
          expect(opened, 'a');
          expect(tester.takeException(), isNull);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              capture,
              output,
              '${size.width.toInt()}-${brightness.name}-graph',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          state.dispose();
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
