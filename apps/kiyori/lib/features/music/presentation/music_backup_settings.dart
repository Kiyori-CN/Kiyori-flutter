import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'music_settings_presentation.dart';

/// 仅保存本次页面已经展示过的解析身份，离屏不保留组件或ticker。
class MusicBackupPreviewSession {
  String? presentedId;
}

class MusicBackupSettings extends StatefulWidget {
  const MusicBackupSettings({required this.snapshot, this.session, super.key});
  final MusicSettingsPresentation snapshot;
  final MusicBackupPreviewSession? session;
  @override
  State<MusicBackupSettings> createState() => _MusicBackupSettingsState();
}

class _MusicBackupSettingsState extends State<MusicBackupSettings> {
  final revision = ValueNotifier(0);
  final routes = <ModalRoute<dynamic>>{};
  ModalRoute<dynamic>? previewRoute;
  final localSession = MusicBackupPreviewSession();
  MusicBackupPreviewSession get session => widget.session ?? localSession;
  MusicBackupPresentation get backup => widget.snapshot.backup;
  bool get enabled =>
      widget.snapshot.editable && !backup.busy && !backup.exportPending;

  @override
  void initState() {
    super.initState();
    schedulePreview();
  }

  @override
  void didUpdateWidget(covariant MusicBackupSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.backup.preview?.id != backup.preview?.id) {
      final oldRoute = previewRoute;
      if (oldRoute != null) remove([oldRoute]);
      previewRoute = null;
      session.presentedId = null;
      schedulePreview();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revision.value++;
    });
  }

  void remove(Iterable<ModalRoute<dynamic>> owned) {
    final removed = owned.toList().reversed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in removed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void schedulePreview() {
    final id = backup.preview?.id;
    if (id == null || id == session.presentedId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || backup.preview?.id != id || session.presentedId == id) {
        return;
      }
      session.presentedId = id;
      previewRoute = dialog((context) {
        final preview = backup.preview;
        if (preview == null || preview.id != id) return const SizedBox.shrink();
        return AlertDialog(
          scrollable: true,
          title: const Text('导入列表预览'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(
                '格式：${preview.format}\n${preview.lists.length} 个列表 · ${preview.trackCount} 首在线歌曲\n${preview.conflicts} 个列表 ID 与本机相同',
              ),
              Text(
                '本地文件记录 ${preview.omittedLocalTracks} 首不导入。账户、设置、历史、下载状态、音源脚本、歌词附件、音质缓存、带参数地址和列表云关联均不导入；歌曲播放地址需重新解析。',
              ),
              const Text(
                '合并按平台歌曲身份去重，保留本机顺序；替换只覆盖同 ID 列表内容。其他本机列表保留。确认后可在本次会话撤销，修改资料或新增历史后撤销失效。',
              ),
              for (final list in preview.lists)
                Text(
                  '${list.name} · ${list.trackCount} 首',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (backup.message case final message?)
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: backup.busy ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            for (final label in ['合并', '替换同 ID'])
              TextButton(
                onPressed: enabled ? emptyAction : null,
                child: Text(label),
              ),
          ],
        );
      });
    });
  }

  ModalRoute<dynamic> dialog(WidgetBuilder builder) {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => ValueListenableBuilder(
        valueListenable: revision,
        builder: (context, _, _) => PopScope(
          canPop: !backup.busy,
          child: SettingsTheme(child: builder(context)),
        ),
      ),
    );
    routes.add(route);
    Navigator.of(context).push(route).whenComplete(() => routes.remove(route));
    return route;
  }

  void export() => dialog(
    (context) => AlertDialog(
      scrollable: true,
      title: const Text('导出 LX 在线列表'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('导出收藏及 ${backup.playlistCount} 个自建列表，保留歌曲平台、身份、顺序和基本元数据。'),
          const Text(
            '此为 LX 兼容列表子集，不含账户、脚本、设置、历史、下载记录、歌词附件、音质缓存或列表云关联。含本地文件或直链时整批拒绝，不静默漏掉歌曲。',
          ),
          if (backup.message case final message?)
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: backup.busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: enabled ? emptyAction : null,
          child: const Text('选择保存位置'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    remove(routes);
    revision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: '列表备份',
      description: '通过系统文件选择器迁移 LX 在线收藏和自建列表',
      children: [
        SettingsRow(
          title: '导入 LX 列表',
          description: '支持 JSON 与 gzip .lxmc，最大 12 MiB；先预览再确认',
          enabled: enabled,
        ),
        const SettingsDivider(),
        SettingsRow(
          title: '导出 LX 列表',
          description: '导出在线收藏和列表为兼容 JSON，不含账号、脚本或设置',
          enabled: enabled,
          onTap: export,
        ),
        if (backup.canUndo) ...[
          const SettingsDivider(),
          SettingsRow(
            title: '撤销上次导入',
            description: '本次会话有效；修改资料或新增历史后撤销记录失效',
            enabled: enabled,
          ),
        ],
        if (backup.busy || widget.snapshot.restoringLists)
          const LinearProgressIndicator(),
        if (backup.message case final message?)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}
