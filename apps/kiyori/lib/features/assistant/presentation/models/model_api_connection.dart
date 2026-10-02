import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'api_provider_drawers.dart';
import 'api_provider_presentation.dart';
import 'model_settings_components.dart';
import 'model_tags_editor.dart';

class ModelApiConnection extends StatefulWidget {
  const ModelApiConnection({super.key});
  @override
  State<ModelApiConnection> createState() => _ModelApiConnectionState();
}

class _ModelApiConnectionState extends State<ModelApiConnection> {
  ApiProviderPresentation provider = builtInApiProviders.first;
  ModelApiProtocol protocol = ModelApiProtocol.chat;
  final endpoint = TextEditingController(
    text: builtInApiProviders.first.protocols.first.endpoint,
  );
  final keyFocus = FocusNode();
  late final apiKey = _ApiKeyController(keyFocus);
  final threads = TextEditingController(text: '4');
  final llamaThreads = TextEditingController(text: '4');
  final llamaContext = TextEditingController(text: '2048');
  final llamaGpu = TextEditingController(text: '0');
  List<String> models = [builtInApiProviders.first.protocols.first.model];
  int forward = 0;
  bool image = false,
      audio = false,
      video = false,
      googleSearch = false,
      claudeCache = false,
      toolCall = true;
  static final inputFilter = FilteringTextInputFormatter.deny(
    RegExp(r'[ \r\n]'),
  );
  static const compute = ['CPU', 'OpenCL', 'Auto', 'OpenGL', 'Vulkan'];

  ProviderProtocolPresentation get route =>
      provider.protocols.firstWhere((entry) => entry.protocol == protocol);

  @override
  void dispose() {
    for (final controller in [
      endpoint,
      apiKey,
      threads,
      llamaThreads,
      llamaContext,
      llamaGpu,
    ]) {
      controller.dispose();
    }
    keyFocus.dispose();
    super.dispose();
  }

  void selectProvider(
    ApiProviderPresentation next,
    ModelApiProtocol nextProtocol,
  ) {
    final nextRoute = next.protocols.firstWhere(
      (entry) => entry.protocol == nextProtocol,
    );
    final defaults = builtInApiProviders.expand((entry) => entry.protocols);
    // 自定义输入不被提供方默认值覆盖；仅更新仍为默认状态的展示草稿。
    if (endpoint.text.isEmpty ||
        defaults.any(
          (entry) =>
              entry.endpoint == endpoint.text ||
              entry.endpoints.any((option) => option.$1 == endpoint.text),
        )) {
      endpoint.text = nextRoute.endpoint;
    }
    if (nextRoute.model.isNotEmpty &&
        (models.isEmpty ||
            (models.length == 1 &&
                defaults.any((entry) => entry.model == models.single)))) {
      models = [nextRoute.model];
    }
    setState(() {
      provider = next;
      protocol = nextProtocol;
    });
  }

