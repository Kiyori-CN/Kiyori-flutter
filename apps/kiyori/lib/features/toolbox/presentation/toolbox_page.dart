import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

typedef _Tool = (String, IconData, IconTone);

/// ToolboxCatalog + ScreenRouteRegistry 的内置顺序；不读取旧数据或启动工具。
class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key});
  @override
  State<ToolboxPage> createState() => _ToolboxPageState();
}

class _ToolboxPageState extends State<ToolboxPage> {
  final collapsed = <int>{};
  static const document = (
    '文档工作台',
    Icons.description_outlined,
    IconTone.document,
  );
  static const speech = ('文本转语音', Icons.record_voice_over, IconTone.audio);
  static const transcript = ('语音转文字', Icons.mic, IconTone.audio);
  static const terminal = ('命令终端', Icons.terminal, IconTone.terminal);
  static const List<(String, List<_Tool>)> groups = [
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

  @override
  Widget build(BuildContext context) => PrimaryPage(
    title: '工具箱',
    actions: const [
      SizedBox(
        width: 96,
        child: PrimaryHeaderActions(
          searchLabel: '搜索工具',
          settingsLabel: '工具箱设置',
        ),
      ),
    ],
    child: ListView.separated(
      key: const PageStorageKey('toolbox-list'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 86),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = groups[index];
        final closed = collapsed.contains(index);
        return PrimaryCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  expanded: !closed,
                  child: PrimarySectionTitle(
                    group.$1,
                    onTap: () => setState(
                      () => closed
                          ? collapsed.remove(index)
                          : collapsed.add(index),
                    ),
                    trailing: Row(
                      children: [
                        if (closed)
                          Text(
                            '${group.$2.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PrimaryColors.secondary,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            closed ? Icons.expand_more : Icons.expand_less,
                            size: 20,
                            color: PrimaryColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!closed)
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [for (final tool in group.$2) _ToolChip(tool)],
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip(this.tool);
  final _Tool tool;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: emptyAction,
      onLongPress: emptyAction,
      borderRadius: BorderRadius.circular(100),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tool.$3.container,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: tool.$3.icon.withValues(alpha: .16),
                width: .5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tool.$2, size: 18, color: tool.$3.icon),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tool.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
