import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  testWidgets('destination action responds while native page transition runs', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: KiyoriTheme.light().copyWith(platform: TargetPlatform.android),
        home: const Scaffold(body: Text('root')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('destination action'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.text('destination action'));
    await tester.pump();
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
  testWidgets('pager first tap before settle opens destination action', (
    tester,
  ) async {
    final pager = PageController();
    addTearDown(pager.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const KiyoriScrollBehavior(),
        home: Scaffold(
          body: PageView(
            controller: pager,
            children: [
              const SizedBox.expand(),
              Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    pager.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(pager.position.isScrollingNotifier.value, isTrue);
    await tester.tap(find.text('action'));
    await tester.pump();
    expect(taps, 1);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(pager.page, closeTo(0, .001));
    expect(taps, 1, reason: 'Dragging must not trigger another tap.');
  });
  for (final mode in ['driven', 'ballistic', 'release']) {
    testWidgets('first tap during $mode scroll', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const KiyoriScrollBehavior(),
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemExtent: 64,
              itemCount: 100,
              itemBuilder: (_, index) => TextButton(
                onPressed: () => taps++,
                child: Text('item $index'),
              ),
            ),
          ),
        ),
      );
      if (mode == 'driven') {
        controller.animateTo(
          1000,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.fling(find.byType(ListView), const Offset(0, -300), 1500);
        if (mode == 'ballistic') {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      expect(controller.position.isScrollingNotifier.value, isTrue);
      await tester.tapAt(const Offset(300, 280));
      await tester.pump();
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
