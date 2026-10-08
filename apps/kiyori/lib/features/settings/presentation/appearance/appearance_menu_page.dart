import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum AppearanceSection { language, theme, display, layout }

/// KiyoriAppearanceSettingsPage；主题五标签是本列表的二级页面。
class AppearanceMenuPage extends StatelessWidget {
  const AppearanceMenuPage({required this.onOpen, super.key});
  final ValueChanged<AppearanceSection> onOpen;
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '界面定制',
    children: [
      SettingsGroup(
        title: '界面与语言',
        description: '调整 Kiyori Flutter 的界面语言、主题、全局显示和 AI 对话布局',
        children: [
          SettingsRow(
            title: '语言',
            description: '切换应用界面使用的显示语言',
            onTap: () => onOpen(AppearanceSection.language),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '主题与外观',
            description: '配置固定亮暗主题，并个性化 AI 对话背景、消息、头像和输入区',
            onTap: () => onOpen(AppearanceSection.theme),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '全局显示',
            description: '管理独立于角色卡和主题的全局显示行为',
            onTap: () => onOpen(AppearanceSection.display),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '布局调整',
            description: '调整 AI 对话输入区、设置栏和内容布局',
            onTap: () => onOpen(AppearanceSection.layout),
          ),
        ],
      ),
    ],
  );
}
