import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                  color: PrimaryColors.secondary.withValues(alpha: .48),
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
        color: IconTone.appearance.icon,
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
                const Divider(
                  height: .6,
                  thickness: .6,
                  color: PrimaryColors.divider,
                ),
              _SettingsRow(groups[index][row]),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.entry);
  final (String, IconData, IconTone) entry;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: emptyAction,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Row(
        children: [
          ToneBadge(
            entry.$2,
            entry.$3,
            glyph: entry.$1 == 'AI 助手'
                ? CustomPaint(
                    size: const Size.square(17),
                    painter: _AiSparkle(entry.$3.icon),
                  )
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
          const Icon(
            Icons.keyboard_arrow_right,
            size: 18,
            color: PrimaryColors.muted,
          ),
        ],
      ),
    ),
  );
}

/// 原 KiyoriActionIcons.aiAssistant 的 24 单位路径。
class _AiSparkle extends CustomPainter {
  const _AiSparkle(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 2)
        ..cubicTo(13.3, 8.7, 15.3, 10.7, 22, 12)
        ..cubicTo(15.3, 13.3, 13.3, 15.3, 12, 22)
        ..cubicTo(10.7, 15.3, 8.7, 13.3, 2, 12)
        ..cubicTo(8.7, 10.7, 10.7, 8.7, 12, 2)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_AiSparkle oldDelegate) => color != oldDelegate.color;
}
