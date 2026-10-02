import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_desktop_lyric_settings.dart';
import 'music_backup_settings.dart';
import 'music_settings_presentation.dart';
import 'music_source_settings.dart';
import 'music_settings_slider.dart';

/// MusicSettingsBody 的空资料默认展示；不创建 MusicWorkspace、音源或播放会话。
class MusicSettingsPage extends StatefulWidget {
  const MusicSettingsPage({
    this.snapshot = const MusicSettingsPresentation(),
    super.key,
  });
  final MusicSettingsPresentation snapshot;
  @override
  State<MusicSettingsPage> createState() => _MusicSettingsPageState();
}

class _MusicSettingsPageState extends State<MusicSettingsPage> {
  MusicSettingsPresentation get snapshot => widget.snapshot;
  MusicPreferencePresentation get preferences => snapshot.preferences;
  final routes = <ModalRoute<dynamic>>{};
  final revision = ValueNotifier(0);
  final backupSession = MusicBackupPreviewSession();
  @override
  void didUpdateWidget(covariant MusicSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.backup.preview?.id != snapshot.backup.preview?.id) {
      backupSession.presentedId = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revision.value++;
    });
  }

  void track(ModalRoute<dynamic> route) {
    if (!mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    if (routes.add(route)) {
      route.popped.whenComplete(() => routes.remove(route));
    }
  }

  @override
  void dispose() {
    final owned = routes.toList().reversed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in owned) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    revision.dispose();
    super.dispose();
  }

  void clearHistory(String title) {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => ValueListenableBuilder(
        valueListenable: revision,
        builder: (context, _, _) => AlertDialog(
          scrollable: true,
          title: Text('$title？'),
          content: const Text('清除后无法撤销，音乐文件和收藏会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: snapshot.editable ? emptyAction : null,
              child: const Text('清除'),
            ),
          ],
        ),
      ),
    );
    track(route);
    Navigator.of(context).push(route);
  }

  static const qualities = [
    '标准 · 128k',
    '高品质 · 320k',
    '无损 · FLAC',
    '24 bit · FLAC',
    'Hi-Res',
    '杜比全景声',
    '臻品全景声',
    '母带 · Master',
  ];

  Widget _choice(
    BuildContext context,
    String title,
    String description,
    String current,
    List<String> options, {
    String? value,
    String? sheetTitle,
    bool? enabled,
  }) => SettingsRow(
    title: title,
    description: description,
    value: value ?? current,
    enabled: enabled ?? snapshot.editable,
    onTap: () async {
      await showSettingsSelection(
        context,
        title: sheetTitle ?? title,
        current: current,
        onRoute: track,
        options: [
          for (final option in options)
            SettingsOption(option, selected: option == current),
        ],
      );
    },
  );
  Widget _group(String title, String description, List<Widget> rows) =>
      SettingsGroup(
        title: title,
        description: description,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            rows[i],
          ],
        ],
      );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '音乐播放器',
    children: [
      MusicSourceSettings(snapshot: snapshot),
      Column(
        spacing: 16,
        children: [
          _group('下载与文件', '设置用于新任务；正在下载的歌曲保留原目录和选项', [
            SettingsRow(
              title: '下载路径',
              description: preferences.directoryDescription ?? '沿用应用下载设置',
              value: preferences.directoryName ?? '跟随应用',
              enabled: snapshot.canEdit,
              onTap: () async {
                await showSettingsSelection(
                  context,
                  title: '音乐下载路径',
                  onRoute: track,
                  current: preferences.directoryName ?? '跟随应用',
                  options: [
                    SettingsOption(
                      '选择文件夹',
                      selected: preferences.directoryName != null,
                    ),
                    SettingsOption(
                      '跟随应用下载设置',
                      selected: preferences.directoryName == null,
                    ),
                  ],
                );
              },
            ),
            _choice(
              context,
              '下载音质',
              '平台与当前音源需支持所选音质',
              preferences.downloadQuality,
              qualities,
              value: preferences.downloadQuality.split(' · ').last,
              enabled: snapshot.canEdit,
            ),
            _choice(context, '文件命名', '同名文件自动编号，保留原有文件', preferences.fileName, [
              '歌名 - 歌手',
              '歌手 - 歌名',
              '歌名',
            ], enabled: snapshot.canEdit),
            if (preferences.directoryError case final error?)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ]),
          _group('下载附加选项', '标签写入不重新编码音频；处理结果可在下载任务中查看', [
            SettingsRow(
              title: '写入标签',
              description: '保存歌曲名、歌手和专辑',
              checked: preferences.tags,
              enabled: snapshot.canEdit,
            ),
            SettingsRow(
              title: '写入别名',
              description: '将平台提供的歌曲别名附加到标题标签',
              checked: preferences.alias,
              enabled: snapshot.canEdit && preferences.tags,
            ),
            SettingsRow(
              title: '下载歌词文件',
              description: '在音频旁保存同名 LRC 文件',
              checked: preferences.lyricFile,
              enabled: snapshot.canEdit,
            ),
            SettingsRow(
              title: '写入罗马音歌词',
              description: '平台提供时合并到 LRC 和内嵌歌词',
              checked: preferences.romanized,
              enabled:
                  snapshot.canEdit &&
                  (preferences.lyricFile || preferences.embedded),
            ),
            SettingsRow(
              title: '写入内嵌歌词',
              description: '将歌词保存在音频文件内',
              checked: preferences.embedded,
              enabled: snapshot.canEdit,
            ),
            SettingsRow(
              title: '写入封面',
              description: '将专辑封面嵌入音频文件；WAV 不支持',
              checked: preferences.cover,
              enabled: snapshot.canEdit,
            ),
          ]),
        ],
      ),
      _group('本地音乐资料', '播放本地文件，在线资料只补全缺失的封面与歌词。', [
        SettingsRow(
          title: '自动匹配在线歌曲',
          description: '按歌名、歌手和时长核对；有歧义时手动选择',
          checked: preferences.autoMatch,
          enabled: snapshot.editable,
        ),
        _choice(context, '资料匹配平台', '不改变音频文件或播放音源', preferences.localPlatform, [
          '网易云',
          'QQ 音乐',
          '酷狗',
          '酷我',
          '咪咕',
        ]),
      ]),
      _group('播放', '音质需要平台和音源共同支持；不自动切换音质', [
        _choice(
          context,
          '播放音质',
          '用于下一次获取播放地址',
          preferences.playQuality,
          qualities,
          value: preferences.playQuality.split(' · ').last,
        ),
        _choice(context, '播放模式', '控制队列结束和下一首的行为', preferences.repeat, [
          '顺序播放',
          '单曲循环',
          '列表循环',
          '随机播放',
          '单曲播放',
        ], enabled: true),
        MusicSettingsSlider(
          title: '音量',
          value: preferences.volume,
          min: 0,
          max: 100,
          unit: '%',
        ),
        _choice(
          context,
          '播放速度',
          '仅调整当前正在播放的音乐',
          '${snapshot.speed}×',
          [
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]) '$speed×',
          ],
          value: snapshot.playingAudio ? '${snapshot.speed}×' : '未在播放音乐',
          enabled:
              snapshot.playingAudio && snapshot.hasMedia && !snapshot.resolving,
        ),
      ]),
      SettingsGroup(
        title: '歌曲详情与歌词',
        description: '左右滑动切换封面和歌词；点击带时间的歌词可跳转播放',
        children: [
          SettingsRow(
            title: '封面旋转',
            description: '播放时旋转专辑封面',
            checked: preferences.spin,
            enabled: snapshot.canEdit,
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '显示歌词翻译',
            description: '歌曲提供翻译时显示在原文下方',
            checked: preferences.translation,
            enabled: snapshot.canEdit,
          ),
          const SettingsDivider(),
          _choice(
            context,
            '歌词对齐方式',
            '歌曲页与播放器设置使用同一偏好',
            preferences.lyricAlign,
            ['居左', '居中', '居右'],
          ),
          SettingsRow(
            title: '允许通过拖拽歌词调整播放进度',
            description: '拖动后使用定位线按钮跳转',
            checked: preferences.seek,
            enabled: snapshot.canEdit,
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '保持屏幕常亮',
            description: '仅在前台查看歌词时生效',
            checked: preferences.keepAwake,
            enabled: snapshot.canEdit,
          ),
          const SettingsDivider(),
          MusicSettingsSlider(
            title: '歌词字号',
            value: preferences.lyricSize,
            enabled: snapshot.editable,
            min: 10,
            max: 36,
            unit: ' sp',
          ),
          const SettingsDivider(),
          MusicSettingsSlider(
            title: '歌词时间偏移',
            value: preferences.lyricOffset,
            enabled: snapshot.editable,
            min: -10,
            max: 10,
            unit: ' 秒',
            decimals: 1,
          ),
        ],
      ),
      MusicDesktopLyricSettings(
        style: snapshot.desktopLyrics,
        editable: snapshot.canEdit,
        onRoute: track,
      ),
      _group('歌曲列表', '调整歌曲点击行为和列表中显示的信息', [
        SettingsRow(
          title: '点击歌曲播放整个列表',
          description: '关闭后只播放选中的歌曲；队列最多 2000 首',
          checked: preferences.clickPlayList,
          enabled: snapshot.canEdit,
        ),
        SettingsRow(
          title: '显示歌曲封面',
          description: '在列表左侧显示专辑图片',
          checked: preferences.listCover,
          enabled: snapshot.canEdit,
        ),
        SettingsRow(
          title: '显示歌曲来源',
          description: '显示歌曲所属平台',
          checked: preferences.listSource,
          enabled: snapshot.canEdit,
        ),
        SettingsRow(
          title: '显示专辑名称',
          description: '在歌手旁显示专辑',
          checked: preferences.listAlbum,
          enabled: snapshot.canEdit,
        ),
        SettingsRow(
          title: '显示歌曲时长',
          description: '歌曲提供时长时显示',
          checked: preferences.listDuration,
          enabled: snapshot.canEdit,
        ),
      ]),
      _group('搜索与历史', '记录仅保存在本机；清除记录不删除文件或收藏', [
        SettingsRow(
          title: '显示搜索历史',
          description: '开启后保存最近的搜索词',
          checked: preferences.searchHistory,
          enabled: snapshot.canEdit,
        ),
        SettingsRow(
          title: '清空搜索历史',
          description: '移除 ${snapshot.searchCount} 条搜索记录',
          enabled: snapshot.editable && snapshot.searchCount > 0,
          onTap: () => clearHistory('清空搜索历史'),
        ),
        SettingsRow(
          title: '清空播放历史',
          description: '移除 ${snapshot.historyCount} 条播放记录',
          enabled: snapshot.editable && snapshot.historyCount > 0,
          onTap: () => clearHistory('清空播放历史'),
        ),
      ]),
      MusicBackupSettings(snapshot: snapshot, session: backupSession),
    ],
  );
}
