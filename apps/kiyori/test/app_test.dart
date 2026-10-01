import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/app/runtime_controller.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

class FakeRun implements DiagnosticRun {
  final controller = StreamController<TaskEvent>();
  bool cancelled = false;
  @override
  Stream<TaskEvent> get events => controller.stream;
  @override
  Future<void> cancel() async {
    if (cancelled) return;
    cancelled = true;
    controller.add(
      const TaskEvent(
        revision: 1,
        phase: TaskPhase.cancelled,
        completedSteps: 0,
        totalSteps: 20,
      ),
    );
    unawaited(controller.close());
  }
}

class FakeClient implements RuntimeClient {
  bool closed = false;
  int starts = 0;
  FakeRun? run;
  Completer<DiagnosticRun>? pendingStart;
  @override
  Future<RuntimeInfo> info() async => const RuntimeInfo(
    coreVersion: '0.1.0',
    hostPlatform: 'windows',
    capabilities: [
      Capability(id: 'kiyori.runtime.diagnostics', available: true, reason: ''),
      Capability(
        id: 'kiyori.browser',
        available: false,
        reason: 'not_implemented',
      ),
    ],
  );
  @override
  Future<DiagnosticRun> startDiagnostic({
    int steps = 20,
    int intervalMs = 100,
  }) async {
    starts++;
    if (pendingStart case final pending?) return pending.future;
    return run = FakeRun();
  }

  @override
  Future<void> close() async {
    closed = true;
    await run?.cancel();
  }
}

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('adaptive navigation and cancellation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = FakeClient();
      await tester.pumpWidget(
        KiyoriApp(connect: () async => client, diagnostics: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('应用核心已连接'), findsOneWidget);
      await tester.ensureVisible(find.text('开始检查'));
      await tester.tap(find.text('开始检查'));
      await tester.pump();
      expect(client.starts, 1);
      expect(find.text('取消检查'), findsOneWidget);
      await tester.tap(find.text('取消检查'));
      await tester.pumpAndSettle();
      expect(find.text('检查已取消'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(client.closed, isTrue);
    });
  }

  test(
    'cancel before the start response and duplicate start are handled',
    () async {
      final client = FakeClient()..pendingStart = Completer<DiagnosticRun>();
      final controller = RuntimeController(() async => client);
      await controller.initialize();
      final running = controller.runCheck();
      await controller.runCheck();
      await controller.cancelCheck();
      final run = FakeRun();
      client.pendingStart!.complete(run);
      await running;
      expect(client.starts, 1);
      expect(run.cancelled, isTrue);
      expect(controller.lastEvent?.phase, TaskPhase.cancelled);
      controller.dispose();
    },
  );

  test(
    'dispose during initialization closes the late native session',
    () async {
      final pending = Completer<RuntimeClient>();
      final controller = RuntimeController(() => pending.future);
      final initializing = controller.initialize();
      controller.dispose();
      final client = FakeClient();
      pending.complete(client);
      await initializing;
      expect(client.closed, isTrue);
    },
  );

  testWidgets('large text remains scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final client = FakeClient();
    await tester.pumpWidget(
      KiyoriApp(connect: () async => client, diagnostics: true),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
