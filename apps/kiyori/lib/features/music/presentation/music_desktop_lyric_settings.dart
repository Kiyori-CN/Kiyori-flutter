import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_settings_slider.dart';
import 'music_settings_presentation.dart';

class MusicDesktopLyricSettings extends StatelessWidget {
  const MusicDesktopLyricSettings({
    this.style = const MusicDesktopLyricPresentation(),
    this.editable = true,
    this.onRoute,
    super.key,
  });
  final MusicDesktopLyricPresentation style;
  final bool editable;
  final void Function(ModalRoute<dynamic>)? onRoute;
  static const colors = {
    0xffffff: '白色',
    0x08e664: '绿色',
    0xfffa12: '黄色',
    0x019ce4: '蓝色',
    0xff1222: '红色',
    0xef6976: '粉色',
    0xc851d4: '紫色',
    0xffa600: '橙色',
    0x000000: '黑色',
  };
  String get colorLabel =>
      colors[style.color & 0xffffff] ??
      '#${(style.color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  Widget _choice(
    BuildContext context,
    String title,
    String description,
    String current,
    List<String> labels,
    String sheet,
  ) => SettingsRow(
    title: title,
    description: description,
    value: current,
    enabled: editable,
    onTap: () async {
      await showSettingsSelection(
        context,
        title: sheet,
        current: current,
        onRoute: onRoute,
        options: [
          for (final label in labels)
            SettingsOption(label, selected: label == current),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => SettingsGroup(
    title: '桌面歌词 · LRC',
    description: '悬浮在其他应用上；修改即时应用，位置与样式保存在本机',
    children: [
      SettingsRow(
        title: '开启桌面歌词',
        description: '需要系统悬浮窗权限；播放音乐时显示',
        checked: style.enabled,
        enabled: editable,
      ),
      const SettingsDivider(),
      SettingsRow(
        title: '锁定位置',
        description: '锁定后触摸穿透；可在这里或长按歌曲页 LRC 解锁',
        checked: style.locked,
        enabled: editable,
      ),
      const SettingsDivider(),
      Padding(
        padding: const EdgeInsets.all(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: style.backgroundOpacity / 100,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '让音乐陪伴每一刻\n桌面歌词样式预览',
                  textAlign: switch (style.align) {
                    '居左' => TextAlign.left,
                    '居右' => TextAlign.right,
                    _ => TextAlign.center,
                  },
                  maxLines: style.maxLines,
                  style: TextStyle(
                    fontSize: style.size,
                    color: Color(style.color)
                        .withValues(alpha: style.opacity / 100),
                    fontWeight: style.bold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontFamily: switch (style.font) {
                      '衬线' => 'serif',
                      '等宽' => 'monospace',
                      _ => 'sans-serif',
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      MusicSettingsSlider(
        title: '字体大小',
        value: style.size,
        enabled: editable,
        min: 10,
        max: 48,
        unit: ' sp',
      ),
      _choice(context, '字体', '使用系统字体，无需导入文件', style.font, [
        '无衬线',
        '衬线',
        '等宽',
      ], '桌面歌词字体'),
      SettingsRow(
        title: '加粗文字',
        description: '提高小字号文字的辨识度',
        checked: style.bold,
        enabled: editable,
      ),
      _choice(context, '文字颜色', '独立于应用主题', colorLabel, [
        '白色',
        '绿色',
        '黄色',
        '蓝色',
        '红色',
        '粉色',
        '紫色',
        '橙色',
        '黑色',
      ], '桌面歌词颜色'),
      SettingsRow(
        title: '文字阴影',
        description: '浅色字用深色阴影，黑字用浅色阴影',
        checked: style.shadow,
        enabled: editable,
      ),
      MusicSettingsSlider(
        title: '文字不透明度',
        value: style.opacity,
        enabled: editable,
        min: 20,
        max: 100,
        unit: '%',
      ),
      MusicSettingsSlider(
        title: '背景不透明度',
        value: style.backgroundOpacity,
        enabled: editable,
        min: 0,
        max: 100,
        unit: '%',
      ),
      _choice(context, '文字对齐', '设置悬浮窗口内的文字位置', style.align, [
        '居左',
        '居中',
        '居右',
      ], '桌面歌词对齐'),
      _choice(context, '最多显示行数', '长歌词按窗口宽度换行', '${style.maxLines} 行', [
        for (var count = 1; count <= 6; count++) '$count 行',
      ], '桌面歌词行数'),
      SettingsRow(
        title: '显示翻译',
        description: '原歌词存在匹配翻译时追加显示，受行数限制',
        checked: style.translation,
        enabled: editable,
      ),
      MusicSettingsSlider(
        title: '窗口宽度',
        value: style.width,
        enabled: editable,
        min: 30,
        max: 100,
        unit: '%',
      ),
      MusicSettingsSlider(
        title: '水平位置',
        value: style.x,
        enabled: editable,
        min: 0,
        max: 100,
        unit: '% · 左 → 右',
      ),
      MusicSettingsSlider(
        title: '垂直位置',
        value: style.y,
        enabled: editable,
        min: 0,
        max: 100,
        unit: '% · 上 → 下',
      ),
      SettingsRow(
        title: '重置位置与宽度',
        enabled: editable,
        description: '回到顶部居中，宽度为屏幕的 90%；不改变锁定状态',
      ),
    ],
  );
}
