import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_business_test.dart' show ChatFixture;

void main() {
  test(
    'nonstream preference controls the real request and reports final usage',
    () async {
      final f = ChatFixture();
      await f.open();
      try {
        await f.chat.setPreference('disable_stream', 'true');
        await f.chat.send('短合成提问');
        expect(f.requests.single['stream'], isFalse);
        expect(f.chat.snapshot!.messages.last.content, f.answer);
        expect(
          f.chat.snapshot!.messages.last.state,
          'completed',
          reason: f.chat.snapshot!.messages.last.error,
        );
        expect(f.chat.snapshot!.messages.last.inputTokens, 7);
        expect(f.chat.snapshot!.messages.last.outputTokens, 9);
      } finally {
        await f.close();
      }
    },
  );
  test('chat preferences persist history, input and reasoning defaults through Rust', () async {
    final fixture = ChatFixture();
    await fixture.open();
    try {
      expect(fixture.chat.preferences!.historyMode, 'folder');
      expect(fixture.chat.preferences!.thinking, isFalse);
      expect(fixture.chat.preferences!.thinkingQuality, 2);
      expect(fixture.chat.preferences!.memoryAuto, isTrue);
      expect(
        await fixture.chat.setPreference('history_mode', 'current'),
        isTrue,
      );
      expect(
        await fixture.chat.setPreference('input_style', 'classic'),
        isTrue,
      );
      expect(await fixture.chat.setPreference('thinking', 'true'), isTrue);
      expect(await fixture.chat.setPreference('thinking_quality', '5'), isTrue);
      final reopened = await fixture.runtime.chatPreferences();
      expect(reopened.historyMode, 'current');
      expect(reopened.inputStyle, 'classic');
      expect(reopened.thinking, isTrue);
      expect(reopened.thinkingQuality, 5);
      expect(
        () => fixture.runtime.changeChatPreference(
          reopened.revision - 1,
          'thinking',
          'false',
        ),
        throwsA(isA<BridgeError>()),
      );
    } finally {
      await fixture.close();
    }
  });
}
