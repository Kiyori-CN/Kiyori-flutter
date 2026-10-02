import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/onboarding/presentation/onboarding_page.dart';
import 'package:kiyori/features/settings/presentation/permission_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'first-run decline confirmation returns to agreement without consent',
    (tester) async {
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: OnboardingPage(onExit: () => exits++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过介绍'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不同意并退出'));
      await tester.pumpAndSettle();
      expect(find.text('不同意就无法使用 Kiyori'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('5/6'), findsOneWidget);
      expect(exits, 0);
      await tester.tap(find.text('不同意并退出'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('退出应用'));
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'onboarding six steps, legal return and selection $size/$scale',
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showGeneralDialog<void>(
                      context: context,
                      pageBuilder: (_, _, _) =>
                          const OnboardingPage(reviewing: true),
                    ),
                    child: const Text('打开引导'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开引导'));
          await tester.pumpAndSettle();
          expect(find.text('1/6'), findsOneWidget);
          for (final cta in ['看看能做什么', '了解 AI 协作', '了解工具与个性化', '查看协议与隐私']) {
            await tester.tap(find.text(cta));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(find.text('5/6'), findsOneWidget);
          await tester.drag(find.byType(PageView), const Offset(-600, 0));
          await tester.pumpAndSettle();
          expect(find.text('5/6'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '同意并继续'),
                )
                .onPressed,
            isNull,
          );
          await revealOnboarding(tester, find.text('Kiyori 用户协议'));
          await tester.tap(find.text('Kiyori 用户协议'));
          await tester.pumpAndSettle();
          expect(find.text('展开目录可定位章节；正文支持滚动与长按复制。'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('5/6'), findsOneWidget);
          expect(find.text('已读 ›'), findsOneWidget);
          final consent = find.byType(Checkbox);
          await revealOnboarding(tester, consent);
          await tester.tap(consent);
          await tester.pumpAndSettle();
          await tester.tap(find.text('同意并继续'));
          await tester.pumpAndSettle();
          expect(find.text('6/6'), findsOneWidget);
          final recommend = find.text('选择通知与媒体');
          await revealOnboarding(tester, recommend);
          await tester.tap(recommend);
          await tester.pumpAndSettle();
          expect(find.text('处理所选 2 项权限'), findsOneWidget);
          await tester.tap(find.text('处理所选 2 项权限'));
          await tester.pumpAndSettle();
          expect(find.text('6/6'), findsOneWidget);
          await revealOnboarding(tester, find.text('全部暂不开启'));
          await tester.tap(find.text('全部暂不开启'));
          await tester.pumpAndSettle();
          expect(find.text('完成介绍，返回设置'), findsOneWidget);
          await tester.tap(find.text('完成介绍，返回设置'));
          await tester.pumpAndSettle();
          expect(find.text('打开引导'), findsOneWidget);
          await tester.tap(find.text('打开引导'));
          await tester.pumpAndSettle();
          expect(find.text('1/6'), findsOneWidget);
          await tester.tap(find.text('跳过介绍'));
          await tester.pumpAndSettle();
          expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('drag on fixed button cannot advance or skip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const OnboardingPage(reviewing: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('看看能做什么'), const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(find.text('1/6'), findsOneWidget);
    final down = await tester.startGesture(tester.getCenter(find.text('跳过介绍')));
    await down.moveBy(const Offset(0, 80));
    await down.moveBy(const Offset(0, -80));
    await down.up();
    await tester.pumpAndSettle();
    expect(find.text('1/6'), findsOneWidget);
    await tester.drag(find.text('跳过介绍'), const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(find.text('1/6'), findsOneWidget);
    await tester.tap(find.text('跳过介绍'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('4/6'), findsOneWidget);
  });

  testWidgets('accepted and granted snapshots do not become editable facts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const OnboardingPage(
          reviewing: true,
          agreementAccepted: true,
          statuses: {
            'notifications': PermissionStatus.granted,
            'media': PermissionStatus.partial,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过介绍'));
    await tester.pumpAndSettle();
    expect(find.text('已读 ›'), findsNWidgets(2));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    await tester.tap(find.text('已同意，继续查看权限'));
    await tester.pumpAndSettle();
    await revealOnboarding(tester, find.text('选择通知与媒体'));
    await tester.tap(find.text('选择通知与媒体'));
    await tester.pumpAndSettle();
    expect(find.text('处理所选 1 项权限'), findsOneWidget);
    // 权限目录与摘要共用同一选择集合。
    final group = find.text('通知、影音与输入 · 只开启你会用到的功能');
    await revealOnboarding(tester, group);
    await tester.tap(group);
    await tester.pumpAndSettle();
    final selected = find.byWidgetPredicate(
      (w) => w is Checkbox && w.value == true,
    );
    await revealOnboarding(tester, selected);
    await tester.tap(selected);
    await tester.pumpAndSettle();
    expect(find.text('完成介绍，返回设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
