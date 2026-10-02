import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum AssistantSettingsSection {
  models,
  functions,
  roles,
  profile,
  avatar,
  replies,
  tts,
  stt,
  wakeup,
  context,
  permissions,
  usage,
  server,
  artifacts,
}

/// 只保留原五组十四入口；实际业务由宿主逐项接入。
class AssistantSettingsPage extends StatelessWidget {
  const AssistantSettingsPage({required this.onOpen, super.key});
  final ValueChanged<AssistantSettingsSection> onOpen;
  static const groups = [
    (
      '模型与生成',
      '先配置可用模型，再为不同任务和角色选择合适的生成方式',
      [
        (
          '模型与 API',
          '管理提供方、密钥、端点、模型列表、请求参数和连接测试',
          AssistantSettingsSection.models,
        ),
        ('功能模型分配', '为对话、总结、记忆和多媒体识别分别指定模型', AssistantSettingsSection.functions),
        ('角色卡和提示词', '管理角色卡、提示词、群组、标签以及人设卡生成', AssistantSettingsSection.roles),
      ],
    ),
    (
      '个性化与交互',
      '定义助手如何理解你、呈现形象并组织回复',
      [
        (
          '用户资料',
          '编辑会作为用户上下文发送给 AI 的 user.md',
          AssistantSettingsSection.profile,
        ),
        ('虚拟形象', '管理形象模型、预览、动作与情绪映射', AssistantSettingsSection.avatar),
        ('回复与表情', '配置分句节奏、标点、表情、自定义回复和自拍', AssistantSettingsSection.replies),
      ],
    ),
    (
      '语音',
      '管理朗读、识别和后台唤醒链路',
      [
        ('文本转语音', '选择朗读引擎、音色、语速、音调和文本清洗规则', AssistantSettingsSection.tts),
        ('语音转文本', '选择本地或远程识别引擎，并配置服务连接', AssistantSettingsSection.stt),
        ('语音唤醒', '设置唤醒词、后台监听、语音响应和自动附加内容', AssistantSettingsSection.wakeup),
      ],
    ),
    (
      '上下文与工具',
      '控制对话保留、自动总结和工具调用边界',
      [
        (
          '上下文与总结',
          '管理上下文窗口、自动总结、自定义规则和历史媒体保留',
          AssistantSettingsSection.context,
        ),
        (
          'AI 工具授权',
          '为工具设置默认规则和允许、询问或禁止例外',
          AssistantSettingsSection.permissions,
        ),
      ],
    ),
    (
      '服务与用量',
      '查看资源消耗，并配置受控的局域网与自动化入口',
      [
        (
          'AI 用量与费用',
          '查看模型请求、Token、费用、汇率和自定义定价',
          AssistantSettingsSection.usage,
        ),
        (
          '局域网与自动化',
          '管理本地 HTTP/Web 对话服务、端口、令牌和调用示例',
          AssistantSettingsSection.server,
        ),
        (
          'AI 产物保存位置',
          '设置 AI 生成、导出、下载和脚手架文件的 Android 与 Ubuntu 默认目录',
          AssistantSettingsSection.artifacts,
        ),
      ],
    ),
  ];
  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: 'AI助手',
    children: [
      for (final group in groups)
        SettingsGroup(
          title: group.$1,
          description: group.$2,
          children: [
            for (var i = 0; i < group.$3.length; i++) ...[
              if (i > 0) const SettingsDivider(),
              SettingsRow(
                title: group.$3[i].$1,
                description: group.$3[i].$2,
                onTap: () => onOpen(group.$3[i].$3),
              ),
            ],
          ],
        ),
    ],
  );
}
