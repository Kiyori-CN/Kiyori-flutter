import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({
    required this.onBackup,
    this.onHistory = emptyAction,
    super.key,
  });
  final VoidCallback onBackup, onHistory;
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '数据备份',
    children: [
      SettingsGroup(
        title: '聊天与记忆数据',
        description: '备份、恢复和整理 AI 对话、记忆库及相关数据',
        children: [
          SettingsRow(
            title: '数据备份与恢复',
            description: '导入、导出或删除聊天记录和记忆库数据',
            onTap: onBackup,
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '聊天历史管理',
            description: '查看统计并批量整理、导入或导出聊天记录',
            onTap: onHistory,
          ),
        ],
      ),
    ],
  );
}
