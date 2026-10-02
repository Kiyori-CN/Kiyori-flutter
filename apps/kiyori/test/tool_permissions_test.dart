import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/permissions/tool_permissions_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealPermission(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final scroll = find.byKey(const PageStorageKey('tool-permissions'));
    final rect = tester.getRect(scroll);
    final up =
        target.evaluate().isNotEmpty &&
        tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      Offset(0, up ? 100 : -100),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

const permissionSnapshot = ToolPermissionsPresentation(
  tools: [
    PermissionToolPresentation('read_file', '读取文件内容'),
    PermissionToolPresentation('write_file', '写入文件内容'),
    PermissionToolPresentation('package_proxy', '隐藏代理'),
    PermissionToolPresentation('proxy', '隐藏代理'),
    PermissionToolPresentation('search', '隐藏搜索'),
  ],
);

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'permission draft exception moves between groups $size/$scale',
        (tester) async {
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
              home: const ToolPermissionsPage(snapshot: permissionSnapshot),
            ),
          );
          await tester.pumpAndSettle();
          final allow = find.byKey(const ValueKey('add-allow'));
          await revealPermission(tester, allow);
          await tester.tap(allow);
          await tester.pumpAndSettle();
          expect(find.text('package_proxy'), findsNothing);
          await tester.enterText(find.byType(TextField), '  读取  ');
          await tester.pumpAndSettle();
          expect(find.text('write_file'), findsNothing);
          final read = find.byKey(const ValueKey('select-tool-read_file'));
          await tester.ensureVisible(read);
          await tester.pumpAndSettle();
          await tester.tap(read);
          await tester.pumpAndSettle();
          expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
          await tester.tap(find.text('完成'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('allow-read_file')), findsOneWidget);
          final forbid = find.byKey(const ValueKey('add-forbid'));
          await revealPermission(tester, forbid);
          await tester.tap(forbid);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'read_file');
          await tester.pumpAndSettle();
          await tester.ensureVisible(read);
          await tester.pumpAndSettle();
          await tester.tap(read);
          await tester.pumpAndSettle();
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('完成'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('allow-read_file')), findsNothing);
          expect(
            find.byKey(const ValueKey('forbid-read_file')),
            findsOneWidget,
          );
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          final remove = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '移除 read_file',
          );
          await revealPermission(tester, remove);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('forbid-read_file')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
