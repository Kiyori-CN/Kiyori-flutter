part of 'onboarding_page.dart';

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({
    required this.selected,
    required this.expanded,
    required this.reviewing,
    required this.onToggle,
    required this.onSelect,
    required this.onExpand,
    required this.onFinish,
    this.statuses = const {},
  });
  final Set<String> selected;
  final Set<int> expanded;
  final bool reviewing;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onSelect;
  final ValueChanged<int> onExpand;
  final VoidCallback onFinish;
  final Map<String, PermissionStatus> statuses;
  PermissionStatus status(String id) =>
      statuses[id] ?? PermissionStatus.unchecked;
  bool selectable(String id) =>
      permissionEntries.firstWhere((e) => e.id == id).action !=
          PermissionAction.none &&
      status(id).previewSelectable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        Expanded(
          child: ListView(
            key: const PageStorageKey('onboarding-permissions'),
            padding: const EdgeInsets.only(top: 14, bottom: 24),
            children: [
              const _Eyebrow('最后一步'),
              const SizedBox(height: 8),
              const Text(
                '用到哪一项，再开哪一项',
                style: TextStyle(
                  fontSize: 24,
                  height: 32 / 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '普通网页浏览无需授予下列权限。只选择你需要的能力，也可以暂不开启，之后在「设置 → 更多功能 → 权限管理」调整。',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 21 / 13.5,
                  color: PrimaryColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PrimaryColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选 ${selected.length} 项待处理。点击下方按钮后发起授权；返回后由你选择继续或停止，不会自动进入下一项。',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 19 / 12.5,
                        color: PrimaryColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Choice(
                          '选择通知与媒体',
                          true,
                          () => onSelect(
                            {
                              'notifications',
                              'media',
                            }.where(selectable).toSet(),
                          ),
                        ),
                        _Choice('全部暂不开启', false, () => onSelect({})),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _GroupTitle('日常使用', '3 项 · 按需选择'),
              for (final row in const [
                ('notifications', '通知', '显示 AI 回复、下载与后台任务状态'),
                ('media', '视频与音频', '读取视频与音频用于播放和处理；Android 14 起可仅授权部分视频'),
                ('microphone', '麦克风', '供语音输入、语音对话与录音工具使用'),
              ])
                _PreviewRow(
                  row.$1,
                  row.$2,
                  row.$3,
                  selected.contains(row.$1),
                  selectable(row.$1) ? () => onToggle(row.$1) : null,
                  status: status(row.$1),
                ),
              const SizedBox(height: 12),
              const _GroupTitle('文件与存储', '2 项 · 用到时再开'),
              const _PreviewRow(
                'all_files',
                '文件访问',
                '读写工作目录、下载与导入导出的文件',
                false,
                null,
              ),
              const _PreviewRow(
                'install',
                '安装应用',
                '允许 Kiyori 发起 APK 安装，仍需在系统界面确认',
                false,
                null,
              ),
              const SizedBox(height: 12),
              const Divider(color: PrimaryColors.divider),
              const SizedBox(height: 12),
              const Text(
                '完整权限目录',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 19 / 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '展开查看全部权限及当前状态。与上方条目共用同一选择，无需重复勾选。',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 16 / 11.5,
                  color: PrimaryColors.secondary,
                ),
              ),
              for (var i = 0; i < permissionGroups.length; i++)
                _catalog(context, i),
              const SizedBox(height: 16),
              const Text(
                '还有哪些访问方式？',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                '联网、网络状态、前台服务、唤醒锁等由 Android 按声明管理，不需要逐项弹窗。照片和文档可通过系统选择器按次提供；屏幕捕获在使用时确认。网站授权与 AI 工具执行授权另行管理，不因同意协议而自动开启。',
                style: TextStyle(
                  fontSize: 12,
                  height: 20 / 12,
                  color: PrimaryColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '拒绝可选权限不影响进入应用，对应功能可能不可用。已授予的访问可到系统设置或对应的 Shizuku、Root 管理器撤销。',
                style: TextStyle(
                  fontSize: 12,
                  height: 20 / 12,
                  color: PrimaryColors.secondary,
                ),
              ),
            ],
          ),
        ),
        _BottomAction(
          horizontalPadding: 0,
          label: selected.isEmpty
              ? (reviewing ? '完成介绍，返回设置' : '直接开始使用')
              : '处理所选 ${selected.length} 项权限',
          onPressed: selected.isEmpty ? onFinish : emptyAction,
          secondary: reviewing ? '返回设置' : '暂不开启，直接开始',
          onSecondary: onFinish,
        ),
      ],
    ),
  );

  Widget _catalog(BuildContext context, int index) {
    final group = permissionGroups[index];
    final entries = permissionEntries.sublist(group.$3, group.$4);
    final count = entries.where((e) => selected.contains(e.id)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PrimaryCard(
        child: Column(
          children: [
            InkWell(
              onTap: () => onExpand(index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.$1,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 19 / 12,
                              color: PrimaryColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            count == 0
                                ? '${entries.length} 项 · 按需开启'
                                : '已选 $count 项',
                            style: const TextStyle(
                              fontSize: 11,
                              color: PrimaryColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      expanded.contains(index)
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded.contains(index))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: selected.contains(entry.id)
                              ? Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: .56)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: selected.contains(entry.id)
                                ? BorderSide(
                                    color: PrimaryColors.accent.withValues(
                                      alpha: .42,
                                    ),
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: !selectable(entry.id)
                                ? null
                                : () => onToggle(entry.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              child: Row(
                                children: [
                                  if (selectable(entry.id))
                                    Checkbox(
                                      value: selected.contains(entry.id),
                                      onChanged: (_) => onToggle(entry.id),
                                    )
                                  else
                                    Icon(
                                      status(entry.id) ==
                                              PermissionStatus.granted
                                          ? Icons.check_circle
                                          : Icons.visibility,
                                      size: 24,
                                      color: PrimaryColors.secondary,
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          status(entry.id).label,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: PrimaryColors.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          entry.description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 18 / 12,
                                            color: PrimaryColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(this.label, this.emphasized, this.onTap);
  final String label;
  final bool emphasized;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      backgroundColor: emphasized
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.white,
      side: emphasized
          ? BorderSide.none
          : const BorderSide(color: PrimaryColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title, this.hint);
  final String title, hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 11.5,
            height: 16 / 11.5,
            color: PrimaryColors.secondary,
          ),
        ),
      ],
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(
    this.id,
    this.title,
    this.description,
    this.selected,
    this.onTap, {
    this.status = PermissionStatus.unchecked,
  });
  final String id, title, description;
  final bool selected;
  final VoidCallback? onTap;
  final PermissionStatus status;
  @override
  Widget build(BuildContext context) {
    final entry = permissionEntries.firstWhere((e) => e.id == id);
    final tone = switch (id) {
      'notifications' => IconTone.warning,
      'media' => IconTone.video,
      'microphone' => IconTone.audio,
      'all_files' => IconTone.folder,
      _ => IconTone.security,
    };
    final checked = selected || status == PermissionStatus.granted;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PrimaryColors.divider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.container,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entry.icon, color: tone.icon, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 16 / 11,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: status.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (id == 'all_files' || id == 'install')
                  const Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '使用时确认',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 15 / 10.5,
                          fontWeight: FontWeight.w600,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Semantics(
                      toggled: checked,
                      label: title,
                      child: Container(
                        width: 38,
                        height: 22,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: checked
                              ? PrimaryColors.accent
                              : PrimaryColors.divider,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 150),
                          alignment: checked
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
