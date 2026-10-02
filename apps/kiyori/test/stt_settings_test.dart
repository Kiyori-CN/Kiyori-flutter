import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/speech/presentation/stt_settings_page.dart';
import 'package:kiyori/features/speech/presentation/stt_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart';

void main() {
  testWidgets('STT handles removed selected profile and empty snapshots', (
    tester,
  ) async {
    Future<void> show(List<SttProfilePresentation> profiles) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: SttSettingsPage(profiles: profiles, activeId: 'one'),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const [
      SttProfilePresentation(id: 'one', name: '配置一', engine: SttEngine.openai),
      SttProfilePresentation(id: 'two', name: '配置二'),
    ]);
    final url = find.byKey(const ValueKey('stt-URL'));
    await revealStt(tester, url);
    await tester.enterText(url, 'https://example.invalid/removed');
    await show(const [SttProfilePresentation(id: 'two', name: '配置二')]);
    expect(tester.takeException(), isNull);
    await revealStt(tester, find.text('Sherpa NCNN (本地)'), reverse: true);
    expect(find.text('Sherpa NCNN (本地)'), findsOneWidget);
    await show(const []);
    expect(find.byTooltip('新建语音配置'), findsNothing);
    expect(tester.takeException(), isNull);
    await show(const [
      SttProfilePresentation(id: 'one', name: '配置一', engine: SttEngine.openai),
    ]);
    await revealStt(tester, url);
    expect(
      tester.widget<TextField>(url).controller!.text,
      'https://api.openai.com/v1/audio/transcriptions',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'STT engines share remote draft and profiles retain independent input $size/$scale',
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
              home: const SttSettingsPage(
                profiles: [
                  SttProfilePresentation(id: 'one', name: '配置一'),
                  SttProfilePresentation(id: 'two', name: '配置二'),
                ],
                activeId: 'one',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('Sherpa NCNN (本地)'));
          await tester.tap(find.text('Sherpa NCNN (本地)'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OpenAI STT (远程)').last);
          await tester.pumpAndSettle();
          final url = find.byKey(const ValueKey('stt-URL'));
          await revealStt(tester, url);
          await tester.enterText(url, 'https://example.invalid/stt');
          final key = find.byKey(const ValueKey('stt-API 密钥'));
          await revealStt(tester, key);
          await tester.enterText(key, 'draft-only');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await revealStt(tester, find.byTooltip('显示密钥'));
          await tester.tap(find.byTooltip('显示密钥'));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(key).obscureText, isFalse);
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('OpenAI STT (远程)'), reverse: true);
          await tester.tap(find.text('OpenAI STT (远程)'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Deepgram STT (远程)').last);
          await tester.pumpAndSettle();
          await revealStt(tester, url);
          expect(
            tester.widget<TextField>(url).controller!.text,
            'https://example.invalid/stt',
          );
          await revealStt(tester, find.byTooltip('新建语音配置'), reverse: true);
          await tester.tap(find.byTooltip('新建语音配置'));
          await tester.pumpAndSettle();
          final name = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(name, '新草稿');
          await tester.pumpAndSettle();
          await tester.tap(find.text('创建'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('配置一'));
          await tester.tap(find.text('配置一'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('配置二').last);
          await tester.pumpAndSettle();
          await revealStt(tester, find.text('Sherpa NCNN (本地)'));
          expect(find.text('Sherpa NCNN (本地)'), findsOneWidget);
          await revealStt(tester, find.text('配置二'), reverse: true);
          await tester.tap(find.text('配置二'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('配置一').last);
          await tester.pumpAndSettle();
          await revealStt(tester, url);
          expect(
            tester.widget<TextField>(url).controller!.text,
            'https://example.invalid/stt',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
