import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// KiyoriBrowserPluginPermissionsPage's empty, unavailable runtime branch.
class BrowserScriptPermissionsPage extends StatelessWidget {
  const BrowserScriptPermissionsPage({super.key});
  @override
  Widget build(BuildContext context) => const SettingsDetailPage(
    title: '扩展权限与网站范围',
    children: [
      SettingsGroup(
        title: '运行授权',
        description: '当前运行环境不可用；总授权由 userscript registry 唯一持有，关闭后不会删除脚本或修改启用状态',
        children: [
          SettingsRow(
            title: '允许用户脚本',
            description: '允许已启用脚本在匹配网页中运行',
            checked: false,
            enabled: false,
          ),
        ],
      ),
      SettingsGroup(
        title: '脚本声明权限与网站',
        description: '尚未安装网页脚本',
        children: [
          Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '暂无已安装脚本；可从扩展中心右上角加号通过 URL、本地文件或扩展库安装',
              style: TextStyle(fontSize: 14, color: PrimaryColors.secondary),
            ),
          ),
        ],
      ),
    ],
  );
}
