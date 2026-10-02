import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/kiyori_app.dart';
import 'package:kiyori/features/video/presentation/player_experience_page.dart';
import 'package:kiyori/features/video/presentation/player_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'app_test.dart' show FakeClient;
import 'settings_detail_test.dart' show reveal;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'player hierarchy, empty actions, drafts and Back $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(KiyoriApp(connect: () async => FakeClient()));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('nav-4')));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('视频播放器'));
          await tester.tap(find.text('视频播放器'));
          await tester.pumpAndSettle();
          final root = tester.state(find.byType(SettingsDetailPage));
          for (final section in PlayerExperienceSection.values) {
            await reveal(tester, find.text(section.title));
            await tester.tap(find.text(section.title));
            await tester.pumpAndSettle();
            expect(find.byType(PlayerExperiencePage), findsOneWidget);
            if (section == PlayerExperienceSection.subtitle) {
              final chip = tester.widget<FilterChip>(
                find.widgetWithText(FilterChip, '100%'),
              );
              expect(chip.selected, isTrue);
              await reveal(tester, find.byType(Slider).first);
              final slider = find.byType(Slider).first;
              await tester.drag(slider, const Offset(-35, 0));
              await tester.pumpAndSettle();
              expect(tester.widget<Slider>(slider).value, lessThan(95));
            }
            if (section == PlayerExperienceSection.danmaku) {
              await reveal(tester, find.byType(TextField));
              await tester.enterText(find.byType(TextField), '屏蔽测试');
              await tester.pumpAndSettle();
              await reveal(tester, find.text('保存屏蔽词'));
              await tester.tap(find.text('保存屏蔽词'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!
                    .text,
                '屏蔽测试',
              );
            }
            expect(tester.takeException(), isNull);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(PlayerSettingsPage), findsOneWidget);
            expect(tester.state(find.byType(SettingsDetailPage)), same(root));
          }
          await reveal(tester, find.text('默认播放倍速'));
          await tester.tap(find.text('默认播放倍速'));
          await tester.pumpAndSettle();
          expect(find.text('当前：1.0x'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(PlayerSettingsPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
