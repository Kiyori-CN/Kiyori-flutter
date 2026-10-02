import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'speech_profiles.dart';
import 'stt_presentation.dart';

class SttSettingsPage extends StatefulWidget {
  const SttSettingsPage({
    this.profiles = const [
      SttProfilePresentation(id: 'legacy-stt-profile', name: '迁移的 STT 配置'),
    ],
    this.activeId = 'legacy-stt-profile',
    super.key,
  });
  final List<SttProfilePresentation> profiles;
  final String activeId;
  @override
  State<SttSettingsPage> createState() => _SttSettingsPageState();
}

class _SttSettingsPageState extends State<SttSettingsPage> {
  late String selected = widget.profiles.any((p) => p.id == widget.activeId)
      ? widget.activeId
      : widget.profiles.firstOrNull?.id ?? '';
  final drafts = <String, _SttDraft>{};
  _SttDraft get draft => drafts.putIfAbsent(
    selected,
    () => _SttDraft(
      widget.profiles.where((p) => p.id == selected).firstOrNull ??
          const SttProfilePresentation(id: '', name: ''),
    ),
  );
  @override
  void dispose() {
    for (final draft in drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SttSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.profiles.map((p) => p.id).toSet();
    for (final id in drafts.keys.where((id) => !ids.contains(id)).toList()) {
      final removed = drafts.remove(id);
      WidgetsBinding.instance.addPostFrameCallback((_) => removed?.dispose());
    }
    for (final profile in widget.profiles) {
      drafts[profile.id]?.update(profile);
    }
    if (oldWidget.activeId != widget.activeId || !ids.contains(selected)) {
      selected = ids.contains(widget.activeId)
          ? widget.activeId
          : widget.profiles.firstOrNull?.id ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = draft;
    final colors = Theme.of(context).colorScheme;
    final remote = current.engine != SttEngine.sherpa;
    final deepgram = current.engine == SttEngine.deepgram;
    Widget field(
      TextEditingController controller,
      String label,
      String hint, {
      String? supporting,
      bool secret = false,
    }) => TextField(
      controller: controller,
      key: ValueKey('stt-$label'),
      obscureText: secret && !current.visible,
      enableSuggestions: !secret,
      autocorrect: !secret,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: supporting,
        helperMaxLines: 8,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: secret
            ? IconButton(
                tooltip: current.visible ? '隐藏密钥' : '显示密钥',
                onPressed: () =>
                    setState(() => current.visible = !current.visible),
                icon: Icon(
                  current.visible ? Icons.visibility_off : Icons.visibility,
                ),
              )
            : null,
      ),
    );
    return SettingsDetailPage(
      title: '语音转文本',
      children: [
        if (widget.profiles.isNotEmpty)
          SpeechProfiles(
            profiles: widget.profiles.map((p) => p.option).toList(),
            selected: selected,
            onSelect: (id) => setState(() => selected = id),
          ),
        SettingsGroup(
          title: '语音转文本 (STT) 设置',
          description: '配置如何将语音转换为文本',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '服务类型',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<SttEngine>(
                    key: ValueKey(
                      'stt-engine-$selected-${current.engine.name}',
                    ),
                    initialValue: current.engine,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'STT 引擎',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: [
                      for (final engine in SttEngine.values)
                        DropdownMenuItem(
                          value: engine,
                          child: Text(engine.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => current.engine = value);
                    },
                  ),
                  if (remote) ...[
                    const SizedBox(height: 16),
                    Text(
                      deepgram ? 'Deepgram STT 配置' : 'OpenAI STT 配置',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    field(
                      current.endpoint,
                      'URL',
                      deepgram
                          ? '例如：https://api.deepgram.com/v1/listen'
                          : '例如：https://api.openai.com/v1/audio/transcriptions',
                      supporting: deepgram
                          ? '需要填写完整接口地址（例如 https://api.deepgram.com/v1/listen）。'
                          : '需要填写完整接口地址，必须包含 /v1/audio/transcriptions',
                    ),
                    const SizedBox(height: 12),
                    field(
                      current.apiKey,
                      'API 密钥',
                      deepgram ? '例如：dg_******' : '例如：sk-xxxxxx',
                      secret: true,
                    ),
                    const SizedBox(height: 12),
                    field(
                      current.model,
                      'model',
                      deepgram
                          ? '例如：nova-2'
                          : '例如：whisper-1 或 gpt-4o-mini-transcribe',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '支持本地 Sherpa 引擎以及 OpenAI / Deepgram STT（远程）。',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '能力说明',
          description: '了解当前语音能力的配置范围与运行方式',
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '语音转文本 (STT)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'STT 服务将语音转换为文本。支持内置的 Sherpa NCNN 和 Sherpa MNN 引擎，均可在本地设备上运行，不需要网络连接。Sherpa MNN 集成了 VAD（语音活动检测）功能，可提升识别准确性和资源利用效率。',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SttDraft {
  _SttDraft(SttProfilePresentation profile)
    : source = profile,
      engine = profile.engine,
      endpoint = TextEditingController(text: profile.endpoint),
      apiKey = TextEditingController(text: profile.apiKey),
      model = TextEditingController(text: profile.model);
  SttEngine engine;
  final TextEditingController endpoint, apiKey, model;
  bool visible = false;
  SttProfilePresentation source;
  void update(SttProfilePresentation next) {
    if (source.engine != next.engine) engine = next.engine;
    for (final value in [
      (endpoint, source.endpoint, next.endpoint),
      (apiKey, source.apiKey, next.apiKey),
      (model, source.model, next.model),
    ]) {
      if (value.$2 != value.$3) value.$1.text = value.$3;
    }
    if (source.apiKey != next.apiKey) visible = false;
    source = next;
  }

  void dispose() {
    endpoint.dispose();
    apiKey.dispose();
    model.dispose();
  }
}
