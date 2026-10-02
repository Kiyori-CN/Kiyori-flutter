import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/server/lan_automation_page.dart';
import 'package:kiyori/features/assistant/presentation/server/lan_automation_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> revealLan(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 150; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final rect = tester.getRect(
      find.byKey(const PageStorageKey('lan-automation')),
    );
    final up =
        target.evaluate().isNotEmpty &&
        tester.getRect(target).center.dy < rect.center.dy;
    await tester.dragFrom(
      Offset(rect.left + 4, rect.center.dy),
      Offset(0, up ? 120 : -120),
    );
    await tester.pumpAndSettle();
  }
  fail('Cannot reveal $target');
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'LAN drafts, token modal and empty service actions $size/$scale',
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
              home: const LanAutomationPage(),
            ),
          );
          await tester.pumpAndSettle();
          await revealLan(tester, find.byType(Switch));
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
          final port = find.byKey(const ValueKey('lan-port'));
          await revealLan(tester, port);
          await tester.enterText(port, 'abc123456');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(port).controller!.text, '12345');
          FocusManager.instance.primaryFocus?.unfocus();
          await revealLan(tester, find.text('保存端口'));
          await tester.tap(find.text('保存端口'));
          await tester.pumpAndSettle();
          final token = find.byKey(const ValueKey('lan-token'));
          await revealLan(tester, token);
          await tester.enterText(token, 'preview-only');
          await tester.pumpAndSettle();
          await revealLan(tester, find.byTooltip('显示 Token'));
          await tester.tap(find.byTooltip('显示 Token'));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(token).obscureText, isFalse);
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await revealLan(tester, find.text('重置 Token'));
          await tester.tap(find.text('重置 Token'));
          await tester.pumpAndSettle();
          final confirm = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('重置 Token'),
          );
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text('重置访问 Token？'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(token).controller!.text,
            'preview-only',
          );
          await revealLan(tester, find.text('服务未运行'));
          expect(find.text('服务未运行'), findsOneWidget);
          await revealLan(tester, find.text('http://127.0.0.1:18094/'));
          expect(find.text('http://127.0.0.1:12345/'), findsNothing);
          await revealLan(tester, find.text('Intent 调用说明'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'LAN running, inconsistent and failed status are injected facts',
    (tester) async {
      for (final snapshot in [
        const LanAutomationPresentation(
          enabled: true,
          running: true,
          activePort: 20000,
          port: 20000,
          addresses: ['192.0.2.1'],
        ),
        const LanAutomationPresentation(running: true),
        const LanAutomationPresentation(lastError: '预览错误'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.dark(),
            home: LanAutomationPage(snapshot: snapshot),
          ),
        );
        await tester.pumpAndSettle();
        await revealLan(tester, find.text(snapshot.status));
        expect(find.text(snapshot.status), findsOneWidget);
        if (snapshot.addresses.isNotEmpty) {
          await revealLan(tester, find.text('http://192.0.2.1:20000'));
          expect(find.text('http://192.0.2.1:20000'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
