import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/permission_presentation.dart';
import 'package:kiyori/features/settings/presentation/permissions_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('permission disclosures and unknown facts $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const PermissionsPage(),
          ),
        );
        await reveal(tester, find.text('权限，由你决定'));
        expect(find.text('— 项已授权'), findsOneWidget);
        await reveal(tester, find.text('日常使用'));
        await tester.tap(find.text('日常使用'));
        await tester.pumpAndSettle();
        expect(find.text('麦克风'), findsNothing);
        await reveal(tester, find.text('高级自动化'));
        await tester.tap(find.text('高级自动化'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Root'));
        expect(find.text('未检查'), findsWidgets);
        await tester.tap(find.text('请求授权'));
        await tester.pumpAndSettle();
        expect(find.text('已授权'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('injected permission facts project status and per-entry action', (
    tester,
  ) async {
    final calls = <String>[];
    final statuses = {
      for (final entry in permissionEntries)
        entry.id: PermissionStatus.notGranted,
    };
    statuses['notifications'] = PermissionStatus.granted;
    statuses['legacy_storage'] = PermissionStatus.notApplicable;
    statuses['screen_capture'] = PermissionStatus.onDemand;
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: PermissionsPage(statuses: statuses, onAction: calls.add),
      ),
    );
    expect(find.text('1 项已授权'), findsOneWidget);
    await reveal(tester, find.text('通知'));
    await tester.tap(find.text('通知'));
    expect(calls, ['notifications']);
    expect(find.text('管理'), findsOneWidget);
    expect(find.text('本机无需'), findsOneWidget);
  });
}
