import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/speech/presentation/wakeup_settings_page.dart';
import 'package:kiyori/features/speech/presentation/wakeup_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'stt_settings_test.dart' show revealStt;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'wake configuration inputs and nested empty actions $size/$scale',
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
              home: const WakeupSettingsPage(),
            ),
          );
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('始终监听'));
          await tester.tap(find.text('始终监听'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SettingsRow>(
                  find.ancestor(
                    of: find.text('始终监听'),
                    matching: find.byType(SettingsRow),
                  ),
                )
                .checked,
            isFalse,
          );
          final phrase = find.byKey(const ValueKey('wake-唤醒词'));
          await revealStt(tester, phrase);
          await tester.enterText(phrase, '测试唤醒草稿');
          FocusManager.instance.primaryFocus?.unfocus();
          await revealStt(tester, find.text('STT（识别文本）'), reverse: true);
          await tester.tap(find.text('STT（识别文本）'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('个人化模板（录三遍）').last);
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('录入个人化唤醒模板'));
          await tester.tap(find.text('录入个人化唤醒模板'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('开始录音').first);
          await tester.tap(find.text('开始录音').first);
          await tester.pumpAndSettle();
          expect(find.text('录音中…'), findsNothing);
          expect(
            tester
                .widget<TextButton>(
                  find.ancestor(
                    of: find.text('保存'),
                    matching: find.byType(TextButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('个人化模板（录三遍）'), reverse: true);
          await tester.tap(find.text('个人化模板（录三遍）'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('STT（识别文本）').last);
          await tester.pumpAndSettle();
          await revealStt(tester, phrase);
          expect(tester.widget<TextField>(phrase).controller!.text, '测试唤醒草稿');
          final timeout = find.byKey(const ValueKey('wake-语音无响应超时（秒）'));
          await revealStt(tester, timeout);
          await tester.enterText(timeout, '9999999999999999999999999999');
          expect(tester.widget<TextField>(timeout).controller!.text, '600');
          await tester.enterText(timeout, '0');
          expect(tester.widget<TextField>(timeout).controller!.text, '1');
          await tester.enterText(timeout, '');
          expect(tester.widget<TextField>(timeout).controller!.text, isEmpty);
          FocusManager.instance.primaryFocus?.unfocus();
          await revealStt(tester, find.text('唤醒后说一句'));
          await tester.tap(find.text('唤醒后说一句'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('wake-朗读内容')))
                .enabled,
            isFalse,
          );
          await revealStt(tester, find.text('唤醒时新建对话'));
          await tester.tap(find.text('唤醒时新建对话'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('wake-自动新建对话分组')))
                .enabled,
            isTrue,
          );
          await revealStt(tester, find.text('时间'));
          await tester.tap(find.text('时间'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            '几点|时间',
          );
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除'));
          await tester.pumpAndSettle();
          expect(find.text('删除自动附加项'), findsOneWidget);
          await tester.tap(find.text('删除').last);
          await tester.pumpAndSettle();
          expect(find.text('删除自动附加项'), findsOneWidget);
          await tester.tap(find.text('取消').last);
          await tester.pumpAndSettle();
          expect(find.text('删除自动附加项'), findsNothing);
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(find.text('时间|几点'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'wake template deletion and missing attachment chooser use injected state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const WakeupSettingsPage(
            snapshot: WakeupPresentation(
              mode: WakeRecognitionMode.personal,
              templateCount: 3,
              attachments: [],
              enrollment: WakeEnrollmentPresentation(completedSteps: {1, 2, 3}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('清除个人化模板'));
      await tester.tap(find.text('清除个人化模板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除个人化模板').last);
      await tester.pumpAndSettle();
      expect(find.text('清除个人唤醒模板'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('录入个人化唤醒模板'));
      await tester.tap(find.text('录入个人化唤醒模板'));
      await tester.pumpAndSettle();
      expect(find.text('已录入'), findsNWidgets(3));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('个人化唤醒配置'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('添加'));
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏幕'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('位置').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('添加附件项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
