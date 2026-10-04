import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_panel_route.dart';

void main() {
  testWidgets('open panel and barrier follow changing top safe area', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('host')),
      ),
    );
    navigator.currentState!.push(
      ChatPanelRoute(
        label: 'close panel',
        builder: (_) => const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: Key('panel'),
            width: 200,
            height: double.infinity,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final inset in [24.0, 40.0, 0.0]) {
      tester.view.padding = FakeViewPadding(top: inset);
      await tester.pumpAndSettle();
      final barrier = find.byWidgetPredicate(
        (widget) =>
            widget is ModalBarrier && widget.semanticsLabel == 'close panel',
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('panel'))).dy,
        inset + 64.5,
      );
      expect(tester.getTopLeft(barrier).dy, inset + 64.5);
    }
    await tester.tapAt(const Offset(500, 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel')), findsNothing);
    expect(find.text('host'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
