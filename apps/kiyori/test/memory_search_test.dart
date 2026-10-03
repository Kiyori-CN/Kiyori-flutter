import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_controller.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_page.dart';
import 'package:kiyori/features/knowledge/presentation/memory_search_sheet.dart';
import 'package:kiyori/features/knowledge/presentation/memory_search_simulation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'knowledge_graph_test.dart' show settleNative;
import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

const defaults = MemorySearchSettings(
  graphVisible: false,
  scoreMode: 'balanced',
  keywordWeight: 10,
  tagWeight: 0,
  vectorWeight: 0,
  edgeWeight: .4,
  autoInterval: 5,
  extractionRules: '',
);
const scope = MemoryQuery(
  kind: 'memory',
  folder: '',
  text: '',
  archived: false,
  sortTitle: false,
  offset: 0,
);

class SearchController extends KnowledgeController {
  SearchController() : super(() async => FakeClient());
  MemorySearchSettings? draft;
  Completer<MemorySearchReport>? pending;
  @override
  Future<bool> saveSearchSettings(
    String space,
    MemorySearchSettings value,
  ) async {
    draft = value;
    error = '无法保存记忆库，请重试。';
    notifyListeners();
    return false;
  }

  @override
  Future<MemorySearchReport> simulateSearch(
    String space,
    MemoryQuery request,
  ) => pending!.future;
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets('simulation dark narrow keyboard layout and host removal', (
    tester,
  ) async {
    if (output.isNotEmpty) await loadCaptureFonts(tester);
    for (final size in [const Size(320, 720), const Size(844, 390)]) {
      final state = SearchController()
        ..pending = Completer<MemorySearchReport>();
      final capture = GlobalKey();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => RepaintBoundary(
            key: capture,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 100),
              ),
              child: child!,
            ),
          ),
          home: SettingsTheme(
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MemorySearchSimulation(
                      controller: state,
                      space: 'default',
                      scope: scope,
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
      await tester.enterText(find.byType(TextField), '中文检索');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) {
        await captureUi(
          tester,
          capture,
          output,
          '${size.width.toInt()}-simulation-dark-keyboard',
        );
      }
      await tester.tap(find.text('执行模拟'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.pending!.completeError(StateError('removed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      state.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets(
    'native settings persist graph choice, rules and simulation across reopening',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('kiyori-search-ui-'),
      ))!;
      final client = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final state = KnowledgeController(() async => client);
      final capture = GlobalKey();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.runAsync(
          () => client.saveMemory(
            'default',
            null,
            const MemoryDraft(
              kind: 'memory',
              title: '长安大学',
              content: '西安的学校',
              category: 'other',
              source: 'user_input',
              folder: '',
              credibility: .8,
              importance: .5,
              tags: ['教育'],
            ),
          ),
        );
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
          find.byWidgetPredicate(
            (w) => w is ShellAction && w.label == '记忆与检索设置',
          ),
        );
        await tester.pumpAndSettle();
        final rules = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '记忆提取附加规则',
        );
        await tester.ensureVisible(rules);
        await tester.enterText(rules, '只保存已确认事实');
        await tester.tap(find.text('保存'));
        await settleNative(tester, state);
        expect(find.byType(MemorySearchSheet), findsNothing);
        expect(state.searchSettings!.extractionRules, '只保存已确认事实');
        await tester.tap(
          find.byWidgetPredicate((w) => w is ShellAction && w.label == '图谱'),
        );
        await settleNative(tester, state);
        expect(state.graphVisible, isTrue);
        await tester.runAsync(() => state.load());
        await settleNative(tester, state);
        expect(state.graphVisible, isTrue);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is ShellAction && w.label == '记忆与检索设置',
          ),
        );
        await tester.pumpAndSettle();
        final simulate = find.text('模拟搜索');
        await tester.scrollUntilVisible(
          simulate,
          250,
          scrollable: find
              .descendant(
                of: find.byType(MemorySearchSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(simulate);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == '模拟查询',
          ),
          '长安大学在西安',
        );
        await tester.tap(find.text('执行模拟'));
        for (var i = 0; i < 80; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (find.text('搜索摘要').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        expect(find.text('范围内记忆: 1'), findsOneWidget);
        expect(find.textContaining('反向包含:1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'search-simulation-native');
        }
        await tester.tap(find.widgetWithText(OutlinedButton, '关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(MemorySearchSheet), findsOneWidget);
        final other = (await tester.runAsync(
          () => client.saveKnowledgeSpace(null, '独立空间'),
        ))!;
        await tester.runAsync(() => state.selectSpace(other));
        await settleNative(tester, state);
        expect(find.byType(MemorySearchSheet), findsNothing);
        expect(state.graphVisible, isFalse);
        expect(state.searchSettings!.extractionRules, isEmpty);
        await tester.runAsync(() => state.selectSpace('default'));
        await settleNative(tester, state);
        expect(state.graphVisible, isTrue);
        expect(state.searchSettings!.extractionRules, '只保存已确认事实');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await client.close();
          final reopened = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
          final settings = await reopened.memorySearchSettings('default');
          expect(settings.graphVisible, isTrue);
          expect(settings.extractionRules, '只保存已确认事实');
          await reopened.close();
        });
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
    'failed settings retain rules and narrow large-text controls remain reachable',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      for (final size in [const Size(320, 720), const Size(844, 390)]) {
        final state = SearchController();
        final capture = GlobalKey();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 100),
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: capture,
              child: SettingsTheme(
                child: Scaffold(
                  body: MemorySearchSheet(
                    controller: state,
                    space: 'default',
                    initial: defaults,
                    dismiss: () async {},
                    onSimulate: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final rules = find.byType(TextField);
        await tester.ensureVisible(rules);
        await tester.enterText(rules, '失败保留规则');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(state.draft?.extractionRules, '失败保留规则');
        expect(tester.widget<TextField>(rules).controller!.text, '失败保留规则');
        await tester.scrollUntilVisible(
          find.text('无法保存记忆库，请重试。'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(MemorySearchSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            capture,
            output,
            '${size.width.toInt()}-settings-failure',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        state.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets('dismissed simulation ignores delayed failure', (tester) async {
    final state = SearchController()..pending = Completer<MemorySearchReport>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => MemorySearchSimulation(
                  controller: state,
                  space: 'default',
                  scope: scope,
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行模拟'));
    await tester.pump();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    state.pending!.completeError(StateError('late'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MemorySearchSimulation), findsNothing);
    state.dispose();
  });
}
