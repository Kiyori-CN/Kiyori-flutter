import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/knowledge/presentation/diary_detail.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_controller.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

const draft = MemoryDraft(
  kind: 'diary',
  title: '学习与实践',
  content: '完整历史',
  category: 'other',
  source: 'user_input',
  folder: '',
  credibility: .8,
  importance: .5,
  tags: ['学习'],
);
const record = MemoryRecord(
  id: 'diary',
  spaceId: 'default',
  draft: draft,
  archived: false,
  createdAt: 1790980000000,
  updatedAt: 1790980000000,
  diary: DiarySummary(
    closed: false,
    entryCount: 1,
    firstDay: '2026-10-03',
    lastPhase: 'plan',
  ),
);
const document = DiaryDocument(
  preface: '',
  entries: [
    DiaryEntry(date: '2026-10-03', time: '09:40', phase: 'plan', body: '开始计划'),
  ],
);

class DiaryController extends KnowledgeController {
  DiaryController() : super(() async => FakeClient());
  String? appendedBody, appendedPhase;
  bool succeeds = true;
  @override
  Future<bool> appendDiary(
    MemoryRecord record,
    String body,
    String phase,
  ) async {
    appendedBody = body;
    appendedPhase = phase;
    return succeeds;
  }
}

Future<void> host(
  WidgetTester tester,
  DiaryController state,
  Size size,
  double scale, {
  double keyboard = 0,
  GlobalKey? capture,
  Brightness brightness = Brightness.light,
  DiaryDocument timeline = document,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => RepaintBoundary(
        key: capture,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SettingsTheme(
                child: DiaryDetail(
                  controller: state,
                  record: record,
                  document: timeline,
                  onMenu: (_, _) {},
                ),
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
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'dirty diary Back keeps draft until discard and host removal clears confirmation',
    (tester) async {
      final state = DiaryController();
      await host(tester, state, const Size(400, 800), 1);
      await tester.enterText(find.byType(TextField), '未提交内容');
      await tester.pump();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '未提交内容',
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'native diary creation opens timeline, appends and edits full content',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      final capture = GlobalKey();
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('kiyori-diary-ui-'),
      ))!;
      final client = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final state = KnowledgeController(() async => client);
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => RepaintBoundary(key: capture, child: child!),
            home: Scaffold(
              body: KnowledgePage(controller: state, onMenu: () {}),
            ),
          ),
        );
        await tester.runAsync(() => state.load());
        await tester.pumpAndSettle();
        Future<void> settleNative() async {
          for (
            var attempt = 0;
            attempt < 200 && (state.loading || state.saving);
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(state.error, isNull);
          expect(
            state.loading || state.saving,
            isFalse,
            reason: 'Native operation did not finish',
          );
        }

        await tester.tap(find.text('日记'));
        await settleNative();
        await tester.tap(find.text('新建日记'));
        await tester.pumpAndSettle();
        final title = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '标题',
        );
        final opening = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '开篇',
        );
        await tester.enterText(title, '真实日记');
        await tester.enterText(opening, '第一条计划');
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'native-opening');
        }
        await tester.tap(find.text('保存'));
        await settleNative();
        expect(state.snapshot!.records.single.diary!.entryCount, 1);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'native-list');
        }
        await tester.tap(find.text('真实日记'));
        for (
          var attempt = 0;
          attempt < 200 && find.byType(DiaryDetail).evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byType(DiaryDetail), findsOneWidget);
        await tester.enterText(find.byType(TextField).hitTestable(), '追加进展');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('追加记录'));
        await tester.tap(find.text('追加记录'));
        await settleNative();
        expect(state.detail!.diary!.entryCount, 2);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'native-timeline');
        }
        final continuation = find.descendant(
          of: find.byType(DiaryDetail),
          matching: find.byType(TextField),
        );
        await tester.enterText(continuation, '尚未保存的续写');
        await tester.tap(find.byTooltip('更多操作'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑全文'));
        await tester.pumpAndSettle();
        expect(find.text('放弃未保存的修改？'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(continuation).controller!.text,
          '尚未保存的续写',
        );
        await tester.tap(find.byTooltip('更多操作'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑全文'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('放弃修改'));
        await tester.pumpAndSettle();
        final content = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '内容',
        );
        expect(
          tester.widget<TextField>(content).controller!.text,
          contains('追加进展'),
        );
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'native-full-editor');
        }
        await tester.tap(find.byTooltip('关闭').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate((w) => w is ShellAction && w.label == '筛选'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '已完结'));
        await settleNative();
        expect(state.query.diaryClosed, isTrue);
        expect(state.snapshot!.records, isEmpty);
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'native-status-filter');
        }
        await tester.tap(find.widgetWithText(ChoiceChip, '进行中'));
        await settleNative();
        expect(state.query.diaryClosed, isFalse);
        expect(state.snapshot!.records.single.diary!.entryCount, 2);
        await tester.tap(find.text('重置筛选'));
        await settleNative();
        expect(state.query.diaryClosed, isNull);
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
    'failed closing summary survives retry and participates in dirty exit',
    (tester) async {
      final state = DiaryController()..succeeds = false;
      await host(tester, state, const Size(400, 800), 1);
      await tester.tap(find.text('结束日记'));
      await tester.pumpAndSettle();
      final summary = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '收尾总结（可留空）',
      );
      await tester.enterText(summary, '保留失败的总结');
      await tester.tap(find.widgetWithText(TextButton, '结束日记').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('结束日记'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(summary).controller!.text, '保留失败的总结');
      state.succeeds = true;
      await tester.tap(find.widgetWithText(TextButton, '结束日记').last);
      await tester.pumpAndSettle();
      expect(state.appendedBody, '保留失败的总结');
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryDetail), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'append failure keeps draft, success clears, close appends empty summary',
    (tester) async {
      final state = DiaryController()..succeeds = false;
      await host(tester, state, const Size(400, 800), 1);
      await tester.enterText(find.byType(TextField), '这次进展');
      await tester.tap(find.text('追加记录'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '这次进展',
      );
      state.succeeds = true;
      await tester.tap(find.text('追加记录'));
      await tester.pumpAndSettle();
      expect(state.appendedPhase, 'progress');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.tap(find.text('结束日记'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '结束日记').last);
      await tester.pumpAndSettle();
      expect(state.appendedPhase, 'closed');
      expect(state.appendedBody, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('diary responsive timeline and append controls', (tester) async {
    if (output.isNotEmpty) await loadCaptureFonts(tester);
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1280, 800),
    ]) {
      for (final scale in [1.0, 2.0]) {
        final state = DiaryController();
        final key = GlobalKey();
        await host(tester, state, size, scale, keyboard: 160, capture: key);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '视口中的续写');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('追加记录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('追加记录'));
        await tester.pumpAndSettle();
        expect(state.appendedBody, '视口中的续写');
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            key,
            output,
            '${size.width.toInt()}-$scale-diary',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        state.dispose();
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('diary default timeline light and dark captures', (tester) async {
    if (output.isNotEmpty) await loadCaptureFonts(tester);
    for (final brightness in Brightness.values) {
      for (final size in [
        const Size(320, 640),
        const Size(844, 390),
        const Size(1280, 800),
      ]) {
        final state = DiaryController();
        final key = GlobalKey();
        await host(
          tester,
          state,
          size,
          1,
          brightness: brightness,
          capture: key,
          timeline: const DiaryDocument(
            preface: '从问题和证据开始记录。',
            entries: [
              DiaryEntry(
                date: '2026-10-03',
                time: '09:40',
                phase: 'plan',
                body: '整理学习计划，保留每一步的原文。',
              ),
              DiaryEntry(
                date: '2026-10-03',
                time: '10:20',
                phase: 'evidence',
                body: '完成第一轮阅读与练习，记录待复核的问题。',
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            key,
            output,
            '${size.width.toInt()}-${brightness.name}-default-diary',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        state.dispose();
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
