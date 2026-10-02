import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// KiyoriDownloadSettingsPage + BrowserDownloadSettings default projection.
/// Selection opens the original menu; no transfer, SAF grant or persistence runs.
class DownloadSettingsPage extends StatelessWidget {
  const DownloadSettingsPage({super.key});

  static const _groups = [
    (
      '下载器与性能',
      '选择任务执行方式，并控制内置下载器的并发和线程预算',
      [
        ('默认下载器', '选择 Kiyori 内置下载器或 Android 系统下载器', 'Kiyori 内置下载器', null),
        ('默认保存位置', '选择应用目录、公开下载目录或 SAF 自定义目录', '应用下载目录', null),
        ('并行下载任务', '同时运行的内置下载任务数，受每任务线程预算限制', '3', null),
        ('普通文件线程数', '支持 Range 的普通文件每个任务最多使用的分段线程', '6', null),
        ('M3U8 线程数', 'M3U8 离线包每个任务最多并行下载的媒体分片数', '16', null),
      ],
    ),
    (
      '网络与后台',
      'Android 14 及以上使用用户发起数据传输任务，旧版本使用前台服务；网络条件同时应用于内置和系统下载器',
      [
        ('网络条件', '允许任意网络，或只在系统判定为非计费网络时下载', '任意网络', null),
        ('允许漫游下载', '关闭后，内置和系统下载器都不会在漫游网络开始新任务', null, false),
        ('完成与失败通知', '内置任务结束时发送系统通知；受系统通知权限和渠道设置控制', null, true),
        ('系统通知设置', '管理文件下载器进行中通知与下载结果通知渠道', '系统设置', null),
      ],
    ),
    (
      'M3U8 与存储',
      '控制流媒体离线包和普通文件的单次读写分块',
      [
        ('M3U8 离线包', '下载媒体分片并生成本地可播放列表；关闭时只保存远程播放列表', null, true),
        ('下载分块大小', '控制普通文件分段读写和网络缓冲的单次块大小', '2MB', null),
      ],
    ),
    (
      '安装与确认',
      '管理安装包生命周期和网页下载请求的确认方式',
      [
        ('安装包自动清理', '安装内置下载的 APK 后自动清理对应任务文件', null, false),
        ('跳过下载确认', '识别到下载请求后直接交给当前默认下载器', null, false),
      ],
    ),
    (
      '网络协议',
      '选择新建内置下载任务使用的 HTTP 连接协议',
      [('HTTP 协议', '优先使用 HTTP/2，或固定使用 HTTP/1.1', '优先 HTTP/2', null)],
    ),
  ];

  List<SettingsOption> _options(String title) => switch (title) {
    '默认下载器' => const [
      SettingsOption(
        'Kiyori 内置下载器',
        description: '支持并行分段、M3U8 离线包、SAF 目录和任务管理',
        selected: true,
      ),
      SettingsOption(
        'Android 系统下载器',
        description: '交给 Android DownloadManager，高级下载设置不参与',
      ),
    ],
    '默认保存位置' => const [
      SettingsOption(
        '应用下载目录',
        description: '保存到 Kiyori 应用专属目录，由下载抽屉统一管理',
        selected: true,
      ),
      SettingsOption(
        '公开下载目录',
        description:
            '普通文件完成后转存到 Download/Kiyori/browser/downloads；M3U8 离线包保留在应用目录',
      ),
      SettingsOption('SAF 自定义目录', description: '通过 Android 系统目录选择器授权一个长期保存位置'),
    ],
    '并行下载任务' => [
      for (var count = 1; count <= 8; count++)
        SettingsOption(
          '$count',
          description: '最多同时运行 $count 个内置下载任务',
          selected: count == 3,
        ),
    ],
    '普通文件线程数' => [
      for (final count in [3, 6, 12, 20, 32])
        SettingsOption(
          '$count',
          description: '每个普通文件最多使用 $count 个分段请求',
          selected: count == 6,
        ),
    ],
    'M3U8 线程数' => [
      for (final count in [3, 8, 16, 20, 32, 48, 64])
        SettingsOption(
          '$count',
          description: '每个 M3U8 离线包最多并行下载 $count 个媒体分片',
          selected: count == 16,
        ),
    ],
    '网络条件' => const [
      SettingsOption(
        '任意网络',
        description: 'Wi-Fi、以太网和移动数据均可开始下载',
        selected: true,
      ),
      SettingsOption('仅非计费网络', description: '只在 Android 判定为非计费网络时开始或继续下载'),
    ],
    '下载分块大小' => [
      for (final label in [
        '12MB',
        '8MB',
        '4MB',
        '2MB',
        '1MB',
        '512KB',
        '256KB',
      ])
        SettingsOption(
          label,
          description: '用于普通文件分段读写和网络传输缓冲',
          selected: label == '2MB',
        ),
    ],
    'HTTP 协议' => const [
      SettingsOption(
        '优先 HTTP/2',
        description: '支持的 HTTPS 服务器使用 HTTP/2，其余连接使用 HTTP/1.1',
        selected: true,
      ),
      SettingsOption('仅 HTTP/1.1', description: '所有新建内置下载连接固定使用 HTTP/1.1'),
    ],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '文件下载器',
    children: [
      for (final group in _groups)
        SettingsGroup(
          title: group.$1,
          description: group.$2,
          children: [
            for (var index = 0; index < group.$3.length; index++) ...[
              if (index > 0) const SettingsDivider(),
              SettingsRow(
                title: group.$3[index].$1,
                description: group.$3[index].$2,
                value: group.$3[index].$3,
                checked: group.$3[index].$4,
                onTap: () async {
                  final row = group.$3[index];
                  final options = _options(row.$1);
                  if (options.isNotEmpty) {
                    await showSettingsSelection(
                      context,
                      title: row.$1,
                      current: row.$3!,
                      options: options,
                    );
                  }
                },
              ),
            ],
          ],
        ),
    ],
  );
}
