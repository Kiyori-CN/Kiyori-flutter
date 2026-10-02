import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

typedef ToolPresentation = (String, IconData, IconTone);

/// 仅共享旧内置入口的展示，工具执行和持久布局由未来领域 owner 提供。
abstract final class ToolboxPresentation {
  static const document = (
    '文档工作台',
    Icons.description_outlined,
    IconTone.document,
  );
  static const speech = ('文本转语音', Icons.record_voice_over, IconTone.audio);
  static const transcript = ('语音转文字', Icons.mic, IconTone.audio);
  static const terminal = ('命令终端', Icons.terminal, IconTone.terminal);
  static const List<(String, List<ToolPresentation>)> groups = [
    ('常用工具', [document, speech, transcript, terminal]),
    (
      '内容处理',
      [
        document,
        ('音乐播放器', Icons.music_note_outlined, IconTone.audio),
        speech,
        transcript,
        ('哔哩哔哩', Icons.video_library, IconTone.video),
        ('音视频处理', Icons.video_settings, IconTone.video),
        ('HTML 打包', Icons.html, IconTone.code),
      ],
    ),
    (
      'AI 助手',
      [
        ('默认助手设置', Icons.smart_toy, IconTone.ai),
        ('API 密钥', Icons.token, IconTone.storage),
        ('AutoGLM 配置', Icons.auto_mode, IconTone.automation),
        ('AutoGLM 执行', Icons.auto_mode, IconTone.automation),
      ],
    ),
    (
      '开发调试',
      [
        ('工具测试', Icons.build, IconTone.tools),
        terminal,
        ('界面调试', Icons.device_hub, IconTone.network),
        ('命令执行器', Icons.code, IconTone.code),
        ('日志查看', Icons.data_object, IconTone.code),
        ('性能诊断', Icons.data_object, IconTone.code),
        ('数据库工具', Icons.table_view, IconTone.success),
      ],
    ),
    (
      '设备管理',
      [
        ('应用权限管理', Icons.security, IconTone.security),
        ('幻象进程限制', Icons.lock_open, IconTone.security),
      ],
    ),
  ];
  static List<ToolPresentation> get all => [
    for (final group in groups.skip(1)) ...group.$2,
  ];
  static List<(String, List<ToolPresentation>)> get categories => [
    ...groups.skip(1),
    ('未分组', const []),
  ];
}
