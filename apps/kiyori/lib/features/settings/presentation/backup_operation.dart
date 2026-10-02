import 'package:flutter/material.dart';

enum BackupPhase {
  idle,
  exporting,
  importing,
  deleting,
  exported,
  imported,
  deleted,
  failed,
}

/// 领域提供操作结果；按钮不能自行推进阶段或填入成功文案。
class BackupOperation {
  const BackupOperation({
    this.phase = BackupPhase.idle,
    this.message = '',
    this.progress,
    this.processedCharacters = 0,
    this.totalCharacters = 0,
  });
  final BackupPhase phase;
  final String message;
  final double? progress;
  final int processedCharacters, totalCharacters;
}

class BackupOperationView extends StatelessWidget {
  const BackupOperationView(
    this.operation, {
    required this.subject,
    this.database = false,
    this.raw = false,
    this.restoring = false,
    super.key,
  });
  final BackupOperation operation;
  final String subject;
  final bool database, raw, restoring;

  @override
  Widget build(BuildContext context) {
    final phase = operation.phase;
    if (phase == BackupPhase.idle) return const SizedBox.shrink();
    final busy =
        phase == BackupPhase.exporting ||
        phase == BackupPhase.importing ||
        phase == BackupPhase.deleting;
    if (busy) {
      if (phase == BackupPhase.exporting && operation.progress != null) {
        final supplied = operation.progress!;
        final progress = supplied.isFinite ? supplied.clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                '正在导出：${(progress * 100).round()}%（${operation.processedCharacters} / ${operation.totalCharacters} 字符）',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      }
      final message = raw && operation.message.trim().isNotEmpty
          ? operation.message
          : switch (phase) {
              BackupPhase.deleting => '正在清除聊天记录...',
              BackupPhase.exporting =>
                database
                    ? '正在备份数据库...'
                    : raw
                    ? '正在生成文件快照备份...'
                    : '正在导出$subject...',
              _ =>
                database
                    ? '正在恢复数据库...'
                    : raw
                    ? '正在恢复文件快照备份...'
                    : '正在导入$subject...',
            };
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(message, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
    final error = phase == BackupPhase.failed;
    final colors = Theme.of(context).colorScheme;
    final color = error ? colors.error : colors.primary;
    final title = switch (phase) {
      BackupPhase.exported => '导出成功',
      BackupPhase.imported => database ? '恢复成功' : '导入成功',
      BackupPhase.deleted => '清除成功',
      _ => restoring ? '恢复失败' : '操作失败',
    };
    final icon = switch (phase) {
      BackupPhase.exported => Icons.cloud_download,
      BackupPhase.imported =>
        database || raw ? Icons.restore : Icons.cloud_upload,
      BackupPhase.deleted => Icons.delete_outline,
      _ => Icons.info,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (error ? colors.errorContainer : colors.primaryContainer)
            .withValues(alpha: .2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(operation.message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
