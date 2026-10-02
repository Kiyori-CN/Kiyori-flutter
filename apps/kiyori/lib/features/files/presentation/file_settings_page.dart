import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'file_open_defaults_dialog.dart';

/// KiyoriFileManagerSettingsPage / FileManagerSettings presentation defaults.
/// Startup paths are draft settings; this surface never probes those locations.
class FileSettingsPage extends StatelessWidget {
  const FileSettingsPage({super.key});

  static const _groups = [
    (
      '默认工作区',
      '两个入口始终保留，不能删除；修改路径不移动文件，也不改变 AI 对话绑定或工具产物设置。',
      [
        (
          'Android工作区',
          '/storage/emulated/0/Download/Kiyori/workspace',
          '编辑',
          null,
        ),
        ('Linux工作区', '/workspace', '编辑', null),
      ],
    ),
    (
      '文件打开',
      '音频与视频分别使用音乐和视频播放器。',
      [('按格式设置默认打开方式', '可自定义、每次询问或恢复推荐方式', '0 项', null)],
    ),
    (
      '启动位置',
      '用于下次新建文件会话；从设置返回时继续浏览原位置。',
      [
        ('左列启动目录', '默认打开手机内部存储', '编辑', null),
        ('右列启动目录', '默认打开手机内部存储', '编辑', null),
      ],
    ),
    (
      '列表显示',
      '显示偏好立即应用到左右两列。',
      [
        ('显示密度', '同时调整文字、图标与行高', '标准', null),
        ('文件名行数', '超过上限的名称省略显示', '最多 4 行', null),
        ('时间显示到秒', '关闭后显示到分钟，始终保留完整年月日', null, true),
        ('统计文件夹大小', '关闭可减少目录扫描；大型目录统计需要更多时间', null, true),
      ],
    ),
    (
      '隐藏项目',
      '只改变 Kiyori 中的可见性，不修改文件，也不提供加密保护。',
      [
        ('显示系统隐藏项', '名称以点开头的文件和文件夹', null, true),
        ('显示手动隐藏项', '临时查看隐藏清单中的项目，清单仍保留', null, false),
        ('手动隐藏清单', '按路径或存储环境查找，取消单项或全部隐藏', '0 项', null),
      ],
    ),
    (
      '排序与刷新',
      '初始排序用于新会话；当前列仍可从文件管理工具栏单独排序。',
      [
        ('初始排序依据', '文件夹始终优先排列', '名称', null),
        ('初始排序方向', '对文件夹和文件分别排序', '升序', null),
        ('自动刷新间隔', '仅在文件管理器前台检查；网络存储至少间隔 30 秒', '3 秒', null),
      ],
    ),
    (
      '侧栏与书签',
      '长按侧栏入口可管理；根目录与内部存储固定保留。',
      [
        ('显示书签分类', '关闭不会删除书签或使桌面快捷方式失效', null, true),
        ('显示工作区分类', '只控制侧栏，不改变 AI 对话绑定的工作区', null, true),
        ('新书签放在顶部', '只影响以后添加的书签', null, false),
        ('隐藏的本地入口', '逐项恢复到侧栏，保留名称与授权', '0 项', null),
        ('恢复默认侧栏布局', '恢复分类、内置入口与顺序，保留自建入口', null, null),
      ],
    ),
    (
      '存储与回收',
      '文件访问遵循系统授权；删除与永久删除分别确认。',
      [
        ('管理访问权限', '查看存储、Shizuku 与 Root 的授权状态', null, null),
        ('回收与恢复说明', '了解回收位置、同名冲突与永久删除', null, null),
      ],
    ),
    (
      '记录与重置',
      '历史仅保存在本机；清理不会删除实际文件或停止任务。',
      [
        ('清空搜索记录', '删除已保存的搜索条件与结果', '0 条', null),
        ('清空已结束的任务记录', '保留实际文件，不影响后续任务', '0 条', null),
        ('恢复浏览默认设置', '重置启动、显示、排序与刷新；保留侧栏、清单和历史', null, null),
      ],
    ),
  ];

