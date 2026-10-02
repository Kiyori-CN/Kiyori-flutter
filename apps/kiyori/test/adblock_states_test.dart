import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/browser/presentation/adblock_presentation.dart';
import 'package:kiyori/features/browser/presentation/adblock_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart' show revealAvatar;

const adblockFixture = AdblockPresentation(
  phase: AdblockRuntimePhase.ready,
  networkRules: [
    AdblockNetworkRule('a', '||ads.example^'),
    AdblockNetworkRule('b', '@@safe.example', enabled: false),
  ],
  elementRules: [
    AdblockElementRule('x', 'z.example', '.banner'),
    AdblockElementRule('y', 'a.example', '.promo', enabled: false),
  ],
  allowlist: ['safe.example', 'local.example'],
  networkCount: 10,
  networkExceptions: 2,
  blockedRequests: 12,
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    AdblockSection section,
    AdblockPresentation snapshot,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: AdblockSettingsPage(
          section: section,
          snapshot: snapshot,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder action(String id, String label) => find.descendant(
    of: find.byKey(ValueKey(id)),
    matching: find.byTooltip(label),
  );

  testWidgets(
    'network editor retains identity on reorder; removal releases owned modal',
    (tester) async {
      await mount(tester, AdblockSection.network, adblockFixture);
      await revealAvatar(tester, action('network:a', '编辑'));
      await tester.tap(action('network:a', '编辑'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        '||ads.example^',
      );
      await tester.enterText(field, 'edited-draft');
      final controller = tester.widget<TextField>(field).controller!;
      await mount(
        tester,
        AdblockSection.network,
        AdblockPresentation(
          networkRules: adblockFixture.networkRules.reversed.toList(),
        ),
      );
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.text, 'edited-draft');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, AdblockSection.network, const AdblockPresentation());
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, AdblockSection.network, adblockFixture);
      await revealAvatar(tester, action('network:a', '编辑'));
      await tester.tap(action('network:a', '编辑'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        '||ads.example^',
      );
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'domain search expands matches and does not leak discarded edit draft',
    (tester) async {
      await mount(tester, AdblockSection.elements, adblockFixture);
      expect(find.text('.banner'), findsNothing);
      await revealAvatar(tester, find.text('a.example'));
      await tester.tap(find.text('a.example'));
      await tester.pumpAndSettle();
      await revealAvatar(tester, action('element:y', '编辑'));
      await tester.tap(action('element:y', '编辑'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'a.example',
      );
      expect(tester.widget<TextField>(fields.last).controller!.text, '.promo');
      await tester.enterText(fields.last, '.draft');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await revealAvatar(tester, find.byType(KiyoriSearchField));
      await tester.enterText(find.byType(TextField), 'BANNER');
      await tester.pumpAndSettle();
      expect(find.text('a.example'), findsNothing);
      expect(find.text('.banner'), findsOneWidget);
      await revealAvatar(tester, action('element:x', '删除'));
      await tester.tap(action('element:x', '删除'));
      await tester.pumpAndSettle();
      expect(find.text('z.example\n.banner'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('.banner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'allowlist removal preserves facts; route change closes old dialog',
    (tester) async {
      await mount(tester, AdblockSection.allowlist, adblockFixture);
      await revealAvatar(tester, action('allowlist:safe.example', '删除'));
      await tester.tap(action('allowlist:safe.example', '删除'));
      await tester.pumpAndSettle();
      expect(find.text('移出站点白名单'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('safe.example'), findsOneWidget);
      await tester.tap(action('allowlist:safe.example', '删除'));
      await tester.pumpAndSettle();
      await mount(tester, AdblockSection.network, adblockFixture);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('runtime phases and failures reflect injected evidence', (
    tester,
  ) async {
    for (final phase in AdblockRuntimePhase.values) {
      final snapshot = AdblockPresentation(
        phase: phase,
        total: 5,
        completed: 2,
        error: '读取快照失败',
      );
      await mount(tester, AdblockSection.overview, snapshot);
      await revealAvatar(tester, find.text('本地规则引擎'));
      expect(find.text(snapshot.status), findsOneWidget);
      expect(find.text(snapshot.description), findsAtLeastNWidgets(1));
      final row = tester.widget<SettingsRow>(
        find.widgetWithText(SettingsRow, '启用广告拦截'),
      );
      expect(row.enabled, snapshot.ready);
    }
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'nonempty rules and editors fit keyboard and double text $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 160),
              ),
              child: child!,
            ),
            home: AdblockSettingsPage(
              section: AdblockSection.network,
              snapshot: adblockFixture,
              onOpen: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editButton = action('network:b', '编辑');
        for (var attempt = 0; attempt < 100; attempt++) {
          final list = find.byType(ListView).first;
          final bounds = tester.getRect(list);
          final center = tester.getCenter(editButton);
          if (editButton.hitTestable().evaluate().isNotEmpty &&
              center.dy > bounds.top + 80 &&
              center.dy < bounds.bottom - 24) {
            break;
          }
          await tester.dragFrom(
            Offset(bounds.left + 3, bounds.bottom - 25),
            Offset(0, center.dy < bounds.top + 80 ? 40 : -40),
          );
          await tester.pumpAndSettle();
        }
        expect(editButton.hitTestable(), findsOneWidget);
        await tester.tap(action('network:b', '编辑'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('保存'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
