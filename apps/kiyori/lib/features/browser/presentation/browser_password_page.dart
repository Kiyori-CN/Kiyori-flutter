import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// The unavailable branch of KiyoriBrowserPasswordManagerPage.
/// No key store or credential is fabricated by this UI-only surface.
class BrowserPasswordPage extends StatelessWidget {
  const BrowserPasswordPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '网站密码管理',
    children: [
      SettingsGroup(
        title: '保存与填充',
        description: '凭据仅保存在本机普通窗口；无痕窗口不会读取、保存或自动填充',
        children: [
          const SettingsRow(
            title: '自动保存网站密码',
            description: '提交包含一个密码字段的登录表单时，安全保存或更新该网站账号',
            checked: true,
          ),
          const SettingsDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '保险库不可用',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '本机凭据存储不可用',
                    style: TextStyle(
                      fontSize: 12,
                      height: 17 / 12,
                      color: PrimaryColors.of(context).secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: '已保存的网站',
        description: '密码保险库当前不可用，已保存内容不会以明文方式打开',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text(
              '本机凭据存储不可用',
              style: TextStyle(
                fontSize: 13,
                height: 19 / 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
