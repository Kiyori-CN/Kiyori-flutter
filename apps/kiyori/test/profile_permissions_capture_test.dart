import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_capture.dart';

import 'package:kiyori/features/assistant/presentation/permissions/tool_permissions_page.dart';
import 'package:kiyori/features/assistant/presentation/profile/user_profile_page.dart';
import 'package:kiyori/features/assistant/presentation/server/lan_automation_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/reply_preferences_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/custom_emoji_page.dart';
import 'package:kiyori/features/assistant/presentation/replies/emoji_presentation.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_page.dart';
import 'package:kiyori/features/speech/presentation/stt_settings_page.dart';
import 'package:kiyori/features/speech/presentation/stt_presentation.dart';
import 'package:kiyori/features/speech/presentation/tts_settings_page.dart';
import 'package:kiyori/features/speech/presentation/tts_tool_page.dart';
import 'package:kiyori/features/speech/presentation/wakeup_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'usage_test.dart' show usageFixture;
import 'stt_settings_test.dart' show revealStt;

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture profile and tool permission surfaces',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      Future<void> show(Widget page, {bool dark = false}) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name, {bool animated = false}) =>
          captureUi(tester, boundaryKey, output, name, animated: animated);

      const page = UserProfilePage(
        snapshot: UserProfilePresentation(
          markdown: '# 关于我\n\n喜欢阅读和编程，希望回复清晰、有依据。\n\n## 交流习惯\n\n- 使用中文\n- 保留关键技术名称\n\n> 遇到不确定的信息，请明确说明。',
          archive: '# 旧资料\n这是一份预览夹具。',
        ),
      );
      await show(page);
      await capture('profile-edit-phone');
      await tester.tap(find.text('预览'));
      await capture('profile-preview-phone');
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧档案'));
      await capture('profile-archive-phone');
      await show(page, dark: true);
      await capture('profile-dark-phone');
      await show(const ToolPermissionsPage());
      await capture('tool-permissions-phone');
      await tester.tap(find.byKey(const ValueKey('add-allow')));
      await capture('tool-picker-phone');
      await show(const LanAutomationPage());
      await capture('lan-automation-phone');
      await show(ReplyPreferencesPage(onCustomEmoji: () {}));
      await capture('reply-preferences-phone');
      await show(CustomEmojiPage(snapshot: EmojiLibraryPresentation.bundled));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await capture('emoji-library-phone');
      await show(const UsagePage());
      await capture('usage-empty-phone');
      await show(const UsagePage(snapshot: usageFixture));
      await capture('usage-summary-phone');
      await show(const SttSettingsPage());
      await capture('stt-local-phone');
      await show(
        const SttSettingsPage(
          profiles: [
            SttProfilePresentation(
              id: 'one',
              name: '远程配置',
              engine: SttEngine.openai,
            ),
          ],
        ),
      );
      await capture('stt-remote-phone');
      await show(const TtsSettingsPage());
      await capture('tts-settings-phone');
      await show(const TtsToolPage());
      await capture('tts-tool-phone');
      await show(const WakeupSettingsPage());
      await capture('wakeup-phone');
      await tester.tap(find.text('STT（识别文本）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('个人化模板（录三遍）').last);
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('录入个人化唤醒模板'));
      await tester.tap(find.text('录入个人化唤醒模板'));
      await capture('wakeup-enrollment-phone');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await revealStt(tester, find.text('时间'));
      await capture('wakeup-attachments-phone');
      await tester.tap(find.text('时间'));
      await capture('wakeup-attachment-dialog-phone');
      expect(tester.takeException(), isNull);
    },
  );
}
