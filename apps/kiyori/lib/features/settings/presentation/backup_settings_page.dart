import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'backup_components.dart';
import 'backup_dialogs.dart';
import 'backup_operation.dart';
import 'backup_restore_dialogs.dart';

export 'backup_operation.dart';
export 'backup_restore_dialogs.dart'
    show BackupPrompt, BackupPromptKind, BackupFile;

/// 旧 ChatBackupSettingsScreen 的初始展示快照；统计不来自宿主文件扫描。
/// 后续由备份领域注入事实，UI 不创建数据库、目录或第二套配置存储。
class BackupPresentation {
  const BackupPresentation({
    this.chats = const [],
    this.profiles = const [],
    this.profileName = '默认配置',
    this.activeProfileId = 'default',
    this.characterCount = 0,
    this.memoryCount = 0,
    this.linkCount = 0,
    this.modelCount = 0,
    this.chatFiles = 0,
    this.characterFiles = 0,
    this.memoryFiles = 0,
    this.modelFiles = 0,
    this.databaseFiles = 0,
    this.dailyBackup,
    this.maxBackups = 10,
    this.auditSummary,
    this.largestAudit,
    this.chatOperation = const BackupOperation(),
    this.characterOperation = const BackupOperation(),
    this.memoryOperation = const BackupOperation(),
    this.modelOperation = const BackupOperation(),
    this.databaseBackup = const BackupOperation(),
    this.databaseRestore = const BackupOperation(),
    this.rawOperation = const BackupOperation(),
    this.scanning = false,
    this.savingDailyBackup = false,
    this.dailyBackupError,
    this.lastBackup = '-',
    this.lastError,
    this.recentBackups = const [],
    this.prompt,
  });
  final List<BackupChoice> chats, profiles;
  final String profileName, activeProfileId;
  final int characterCount, memoryCount, linkCount, modelCount;
  final int chatFiles, characterFiles, memoryFiles, modelFiles, databaseFiles;
  final bool? dailyBackup;
  final int maxBackups;
  final String? auditSummary, largestAudit;
  final BackupOperation chatOperation,
      characterOperation,
      memoryOperation,
      modelOperation,
      databaseBackup,
      databaseRestore,
      rawOperation;
  final bool scanning, savingDailyBackup;
  final String? dailyBackupError, lastError;
  final String lastBackup;
  final List<BackupFile> recentBackups;
  final BackupPrompt? prompt;
}

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({
    this.snapshot = const BackupPresentation(),
    super.key,
  });
  final BackupPresentation snapshot;

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  BackupPresentation get snapshot => widget.snapshot;
  final _changes = _BackupChanges();
  final _routes = <ModalRoute<dynamic>, bool Function()>{};
  (String, BackupPromptKind)? _handledPrompt;

  @override
  void initState() {
    super.initState();
    _schedulePrompt();
  }

  @override
  void didUpdateWidget(covariant BackupSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stale = _routes.entries
        .where((entry) => !entry.value())
        .map((entry) => entry.key)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in stale.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      if (mounted) _changes.refresh();
    });
    _schedulePrompt();
  }

  Future<T?> _dialog<T>(WidgetBuilder builder, {bool Function()? valid}) async {
    if (!mounted) return null;
    final route = DialogRoute<T>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _changes,
        builder: (context, _) => SettingsTheme(child: builder(context)),
      ),
    );
    _routes[route] = valid ?? () => true;
    try {
      return await Navigator.of(context).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void _schedulePrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prompt = snapshot.prompt;
      if (prompt == null || _handledPrompt == (prompt.id, prompt.kind)) return;
      _handledPrompt = (prompt.id, prompt.kind);
      _openPrompt(prompt);
    });
  }

  Future<void> _openPrompt(BackupPrompt prompt) async {
    bool valid() =>
        mounted &&
        snapshot.prompt?.id == prompt.id &&
        snapshot.prompt?.kind == prompt.kind;
    if (prompt.kind == BackupPromptKind.memoryImport) {
      final id = await _dialog<String>(
        (_) => BackupProfileDialog(
          profiles: snapshot.profiles,
          selectedId: snapshot.activeProfileId,
          title: '选择要导入到的配置',
          returnSelection: true,
        ),
        valid: valid,
      );
      if (id == null || !valid() || !snapshot.profiles.any((p) => p.id == id)) {
        return;
      }
      await _dialog<void>(
        (_) => const BackupMemoryStrategyDialog(),
        valid: () => valid() && snapshot.profiles.any((p) => p.id == id),
      );
    } else {
      await _dialog<void>(
        (_) => prompt.kind == BackupPromptKind.chatImport
            ? const BackupFormatDialog(importing: true)
            : BackupRestoreDialog(prompt: valid() ? snapshot.prompt! : prompt),
        valid: valid,
      );
    }
  }

  Future<void> _exportChats() async {
    final selected = await _dialog<Set<String>>(
      (_) => BackupChatSelection(snapshot.chats),
    );
    if (selected == null || !mounted) return;
    // 集合沿选择→格式这一次会话存活，目录移除后不会因同ID重入复活。
    bool valid() {
      selected.retainAll(snapshot.chats.map((chat) => chat.id));
      return selected.isNotEmpty;
    }

    if (!valid()) return;
    await _dialog<void>(
      (_) => BackupFormatDialog(selectedChatIds: Set.unmodifiable(selected)),
      valid: valid,
    );
  }

  @override
  void dispose() {
    final routes = _routes.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      _changes.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '数据备份与恢复',
    onBack: () => Navigator.maybePop(context),
    body: ListView.separated(
      key: const PageStorageKey('backup-settings'),
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => switch (index) {
        0 => _overview(context),
        1 => _fileStatistics(context),
        2 => _management(
          context,
          title: '聊天记录',
          subtitle: '跨格式备份、导出与恢复',
          icon: Icons.history,
          tone: IconTone.browser,
          description: '当前共有 ${snapshot.chats.length} 条聊天记录。',
          onExport: _exportChats,
          operation: snapshot.chatOperation,
          delete: true,
        ),
        3 => BackupCard(
          spacing: 10,
          children: [
            const BackupHeader(
              '对话审计存储',
              '审计随已保存对话持久化，只有删除整个对话时才会清除',
              Icons.storage,
              IconTone.storage,
            ),
            if (snapshot.auditSummary == null)
              // 原页未取得 summary 时的外观。没有后台扫描；只在可见列表项绘制。
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(),
              )
            else ...[
              Text(
                snapshot.auditSummary!,
                style: const TextStyle(fontSize: 14),
              ),
              BackupText(snapshot.largestAudit ?? '尚无审计 payload', small: true),
            ],
          ],
        ),
        4 => _management(
          context,
          title: '角色卡',
          subtitle: '备份与恢复角色卡配置',
          icon: Icons.person,
          tone: IconTone.account,
          description:
              '当前共有 ${snapshot.characterCount} 个角色卡。导出的文件会保存在「下载/Kiyori」文件夹中。',
          operation: snapshot.characterOperation,
        ),
        5 => _management(
          context,
          title: '记忆库',
          subtitle: '跨配置备份与恢复，保持思维链一致',
          icon: Icons.psychology,
          tone: IconTone.ai,
          description:
              '当前共有 ${snapshot.memoryCount} 条记忆和 ${snapshot.linkCount} 个链接。',
          operation: snapshot.memoryOperation,
          onExport: () => _dialog<void>(
            (_) => BackupProfileDialog(
              profiles: snapshot.profiles,
              selectedId: snapshot.activeProfileId,
            ),
          ),
        ),
        6 => _management(
          context,
          title: '模型配置',
          subtitle: '备份与恢复所有模型设置，包括API密钥和参数',
          icon: Icons.settings_outlined,
          tone: IconTone.settings,
          description: '当前共有 ${snapshot.modelCount} 个模型配置。',
          operation: snapshot.modelOperation,
        ),
        7 => _faq(),
        8 => _database(context),
        _ => BackupCard(
          children: [
            const BackupHeader(
              '文件快照备份（实验）',
              '以文件/目录为单位的整体压缩备份与恢复',
              Icons.storage,
              IconTone.storage,
            ),
            const BackupText(
              '将打包会随“清除数据”一起删除的应用数据：内部 files/shared_prefs/datastore/databases，以及 Android/data/包名/files（终端 Linux 环境体积很大，默认不备份）。恢复会覆盖当前数据，并且需要重启应用生效。部分加密数据在换机/重装后可能无法使用。',
              small: true,
            ),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                BackupButton('立即备份', Icons.cloud_download),
                BackupButton('从文件恢复', Icons.file_open, warning: true),
              ],
            ),
            if (snapshot.rawOperation.phase != BackupPhase.idle)
              BackupOperationView(
                snapshot.rawOperation,
                subject: '文件快照',
                raw: true,
              ),
          ],
        ),
      },
    ),
  );

  Widget _overview(BuildContext context) => BackupCard(
    spacing: 20,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('数据概览', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          BackupText('当前配置：${snapshot.profileName}'),
        ],
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          BackupStat(
            '聊天记录',
            snapshot.chats.length,
            Icons.history,
            IconTone.browser.iconFor(context),
          ),
          BackupStat(
            '角色卡',
            snapshot.characterCount,
            Icons.person,
            IconTone.account.iconFor(context),
          ),
          BackupStat(
            '记忆条目',
            snapshot.memoryCount,
            Icons.psychology,
            IconTone.ai.iconFor(context),
          ),
          BackupStat(
            '记忆关联',
            snapshot.linkCount,
            Icons.link,
            IconTone.link.iconFor(context),
          ),
        ],
      ),
    ],
  );

  Widget _fileStatistics(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BackupCard(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📁 备份文件统计', style: TextStyle(fontSize: 22)),
                  SizedBox(height: 4),
                  BackupText('Kiyori 导出目录中的备份文件'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 40,
              child: FilledButton.tonal(
                onPressed: snapshot.scanning ? null : emptyAction,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: snapshot.scanning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20, semanticLabel: '刷新'),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BackupStat(
              '聊天记录',
              snapshot.chatFiles,
              Icons.history,
              colors.primary,
              file: true,
            ),
            BackupStat(
              '角色卡',
              snapshot.characterFiles,
              Icons.person,
              colors.primary,
              file: true,
            ),
            BackupStat(
              '记忆库',
              snapshot.memoryFiles,
              Icons.psychology,
              colors.secondary,
              file: true,
            ),
            BackupStat(
              '模型配置',
              snapshot.modelFiles,
              Icons.settings_outlined,
              colors.tertiary,
              file: true,
            ),
            BackupStat(
              '数据库',
              snapshot.databaseFiles,
              Icons.storage,
              colors.primary,
              file: true,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(
              Theme.of(context).brightness == Brightness.dark
                  ? 0xFF242A31
                  : 0xFFEDF1F5,
            ).withValues(alpha: .5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const BackupText(
            '💡 提示：备份文件保存在 Download/Kiyori 文件夹',
            small: true,
          ),
        ),
      ],
    );
  }

  Widget _management(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required IconTone tone,
    required String description,
    VoidCallback onExport = emptyAction,
    BackupOperation operation = const BackupOperation(),
    bool delete = false,
  }) => BackupCard(
    children: [
      BackupHeader(title, subtitle, icon, tone),
      BackupText(description),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          BackupButton(
            '导出',
            Icons.cloud_download,
            onPressed: onExport,
            key: ValueKey('backup-export-$title'),
          ),
          const BackupButton('导入', Icons.cloud_upload),
          if (delete)
            BackupButton(
              '删除全部',
              Icons.delete_outline,
              destructive: true,
              onPressed: () => _dialog<void>((_) => const BackupDeleteDialog()),
            ),
        ],
      ),
      if (operation.phase != BackupPhase.idle)
        BackupOperationView(operation, subject: title),
    ],
  );

  Widget _faq() => const BackupCard(
    spacing: 12,
    children: [
      Text('常见问题', style: TextStyle(fontSize: 22)),
      BackupText('了解备份与导入时的注意事项，避免常见误区。'),
      Divider(height: 1),
      _FaqItem('为什么要备份数据？', '备份聊天记录可以防止应用卸载或数据丢失时，您的重要内容丢失。定期备份是个好习惯！'),
      _FaqItem(
        '导出的文件保存在哪里？',
        '导出的备份文件会保存在您手机的「下载/Kiyori」文件夹中，文件名包含导出的数据类型、日期和时间。',
      ),
      _FaqItem(
        '导入后会出现重复的数据吗？',
        '系统会根据记录ID判断，相同ID的记录会被更新而不是重复导入。不同ID的记录会作为新记录添加。',
      ),
    ],
  );

  Widget _database(BuildContext context) => BackupCard(
    children: [
      BackupHeader(
        '数据库（自动+手动备份）',
        '每日备份 Room SQLite 数据库，最多保留 ${snapshot.maxBackups} 份（超出会自动删除旧备份）',
        Icons.storage,
        IconTone.storage,
      ),
      const BackupText(
        '这是更底层的整库备份（Room/SQLite），通常包含聊天记录、消息等结构化数据。恢复会覆盖当前数据库，建议先备份。',
        small: true,
      ),
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每日自动备份',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                BackupText('默认关闭；开启后每天生成 1 份数据库备份', small: true),
              ],
            ),
          ),
          Switch(
            value: snapshot.dailyBackup == true,
            onChanged:
                snapshot.dailyBackup == null || snapshot.savingDailyBackup
                ? null
                : (_) {},
          ),
        ],
      ),
      const BackupText(
        '保存位置：/storage/emulated/0/Download/Kiyori-Android/backup/room_db\n不随主动导出目录改变。关闭自动备份不删除已有文件，仍可手动备份。备份可能包含对话内容，分享前请检查。',
        small: true,
      ),
      if (snapshot.dailyBackupError != null)
        Text(
          snapshot.dailyBackupError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      LayoutBuilder(
        builder: (context, constraints) {
          const label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最大保留备份数',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              BackupText('超过此数量时，会自动删除更旧的备份文件（范围 1-100）', small: true),
            ],
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: snapshot.maxBackups > 1 ? emptyAction : null,
                child: const Text('-'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${snapshot.maxBackups}'),
              ),
              TextButton(
                onPressed: snapshot.maxBackups < 100 ? emptyAction : null,
                child: const Text('+'),
              ),
            ],
          );
          // 原手机默认几何保持横排，大字/窄窗下给控件独立一行。
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, controls],
            );
          }
          return Row(
            children: [
              const Expanded(child: label),
              controls,
            ],
          );
        },
      ),
      const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          BackupButton('立即备份', Icons.cloud_download),
          BackupButton('从文件恢复', Icons.file_open, warning: true),
        ],
      ),
      if (snapshot.recentBackups.isNotEmpty) ...[
        const Text(
          '最近三次备份（自动 + 手动，仅展示 3 份）',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        for (final file in snapshot.recentBackups.take(3))
          BackupFileRow(
            file: file,
            onRestore: () => _dialog<void>(
              (_) => BackupRestoreDialog(
                prompt: BackupPrompt(
                  id: file.id,
                  kind: BackupPromptKind.databaseRestore,
                  fileName:
                      snapshot.recentBackups
                          .where((entry) => entry.id == file.id)
                          .firstOrNull
                          ?.fileName ??
                      file.fileName,
                ),
              ),
              valid: () =>
                  snapshot.recentBackups.any((entry) => entry.id == file.id),
            ),
          ),
      ],
      if (snapshot.databaseBackup.phase != BackupPhase.idle)
        BackupOperationView(
          snapshot.databaseBackup,
          subject: '数据库',
          database: true,
        ),
      if (snapshot.databaseRestore.phase != BackupPhase.idle)
        BackupOperationView(
          snapshot.databaseRestore,
          subject: '数据库',
          database: true,
          restoring: true,
        ),
      BackupText('上次成功备份：${snapshot.lastBackup}', small: true),
      if (snapshot.lastError?.trim().isNotEmpty == true)
        Text(
          '上次错误：${snapshot.lastError}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
    ],
  );
}

class _BackupChanges extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class _FaqItem extends StatelessWidget {
  const _FaqItem(this.question, this.answer);
  final String question, answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(answer, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
