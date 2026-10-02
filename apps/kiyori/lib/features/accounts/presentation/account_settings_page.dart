import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'bilibili_login_dialog.dart';

/// 未连接账号的展示快照；不查询凭据或启动 OAuth。
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '我的账号',
    children: [
      SettingsGroup(
        title: 'GitHub 账号',
        description: '连接 GitHub 后可使用市场发布、管理和其他需要身份的功能',
        children: [
          SettingsRow(
            title: '登录 GitHub',
            description: '使用 GitHub 登录以启用需要账号身份的服务',
            value: '未登录',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _GitHubMethodDialog(),
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: '哔哩哔哩账号',
        description: '哔哩哔哩五个栏目与 AI 哔哩工具包默认共用此账号。凭据仅在本机加密保存。',
        children: [
          SettingsRow(
            title: '登录哔哩哔哩',
            description: '扫码登录，或使用 Cookie / 浏览器已有登录信息',
            value: '未连接',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const BilibiliLoginDialog(),
            ),
          ),
        ],
      ),
    ],
  );
}

class _GitHubMethodDialog extends StatelessWidget {
  const _GitHubMethodDialog();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('登录 GitHub'),
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('请选择 GitHub 登录方式。内嵌模式适合无法调起外部浏览器的设备，外部浏览器模式兼容性更好。'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: emptyAction,
          icon: const Icon(Icons.language),
          label: const Text('使用内嵌页面登录'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: emptyAction,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('使用外部浏览器登录'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