  @override
  Widget build(BuildContext context) => ModelSettingsCard(
    children: [
      const ModelSettingsHeading('API设置', Icons.api, IconTone.link),
      ModelSettingsSelector(
        'API提供方',
        provider.name,
        summary: provider.summary,
        onTap: () async {
          final value = await showApiProviderDrawer(
            context,
            selectedId: provider.id,
          );
          if (mounted && value != null) {
            selectProvider(value, value.defaultProtocol);
          }
        },
      ),
      if (provider.protocols.length > 1)
        ModelSettingsSelector(
          'API协议',
          provider.protocolLabel(protocol),
          subtitle: '选择API协议',
          onTap: () async {
            final value = await showApiProtocolDrawer(
              context,
              provider: provider,
              selected: protocol,
            );
            if (mounted && value != null) selectProvider(provider, value);
          },
        ),
      if (provider.id == 'MNN') ...[
        const ModelSettingsBanner('本地运行模型理解能力较差，建议关闭记忆链接、开启禁用工具进行对话'),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download),
          label: const Text('本地模型下载'),
        ),
        ModelSettingsSelector(
          '计算类型',
          compute[forward],
          subtitle: '选择',
          onTap: () async {
            final index = await showDialog<int>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('计算类型'),
                children: [
                  for (var i = 0; i < compute.length; i++)
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(context).pop(i),
                      child: Text(compute[i]),
                    ),
                ],
              ),
            );
            if (mounted && index != null) setState(() => forward = index);
          },
        ),
        ModelSettingsField(
          '线程数',
          threads,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ] else if (provider.id == 'LLAMA_CPP') ...[
        const ModelSettingsBanner('本地运行模型理解能力较差，建议关闭记忆链接、开启禁用工具进行对话'),
        const ModelSettingsBanner(
          'llama.cpp 模型需要自行下载（.gguf）。请将模型文件放入以下文件夹，然后在“模型名称”中填写文件名：\n\n默认模型目录：/storage/emulated/0/Download/Kiyori-Android/models/llama',
        ),
        ModelSettingsField(
          '线程数',
          llamaThreads,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        ModelSettingsField(
          '上下文长度',
          llamaContext,
          subtitle: 'Android 上建议先从 2048 开始，太大更容易因内存压力初始化失败',
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        ModelSettingsField(
          'GPU 层数',
          llamaGpu,
          subtitle: '当前构建存在 GPU backend 时才会生效，0 表示纯 CPU',
          keyboardType: TextInputType.number,
        ),
        const ModelSettingsBanner(
          '批大小、mmap、Flash Attention、KV 等 Android 兼容参数已内置，普通使用只需要调整线程数、上下文大小和 GPU 层数。',
        ),
      ] else ...[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModelSettingsField(
              'API端点',
              endpoint,
              subtitle: '例如: https://api.openai.com/v1/chat/completions',
              keyboardType: TextInputType.url,
              formatters: [inputFilter],
              trailing: route.endpoints.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '选择API端点',
                      onPressed: () async {
                        final value = await showDialog<String>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('API端点'),
                            children: [
                              for (final option in route.endpoints)
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.of(context).pop(option.$1),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(option.$1),
                                      if (option.$2 != option.$1)
                                        Text(
                                          option.$2,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: PrimaryColors.secondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                        if (mounted && value != null) endpoint.text = value;
                      },
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
            ),
            ValueListenableBuilder(
              valueListenable: endpoint,
              builder: (_, value, _) {
                final completed = completeModelEndpointPreview(
                  value.text,
                  protocol,
                );
                return completed == value.text
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '实际请求地址: $completed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: PrimaryColors.accent,
                              ),
                            ),
                            const Text(
                              '提示: 如果您输入的是基础URL，系统将自动补全路径。如需禁用，请在URL末尾添加#号。',
                              style: TextStyle(
                                fontSize: 12,
                                color: PrimaryColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      );
              },
            ),
          ],
        ),
        ModelSettingsField(
          'API密钥',
          apiKey,
          focusNode: keyFocus,
          subtitle: '输入API密钥',
          formatters: [inputFilter],
        ),
      ],
      ModelTagsEditor(
        models: models,
        onChanged: (value) => setState(() => models = value),
      ),
      ModelSettingsSwitch(
        '模型支持识图',
        '启用后，图片将直接发送给AI处理，而不是让AI通过OCR工具读取',
        image,
        onChanged: (value) => setState(() => image = value),
      ),
      ModelSettingsSwitch(
        '模型支持音频解析',
        '启用后，音频将直接发送给AI处理，而不是通过工具返回文本转写/描述',
        audio,
        onChanged: (value) => setState(() => audio = value),
      ),
      ModelSettingsSwitch(
        '模型支持视频解析',
        '启用后，视频将直接发送给AI处理，而不是通过工具抽帧/分析',
        video,
        onChanged: (value) => setState(() => video = value),
      ),
      if (provider.id == 'GOOGLE')
        ModelSettingsSwitch(
          '启用 Google Search',
          '启用后，Gemini 将使用 Google 搜索来增强回答（可能产生额外费用）',
          googleSearch,
          onChanged: (value) => setState(() => googleSearch = value),
        ),
      if (protocol == ModelApiProtocol.messages)
        ModelSettingsSwitch(
          '启用 Claude 1 小时提示缓存',
          '启用后，Claude 和 Claude 兼容供应商的提示缓存 TTL 将使用 1 小时',
          claudeCache,
          onChanged: (value) => setState(() => claudeCache = value),
        ),
      ModelSettingsSwitch(
        '原生工具调用（ToolCall）',
        '开启：通过所选 API 协议发送工具定义，需要当前端点和模型支持。关闭：使用提示词 XML 工具调用，仍可使用工具。扩展工具均需先激活对应包。连接测试按当前流式与思考设置验证真实调用及结果续答；切换后建议重新测试。',
        toolCall,
        onChanged: (value) => setState(() => toolCall = value),
      ),
    ],
  );
}

/// 与旧 EndpointCompleter 相同的地址预览；不建立请求或验证服务可用性。
String completeModelEndpointPreview(
  String endpoint,
  ModelApiProtocol protocol,
) {
  final trimmed = endpoint.trim();
  if (trimmed.endsWith('#')) return trimmed.substring(0, trimmed.length - 1);
  if (protocol == ModelApiProtocol.native) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return endpoint;
  }
  final path = uri.path.replaceFirst(RegExp(r'/$'), '');
  final base = trimmed.replaceFirst(RegExp(r'/$'), '');
  final suffix = switch (protocol) {
    ModelApiProtocol.chat => 'chat/completions',
    ModelApiProtocol.responses => 'responses',
    ModelApiProtocol.messages => 'messages',
    ModelApiProtocol.native => '',
  };
  if (path.isEmpty ||
      (protocol == ModelApiProtocol.messages &&
          path.toLowerCase().endsWith('/anthropic'))) {
    return '$base/v1/$suffix';
  }
  if (path.toLowerCase().endsWith('/v1')) return '$base/$suffix';
  return endpoint;
}

class _ApiKeyController extends TextEditingController {
  _ApiKeyController(this.focus) {
    focus.addListener(notifyListeners);
  }
  final FocusNode focus;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (focus.hasFocus || text.length <= 8) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      text:
          '${text.substring(0, 4)}${'*' * (text.length - 8)}${text.substring(text.length - 4)}',
    );
  }

  @override
  void dispose() {
    focus.removeListener(notifyListeners);
    super.dispose();
  }
}
