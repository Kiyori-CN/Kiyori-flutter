import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_desktop_lyric_settings.dart';
import 'music_settings_slider.dart';

/// MusicSettingsBody 的空资料默认展示；不创建 MusicWorkspace、音源或播放会话。
class MusicSettingsPage extends StatelessWidget {
  const MusicSettingsPage({super.key});
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
  }) => SettingsRow(
    title: title,
    description: description,
    value: value ?? current,
    onTap: () async {
      await showSettingsSelection(
        context,
        title: sheetTitle ?? title,
        current: current,
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
      _group('音源管理', '可保存多个 LX 音源；首次导入自动启用，播放时使用当前音源', [
        const SettingsRow(
          title: '当前音源',
          description: '切换后用于下一次播放或下载地址解析',
          value: '未启用',
          enabled: false,
        ),
        SettingsRow(
          title: '在线导入',
          description: '保存 HTTPS 链接，之后可在音源详情中更新',
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const _SourceLinkDialog(),
          ),
        ),
        const SettingsRow(title: '本地导入', description: '可多选 LX 脚本，单个最大 256 KiB'),
      ]),
      Column(
        spacing: 16,
        children: [
          _group('下载与文件', '设置用于新任务；正在下载的歌曲保留原目录和选项', [
            SettingsRow(
              title: '下载路径',
              description: '沿用应用下载设置',
              value: '跟随应用',
              onTap: () async {
                await showSettingsSelection(
                  context,
                  title: '音乐下载路径',
                  current: '跟随应用',
                  options: const [
                    SettingsOption('选择文件夹'),
                    SettingsOption('跟随应用下载设置', selected: true),
                  ],
                );
              },
            ),
            _choice(
              context,
              '下载音质',
              '平台与当前音源需支持所选音质',
              '高品质 · 320k',
              qualities,
              value: '320k',
            ),
            _choice(context, '文件命名', '同名文件自动编号，保留原有文件', '歌名 - 歌手', [
              '歌名 - 歌手',
              '歌手 - 歌名',
              '歌名',
            ]),
          ]),
          _group('下载附加选项', '标签写入不重新编码音频；处理结果可在下载任务中查看', const [
            SettingsRow(
              title: '写入标签',
              description: '保存歌曲名、歌手和专辑',
              checked: true,
            ),
            SettingsRow(
              title: '写入别名',
              description: '将平台提供的歌曲别名附加到标题标签',
              checked: false,
            ),
            SettingsRow(
              title: '下载歌词文件',
              description: '在音频旁保存同名 LRC 文件',
              checked: false,
            ),
            SettingsRow(
              title: '写入罗马音歌词',
              description: '平台提供时合并到 LRC 和内嵌歌词',
              checked: false,
            ),
            SettingsRow(
              title: '写入内嵌歌词',
              description: '将歌词保存在音频文件内',
              checked: true,
            ),
            SettingsRow(
              title: '写入封面',
              description: '将专辑封面嵌入音频文件；WAV 不支持',
              checked: true,
            ),
          ]),
        ],
      ),
      _group('本地音乐资料', '播放本地文件，在线资料只补全缺失的封面与歌词。', [
        const SettingsRow(
          title: '自动匹配在线歌曲',
          description: '按歌名、歌手和时长核对；有歧义时手动选择',
          checked: true,
        ),
        _choice(context, '资料匹配平台', '不改变音频文件或播放音源', '网易云', [
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
          '高品质 · 320k',
          qualities,
          value: '320k',
        ),
        _choice(context, '播放模式', '控制队列结束和下一首的行为', '顺序播放', [
          '顺序播放',
          '单曲循环',
          '列表循环',
          '随机播放',
          '单曲播放',
        ]),
        const MusicSettingsSlider(
          title: '音量',
          value: 100,
          min: 0,
          max: 100,
          unit: '%',
        ),
        const SettingsRow(
          title: '播放速度',
          description: '仅调整当前正在播放的音乐',
          value: '未在播放音乐',
          enabled: false,
        ),
      ]),
      SettingsGroup(
        title: '歌曲详情与歌词',
        description: '左右滑动切换封面和歌词；点击带时间的歌词可跳转播放',
        children: [
          const SettingsRow(
            title: '封面旋转',
            description: '播放时旋转专辑封面',
            checked: true,
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '显示歌词翻译',
            description: '歌曲提供翻译时显示在原文下方',
            checked: true,
          ),
          const SettingsDivider(),
          _choice(context, '歌词对齐方式', '歌曲页与播放器设置使用同一偏好', '居中', [
            '居左',
            '居中',
            '居右',
          ]),
          const SettingsRow(
            title: '允许通过拖拽歌词调整播放进度',
            description: '拖动后使用定位线按钮跳转',
            checked: true,
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '保持屏幕常亮',
            description: '仅在前台查看歌词时生效',
            checked: true,
          ),
          const SettingsDivider(),
          const MusicSettingsSlider(
            title: '歌词字号',
            value: 18,
            min: 10,
            max: 36,
            unit: ' sp',
          ),
          const SettingsDivider(),
          const MusicSettingsSlider(
            title: '歌词时间偏移',
            value: 0,
            min: -10,
            max: 10,
            unit: ' 秒',
            decimals: 1,
          ),
        ],
      ),
      const MusicDesktopLyricSettings(),
      _group('歌曲列表', '调整歌曲点击行为和列表中显示的信息', const [
        SettingsRow(
          title: '点击歌曲播放整个列表',
          description: '关闭后只播放选中的歌曲；队列最多 2000 首',
          checked: false,
        ),
        SettingsRow(title: '显示歌曲封面', description: '在列表左侧显示专辑图片', checked: true),
        SettingsRow(title: '显示歌曲来源', description: '显示歌曲所属平台', checked: true),
        SettingsRow(title: '显示专辑名称', description: '在歌手旁显示专辑', checked: true),
        SettingsRow(title: '显示歌曲时长', description: '歌曲提供时长时显示', checked: true),
      ]),
      _group('搜索与历史', '记录仅保存在本机；清除记录不删除文件或收藏', const [
        SettingsRow(title: '显示搜索历史', description: '开启后保存最近的搜索词', checked: true),
        SettingsRow(title: '清空搜索历史', description: '移除 0 条搜索记录', enabled: false),
        SettingsRow(title: '清空播放历史', description: '移除 0 条播放记录', enabled: false),
      ]),
      _group('列表备份', '通过系统文件选择器迁移 LX 在线收藏和自建列表', [
        const SettingsRow(
          title: '导入 LX 列表',
          description: '支持 JSON 与 gzip .lxmc，最大 12 MiB；先预览再确认',
        ),
        SettingsRow(
          title: '导出 LX 列表',
          description: '导出在线收藏和列表为兼容 JSON，不含账号、脚本或设置',
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('导出 LX 在线列表'),
              content: const SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Text('导出收藏及 0 个自建列表，保留歌曲平台、身份、顺序和基本元数据。'),
                    Text(
                      '此为 LX 兼容列表子集，不含账户、脚本、设置、历史、下载记录、歌词附件、音质缓存或列表云关联。含本地文件或直链时整批拒绝，不静默漏掉歌曲。',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const TextButton(onPressed: emptyAction, child: Text('选择保存位置')),
              ],
            ),
          ),
        ),
      ]),
    ],
  );
}

class _SourceLinkDialog extends StatefulWidget {
  const _SourceLinkDialog();
  @override
  State<_SourceLinkDialog> createState() => _SourceLinkDialogState();
}

class _SourceLinkDialogState extends State<_SourceLinkDialog> {
  final controller = TextEditingController();
  bool visible = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('在线导入音源'),
    content: SizedBox(
      width: 312,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text('输入 HTTPS 脚本链接。链接与脚本加密保存在本机，更新失败会保留原版本。'),
            TextField(
              controller: controller,
              obscureText: !visible,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: '音源链接',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => visible = !visible),
                child: Text(visible ? '隐藏链接' : '显示链接'),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      ValueListenableBuilder(
        valueListenable: controller,
        builder: (_, value, _) => TextButton(
          onPressed: value.text.trim().isEmpty ? null : emptyAction,
          child: const Text('导入'),
        ),
      ),
    ],
  );
}
