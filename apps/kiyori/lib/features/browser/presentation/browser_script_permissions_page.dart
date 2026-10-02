import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'browser_scripts_presentation.dart';

/// 权限声明仅展示；总授权和实际运行仍属于共享userscript owner。
class BrowserScriptPermissionsPage extends StatelessWidget {
  const BrowserScriptPermissionsPage({
    this.snapshot = const BrowserScriptsPresentation(),
    this.onOpenScript,
    super.key,
  });
  final BrowserScriptsPresentation snapshot;
  final ValueChanged<String>? onOpenScript;
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '扩展权限与网站范围',
    children: [
      SettingsGroup(
        title: '运行授权',
        description:
            '${snapshot.supported ? '当前运行环境可用' : '当前运行环境不可用'}${snapshot.reason.trim().isEmpty ? '' : '：${snapshot.reason}'}；总授权由 userscript registry 唯一持有，关闭后不会删除脚本或修改启用状态',
        children: [
          SettingsRow(
            title: '允许用户脚本',
            description: '允许已启用脚本在匹配网页中运行',
            checked: snapshot.allowed,
            enabled: snapshot.supported || snapshot.allowed,
          ),
        ],
      ),
      SettingsGroup(
        title: '脚本声明权限与网站',
        description: snapshot.scripts.isEmpty
            ? '尚未安装网页脚本'
            : '点击脚本进入完整管理页；这里不把脚本声明权限伪装成独立授权开关',
        children: [
          if (snapshot.scripts.isEmpty)
            Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '暂无已安装脚本；可从扩展中心右上角加号通过 URL、本地文件或扩展库安装',
                style: TextStyle(
                  fontSize: 14,
                  color: PrimaryColors.of(context).secondary,
                ),
              ),
            ),
          for (var i = 0; i < snapshot.scripts.length; i++) ...[
            if (i > 0) const SettingsDivider(),
            SettingsRow(
              key: ValueKey(snapshot.scripts[i].id),
              title: snapshot.scripts[i].name,
              description: snapshot.scripts[i].description,
              value: snapshot.scripts[i].state,
              onTap: () => onOpenScript?.call(snapshot.scripts[i].id),
            ),
          ],
        ],
      ),
    ],
  );
}
