import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_settings_slider.dart';

class MusicDesktopLyricSettings extends StatelessWidget {
  const MusicDesktopLyricSettings({super.key});
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
    onTap: () async {
      await showSettingsSelection(
        context,
        title: sheet,
        current: current,
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
      const SettingsRow(
        title: '开启桌面歌词',
        description: '需要系统悬浮窗权限；播放音乐时显示',
        checked: false,
      ),
      const SettingsDivider(),
      const SettingsRow(
        title: '锁定位置',
        description: '锁定后触摸穿透；可在这里或长按歌曲页 LRC 解锁',
        checked: false,
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
              color: Colors.black.withValues(alpha: .4),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '让音乐陪伴每一刻\n桌面歌词样式预览',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
      const MusicSettingsSlider(
        title: '字体大小',
        value: 18,
        min: 10,
        max: 48,
        unit: ' sp',
      ),
      _choice(context, '字体', '使用系统字体，无需导入文件', '无衬线', [
        '无衬线',
        '衬线',
        '等宽',
      ], '桌面歌词字体'),
      const SettingsRow(
        title: '加粗文字',
        description: '提高小字号文字的辨识度',
        checked: false,
      ),
      _choice(context, '文字颜色', '独立于应用主题', '白色', [
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
      const SettingsRow(
        title: '文字阴影',
        description: '浅色字用深色阴影，黑字用浅色阴影',
        checked: true,
      ),
      const MusicSettingsSlider(
        title: '文字不透明度',
        value: 100,
        min: 20,
        max: 100,
        unit: '%',
      ),
      const MusicSettingsSlider(
        title: '背景不透明度',
        value: 40,
        min: 0,
        max: 100,
        unit: '%',
      ),
      _choice(context, '文字对齐', '设置悬浮窗口内的文字位置', '居中', [
        '居左',
        '居中',
        '居右',
      ], '桌面歌词对齐'),
      _choice(context, '最多显示行数', '长歌词按窗口宽度换行', '2 行', [
        for (var count = 1; count <= 6; count++) '$count 行',
      ], '桌面歌词行数'),
      const SettingsRow(
        title: '显示翻译',
        description: '原歌词存在匹配翻译时追加显示，受行数限制',
        checked: true,
      ),
      const MusicSettingsSlider(
        title: '窗口宽度',
        value: 90,
        min: 30,
        max: 100,
        unit: '%',
      ),
      const MusicSettingsSlider(
        title: '水平位置',
        value: 50,
        min: 0,
        max: 100,
        unit: '% · 左 → 右',
      ),
      const MusicSettingsSlider(
        title: '垂直位置',
        value: 15,
        min: 0,
        max: 100,
        unit: '% · 上 → 下',
      ),
      const SettingsRow(
        title: '重置位置与宽度',
        description: '回到顶部居中，宽度为屏幕的 90%；不改变锁定状态',
      ),
    ],
  );
}
