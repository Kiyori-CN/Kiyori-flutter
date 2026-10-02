import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/context/context_summary_page.dart';
import 'package:kiyori/features/assistant/presentation/profile/user_profile_page.dart';
import 'package:kiyori/features/assistant/presentation/server/lan_automation_page.dart';
import 'package:kiyori/features/assistant/presentation/server/lan_automation_presentation.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_page.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_presentation.dart';
import 'package:kiyori/features/speech/presentation/stt_settings_page.dart';
import 'package:kiyori/features/speech/presentation/stt_presentation.dart';
import 'package:kiyori/features/speech/presentation/tts_settings_page.dart';
import 'package:kiyori/features/speech/presentation/tts_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart';
import 'support/ui_capture.dart';

const capture = String.fromEnvironment('KIYORI_CAPTURE');

void main() {
  late ValueNotifier<Widget> host;
  late GlobalKey boundary;
  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = ValueNotifier(page);
    boundary = GlobalKey();
    if (capture.isNotEmpty) await loadCaptureFonts(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: KiyoriTheme.light(),
          home: ValueListenableBuilder(
            valueListenable: host,
            builder: (_, child, _) => child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> update(WidgetTester tester, Widget page) async {
    host.value = page;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (capture.isNotEmpty) await captureUi(tester, boundary, capture, name);
  }

  String text(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets(
    'TTS authority refresh preserves unrelated draft and system default remains selectable',
    (tester) async {
      const initial = TtsProfilePresentation(
        id: 'a',
        name: '远程',
        engine: TtsEngine.openai,
        model: 'old',
      );
      await mount(
        tester,
        const TtsSettingsPage(profiles: [initial], activeId: 'a'),
      );
      final model = find.byKey(const ValueKey('tts-model'));
      await revealStt(tester, model);
      await tester.enterText(model, 'local');
      await update(
        tester,
        const TtsSettingsPage(profiles: [initial], activeId: 'a'),
      );
      expect(text(tester, model), 'local');
      await update(
        tester,
        const TtsSettingsPage(
          profiles: [
            TtsProfilePresentation(
              id: 'a',
              name: '远程',
              engine: TtsEngine.openai,
              model: 'new',
            ),
          ],
          activeId: 'a',
        ),
      );
      expect(text(tester, model), 'new');
      await update(
        tester,
        const TtsSettingsPage(
          profiles: [TtsProfilePresentation(id: 'b', name: '系统', voice: 'v')],
          activeId: 'b',
          catalog: TtsCatalogPresentation(
            systemVoices: [SpeechVoiceOption('v', '音色甲', locale: 'zh-CN')],
          ),
        ),
      );
      await revealStt(tester, find.byTooltip('选择系统音色'), reverse: true);
      await tester.tap(find.byTooltip('选择系统音色'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用系统默认音色'));
      await tester.pumpAndSettle();
      expect(find.text('音色甲 (zh-CN)'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile load, clean refresh and dirty refresh preserve correct source',
    (tester) async {
      await mount(
        tester,
        const UserProfilePage(snapshot: UserProfilePresentation(loading: true)),
      );
      await update(
        tester,
        const UserProfilePage(
          snapshot: UserProfilePresentation(markdown: '# 已加载'),
        ),
      );
      final editor = find.byKey(const ValueKey('user-md-editor'));
      expect(text(tester, editor), '# 已加载');
      await update(
        tester,
        const UserProfilePage(
          snapshot: UserProfilePresentation(markdown: '# 新正文'),
        ),
      );
      expect(text(tester, editor), '# 新正文');
      await tester.enterText(editor, '# 本地草稿');
      await update(
        tester,
        const UserProfilePage(
          snapshot: UserProfilePresentation(markdown: '# 后台更新'),
        ),
      );
      expect(text(tester, editor), '# 本地草稿');
      await shot(tester, 'profile-dirty-refresh');
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复默认模板'));
      await tester.pumpAndSettle();
      await shot(tester, 'profile-reset');
      await update(
        tester,
        const UserProfilePage(
          snapshot: UserProfilePresentation(markdown: '# 又更新'),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(text(tester, editor), '# 本地草稿');
    },
  );

  testWidgets(
    'profile archive invalidation and host disposal release drawer and dialog',
    (tester) async {
      await mount(
        tester,
        const UserProfilePage(
          snapshot: UserProfilePresentation(archive: '旧档案正文'),
        ),
      );
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧档案'));
      await tester.pumpAndSettle();
      expect(find.text('旧档案正文'), findsOneWidget);
      await shot(tester, 'profile-archive');
      await update(tester, const UserProfilePage());
      expect(find.text('旧档案正文'), findsNothing);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复默认模板'));
      await tester.pumpAndSettle();
      await update(tester, const SizedBox());
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'context equal refresh keeps draft but config identity resets all fields and modal',
    (tester) async {
      await mount(tester, const ContextSummaryPage());
      final length = find.byKey(const ValueKey('上下文长度'));
      await revealContext(tester, length);
      await tester.enterText(length, '31');
      await update(
        tester,
        const ContextSummaryPage(
          snapshot: ContextSummaryPresentation(configName: '重命名'),
        ),
      );
      expect(text(tester, length), '31');
      await revealContext(tester, find.text('恢复历史媒体默认值'));
      await tester.tap(find.text('恢复历史媒体默认值'));
      await tester.pumpAndSettle();
      await shot(tester, 'context-reset');
      await update(
        tester,
        const ContextSummaryPage(
          snapshot: ContextSummaryPresentation(configId: 'other'),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(text(tester, length), '64');
      await update(
        tester,
        const ContextSummaryPage(
          snapshot: ContextSummaryPresentation(
            configId: 'other',
            contextLength: '80',
          ),
        ),
      );
      expect(text(tester, length), '80');
    },
  );

  testWidgets(
    'LAN authority refresh hides changed token and invalidates old reset',
    (tester) async {
      await mount(
        tester,
        const LanAutomationPage(
          snapshot: LanAutomationPresentation(token: 'fixture-one'),
        ),
      );
      final port = find.byKey(const ValueKey('lan-port'));
      await tester.ensureVisible(port);
      await tester.enterText(port, '19000');
      await update(
        tester,
        const LanAutomationPage(
          snapshot: LanAutomationPresentation(token: 'fixture-one'),
        ),
      );
      expect(text(tester, port), '19000');
      final token = find.byKey(const ValueKey('lan-token'));
      await tester.ensureVisible(token);
      await tester.tap(find.byTooltip('显示 Token'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('重置 Token'));
      await tester.tap(find.text('重置 Token'));
      await tester.pumpAndSettle();
      await shot(tester, 'lan-token-reset');
      await update(
        tester,
        const LanAutomationPage(
          snapshot: LanAutomationPresentation(
            port: 20000,
            token: 'fixture-two',
          ),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(text(tester, port), '20000');
      expect(text(tester, token), 'fixture-two');
      expect(tester.widget<TextField>(token).obscureText, isTrue);
      await tester.ensureVisible(find.text('重置 Token'));
      await tester.tap(find.text('重置 Token'));
      await tester.pumpAndSettle();
      await update(tester, const SizedBox());
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'usage pricing equal snapshot retains draft, authority updates, removal releases modal',
    (tester) async {
      const a = ModelUsagePresentation(name: 'A', inputPriceCny: 2);
      const b = ModelUsagePresentation(name: 'B');
      await mount(
        tester,
        const UsagePage(snapshot: UsagePresentation(models: [a, b])),
      );
      await revealUsage(tester, find.byKey(const ValueKey('usage-A')));
      await tester.tap(find.byKey(const ValueKey('usage-A')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('输入价格（每百万Token） (CNY)'));
      await tester.enterText(field, '7');
      await update(
        tester,
        const UsagePage(snapshot: UsagePresentation(models: [b, a])),
      );
      expect(text(tester, field), '7');
      await update(
        tester,
        const UsagePage(
          snapshot: UsagePresentation(
            models: [ModelUsagePresentation(name: 'A', inputPriceCny: 3)],
          ),
        ),
      );
      expect(text(tester, field), '3');
      await shot(tester, 'usage-price-refresh');
      await update(tester, const UsagePage());
      expect(find.byType(AlertDialog), findsNothing);
      await update(
        tester,
        const UsagePage(snapshot: UsagePresentation(models: [a])),
      );
      await revealUsage(tester, find.byKey(const ValueKey('usage-A')));
      await tester.tap(find.byKey(const ValueKey('usage-A')));
      await tester.pumpAndSettle();
      expect(text(tester, field), '2');
      await update(tester, const SizedBox());
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'STT live fields retain drafts and invalidate rename when entity disappears',
    (tester) async {
      const a = SttProfilePresentation(
        id: 'a',
        name: '配置甲',
        engine: SttEngine.openai,
      );
      const b = SttProfilePresentation(
        id: 'b',
        name: '配置乙',
        engine: SttEngine.deepgram,
        model: 'model-b',
      );
      await mount(
        tester,
        const SttSettingsPage(profiles: [a, b], activeId: 'a'),
      );
      final field = find.byKey(const ValueKey('stt-model'));
      await revealStt(tester, field);
      await tester.enterText(field, 'local');
      await update(
        tester,
        const SttSettingsPage(profiles: [a, b], activeId: 'a'),
      );
      expect(text(tester, field), 'local');
      await update(
        tester,
        const SttSettingsPage(profiles: [a, b], activeId: 'b'),
      );
      expect(text(tester, field), 'model-b');
      await revealStt(tester, find.byTooltip('重命名语音配置').first, reverse: true);
      await tester.tap(find.byTooltip('重命名语音配置').first);
      await tester.pumpAndSettle();
      await shot(tester, 'speech-rename');
      await update(tester, const SttSettingsPage(profiles: [a], activeId: 'a'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(text(tester, field), 'local');
      await update(tester, const SttSettingsPage(profiles: [], activeId: ''));
      await update(tester, const SttSettingsPage(profiles: [a], activeId: 'a'));
      expect(text(tester, field), 'whisper-1');
    },
  );

  testWidgets(
    'TTS remote and system pickers close on catalog change or host exit',
    (tester) async {
      const remote = TtsProfilePresentation(
        id: 'a',
        name: '远程',
        engine: TtsEngine.openai,
      );
      const system = TtsProfilePresentation(id: 'b', name: '系统');
      const catalog = TtsCatalogPresentation(
        models: [SpeechVoiceOption('model-a', '模型甲')],
        systemVoices: [SpeechVoiceOption('v', '音色甲', locale: 'zh-CN')],
      );
      await mount(
        tester,
        const TtsSettingsPage(
          profiles: [remote, system],
          activeId: 'a',
          catalog: catalog,
        ),
      );
      await revealStt(tester, find.byTooltip('可用模型列表'));
      await tester.tap(find.byTooltip('可用模型列表'));
      await tester.pumpAndSettle();
      await shot(tester, 'tts-model-picker');
      await update(
        tester,
        const TtsSettingsPage(profiles: [remote, system], activeId: 'a'),
      );
      expect(find.byType(AlertDialog), findsNothing);
      await update(
        tester,
        const TtsSettingsPage(
          profiles: [remote, system],
          activeId: 'b',
          catalog: catalog,
        ),
      );
      await revealStt(tester, find.byTooltip('选择系统音色'), reverse: true);
      await tester.tap(find.byTooltip('选择系统音色'));
      await tester.pumpAndSettle();
      await shot(tester, 'tts-system-picker');
      await update(
        tester,
        const TtsSettingsPage(profiles: [remote, system], activeId: 'b'),
      );
      expect(find.byType(AlertDialog), findsNothing);
      await update(
        tester,
        const TtsSettingsPage(
          profiles: [remote, system],
          activeId: 'b',
          catalog: catalog,
        ),
      );
      await tester.tap(find.byTooltip('选择系统音色'));
      await tester.pumpAndSettle();
      await update(tester, const SizedBox());
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
