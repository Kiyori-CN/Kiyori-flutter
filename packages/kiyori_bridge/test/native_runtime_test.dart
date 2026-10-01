import 'dart:async';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

void main() {
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
