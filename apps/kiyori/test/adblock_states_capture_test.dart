import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/browser/presentation/adblock_presentation.dart';
import 'package:kiyori/features/browser/presentation/adblock_settings_page.dart';
import 'package:kiyori/features/browser/presentation/adblock_subscription_group.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart' show revealAvatar;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture populated adblock and error states',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      const snapshot = AdblockPresentation(
        phase: AdblockRuntimePhase.ready,
        networkRules: [
          AdblockNetworkRule('a', '||ads.example^'),
          AdblockNetworkRule('b', '@@safe.example', enabled: false),
        ],
        elementRules: [AdblockElementRule('x', 'example.com', '.banner')],
        subscriptions: [
          AdblockSubscription(
            id: 's',
            name: '测试自定义订阅',
            url: 'https://example.invalid/rules',
            hasLocalRules: true,
            network: 120,
            networkExceptions: 3,
            elements: 40,
            ignored: 5,
            error: '下载失败，保留已有规则',
            updatedLabel: '测试时间',
          ),
        ],
      );
      for (final dark in [false, true]) {
        for (final large in [false, true]) {
          tester.view.physicalSize = large
              ? const Size(320, 640)
              : const Size(390, 844);
          final suffix =
              '${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}';
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                    child: child!,
                  ),
                  home: child,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount(
            AdblockSettingsPage(
              key: ValueKey(suffix),
              section: AdblockSection.network,
              snapshot: snapshot,
              onOpen: (_) {},
            ),
          );
          await captureUi(tester, boundary, output, 'rules-$suffix');
          final edit = find.descendant(
            of: find.byKey(const ValueKey('network:a')),
            matching: find.byTooltip('编辑'),
          );
          await revealAvatar(tester, edit);
          await tester.tap(edit);
          await captureUi(tester, boundary, output, 'rule-edit-$suffix');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await mount(
            Scaffold(
              body: SingleChildScrollView(
                child: AdblockSubscriptionGroup(
                  title: '自定义订阅',
                  description: '可添加、改名、换址、启停、刷新或删除',
                  query: '',
                  group: AdblockSubscriptionGroupKind.custom,
                  snapshot: snapshot,
                ),
              ),
            ),
          );
          await tester.tap(find.text('测试自定义订阅'));
          await captureUi(tester, boundary, output, 'subscription-$suffix');
          await tester.ensureVisible(find.text('编辑'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('编辑'));
          await captureUi(
            tester,
            boundary,
            output,
            'subscription-edit-$suffix',
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