  List<SettingsOption> _options(String title) => switch (title) {
    '显示密度' => const [
      SettingsOption('紧凑', description: '文字、图标与行高缩放为 80%'),
      SettingsOption('标准', description: '文字、图标与行高缩放为 100%', selected: true),
      SettingsOption('宽松', description: '文字、图标与行高缩放为 120%'),
    ],
    '文件名行数' => [
      for (var count = 1; count <= 6; count++)
        SettingsOption(
          '最多 $count 行',
          description: count == 1 ? '列表更紧凑，长名称省略显示' : '显示更多名称内容，行高随内容增长',
          selected: count == 4,
        ),
    ],
    '初始排序依据' => [
      for (final label in ['名称', '大小', '修改时间', '文件格式'])
        SettingsOption(
          label,
          description: '文件夹优先；下次新建文件会话生效',
          selected: label == '名称',
        ),
    ],
    '初始排序方向' => const [
      SettingsOption('升序', description: '下次新建文件会话生效', selected: true),
      SettingsOption('降序', description: '下次新建文件会话生效'),
    ],
    '自动刷新间隔' => [
      for (final count in [0, 3, 10, 30])
        SettingsOption(
          count == 0 ? '关闭' : '$count 秒',
          description: count == 0 ? '仍可从工具栏或下拉手动刷新' : '仅前台检查；网络存储至少间隔 30 秒',
          selected: count == 3,
        ),
    ],
    _ => const [],
  };

  Future<void> _open(BuildContext context, String title, String? value) async {
    final options = _options(title);
    if (options.isNotEmpty) {
      await showSettingsSelection(
        context,
        title: title,
        current: value!,
        options: options,
      );
    } else if (title == '按格式设置默认打开方式') {
      await showFileOpenDefaults(context);
    } else if (['Android工作区', 'Linux工作区', '左列启动目录', '右列启动目录'].contains(title)) {
      await showDialog<void>(
        context: context,
        builder: (_) => _PathDialog(title: title),
      );
    } else if (title == '手动隐藏清单' || title == '隐藏的本地入口') {
      await showDialog<void>(
        context: context,
        builder: (_) => _HiddenDialog(title: title),
      );
    } else if (title == '回收与恢复说明') {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地删除会先移到源存储卷的回收目录，保留原始位置；回收失败会显示原因，不会静默改为永久删除。'),
                SizedBox(height: 10),
                Text('恢复时若原位置已有同名文件会停止操作，不覆盖现有文件。永久删除需再次确认，且无法恢复。'),
                SizedBox(height: 10),
                Text('网络和授权目录的能力由存储后端决定，未支持的操作会明确提示。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } else if (title == '恢复默认侧栏布局' || title == '恢复浏览默认设置') {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(
            title == '恢复默认侧栏布局'
                ? '将恢复分类、内置入口和顺序，保留自建入口、别名、授权和书签。'
                : '将恢复启动位置、显示、排序和刷新偏好；侧栏、隐藏清单与历史记录会保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const TextButton(onPressed: emptyAction, child: Text('确认')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '文件管理器',
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
                enabled: !group.$3[index].$1.startsWith('清空'),
                onTap: () =>
                    _open(context, group.$3[index].$1, group.$3[index].$3),
              ),
            ],
          ],
        ),
    ],
  );
}

class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.title});
  final String title;
  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  late final input = TextEditingController(
    text: widget.title == 'Linux工作区' ? '/workspace' : '',
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title.endsWith('工作区')
                ? '留空恢复默认工作区路径；保存后入口立即更新，不会迁移文件，也不改变已打开的位置。'
                : '留空使用手机内部存储。只在下次新建文件会话时生效，不会移动文件。',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: input,
            minLines: 1,
            maxLines: null,
            decoration: settingsFieldDecoration(
              label: '绝对目录路径',
              hint: widget.title == 'Linux工作区'
                  ? '/workspace'
                  : '/storage/emulated/0/Download',
              helper: '不使用 .、.. 或控制字符',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      const TextButton(onPressed: emptyAction, child: Text('保存')),
    ],
  );
}

class _HiddenDialog extends StatelessWidget {
  const _HiddenDialog({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('0 项 · 只改变侧栏或列表显示，不修改文件', style: TextStyle(fontSize: 12)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              decoration: settingsFieldDecoration(label: '筛选路径或名称'),
            ),
          ),
          const Text('暂无记录', style: TextStyle(color: PrimaryColors.secondary)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('完成'),
      ),
    ],
  );
}
