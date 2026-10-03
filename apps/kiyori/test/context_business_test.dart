import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/context/context_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/context/persistent_context_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

void main() {
  test('real context FFI drains edits and retains failed drafts without clobbering new revisions', () async {
    final directory = Directory.systemTemp.createTempSync('kiyori-context-');
    final runtime = await NativeRuntimeClient.open(
      dataDirectory: directory.path,
    );
    Completer<void>? gate;
    final entered = Completer<void>();
    final session = ContextEditSession(() async {
      if (!entered.isCompleted) entered.complete();
      if (gate != null) await gate.future;
      return runtime;
    }, await runtime.contextSettings());
    try {
      final original = session.base;
      session.history = const HistoryRetention(
        revision: 1,
        imageTurns: 4294967296,
        mediaTurns: 0,
      );
      expect(await session.flush(), isFalse);
      expect((await runtime.contextSettings()).history.imageTurns, 2);
      gate = Completer<void>();
      session.history = HistoryRetention(
        revision: 1,
        imageTurns: 4,
        mediaTurns: 3,
      );
      session.changed();
      final saving = session.flush();
      await entered.future;
      session.history = HistoryRetention(
        revision: 1,
        imageTurns: 7,
        mediaTurns: 0,
      );
      session.changed();
      gate.complete();
      expect(await saving, isTrue);
      final saved = await runtime.contextSettings();
      expect(saved.history.imageTurns, 7);
      expect(saved.history.mediaTurns, 0);
      expect(saved.config.revision, original.config.revision);
      await runtime.saveContextSettings(
        saved.config.id,
        saved.config.revision,
        session.options,
        HistoryRetention(
          revision: saved.history.revision,
          imageTurns: 8,
          mediaTurns: 2,
        ),
      );
      session.history = HistoryRetention(
        revision: saved.history.revision,
        imageTurns: 9,
        mediaTurns: 9,
      );
      expect(await session.flush(), isFalse);
      expect(session.history.imageTurns, 9);
      expect(session.error, isNotNull);
      expect((await runtime.contextSettings()).history.imageTurns, 8);
    } finally {
      session.dispose();
      await runtime.close();
      directory.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'real context page autosaves, resets only media and keeps invalid draft on Back',
    (tester) async {
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Directory.systemTemp.createTempSync(
        'kiyori-context-ui-',
      );
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final capture = GlobalKey();
      Future<void> settle() async {
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 25));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> edit(String field, String value) async {
        final finder = find.byKey(ValueKey(field));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.enterText(finder, value);
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.dark(),
            builder: (_, child) => RepaintBoundary(key: capture, child: child),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PersistentContextPage(connect: () async => runtime),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle();
        await edit('上下文长度', '96');
        await edit('summary-rules', '保留全部关键结论');
        await settle();
        await edit('历史图片保留回合数', '6');
        await edit('历史音视频保留回合数', '4');
        await settle();
        var saved = (await tester.runAsync(runtime.contextSettings))!;
        expect(saved.config.draft.options.contextLength, 96);
        expect(saved.config.draft.options.summaryRules, '保留全部关键结论');
        expect(saved.history.imageTurns, 6);
        await tester.ensureVisible(find.text('恢复历史媒体默认值'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复历史媒体默认值'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复默认'));
        await settle();
        final reset = (await tester.runAsync(runtime.contextSettings))!;
        expect(reset.history.imageTurns, 2);
        expect(reset.history.mediaTurns, 1);
        expect(reset.config.revision, saved.config.revision);
        await edit('上下文长度', '0');
        await settle();
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'context-invalid-draft');
        }
        await tester.binding.handlePopRoute();
        await settle();
        expect(find.text('未能保存上下文设置'), findsOneWidget);
        await tester.tap(find.text('继续编辑'));
        await tester.pumpAndSettle();
        await edit('上下文长度', '128');
        // 不等700ms，Back也必须刷写最后的输入。
        await tester.binding.handlePopRoute();
        await settle();
        expect(find.text('open'), findsOneWidget);
        saved = (await tester.runAsync(runtime.contextSettings))!;
        expect(saved.config.draft.options.contextLength, 128);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(runtime.close);
        directory.deleteSync(recursive: true);
      }
    },
  );
}
