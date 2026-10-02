import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      final center = tester.getCenter(finder);
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (center.dy > 90 &&
          center.dy < height - 80 &&
          finder.hitTestable().evaluate().isNotEmpty) {
        return;
      }
    }
    // 只滚动当前可命中的列表，避免路由过渡/遮罩时误拖底层页面。
    final lists = find.byType(ListView).hitTestable();
    if (lists.evaluate().isNotEmpty) {
      await tester.drag(lists.last, const Offset(0, -140));
    }
    await tester.pumpAndSettle();
  }
  fail('Could not reveal $finder');
}

Future<void> revealHistory(
  WidgetTester tester,
  Finder target, {
  bool up = false,
}) async {
  var towardTop = up;
  for (var i = 0; i < 100; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final list = find.byKey(const PageStorageKey('chat-history-management'));
    final rect = tester.getRect(list);
    if (target.evaluate().isNotEmpty) {
      towardTop = tester.getRect(target).center.dy < rect.center.dy;
    } else if (towardTop) {
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      if (tester.state<ScrollableState>(scrollable).position.pixels <= 0) {
        towardTop = false;
      }
    }
    await tester.dragFrom(
      Offset(rect.left + 5, rect.center.dy),
      Offset(0, towardTop ? 90 : -90),
    );
    await tester.pumpAndSettle();
  }
  fail(
    'Unable to reach $target; scrolls: ${tester.widgetList<Scrollable>(find.byType(Scrollable)).map((w) => '${w.axisDirection}: ${w.controller?.positions.map((p) => '${p.pixels}/${p.maxScrollExtent}')}')}',
  );
}

Future<void> revealContext(
  WidgetTester tester,
  Finder target, {
  bool up = false,
}) async {
  var towardTop = up;
  for (var i = 0; i < 120; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final body = find.byKey(const PageStorageKey('context-summary'));
    final rect = tester.getRect(body);
    if (target.evaluate().isNotEmpty) {
      towardTop = tester.getRect(target).center.dy < rect.center.dy;
    }
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      Offset(0, towardTop ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

Future<void> revealFunction(
  WidgetTester tester,
  Finder target, {
  bool up = false,
}) async {
  var towardTop = up;
  for (var i = 0; i < 160; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final body = find.byKey(const PageStorageKey('function-models'));
    final rect = tester.getRect(body);
    if (target.evaluate().isNotEmpty) {
      towardTop = tester.getRect(target).center.dy < rect.center.dy;
    }
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      Offset(0, towardTop ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

Future<void> revealModel(WidgetTester tester, Finder target) async {
  final scroll = find.byType(SingleChildScrollView).first;
  for (var i = 0; i < 160; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final rect = tester.getRect(scroll);
    final up =
        target.evaluate().isNotEmpty &&
        tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      Offset(0, up ? 140 : -140),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

Future<void> revealStt(
  WidgetTester tester,
  Finder target, {
  bool reverse = false,
}) async {
  for (var i = 0; i < 100; i++) {
    final hits = target.hitTestable();
    if (hits.evaluate().isNotEmpty && tester.getCenter(hits).dy > 80) return;
    final rect = tester.getRect(find.byType(ListView).first);
    final up = target.evaluate().isEmpty
        ? reverse
        : tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      Offset(0, up ? 110 : -110),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

Future<void> revealUsage(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final rect = tester.getRect(find.byKey(const PageStorageKey('usage')));
    final up =
        target.evaluate().isNotEmpty &&
        tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      Offset(0, up ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

Future<void> revealBackup(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) {
      final y = tester.getCenter(finder).dy;
      final height = tester.view.physicalSize.height;
      if (y > 90 && y < height - 60) return;
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('Could not reveal $finder');
}

Future<void> revealOnboarding(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final list = find.byType(ListView).last;
    for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
      final rect = tester.getRect(list);
      await tester.dragFrom(
        Offset(rect.left + 5, rect.center.dy),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
