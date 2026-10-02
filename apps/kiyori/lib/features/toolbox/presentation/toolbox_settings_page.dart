import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_management_drawers.dart';

class ToolboxSettingsPage extends StatelessWidget {
  const ToolboxSettingsPage({this.onOpenDocuments = emptyAction, super.key});
  final VoidCallback onOpenDocuments;
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '工具箱设置',
    children: [
      // 原页为 preference notice 保留独立 lazy item；默认没有错误内容。
      const SizedBox.shrink(),
      SettingsGroup(
        title: '页面布局',
        description: '',
        children: [
          SettingsRow(
            title: '常用工具',
            description: '添加、移除与调整顺序',
            onTap: () => showToolboxFavorites(context),
          ),
          const SettingsRow(
            title: '清除自定义颜色',
            description: '恢复中性灰；也可长按单个工具设置颜色',
            enabled: false,
          ),
          SettingsRow(
            title: '管理分组',
            description: '新建、重命名、排序与批量移动工具',
            onTap: () => showToolboxGroups(context),
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
            onTap: onOpenDocuments,
          ),
        ],
      ),
    ],
  );
}
