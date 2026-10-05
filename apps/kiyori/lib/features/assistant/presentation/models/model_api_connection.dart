import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'api_provider_drawers.dart';
import 'api_provider_presentation.dart';
import 'model_settings_components.dart';
import 'model_tags_editor.dart';
import 'model_edit_session.dart';
import 'model_credentials.dart';
import 'model_options_editing.dart';
import 'upstream_model_drawer.dart';
import 'gguf_import_dialog.dart';

import 'package:kiyori_bridge/kiyori_bridge.dart' show ModelNamesUndo;

class ModelApiConnection extends StatefulWidget {
  const ModelApiConnection({
    this.onOpenLocalModels = emptyAction,
    this.session,
    this.modelFilePicker,
    super.key,
  });
  final ModelEditSession? session;
  final ModelFilePicker? modelFilePicker;
  final VoidCallback onOpenLocalModels;
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
  ModalRoute<dynamic>? _directoryRoute;
  DialogRoute<bool>? _changeRoute;
  final _undos = <ModelNamesUndo>[];
  bool _changingNames = false, _active = true;
  int _namesVersion = 0;
  bool _importing = false;

  Future<void> importGguf() async {
    final session = widget.session;
    if (session == null || _importing || !_active) return;
    _importing = true;
    try {
      if (!await session.flush() || !mounted || !_active) return;
      final name = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GgufImportDialog(
          connect: session.owner.connect,
          picker: widget.modelFilePicker ?? createModelFilePicker(),
        ),
      );
      // 模态退出先让宿主恢复TickerMode；不能把自身弹窗的临时停帧当成页面已离开。
      for (var frame = 0; frame < 30 && mounted; frame++) {
        await WidgetsBinding.instance.endOfFrame;
        if (_active) break;
      }
      if (!mounted ||
          !_active ||
          !identical(widget.session, session) ||
          name == null ||
          session.draft.provider != 'LLAMA_CPP') {
        return;
      }
      if (models.contains(name)) {
        message('模型已导入，可以从本地模型目录选择');
      } else {
        await changeNames([...models, name], success: '模型已导入，可以从本地模型目录选择');
      }
    } finally {
      _importing = false;
    }
  }

  void namesRecovered() {
    final session = widget.session;
    if (mounted && session != null && session.namesVersion != _namesVersion) {
      _namesVersion = session.namesVersion;
      super.setState(() => models = List.of(session.draft.models));
    }
  }

  void invalidateDirectory() {
    final directory = widget.session?.directory;
    if (directory != null) unawaited(directory.cancel());
    final route = _directoryRoute;
    _directoryRoute = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active && !active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_active) invalidateDirectory();
      });
    }
    _active = active;
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> fetchModels() async {
    final session = widget.session;
    if (session == null ||
        session.directory.loading ||
        _changingNames ||
        !_active) {
      return;
    }
    await session.poolTest.pause();
    if (!await session.flush() || !mounted || !_active) return;
    final success = await session.directory.refresh(
      session.draft,
      session.credentials,
      config: session.base,
    );
    if (!mounted || !_active) return;
    if (!success) {
      message(session.directory.error ?? '获取模型目录已取消');
      return;
    }
    final result = await showKiyoriModalDrawer<Set<String>>(
      context,
      onRoute: (route) => _directoryRoute = route,
      builder: (context, dismiss) => UpstreamModelDrawer(
        directory: session.directory,
        existing: List.of(models),
        dismiss: dismiss,
        refresh: () => unawaited(() async {
          final success = await session.directory.refresh(
            session.draft,
            session.credentials,
            config: session.base,
          );
          if (!success &&
              mounted &&
              _active &&
              session.directory.models.isNotEmpty) {
            message(session.directory.error ?? '获取模型目录已取消');
          }
        }()),
      ),
    );
    _directoryRoute = null;
    await session.directory.cancel();
    if (!mounted || !_active || result == null) return;
    // 刷新后的目录可能不同；选择只影响上游存在项，自定义名称保留原顺序。
    final upstream = session.directory.models.map((m) => m.id).toSet();
    final existing = models.toSet();
    final desired = [
      for (final name in models)
        if (!upstream.contains(name) || result.contains(name)) name,
      for (final entry in session.directory.models)
        if (result.contains(entry.id) && !existing.contains(entry.id)) entry.id,
    ];
    await changeNames(desired, upstream: true);
  }

  Future<bool> confirm(String title, String content, String action) async {
    if (_changeRoute != null) return false;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    _changeRoute = route;
    final result = await Navigator.of(context).push(route);
    if (identical(_changeRoute, route)) _changeRoute = null;
    return mounted && _active && result == true;
  }

  Future<void> changeNames(
    List<String> desired, {
    bool clear = false,
    bool upstream = false,
    String? success,
  }) async {
    final session = widget.session;
    if (_changingNames || !_active) return;
    if (session == null) {
      setState(() => models = desired);
      return;
    }
    _changingNames = true;
    try {
      await session.poolTest.pause();
      if (!await session.flush() || !mounted || !_active) return;
      final before = List<String>.of(models);
      final removed = before.where((m) => !desired.contains(m)).toSet();
      final runtime = await session.owner.connect();
      final catalog = await runtime.modelCatalog();
      final prompts = await runtime.promptCatalog();
      if (!mounted || !_active) return;
      final functions = catalog.functions
          .where(
            (f) =>
                f.configId == session.base.id && removed.contains(f.modelName),
          )
          .length;
      final characters = prompts.characters
          .where(
            (c) =>
                c.draft.modelConfig == session.base.id &&
                removed.contains(c.draft.modelName),
          )
          .length;
      final bound = functions + characters;
      if (bound > 0 && desired.isEmpty) {
        await confirm(
          '无法移除全部模型',
          '仍有 $functions 项功能和 $characters 张角色卡使用这些模型，请至少保留一个模型。',
          '知道了',
        );
        return;
      }
      if (bound > 0 &&
          !await confirm(
            upstream ? '应用模型选择更改？' : '删除已绑定的模型？',
            '将移除 ${removed.length} 个模型，其中影响 $functions 项功能和 $characters 张角色卡。这些绑定将改用新的测试模型“${desired.first}”。',
            upstream ? '应用更改' : '删除',
          )) {
        return;
      }
      if (clear &&
          !await confirm(
            '清空模型列表？',
            '将移除当前配置中的全部 ${models.length} 个模型。此操作可以立即撤销。',
            '清空全部',
          )) {
        return;
      }
      if (!mounted || !_active) return;
      final undo = await session.changeNames(
        desired,
        replacement: bound > 0 ? desired.first : null,
      );
      if (!mounted) {
        undo.close();
        return;
      }
      super.setState(() => models = List.of(session.draft.models));
      if (upstream) {
        undo.close();
        final added = desired.where((name) => !before.contains(name)).length;
        message('已添加 $added 个模型，移除 ${removed.length} 个模型');
        return;
      }
      _undos.add(undo);
      final notification = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ?? (clear ? '已清空模型列表' : '模型已删除')),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              if (!mounted || !_active) return;
              _undos.remove(undo);
              try {
                await session.undoNames(undo);
                if (mounted) {
                  super.setState(() => models = List.of(session.draft.models));
                }
              } on ModelNamesCommittedException {
                message('撤销已提交，但结果读取失败；请重新载入后核对');
              } catch (_) {
                message('撤销失败：配置或绑定已发生变化，请重新核对');
              } finally {
                _undos.remove(undo);
                undo.close();
              }
            },
          ),
        ),
      );
      unawaited(
        notification.closed.then((_) {
          if (_undos.remove(undo)) undo.close();
        }),
      );
    } on ModelNamesCommittedException {
      message('模型更改已提交，但结果读取失败；请重新载入后核对');
    } catch (_) {
      message('模型操作未能保存，原列表已保留；请核对绑定和配置后重试');
    } finally {
      _changingNames = false;
    }
  }

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session == null) return;
    final d = session.draft, o = d.options;
    protocol = ModelApiProtocol.values.byName(d.protocol);
    provider =
        builtInApiProviders.where((p) => p.id == d.provider).firstOrNull ??
        ApiProviderPresentation(d.provider, d.provider, '', protocol, [
          ProviderProtocolPresentation(protocol, '', d.endpoint),
        ]);
    endpoint.text = d.endpoint;
    apiKey.text = session.credentials.apiKey;
    models = List.of(d.models);
    threads.text = o.mnnThreads.toString();
    llamaThreads.text = o.llamaThreads.toString();
    llamaContext.text = o.llamaContext.toString();
    llamaGpu.text = o.llamaGpuLayers.toString();
    forward = o.mnnForward;
    image = o.image;
    audio = o.audio;
    video = o.video;
    googleSearch = o.googleSearch;
    claudeCache = o.claudeCache;
    toolCall = o.toolCall;
    session.readers[this] = capture;
    _namesVersion = session.namesVersion;
    session.addListener(namesRecovered);
    for (final c in [
      endpoint,
      apiKey,
      threads,
      llamaThreads,
      llamaContext,
      llamaGpu,
    ]) {
      c.addListener(session.changed);
    }
    endpoint.addListener(invalidateDirectory);
    apiKey.addListener(invalidateDirectory);
  }

  void capture() {
    final s = widget.session!;
    s.update(
      provider: provider.id,
      protocol: protocol.name,
      endpoint: endpoint.text,
      models: List.of(models),
      options: s.draft.options.copyWith(
        mnnForward: forward,
        mnnThreads: int.parse(threads.text),
        llamaThreads: int.parse(llamaThreads.text),
        llamaContext: int.parse(llamaContext.text),
        llamaGpuLayers: int.parse(llamaGpu.text),
        image: image,
        audio: audio,
        video: video,
        googleSearch: googleSearch,
        claudeCache: claudeCache,
        toolCall: toolCall,
      ),
    );
    final old = s.credentials;
    s.credentials = ModelCredentials(
      apiKey: apiKey.text,
      headers: old.headers,
      usePool: old.usePool,
      keys: old.keys,
      rotation: old.rotation,
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.session?.changed();
  }

  ProviderProtocolPresentation get route =>
      provider.protocols.firstWhere((entry) => entry.protocol == protocol);

  @override
  void dispose() {
    for (final undo in _undos) {
      undo.close();
    }
    final directoryRoute = _directoryRoute, changeRoute = _changeRoute;
    _directoryRoute = null;
    _changeRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in [directoryRoute, changeRoute]) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    widget.session?.readers.remove(this);
    widget.session?.removeListener(namesRecovered);
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
    invalidateDirectory();
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
          summary: protocol.summary,
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
          onPressed: widget.onOpenLocalModels,
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
        Semantics(
          button: true,
          label: '导入 GGUF 模型',
          child: InkWell(
            onTap: importGguf,
            borderRadius: BorderRadius.circular(8),
            child: const ModelSettingsBanner(
              'llama.cpp 模型需要自行下载（.gguf）。点击此处选择模型文件，导入后在“模型名称”中选择文件名：\n\n默认模型目录：应用私有模型资源',
            ),
          ),
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: PrimaryColors.of(context)
                                                .secondary,
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
                              style: TextStyle(
                                fontSize: 12,
                                color: PrimaryColors.of(context).accent,
                              ),
                            ),
                            Text(
                              '提示: 如果您输入的是基础URL，系统将自动补全路径。如需禁用，请在URL末尾添加#号。',
                              style: TextStyle(
                                fontSize: 12,
                                color: PrimaryColors.of(context).secondary,
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
      if (widget.session case final session?)
        ListenableBuilder(
          listenable: session.directory,
          builder: (context, _) => ModelTagsEditor(
            models: models,
            onChanged: (value) => setState(() => models = value),
            loading: session.directory.loading,
            onFetch: fetchModels,
            onRemove: (name) =>
                changeNames(models.where((m) => m != name).toList()),
            onClear: () => changeNames([], clear: true),
          ),
        )
      else
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
