import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/chat_page.dart';
import 'package:kiyori/features/assistant/presentation/chat_classic_input.dart';
import 'package:kiyori/features/assistant/presentation/chat_messages.dart';
import 'package:kiyori/features/settings/presentation/appearance/appearance_settings_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/chat_fixture.dart';
import 'support/ui_capture.dart';

void main() {
  testWidgets(
    'appearance modes persist and preserve draft across narrow dark keyboard layout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final f = ChatFixture();
      await tester.runAsync(() async {
        await f.open();
        await f.chat.send('气泡模式合成提问');
      });
      final key = GlobalKey();
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      try {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: KiyoriTheme.light(),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(
                      builder: (context) => TextButton(
                        child: const Text('打开主题'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AnimatedBuilder(
                              animation: f.chat,
                              builder: (_, _) => AppearanceSettingsPage(
                                messageStyle: f.chat.preferences?.messageStyle,
                                inputStyle: f.chat.preferences?.inputStyle,
                                onPreference: f.chat.setPreference,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: ChatPage(controller: f.chat)),
                  ],
                ),
              ),
            ),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.enterText(
          find.byKey(const Key('chat-draft')),
          '切换模式保留\n完整草稿',
        );
        await tester.tap(find.text('打开主题'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('聊天').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('对话框'));
        await until(tester, () => f.chat.preferences?.messageStyle == 'bubble');
        await tester.tap(find.text('输入栏').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('经典样式'));
        await until(tester, () => f.chat.preferences?.inputStyle == 'classic');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ChatClassicInput), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('chat-draft')))
              .controller!
              .text,
          '切换模式保留\n完整草稿',
        );
        expect(find.text('Prompt'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ChatMessageTile),
            matching: find.text('气泡模式合成提问'),
          ),
          findsOneWidget,
        );
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-bubble-classic');
        }
        tester.view.physicalSize = const Size(320, 740);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: KiyoriTheme.dark(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 240),
                ),
                child: child!,
              ),
              home: Scaffold(body: ChatPage(controller: f.chat)),
            ),
          ),
        );
        await until(tester, () => !f.chat.loading);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty) {
          await captureUi(tester, key, output, 'chat-bubble-classic-narrow');
        }
        final persisted = await tester.runAsync(f.runtime.chatPreferences);
        expect(persisted!.messageStyle, 'bubble');
        expect(persisted.inputStyle, 'classic');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}
