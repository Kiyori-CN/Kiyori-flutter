import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/music/presentation/music_desktop_lyric_settings.dart';
import 'package:kiyori/features/music/presentation/music_settings_page.dart';
import 'package:kiyori/features/music/presentation/music_settings_presentation.dart';
import 'package:kiyori/features/music/presentation/music_settings_slider.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart' show revealAvatar;

void main() {
  testWidgets('download dependencies and busy history use current snapshot', (
    tester,
  ) async {
    Future<void> mount(MusicSettingsPresentation snapshot) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: MusicSettingsPage(snapshot: snapshot),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount(
      const MusicSettingsPresentation(
        searchCount: 4,
        playingAudio: true,
        hasMedia: true,
        speed: 1.25,
        preferences: MusicPreferencePresentation(
          tags: false,
          embedded: false,
          directoryName: '测试目录',
          directoryDescription: '共享下载目录',
          lyricFile: false,
        ),
      ),
    );
    await revealAvatar(tester, find.text('写入别名'));
    SettingsRow row(String title) => tester.widget<SettingsRow>(
      find
          .ancestor(of: find.text(title), matching: find.byType(SettingsRow))
          .first,
    );
    expect(row('写入别名').enabled, isFalse);
    await revealAvatar(tester, find.text('写入罗马音歌词'));
    expect(row('写入罗马音歌词').enabled, isFalse);
    await revealAvatar(tester, find.text('播放速度'));
    expect(row('播放速度').value, '1.25×');
    await tester.tap(find.text('播放速度'));
    await tester.pumpAndSettle();
    expect(find.text('当前：1.25×'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2.0×'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.0×'));
    await tester.pumpAndSettle();
    expect(row('播放速度').value, '1.25×');
    await revealAvatar(tester, find.text('清空搜索历史'));
    await tester.tap(find.text('清空搜索历史'));
    await tester.pumpAndSettle();
    await mount(
      const MusicSettingsPresentation(searchCount: 4, importing: true),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '清除'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'slider draft resets after release and adopts authoritative changes',
    (tester) async {
      Future<void> mount(double value, {bool enabled = true}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MusicSettingsSlider(
                title: '音量',
                value: value,
                min: 0,
                max: 100,
                unit: '%',
                enabled: enabled,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(30);
      await tester.drag(find.byType(Slider), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 30);
      await mount(70);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 70);
      await mount(70, enabled: false);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    },
  );

  testWidgets(
    'desktop lyrics project nondefault style without opening an overlay service',
    (tester) async {
      const style = MusicDesktopLyricPresentation(
        color: 0xff123456,
        bold: true,
        font: '等宽',
        align: '居右',
        maxLines: 4,
        size: 25,
        opacity: 60,
        backgroundOpacity: 20,
        locked: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MusicDesktopLyricSettings(style: style, editable: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<Text>(find.text('让音乐陪伴每一刻\n桌面歌词样式预览'));
      expect(preview.style!.fontSize, 25);
      expect(preview.style!.fontFamily, 'monospace');
      expect(preview.style!.fontWeight, FontWeight.bold);
      expect(preview.textAlign, TextAlign.right);
      expect(preview.maxLines, 4);
      expect(find.text('#123456'), findsOneWidget);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .every((s) => s.onChanged == null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
