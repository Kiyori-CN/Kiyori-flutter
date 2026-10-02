import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum BackupPromptKind {
  chatImport,
  memoryImport,
  databaseRestore,
  rawRestore,
  databaseRestart,
  rawRestart,
  modelExportWarning,
}

/// 已解析文件或已完成操作的展示请求。id标识一次会话，不能使用路径代替。
class BackupPrompt {
  const BackupPrompt({
    required this.id,
    required this.kind,
    this.fileName = '',
  });
  final String id, fileName;
  final BackupPromptKind kind;
}

class BackupFile {
  const BackupFile({
    required this.id,
    required this.fileName,
    required this.restoreLabel,
  });
  final String id, fileName, restoreLabel;
}

class BackupFileRow extends StatelessWidget {
  const BackupFileRow({required this.file, required this.onRestore, super.key});
  final BackupFile file;
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.storage),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '恢复到：${file.restoreLabel}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                file.fileName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          key: ValueKey('backup-restore-${file.id}'),
          onPressed: onRestore,
          tooltip: '恢复',
          icon: const Icon(Icons.restore),
        ),
      ],
    ),
  );
}

class BackupRestoreDialog extends StatelessWidget {
  const BackupRestoreDialog({required this.prompt, super.key});
  final BackupPrompt prompt;
  @override
  Widget build(BuildContext context) {
    if (prompt.kind == BackupPromptKind.modelExportWarning) {
      return _modelWarning(context);
    }
    final raw =
        prompt.kind == BackupPromptKind.rawRestore ||
        prompt.kind == BackupPromptKind.rawRestart;
    final restart =
        prompt.kind == BackupPromptKind.databaseRestart ||
        prompt.kind == BackupPromptKind.rawRestart;
    return AlertDialog(
      title: Text(
        restart
            ? '需要重启应用'
            : raw
            ? '确认恢复文件快照'
            : '确认恢复数据库',
      ),
      scrollable: true,
      content: Text(
        restart
            ? raw
                  ? '文件快照已恢复。为避免旧的缓存/连接导致异常，建议立即重启应用。'
                  : '数据库已恢复。为避免旧的数据库连接导致异常，建议立即重启应用。'
            : '将使用以下备份文件覆盖当前${raw ? '应用数据' : '数据库'}：\n${prompt.fileName}\n\n此操作不可撤销。建议先执行一次备份再恢复。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(restart ? '稍后' : '取消'),
        ),
        TextButton(
          onPressed: emptyAction,
          child: Text(restart ? '立即重启' : '确认恢复'),
        ),
      ],
    );
  }

  Widget _modelWarning(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.info, color: colors.error, size: 40),
      title: const Text(
        '⚠️ 安全提示',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '该配置文件包含以下敏感信息：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final text in [
              '🔑 API 密钥',
              '🌐 API 端点地址',
              '⚙️ 模型参数配置',
              '🔧 自定义参数设置',
            ])
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(text, style: const TextStyle(fontSize: 14)),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 安全建议：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 请勿将此文件分享给他人\n• 请勿上传到公共云存储\n• 建议将文件移动到安全位置\n• 建议使用加密工具保护文件',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '导出位置：',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                prompt.fileName,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
          ),
          child: const Text('我知道了'),
        ),
      ],
    );
  }
}
