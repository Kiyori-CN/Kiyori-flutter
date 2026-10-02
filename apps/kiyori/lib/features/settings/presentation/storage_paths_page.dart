import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 只描述旧 Android 默认画面，不能用这些字符串访问宿主文件系统。
abstract final class StoragePathPresentation {
  static const android =
      '/storage/emulated/0/Download/Kiyori-Android/workspace';
  static const linux = '/workspace';
  static const exports = '/storage/emulated/0/Download/Kiyori-Android/exports';
}

enum StorageSettingsSection { files, downloads, player, backup, artifacts }

class StoragePathsPage extends StatelessWidget {
  const StoragePathsPage({required this.onOpen, super.key});
  final ValueChanged<StorageSettingsSection> onOpen;

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '存储与路径',
    children: [
      SettingsGroup(
        title: '工作区',
        description: '用于文件管理入口；不会自动更改已有 AI 对话的工作区绑定。',
        children: [
          _PathRow(
            'Android工作区',
            StoragePathPresentation.android,
            () => onOpen(StorageSettingsSection.files),
          ),
          const SettingsDivider(),
          _PathRow(
            'Linux工作区',
            StoragePathPresentation.linux,
            () => onOpen(StorageSettingsSection.files),
          ),
        ],
      ),
      SettingsGroup(
        title: '下载与媒体',
        description: '系统下载、内置下载与播放器各有明确目标；配置只影响新任务。',
        children: [
          _PathRow(
            '文件下载位置',
            '查看当前引擎、应用目录、公开目录或已授权的自定义目录',
            () => onOpen(StorageSettingsSection.downloads),
          ),
          const SettingsDivider(),
          _PathRow(
            '播放器截图与视频',
            '跟随下载设置，或使用播放器独立授权目录',
            () => onOpen(StorageSettingsSection.player),
          ),
        ],
      ),
      SettingsGroup(
        title: '主动导出',
        description: '浏览器、配置、备份、审计与工作区打包使用此根目录，并保留分类子目录。图片保存仍使用图片集合或播放器设置。',
        children: [
          _PathRow(
            '导出根目录',
            StoragePathPresentation.exports,
            () => showDialog<void>(
              context: context,
              builder: (_) => const _ExportPathDialog(),
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: '日志与自动备份',
        description: '默认关闭，按需开启。关闭仅停止后续自动保存，已有文件保留；应用内部运行日志和对话详情不受影响。',
        children: [
          const SettingsRow(
            title: '自动保存扩展诊断日志',
            description: '排查扩展加载与运行问题时开启。最多保留 5 份，每份不超过 2 MiB。',
            checked: false,
          ),
          const _PathNote(
            '日志保存位置：/storage/emulated/0/Download/Kiyori-Android/logs/packages',
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '每日自动备份数据库',
            description: '保存聊天等数据库内容用于恢复；关闭后仍可手动备份。',
            checked: false,
          ),
          const _PathNote(
            '数据库备份位置：/storage/emulated/0/Download/Kiyori-Android/backup/room_db',
          ),
          const SettingsDivider(),
          _PathRow(
            '管理数据库备份',
            '立即备份、恢复文件与保留份数；使用现有数据备份页面。',
            () => onOpen(StorageSettingsSection.backup),
          ),
          const _PathNote(
            '这些公共目录中的文件可能含对话或扩展运行内容，分享前请检查。位置固定，不随主动导出根目录改变。',
            padding: EdgeInsets.all(18),
          ),
        ],
      ),
      SettingsGroup(
        title: 'AI 与工具生成文件',
        description: '显式输出目标和调用所属对话的工作区优先；默认值不重定向读写、删除或第三方远端文件。',
        children: [
          _PathRow(
            'Android 默认产物目录',
            StoragePathPresentation.android,
            () => onOpen(StorageSettingsSection.artifacts),
          ),
          const SettingsDivider(),
          _PathRow(
            'Linux 默认产物目录',
            StoragePathPresentation.linux,
            () => onOpen(StorageSettingsSection.artifacts),
          ),
        ],
      ),
      const SettingsGroup(
        title: '生效规则',
        description: '修改路径不会移动、合并或删除已有文件，也不会自动取得存储授权。',
        children: [
          _PathNote(
            '运行环境、依赖缓存、模型、ToolPkg 私有数据与应用备份内部暂存由各模块管理；这些目录不属于可交付文件，不随输出路径变更。',
            padding: EdgeInsets.all(16),
          ),
        ],
      ),
    ],
  );
}

class _PathRow extends StatelessWidget {
  const _PathRow(this.title, this.description, this.onTap);
  final String title, description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: PrimaryColors.secondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PathNote extends StatelessWidget {
  const _PathNote(
    this.text, {
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  });
  final String text;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}

class _ExportPathDialog extends StatefulWidget {
  const _ExportPathDialog();
  @override
  State<_ExportPathDialog> createState() => _ExportPathDialogState();
}

class _ExportPathDialogState extends State<_ExportPathDialog> {
  final controller = TextEditingController(
    text: StoragePathPresentation.exports,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('导出根目录'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '绝对路径',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '使用公共 Download 下的专用目录，以保持 Android MediaStore 导出兼容。只影响之后的导出。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => controller.text = StoragePathPresentation.exports,
            child: const Text('填入默认路径'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(onPressed: emptyAction, child: const Text('保存')),
    ],
  );
}
