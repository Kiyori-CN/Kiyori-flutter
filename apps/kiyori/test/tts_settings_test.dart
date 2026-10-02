import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/speech/presentation/tts_settings_page.dart';
import 'package:kiyori/features/speech/presentation/tts_presentation.dart';
import 'package:kiyori/features/speech/presentation/tts_draft.dart';
import 'package:kiyori/features/speech/presentation/tts_tool_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';
import 'package:kiyori/app/kiyori_app.dart';

import 'support/fake_runtime.dart' show FakeClient;

import 'support/ui_test_helpers.dart' show revealStt;

void main() {
  testWidgets(
    'TTS tool returns to its settings or toolbox source without a runtime call',
    (tester) async {
      final client = FakeClient();
      await tester.pumpWidget(KiyoriApp(connect: () async => client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 助手'));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('文本转语音'));
      await tester.tap(find.text('文本转语音'));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('测试 TTS 功能'));
      await tester.tap(find.text('测试 TTS 功能'));
      await tester.pumpAndSettle();
      expect(find.byType(TtsToolPage), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(TtsSettingsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-2')));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('文本转语音').first);
      await tester.tap(find.text('文本转语音').first);
      await tester.pumpAndSettle();
      expect(find.byType(TtsToolPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('工具箱'), findsWidgets);
      expect(client.starts, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets(
      'TTS selectors and tools preserve ownership with keyboard $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const TtsSettingsPage(
              profiles: [
                TtsProfilePresentation(id: 'simple', name: '本地配置'),
                TtsProfilePresentation(
                  id: 'remote',
                  name: '远程配置',
                  engine: TtsEngine.openai,
                ),
              ],
              activeId: 'simple',
              catalog: TtsCatalogPresentation(
                systemVoices: [
                  SpeechVoiceOption('v1', '音色甲', locale: 'zh-CN'),
                  SpeechVoiceOption('v2', 'Voice B', locale: 'en-US'),
                ],
                models: [SpeechVoiceOption('tts-1', 'tts-1')],
                voices: TtsCatalogPresentation.openAiVoices,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await revealStt(tester, find.byTooltip('选择系统音色'));
        await tester.tap(find.byTooltip('选择系统音色'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('音色甲 (zh-CN)'));
        await tester.pumpAndSettle();
        expect(find.text('音色甲 (zh-CN)'), findsOneWidget);
        await revealStt(tester, find.text('本地配置'), reverse: true);
        await tester.tap(find.text('本地配置'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('远程配置').last);
        await tester.pumpAndSettle();
        await revealStt(tester, find.byTooltip('可用模型列表'));
        await tester.tap(find.byTooltip('可用模型列表'));
        await tester.pumpAndSettle();
        final search = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'tts');
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 120 : 240,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(find.text('tts-1'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('tts-model')))
              .controller!
              .text,
          'tts-1',
        );
        await revealStt(tester, find.byTooltip('选择音色'));
        await tester.tap(find.byTooltip('选择音色'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'nova',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('nova'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('tts-voice')))
              .controller!
              .text,
          'nova',
        );
        await revealStt(tester, find.text('远程配置'), reverse: true);
        await tester.tap(find.text('远程配置'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('本地配置').last);
        await tester.pumpAndSettle();
        await revealStt(tester, find.text('音色甲 (zh-CN)'));
        expect(find.text('音色甲 (zh-CN)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: const TtsToolPage(
              snapshot: TtsToolPresentation(
                initialized: true,
                error: '测试错误',
                details: '详细说明',
                debug: '测试快照',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('tts-tool-input')),
          '一段朗读草稿',
        );
        await revealStt(tester, find.text('播放语音'));
        await tester.tap(find.text('播放语音'));
        await tester.pumpAndSettle();
        await revealStt(tester, find.text('未播放'));
        expect(find.text('未播放'), findsOneWidget);
        await revealStt(tester, find.text('清除错误信息'));
        await tester.tap(find.text('清除错误信息'));
        await tester.pumpAndSettle();
        expect(find.text('测试错误'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'speech JSON respects map and pipeline editable shapes without executing',
    () {
      expect(validSpeechJson('{"token":"draft"}'), isTrue);
      expect(validSpeechJson('{"token":1}'), isFalse);
      expect(validSpeechJson('[1]'), isFalse);
      expect(
        validSpeechJson('[{"type":"pick","path":"audio_uri"}]', pipeline: true),
        isTrue,
      );
      expect(
        validSpeechJson(
          '[{"type":"http_get","headers":{"X":2}}]',
          pipeline: true,
        ),
        isFalse,
      );
      expect(
        validSpeechJson('[{"path":"audio_uri"}]', pipeline: true),
        isFalse,
      );
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'TTS nine engine branches fit and retain safe drafts $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          for (final engine in TtsEngine.values) {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MaterialApp(
                theme: KiyoriTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: TtsSettingsPage(
                  profiles: [
                    TtsProfilePresentation(
                      id: 'test',
                      name: '语音配置',
                      engine: engine,
                    ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            await revealStt(tester, find.text(engine.label));
            await revealStt(tester, find.byKey(const ValueKey('tts-template')));
            await tester.tap(find.byKey(const ValueKey('tts-template')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('删除 XML 标签'));
            await tester.pumpAndSettle();
            await revealStt(tester, find.text('测试 TTS 功能'));
            expect(tester.takeException(), isNull, reason: engine.name);
            if (engine != TtsEngine.simple) {
              final key = find.byKey(const ValueKey('tts-model'));
              final input = engine == TtsEngine.http
                  ? find.byKey(const ValueKey('tts-pipeline'))
                  : engine == TtsEngine.vits
                  ? find.byKey(const ValueKey('tts-options'))
                  : key;
              await revealStt(tester, input, reverse: true);
              await tester.enterText(input, 'draft-only');
              tester.view.viewInsets = FakeViewPadding(
                bottom: size.height < 500 ? 120 : 240,
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: 'keyboard ${engine.name}',
              );
              tester.view.viewInsets = const FakeViewPadding();
            }
          }
        },
      );
    }
  }
  testWidgets(
    'TTS cleaner removal keeps neighboring input and engine defaults are local',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const TtsSettingsPage()),
      );
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('添加'));
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      final cleaners = find
          .byType(TextField)
          .evaluate()
          .where(
            (e) =>
                (e.widget as TextField).decoration?.hintText == r'例如：\[.*?\]',
          )
          .map((e) => (e.widget as TextField).controller!)
          .toList();
      expect(cleaners.length, 3);
      cleaners.last.text = 'retain';
      final deletes = find.byTooltip('删除正则');
      await revealStt(tester, deletes.first, reverse: true);
      await tester.tap(deletes.first);
      await tester.pumpAndSettle();
      expect(find.text('retain'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await revealStt(tester, find.text('HTTP API (远程)'), reverse: true);
      await tester.tap(find.text('HTTP API (远程)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('豆包 TTS').last);
      await tester.pumpAndSettle();
      final endpoint = find.byKey(const ValueKey('tts-endpoint'));
      await revealStt(tester, endpoint);
      expect(
        tester.widget<TextField>(endpoint).controller!.text,
        'https://openspeech.bytedance.com/api/v1/tts',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
