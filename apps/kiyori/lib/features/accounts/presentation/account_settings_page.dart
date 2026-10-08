import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'bilibili_login_dialog.dart';
import 'account_presentation.dart';
import 'github_login_dialog.dart';

/// 账号目录的展示快照；不查询凭据或启动 OAuth。
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({
    this.snapshot = const AccountPresentation(),
    super.key,
  });
  final AccountPresentation snapshot;

  void confirm(BuildContext context, {required bool github}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(github ? '退出 GitHub' : '移除哔哩哔哩账号'),
        content: Text(
          github
              ? '确定要断开当前 GitHub 账号连接吗？'
              : '将删除 Kiyori Flutter 保存的哔哩哔哩账号与凭据。浏览器及哔哩哔哩客户端的登录状态不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          // 只关闭确认层，不把账号事实改成“已退出”。
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(github ? '退出' : '移除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final githubLabel = !snapshot.githubConnected
        ? '未登录'
        : snapshot.githubLogin == null
        ? '读取中'
        : '@${snapshot.githubLogin}';
    final account = snapshot.bilibili;
    return SettingsDetailPage(
      title: '我的账号',
      children: [
        SettingsGroup(
          title: 'GitHub 账号',
          description: '连接 GitHub 后可使用市场发布、管理和其他需要身份的功能',
          children: [
            SettingsRow(
              title: snapshot.githubConnected ? 'GitHub 已连接' : '登录 GitHub',
              description: snapshot.githubConnected
                  ? '当前账号 $githubLabel，点击可退出登录'
                  : '使用 GitHub 登录以启用需要账号身份的服务',
              value: githubLabel,
              onTap: () => snapshot.githubConnected
                  ? confirm(context, github: true)
                  : showDialog<void>(
                      context: context,
                      builder: (_) => const GitHubLoginDialog(),
                    ),
            ),
          ],
        ),
        SettingsGroup(
          title: '哔哩哔哩账号',
          description: '哔哩哔哩五个栏目与 AI 哔哩工具包默认共用此账号。凭据仅在本机加密保存。',
          children: [
            SettingsRow(
              title: account?.name ?? '登录哔哩哔哩',
              description: snapshot.bilibiliLoading
                  ? '正在读取本机账号…'
                  : account == null
                  ? '扫码登录，或使用 Cookie / 浏览器已有登录信息'
                  : !account.valid
                  ? 'UID ${account.uid} · 登录已失效，请重新登录'
                  : 'UID ${account.uid} · Lv.${account.level}${account.vip ? ' · 大会员' : ''}',
              value: account?.valid == true ? '已连接' : '未连接',
              enabled: !snapshot.bilibiliLoading && !snapshot.bilibiliBusy,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => BilibiliLoginDialog(accountName: account?.name),
              ),
            ),
            if (account != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '上次验证：${account.verifiedAtLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: snapshot.bilibiliBusy ? null : emptyAction,
                      child: Text(snapshot.bilibiliBusy ? '正在验证…' : '重新验证登录'),
                    ),
                    TextButton(
                      onPressed: snapshot.bilibiliBusy
                          ? null
                          : () => confirm(context, github: false),
                      child: const Text('移除本地账号'),
                    ),
                  ],
                ),
              ),
            ],
            if (snapshot.bilibiliError case final error?) ...[
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              if (account == null)
                TextButton(
                  onPressed: () => confirm(context, github: false),
                  child: const Text('清除无法读取的本地账号'),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
