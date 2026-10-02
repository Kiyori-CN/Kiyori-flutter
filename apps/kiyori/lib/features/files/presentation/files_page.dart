import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

typedef _Entry = (String, IconData, IconTone, String);

class FilesPage extends StatelessWidget {
  const FilesPage({this.onSettings = emptyAction, super.key});
  final VoidCallback onSettings;
  // 未接入扫描，使用旧页面未统计状态，不伪造文件数量或设备容量。
  static const types = <_Entry>[
    ('图片', Icons.image, IconTone.image, '待统计'),
    ('视频', Icons.play_circle, IconTone.video, '待统计'),
    ('音频', Icons.music_note, IconTone.audio, '待统计'),
    ('文档', Icons.description, IconTone.document, '待统计'),
    ('安装包', Icons.android, IconTone.success, '待统计'),
    ('压缩包', Icons.folder_zip_rounded, IconTone.backup, '待统计'),
  ];
  static const quick = <_Entry>[
    ('下载', Icons.download_outlined, IconTone.download, '待统计'),
    ('相机', Icons.photo_camera_outlined, IconTone.image, '待统计'),
    ('截屏', Icons.screenshot_outlined, IconTone.image, '待统计'),
    ('文档目录', Icons.description_outlined, IconTone.document, '待统计'),
  ];
  static const locations = <_Entry>[
    ('内部存储', Icons.smartphone, IconTone.network, '容量暂不可用'),
    ('Linux', Icons.terminal_rounded, IconTone.terminal, ''),
    ('Android 工作区', Icons.workspaces_rounded, IconTone.folder, ''),
    ('Linux 工作区', Icons.workspaces_rounded, IconTone.folder, ''),
    ('回收站', Icons.restore_from_trash_rounded, IconTone.recycle, '统计暂不可用'),
  ];

  @override
  Widget build(BuildContext context) => PrimaryPage(
    title: '文件管理',
    actions: [
      SizedBox(
        width: 96,
        child: PrimaryHeaderActions(
          searchLabel: '搜索文件',
          settingsLabel: '文件管理器设置',
          onSettings: onSettings,
        ),
      ),
    ],
    child: ListView(
      key: const PageStorageKey('files-list'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: const [
        _FileSection('文件类型', types),
        SizedBox(height: 10),
        _FileSection('快捷访问', quick),
        SizedBox(height: 10),
        _FileSection('存储位置', locations, list: true),
      ],
    ),
  );
}

class _FileSection extends StatelessWidget {
  const _FileSection(this.title, this.entries, {this.list = false});
  final String title;
  final List<_Entry> entries;
  final bool list;
  @override
  Widget build(BuildContext context) => PrimaryCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          PrimarySectionTitle(
            title,
            trailing: Semantics(
              button: true,
              label: '管理$title',
              child: InkWell(
                onTap: emptyAction,
                child: Padding(
                  padding: EdgeInsets.only(left: 12, top: 12, bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        '全部',
                        style: TextStyle(
                          fontSize: 12,
                          color: PrimaryColors.of(context).accent,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        size: 18,
                        color: PrimaryColors.of(context).accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (list) ...[
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _LocationRow(entries[i]),
            ],
          ] else ...[
            for (var start = 0; start < entries.length; start += 4) ...[
              if (start > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < 4; column++) ...[
                    if (column > 0) const SizedBox(width: 6),
                    Expanded(
                      child: start + column < entries.length
                          ? _GridEntry(entries[start + column])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _GridEntry extends StatelessWidget {
  const _GridEntry(this.entry);
  final _Entry entry;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: emptyAction,
    borderRadius: BorderRadius.circular(16),
    child: Column(
      children: [
        ToneBadge(entry.$2, entry.$3, size: 36, iconSize: 16),
        const SizedBox(height: 5),
        Text(
          entry.$1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          entry.$4,
          style: TextStyle(
            fontSize: 11,
            height: 16 / 11,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow(this.entry);
  final _Entry entry;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: emptyAction,
    borderRadius: BorderRadius.circular(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            ToneBadge(entry.$2, entry.$3, size: 32, iconSize: 20),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Text(
                  entry.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (entry.$4.isNotEmpty)
              Expanded(
                flex: 18,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    entry.$4,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: PrimaryColors.of(context).secondary,
                    ),
                  ),
                ),
              ),
            Icon(
              Icons.keyboard_arrow_right,
              size: 18,
              color: PrimaryColors.of(context).secondary,
            ),
          ],
        ),
      ),
    ),
  );
}
