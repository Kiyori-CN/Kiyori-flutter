import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum MoreSettingsSection {
  permissions,
  storage,
  network,
  licenses,
  agreement,
  privacy,
  onboarding,
}

/// KiyoriMoreFeaturesSettingsPage 的原顺序与文案。
class MoreSettingsPage extends StatelessWidget {
  const MoreSettingsPage({required this.onOpen, super.key});
  final ValueChanged<MoreSettingsSection> onOpen;

  static const groups = [
    (
      '系统能力',
      '管理 Kiyori 在设备上运行所需的授权和系统访问能力',
      [
        ('权限管理', '查看应用权限、系统访问和高级设备能力的当前状态', MoreSettingsSection.permissions),
        ('存储与路径', '管理工作区、下载、主动导出和 AI 工具生成文件的位置', MoreSettingsSection.storage),
      ],
    ),
    (
      '网络能力',
      '为 Kiyori 内部模块管理代理订阅、策略组和路由规则',
      [('网络代理', '配置直连或内嵌 Mihomo 代理，并查看当前连接策略', MoreSettingsSection.network)],
    ),
    (
      '开源与法律',
      '了解 Kiyori 的开源组成、使用规则和数据处理方式',
      [
        ('开源协议', '查看随 Kiyori 分发的开源组件、许可证和项目地址', MoreSettingsSection.licenses),
        ('用户协议', '查看 Kiyori 的服务边界、使用规则和责任说明', MoreSettingsSection.agreement),
        ('隐私政策', '查看设备端数据、联网场景、权限用途和删除方式', MoreSettingsSection.privacy),
      ],
    ),
    (
      '使用引导',
      '回顾功能入口与使用方式，按自己的节奏重新了解 Kiyori',
      [
        (
          '重新查看首次引导',
          '从第一页重新了解功能与使用方式，完成后返回此页；保留已有数据与授权',
          MoreSettingsSection.onboarding,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '更多功能',
    children: [
      for (final group in groups)
        SettingsGroup(
          title: group.$1,
          description: group.$2,
          children: [
            for (var index = 0; index < group.$3.length; index++) ...[
              if (index > 0) const SettingsDivider(),
              SettingsRow(
                title: group.$3[index].$1,
                description: group.$3[index].$2,
                onTap: () => onOpen(group.$3[index].$3),
              ),
            ],
          ],
        ),
    ],
  );
}
