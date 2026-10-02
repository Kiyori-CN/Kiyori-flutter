import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'speech_profiles.dart';
import 'tts_draft.dart';
import 'tts_fields.dart';
import 'tts_presentation.dart';
import 'tts_strings.dart';
import 'tts_system_settings.dart';

class TtsSettingsPage extends StatefulWidget {
  const TtsSettingsPage({
    this.profiles = const [TtsProfilePresentation.initial],
    this.activeId = 'builtin-next-tts',
    this.catalog = const TtsCatalogPresentation(),
    this.onTest = emptyAction,
    super.key,
  });
  final List<TtsProfilePresentation> profiles;
  final String activeId;
  final TtsCatalogPresentation catalog;
  final VoidCallback onTest;
  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  late String selected = widget.profiles.any((p) => p.id == widget.activeId)
      ? widget.activeId
      : widget.profiles.firstOrNull?.id ?? '';
  final drafts = <String, TtsDraft>{};
  final picker = TtsOptionSession();
  TtsDraft get draft => drafts.putIfAbsent(
    selected,
    () => TtsDraft(
      widget.profiles.where((p) => p.id == selected).firstOrNull ??
          const TtsProfilePresentation(id: '', name: ''),
    ),
  );
  @override
  void dispose() {
    picker.close();
    for (final draft in drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(TtsSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.profiles.map((p) => p.id).toSet();
    final previous = selected;
    for (final id in drafts.keys.where((id) => !ids.contains(id)).toList()) {
      final removed = drafts.remove(id);
      WidgetsBinding.instance.addPostFrameCallback((_) => removed?.dispose());
    }
    for (final profile in widget.profiles) {
      final current = drafts[profile.id];
      if (profile.id == selected &&
          current != null &&
          (current.source.engine != profile.engine ||
              current.source.endpoint != profile.endpoint ||
              current.source.apiKey != profile.apiKey ||
              current.source.voice != profile.voice ||
              current.source.model != profile.model)) {
        picker.close();
      }
      current?.update(profile);
    }
    if (oldWidget.activeId != widget.activeId || !ids.contains(selected)) {
      selected = ids.contains(widget.activeId)
          ? widget.activeId
          : widget.profiles.firstOrNull?.id ?? '';
    }
    if (previous != selected ||
        !sameSpeechOptions(oldWidget.catalog.models, widget.catalog.models) ||
        !sameSpeechOptions(oldWidget.catalog.voices, widget.catalog.voices)) {
      picker.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = draft;
    final engine = current.engine;
    return SettingsDetailPage(
      title: '文本转语音',
      children: [
        if (widget.catalog.saveError case final error?)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.profiles.isNotEmpty)
          SpeechProfiles(
            profiles: widget.profiles.map((p) => p.option).toList(),
            selected: selected,
            onSelect: (id) {
              picker.close();
              setState(() => selected = id);
            },
          ),
        SettingsGroup(
          title: ttsText('tts_title'),
          description: ttsText('tts_desc'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                key: ValueKey(selected),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '服务类型',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<TtsEngine>(
                    key: ValueKey('tts-engine-$selected-${engine.name}'),
                    initialValue: engine,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: ttsText('tts_engine'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: [
                      for (final value in TtsEngine.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        picker.close();
                        setState(() => current.selectEngine(value));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _slider(
                    '语速',
                    current.rate,
                    (value) => setState(() => current.rate = value),
                  ),
                  const SizedBox(height: 12),
                  _slider(
                    '音调',
                    current.pitch,
                    (value) => setState(() => current.pitch = value),
                  ),
                  const SizedBox(height: 16),
                  if (engine == TtsEngine.simple)
                    TtsSystemSettings(draft: current, catalog: widget.catalog),
                  _cleaners(current),
                  const SizedBox(height: 8),
                  if (engine != TtsEngine.simple) const SizedBox(height: 16),
                  if (engine == TtsEngine.http) _http(current),
                  if (engine == TtsEngine.vits) _vits(current),
                  if (engine == TtsEngine.siliconflow)
                    _silicon(context, current),
                  if (engine == TtsEngine.minimax)
                    _provider(current, 'minimax'),
                  if (engine == TtsEngine.mimo) _mimo(context, current),
                  if (engine == TtsEngine.doubao) _doubao(context, current),
                  if (engine == TtsEngine.openaiWs)
                    _openAi(context, current, realtime: true),
                  if (engine == TtsEngine.openai) _openAi(context, current),
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
                      '文本转语音 (TTS)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'TTS 服务将文本转换为语音。您可以使用内置系统 TTS，或连接远程 HTTP / WebSocket 语音接口。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: ttsText('tools_title'),
          description: ttsText('tools_desc'),
          children: [
            SettingsRow(
              title: ttsText('test_tts'),
              description: ttsText('test_tts_desc'),
              onTap: widget.onTest,
            ),
          ],
        ),
      ],
    );
  }

  Widget _slider(String title, double value, ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$title: ${value.toStringAsFixed(2)}x'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Slider(
              value: value,
              min: .5,
              max: 2,
              divisions: 6,
              onChanged: onChanged,
            ),
          ),
        ],
      );
  Widget _http(TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ttsHeading(ttsText('http_tts_config')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'endpoint',
        label: ttsText('http_url_template'),
        hint: ttsText('http_url_placeholder'),
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'key',
        label: ttsText('http_api_key'),
        hint: ttsText('http_api_key_placeholder'),
        secret: true,
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'headers',
        label: ttsText('http_headers'),
        hint: ttsText('http_headers_placeholder'),
        lines: 2,
        jsonError: ttsText('http_headers_error'),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final method = DropdownButtonFormField<String>(
            key: ValueKey(d.method),
            initialValue: d.method,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: ttsText('http_method'),
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'GET', child: Text('GET')),
              DropdownMenuItem(value: 'POST', child: Text('POST')),
            ],
            onChanged: (v) => setState(() => d.method = v ?? 'GET'),
          );
          final type = TtsField(
            draft: d,
            field: 'contentType',
            label: ttsText('http_content_type'),
            hint: ttsText('http_content_type_placeholder'),
          );
          if (constraints.maxWidth <
              240 * MediaQuery.textScalerOf(context).scale(1)) {
            return Column(children: [method, const SizedBox(height: 8), type]);
          }
          return Row(
            children: [
              Expanded(child: method),
              const SizedBox(width: 8),
              Expanded(child: type),
            ],
          );
        },
      ),
      if (d.method == 'POST') ...[
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'body',
          label: ttsText('http_request_body'),
          hint: ttsText('http_request_body_placeholder'),
          lines: 3,
        ),
      ],
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'pipeline',
        label: ttsText('http_response_pipeline'),
        hint: ttsText('http_response_pipeline_placeholder'),
        help: ttsText('http_response_pipeline_hint'),
        lines: 6,
        jsonError: ttsText('http_response_pipeline_error'),
      ),
    ],
  );
  Widget _vits(TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ttsHeading(ttsText('vits_config')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'packagePath',
        label: ttsText('vits_package_path'),
        hint: ttsText('vits_package_path_placeholder'),
        help: ttsText('vits_package_path_hint'),
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'speaker',
        label: ttsText('vits_speaker_id'),
        hint: ttsText('vits_speaker_id_placeholder'),
        help: ttsText('vits_speaker_id_hint'),
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'options',
        label: ttsText('vits_options'),
        hint: ttsText('vits_options_placeholder'),
        help: ttsText('vits_options_hint'),
        lines: 5,
        jsonError: ttsText('vits_options_error'),
      ),
    ],
  );
  Widget _provider(TtsDraft d, String kind, {Widget? voiceSelector}) {
    final p = kind == 'minimax' ? 'minimax' : 'mimo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ttsHeading(ttsText('${p}_config')),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'endpoint',
          label: ttsText('${p}_url'),
          hint: ttsText('${p}_url_placeholder'),
          help: ttsText('${p}_url_hint'),
        ),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'key',
          label: ttsText('${p}_api_key'),
          hint: ttsText('${p}_api_key_placeholder'),
          secret: true,
        ),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'model',
          label: ttsText('${p}_model_name'),
          hint: ttsText('${p}_model_name_placeholder'),
          help: ttsText('${p}_model_name_hint'),
        ),
        const SizedBox(height: 8),
        if (voiceSelector != null) ...[
          voiceSelector,
          const SizedBox(height: 8),
        ],
        TtsField(
          draft: d,
          field: 'voice',
          label: ttsText('${p}_voice_id'),
          hint: ttsText('${p}_voice_id_placeholder'),
          help: ttsText('${p}_voice_id_hint'),
        ),
      ],
    );
  }

  Widget _silicon(BuildContext context, TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ttsHeading(ttsText('siliconflow_config')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'key',
        label: ttsText('siliconflow_api_key'),
        hint: ttsText('siliconflow_api_key_placeholder'),
        secret: true,
      ),
      const SizedBox(height: 16),
      ttsHeading(ttsText('siliconflow_model_settings')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'model',
        label: ttsText('siliconflow_model_name'),
        hint: ttsText('siliconflow_model_name_placeholder'),
        help: ttsText('siliconflow_model_name_hint'),
      ),
      const SizedBox(height: 16),
      ttsHeading(ttsText('siliconflow_voice_settings')),
      const SizedBox(height: 8),
      _voiceDropdown(
        d,
        TtsCatalogPresentation.siliconVoices,
        ttsText('siliconflow_voice_select'),
        namesOnly: true,
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'voice',
        label: ttsText('siliconflow_voice_id'),
        hint: ttsText('siliconflow_voice_id_placeholder'),
        help: ttsText('siliconflow_voice_id_hint'),
      ),
    ],
  );
  Widget _mimo(BuildContext context, TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _provider(
        d,
        'mimo',
        voiceSelector: _voiceDropdown(
          d,
          TtsCatalogPresentation.mimoVoices,
          ttsText('mimo_voice_select'),
        ),
      ),
    ],
  );
  Widget _doubao(BuildContext context, TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ttsHeading(ttsText('doubao_config')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'endpoint',
        label: ttsText('doubao_url'),
        hint: ttsText('doubao_url_placeholder'),
        help: ttsText('doubao_url_hint'),
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'model',
        label: ttsText('doubao_appid'),
        hint: ttsText('doubao_appid_placeholder'),
      ),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'key',
        label: ttsText('doubao_token'),
        hint: ttsText('doubao_token_placeholder'),
        secret: true,
      ),
      const SizedBox(height: 8),
      _voiceDropdown(d, const [
        SpeechVoiceOption('BV700_V2_streaming', 'BV700_V2_streaming'),
      ], ttsText('doubao_voice_select')),
      const SizedBox(height: 8),
      TtsField(
        draft: d,
        field: 'voice',
        label: ttsText('doubao_voice_id'),
        hint: ttsText('doubao_voice_id_placeholder'),
        help: ttsText('doubao_voice_id_hint'),
      ),
    ],
  );
  Widget _openAi(BuildContext context, TtsDraft d, {bool realtime = false}) {
    final p = realtime ? 'openai_ws' : 'openai';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ttsHeading(ttsText('${p}_config')),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'endpoint',
          label: ttsText('${p}_url'),
          hint: ttsText('${p}_url_placeholder'),
          help: ttsText('${p}_url_hint'),
        ),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'key',
          label: ttsText('openai_api_key'),
          hint: ttsText('openai_api_key_placeholder'),
          secret: true,
        ),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'model',
          label: ttsText('openai_model'),
          hint: ttsText(
            realtime
                ? 'openai_ws_model_placeholder'
                : 'openai_model_placeholder',
          ),
          help: realtime ? ttsText('openai_ws_model_hint') : null,
          suffix: realtime ? null : _remotePicker(context, d, models: true),
        ),
        if (!realtime && widget.catalog.modelsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.catalog.modelsError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        ttsHeading(ttsText('openai_voice_settings')),
        const SizedBox(height: 8),
        TtsField(
          draft: d,
          field: 'voice',
          label: ttsText('openai_voice_id'),
          hint: ttsText(
            realtime
                ? 'openai_ws_voice_id_placeholder'
                : 'openai_voice_id_placeholder',
          ),
          help: realtime ? ttsText('openai_ws_voice_id_hint') : null,
          suffix: !realtime
              ? _remotePicker(context, d)
              : _voiceButton(
                  context,
                  d,
                  realtime
                      ? TtsCatalogPresentation.realtimeVoices
                      : widget.catalog.voices,
                  ttsText('openai_voice_select'),
                ),
        ),
        if (!realtime && widget.catalog.voicesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.catalog.voicesError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _voiceDropdown(
    TtsDraft d,
    List<SpeechVoiceOption> options,
    String title, {
    bool namesOnly = false,
  }) => ValueListenableBuilder(
    valueListenable: d['voice'],
    builder: (context, value, _) {
      final selectedVoice = options
          .where((v) => v.id == value.text)
          .firstOrNull;
      return DropdownButtonFormField<String>(
        key: ValueKey('$title-${value.text}'),
        initialValue: selectedVoice?.id,
        isExpanded: true,
        hint: const Text('自定义音色'),
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
        selectedItemBuilder: (_) => [
          for (final voice in options) Text(voice.name),
        ],
        items: [
          for (final voice in options)
            DropdownMenuItem(
              value: voice.id,
              child: Text(
                namesOnly ? voice.name : '${voice.name} (${voice.id})',
              ),
            ),
        ],
        onChanged: (id) {
          if (id != null) d['voice'].text = id;
        },
      );
    },
  );

  Widget _remotePicker(
    BuildContext context,
    TtsDraft d, {
    bool models = false,
  }) {
    final options = models ? widget.catalog.models : widget.catalog.voices;
    final loading = models
        ? widget.catalog.modelsLoading
        : widget.catalog.voicesLoading;
    return ListenableBuilder(
      listenable: Listenable.merge([d['endpoint'], d['key']]),
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: models ? '刷新模型列表' : '刷新音色列表',
            onPressed:
                !loading &&
                    d['endpoint'].text.trim().isNotEmpty &&
                    d['key'].text.trim().isNotEmpty
                ? emptyAction
                : null,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
          ),
          IconButton(
            tooltip: models ? '可用模型列表' : '选择音色',
            onPressed: models && options.isEmpty
                ? null
                : () async {
                    final engine = d.engine;
                    final choice = await picker.show(
                      context,
                      (_) => TtsOptionDialog(
                        title: models ? '选择模型' : '选择预设音色',
                        options: options,
                        models: models,
                      ),
                    );
                    if (mounted &&
                        choice != null &&
                        identical(drafts[selected], d) &&
                        d.engine == engine &&
                        (models ? widget.catalog.models : widget.catalog.voices)
                            .any((option) => option.id == choice.id)) {
                      d[models ? 'model' : 'voice'].text = choice.id;
                    }
                  },
            icon: const Icon(Icons.format_list_bulleted),
          ),
        ],
      ),
    );
  }

  Widget _voiceButton(
    BuildContext context,
    TtsDraft d,
    List<SpeechVoiceOption> options,
    String title,
  ) => IconButton(
    tooltip: title,
    icon: const Icon(Icons.format_list_bulleted),
    onPressed: () async {
      final engine = d.engine;
      final voice = await picker.show(
        context,
        (_) => TtsOptionDialog(title: title, options: options),
      );
      if (mounted &&
          voice != null &&
          identical(drafts[selected], d) &&
          d.engine == engine) {
        d['voice'].text = voice.id;
      }
    },
  );
  Widget _cleaners(TtsDraft d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        ttsText('tts_cleaner_title'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 4),
      Text(ttsText('tts_cleaner_desc'), style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      for (var i = 0; i < d.cleaners.length; i++) ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ObjectKey(d.cleaners[i]),
                controller: d.cleaners[i],
                decoration: InputDecoration(
                  hintText: ttsText('tts_cleaner_placeholder'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: ttsText('tts_cleaner_delete'),
              onPressed: () {
                final removed = d.cleaners[i];
                setState(() => d.cleaners.removeAt(i));
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => removed.dispose(),
                );
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  setState(() => d.cleaners.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: Text(ttsText('tts_cleaner_add')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PopupMenuButton<String>(
              key: const ValueKey('tts-template'),
              tooltip: ttsText('tts_cleaner_template'),
              onSelected: (value) => setState(
                () => d.cleaners.add(TextEditingController(text: value)),
              ),
              itemBuilder: (_) => [
                for (final template in const [
                  ('asterisk', r'\*[^*]+\*'),
                  ('double_asterisk', r'\*\*[^*]+\*\*'),
                  ('parenthesis', r'\([^)]+\)'),
                  ('chinese_parenthesis', '（[^）]+）'),
                  ('xml', '<[^>]+>'),
                ])
                  PopupMenuItem(
                    value: template.$2,
                    child: Text(ttsText('tts_cleaner_template_${template.$1}')),
                  ),
              ],
              child: IgnorePointer(
                child: OutlinedButton(
                  onPressed: emptyAction,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(ttsText('tts_cleaner_template'))),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
