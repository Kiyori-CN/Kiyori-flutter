import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_management_drawers.dart';
import 'toolbox_settings_presentation.dart';
import 'toolbox_settings_session.dart';

class ToolboxSettingsPage extends StatefulWidget {
  const ToolboxSettingsPage({
    this.onOpenDocuments = emptyAction,
    this.snapshot = const ToolboxSettingsPresentation(),
    super.key,
  });
  final VoidCallback onOpenDocuments;
  final ToolboxSettingsPresentation snapshot;
  @override
  State<ToolboxSettingsPage> createState() => _ToolboxSettingsPageState();
}

class _ToolboxSettingsPageState extends State<ToolboxSettingsPage> {
  late final session = ToolboxSettingsSession(widget.snapshot);
  @override
  void didUpdateWidget(covariant ToolboxSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    session.update(widget.snapshot);
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  void clearColors() => session.dialog(
    context,
    (context) => AlertDialog(
      scrollable: true,
      title: const Text('清除所有自定义颜色？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('所有工具恢复默认功能配色，常用、分组和顺序保持不变。'),
          if (widget.snapshot.error != null)
            Text(
              widget.snapshot.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.snapshot.saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: widget.snapshot.saving ? null : emptyAction,
          child: const Text('清除颜色'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '工具箱设置',
    children: [
      ToolboxPreferenceNotice(widget.snapshot),
      SettingsGroup(
        title: '页面布局',
        description: '',
        children: [
          SettingsRow(
            title: '常用工具',
            description: '添加、移除与调整顺序',
            onTap: () => showToolboxFavorites(context, session),
          ),
          SettingsRow(
            title: '清除自定义颜色',
            description: '恢复中性灰；也可长按单个工具设置颜色',
            enabled: widget.snapshot.hasCustomColors && !widget.snapshot.saving,
            onTap: clearColors,
          ),
          SettingsRow(
            title: '管理分组',
            description: '新建、重命名、排序与批量移动工具',
            enabled: widget.snapshot.enabled,
            onTap: () => showToolboxGroups(context, session),
          ),
        ],
      ),
      SettingsGroup(
        title: '工具偏好',
        description: '',
        children: [
          SettingsRow(
            title: '文档工作台',
            description: '阅读显示、文本编辑与记录管理',
            onTap: widget.onOpenDocuments,
          ),
        ],
      ),
    ],
  );
}
