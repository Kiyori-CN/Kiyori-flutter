import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'toolbox_presentation.dart';

class ToolboxToolPresentation {
  const ToolboxToolPresentation(
    this.id,
    this.visual, {
    this.description = '',
    this.keywords = '',
  });
  final String id, description, keywords;
  final ToolPresentation visual;
  bool matches(String query) => query
      .trim()
      .split(RegExp(r'\s+'))
      .every(
        (word) => [
          visual.$1,
          description,
          keywords,
        ].any((field) => field.toLowerCase().contains(word.toLowerCase())),
      );
}

class ToolboxGroupPresentation {
  const ToolboxGroupPresentation(this.id, this.title, this.tools);
  final String id, title;
  final List<ToolboxToolPresentation> tools;
  bool get custom => id.startsWith('custom:');
}

/// 布局 owner 的只读投影；不保存分组、颜色或工具安装事实。
class ToolboxSettingsPresentation {
  const ToolboxSettingsPresentation({
    this.loaded = true,
    this.saving = false,
    this.hasCustomColors = false,
    this.error,
    this.groups,
    this.favorites,
  });
  final bool loaded, saving, hasCustomColors;
  final String? error;
  final List<ToolboxGroupPresentation>? groups;
  final List<ToolboxToolPresentation>? favorites;
  bool get enabled => loaded && !saving;
  List<ToolboxGroupPresentation> get orderedGroups => groups ?? defaults;
  List<ToolboxToolPresentation> get tools => [
    for (final g in orderedGroups) ...g.tools,
  ];
  List<ToolboxToolPresentation> get favoriteTools => !loaded
      ? const []
      : favorites ??
            [
              for (final visual in ToolboxPresentation.groups.first.$2)
                for (final tool in tools)
                  if (tool.visual == visual) tool,
            ];
  ToolboxGroupPresentation? group(String id) =>
      orderedGroups.where((g) => g.id == id).firstOrNull;

  static final defaults = List<ToolboxGroupPresentation>.unmodifiable([
    for (var i = 0; i < ToolboxPresentation.categories.length; i++)
      ToolboxGroupPresentation(
        ['CONTENT', 'AI', 'DEVELOPMENT', 'DEVICE', 'EXTENSION'][i],
        ToolboxPresentation.categories[i].$1,
        List.unmodifiable([
          for (final visual in ToolboxPresentation.categories[i].$2)
            ToolboxToolPresentation(
              _metadata[visual.$1]!.$1,
              visual,
              keywords: _metadata[visual.$1]!.$2,
            ),
        ]),
      ),
  ]);
  static const _metadata = <String, (String, String)>{
    '文档工作台': (
      'kiyori.document_workbench',
      '办公预览 文本编辑 阅读 Word Excel PPT PDF Markdown 电子书 文档',
    ),
    '音乐播放器': ('kiyori.music', '本地音乐 直链播放 队列 音乐 播放 音频 music'),
    '文本转语音': ('toolbox.text_to_speech', '朗读 TTS'),
    '语音转文字': ('toolbox.speech_to_text', '转录 听写 STT'),
    '哔哩哔哩': (
      'toolbox.bilibili',
      '哔哩番剧 哔哩视频 B站 bilibili bilibilias bangumi 推荐 热门 动漫 国创 番剧 影视 电影 电视剧 纪录片 综艺 我的 搜索 点赞 投币 收藏 历史 追番 追剧 稍后再看 投稿 视频 音频 字幕 下载',
    ),
    '音视频处理': ('toolbox.ffmpeg_toolbox', 'FFmpeg 视频转换 音频转换 剪辑'),
    'HTML 打包': ('toolbox.html_packager', '网页'),
    '默认助手设置': ('toolbox.default_assistant_guide', ''),
    'API 密钥': ('toolbox.token_config', '获取密钥 模型配置'),
    'AutoGLM 配置': ('toolbox.auto_glm_one_click', '手机自动化'),
    'AutoGLM 执行': ('toolbox.auto_glm_tool', '手机自动化'),
    '工具测试': ('toolbox.tool_tester', ''),
    '命令终端': ('toolbox.terminal', 'Linux Ubuntu'),
    '界面调试': ('toolbox.ui_debugger', 'UI 控件'),
    '命令执行器': ('toolbox.shell_executor', 'Shell'),
    '日志查看': ('toolbox.logcat', 'Logcat'),
    '性能诊断': ('toolbox.runtime_performance', 'CPU 内存 流量 性能'),
    '数据库工具': ('toolbox.sql_viewer', 'SQL SQLite'),
    '应用权限管理': ('toolbox.app_permissions', ''),
    '幻象进程限制': ('toolbox.process_limit_remover', ''),
  };
}

String? toolboxGroupNameError(
  String value,
  Iterable<ToolboxGroupPresentation> groups,
) {
  final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  String key(String text) => unorm.nfkc(text).toLowerCase();
  if (name.isEmpty) return '请输入分组名称';
  if (name.length > 40) return '分组名称不能超过 40 个字符';
  if (name.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))) return '分组名称不能包含控制字符';
  if ([
    '常用工具',
    ...ToolboxSettingsPresentation.defaults.map((g) => g.title),
    ...groups.map((g) => g.title),
  ].any((title) => key(title) == key(name))) {
    return '已存在同名分组';
  }
  return null;
}
