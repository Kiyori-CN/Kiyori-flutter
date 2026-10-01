import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile cold and warm three-page swipes', (tester) async {
    // Debug 的断言、JIT 与测试宿主不能充当真实帧时间基线。
    expect(
      kProfileMode,
      isTrue,
      reason: 'Run with --profile on a real device.',
    );
    await tester.pumpWidget(KiyoriApp(connect: NativeRuntimeClient.open));
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    final size = tester.getSize(find.byType(PageView));
    final center =
        tester.getTopLeft(find.byType(PageView)) +
        Offset(size.width / 2, size.height * .5);

    Future<void> swipe(double direction, int expectedPage) async {
      await tester.timedDragFrom(
        center,
        Offset(size.width * .7 * direction, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(pager.page, closeTo(expectedPage.toDouble(), .001));
      expect(tester.takeException(), isNull);
    }

    Future<void> roundTrip() async {
      await swipe(1, 0);
      await swipe(-1, 1);
      await swipe(-1, 2);
      await swipe(1, 1);
    }

    await binding.watchPerformance(roundTrip, reportKey: 'first_swipes');
    await binding.watchPerformance(() async {
      for (var i = 0; i < 10; i++) {
        await roundTrip();
      }
    }, reportKey: 'warm_swipes');
    binding.reportData!['environment'] = {
      'mode': 'profile',
      'platform': defaultTargetPlatform.name,
      'refresh_rate_hz': tester.view.display.refreshRate,
      'device_pixel_ratio': tester.view.devicePixelRatio,
      'logical_width': size.width,
      'logical_height': size.height,
      'warm_swipe_count': 40,
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
