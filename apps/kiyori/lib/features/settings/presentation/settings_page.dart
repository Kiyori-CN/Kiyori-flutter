import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    this.onOpenBrowser = emptyAction,
    this.onOpenDownloads = emptyAction,
    this.onOpenFiles = emptyAction,
    this.onOpenPlayer = emptyAction,
    this.onOpenToolbox = emptyAction,
    this.onOpenMusic = emptyAction,
    this.onOpenAdblock = emptyAction,
    this.onOpenMore = emptyAction,
    this.onOpenBackup = emptyAction,
    this.onOpenAppearance = emptyAction,
    this.onOpenAssistant = emptyAction,
    this.onOpenAccount = emptyAction,
    super.key,
  });
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenToolbox;
  final VoidCallback onOpenMusic;
  final VoidCallback onOpenAdblock;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenAccount;

  static const groups = [
    [
      ('我的账号', Icons.account_circle_outlined, IconTone.account),
      ('AI 助手', Icons.auto_awesome, IconTone.ai),
      ('工具箱', Icons.apps, IconTone.tools),
    ],
    [
      ('网页浏览器', Icons.language, IconTone.browser),
      ('文件下载器', Icons.download_outlined, IconTone.download),
      ('文件管理器', Icons.folder_outlined, IconTone.folder),
    ],
    [
      ('视频播放器', Icons.play_circle_outline, IconTone.video),
      ('音乐播放器', Icons.audiotrack_outlined, IconTone.audio),
      ('广告拦截器', Icons.shield_outlined, IconTone.security),
    ],
    [
      ('界面定制', Icons.palette_outlined, IconTone.appearance),
      ('数据备份', Icons.backup_outlined, IconTone.backup),
      ('更多功能', Icons.widgets_outlined, IconTone.network),
    ],
  ];

  @override
  Widget build(BuildContext context) => PrimaryPage(
    title: '设置',
    actionWidth: 160,
    actions: [
      for (final entry in [
        ('top_search', '搜索'),
        ('scan', '扫描'),
        ('top_refresh', '刷新'),
      ])
        Semantics(
          button: true,
          label: entry.$2,
          child: InkWell(
            onTap: emptyAction,
            child: SizedBox.square(
              dimension: 40,
              child: Center(
                child: Image.asset(
                  'assets/chrome/settings_header_${entry.$1}.png',
                  width: 22,
                  height: 22,
                  color: PrimaryColors.of(context).secondary
                      .withValues(alpha: .48),
                ),
              ),
            ),
          ),
        ),
      ShellAction(
        Icons.light_mode_outlined,
        '浅色主题',
        size: 40,
        iconSize: 22,
        color: IconTone.appearance.iconFor(context),
      ),
    ],
    child: ListView.separated(
      key: const PageStorageKey('settings-list'),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 112),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => PrimaryCard(
        child: Column(
          children: [
            for (var row = 0; row < groups[index].length; row++) ...[
              if (row > 0)
                Divider(
                  height: .6,
                  thickness: .6,
                  color: PrimaryColors.of(context).divider,
                ),
              _SettingsRow(
                groups[index][row],
                onTap: groups[index][row].$1 == '网页浏览器'
                    ? onOpenBrowser
                    : groups[index][row].$1 == '文件下载器'
                    ? onOpenDownloads
                    : groups[index][row].$1 == '文件管理器'
                    ? onOpenFiles
                    : groups[index][row].$1 == '视频播放器'
                    ? onOpenPlayer
                    : groups[index][row].$1 == '工具箱'
                    ? onOpenToolbox
                    : groups[index][row].$1 == '音乐播放器'
                    ? onOpenMusic
                    : groups[index][row].$1 == '广告拦截器'
                    ? onOpenAdblock
                    : groups[index][row].$1 == '更多功能'
                    ? onOpenMore
                    : groups[index][row].$1 == '数据备份'
                    ? onOpenBackup
                    : groups[index][row].$1 == '界面定制'
                    ? onOpenAppearance
                    : groups[index][row].$1 == 'AI 助手'
                    ? onOpenAssistant
                    : groups[index][row].$1 == '我的账号'
                    ? onOpenAccount
                    : emptyAction,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.entry, {this.onTap = emptyAction});
  final (String, IconData, IconTone) entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Row(
        children: [
          ToneBadge(
            entry.$2,
            entry.$3,
            glyph: entry.$1 == 'AI 助手'
                ? AiSparkleIcon(size: 17, color: entry.$3.iconFor(context))
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              entry.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_right,
            size: 18,
            color: PrimaryColors.of(context).muted,
          ),
        ],
      ),
    ),
  );
}
