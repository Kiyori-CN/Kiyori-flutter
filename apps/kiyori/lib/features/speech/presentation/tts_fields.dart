import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'tts_draft.dart';
import 'tts_presentation.dart';
import 'tts_strings.dart';

class TtsField extends StatelessWidget {
  const TtsField({
    required this.draft,
    required this.field,
    required this.label,
    this.hint,
    this.help,
    this.lines = 1,
    this.jsonError,
    this.secret = false,
    this.rounded = false,
    this.suffix,
    super.key,
  });
  final TtsDraft draft;
  final String field, label;
  final String? hint, help, jsonError;
  final int lines;
  final bool secret, rounded;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: draft[field],
    builder: (context, value, _) => _TtsInput(
      draft: draft,
      controller: draft[field],
      field: field,
      label: label,
      hint: hint,
      help: help,
      lines: lines,
      secret: secret,
      rounded: rounded,
      suffix: suffix,
      error:
          jsonError != null &&
              !validSpeechJson(value.text, pipeline: field == 'pipeline')
          ? jsonError
          : null,
    ),
  );
}

class _TtsInput extends StatefulWidget {
  const _TtsInput({
    required this.draft,
    required this.controller,
    required this.field,
    required this.label,
    required this.hint,
    required this.help,
    required this.lines,
    required this.secret,
    required this.rounded,
    required this.suffix,
    required this.error,
  });
  final TextEditingController controller;
  final TtsDraft draft;
  final String field, label;
  final String? hint, help, error;
  final int lines;
  final bool secret, rounded;
  final Widget? suffix;
  @override
  State<_TtsInput> createState() => _TtsInputState();
}

class _TtsInputState extends State<_TtsInput> {
  bool get visible => widget.draft.keyVisible;
  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('tts-${widget.field}'),
    controller: widget.controller,
    minLines: widget.lines,
    maxLines: widget.lines == 1 ? 1 : null,
    obscureText: widget.secret && !visible,
    enableSuggestions: !widget.secret,
    autocorrect: !widget.secret,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.help,
      helperMaxLines: 20,
      errorText: widget.error,
      errorMaxLines: 5,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          widget.rounded || widget.secret ? 14 : 4,
        ),
      ),
      suffixIcon: widget.secret
          ? IconButton(
              tooltip: visible ? '隐藏密钥' : '显示密钥',
              onPressed: () =>
                  setState(() => widget.draft.keyVisible = !visible),
              icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
            )
          : widget.suffix,
    ),
  );
}

Widget ttsHeading(String text) => Text(
  text,
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
);

class TtsOptionDialog extends StatefulWidget {
  const TtsOptionDialog({
    required this.title,
    required this.options,
    this.search = true,
    this.system = false,
    this.models = false,
    super.key,
  });
  final String title;
  final List<SpeechVoiceOption> options;
  final bool search, system, models;
  @override
  State<TtsOptionDialog> createState() => _TtsOptionDialogState();
}

class _TtsOptionDialogState extends State<TtsOptionDialog> {
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.text.trim().toLowerCase();
    final options = widget.options
        .where(
          (v) =>
              v.id.toLowerCase().contains(q) ||
              v.name.toLowerCase().contains(q),
        )
        .toList();
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        height: (MediaQuery.sizeOf(context).height * .55).clamp(180, 420),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height * .55).clamp(
              120,
              420,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.search) ...[
                KiyoriSearchField(
                  controller: query,
                  showSearchIcon: true,
                  showClear: true,
                  hint: widget.models ? '搜索模型' : '搜索',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (widget.system)
                        TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            const SpeechVoiceOption('', ''),
                          ),
                          child: Text(ttsText('simple_tts_voice_default')),
                        ),
                      if (options.isEmpty && !widget.system)
                        const Text('没有找到可用模型'),
                      for (final option in options)
                        widget.system
                            ? TextButton(
                                onPressed: () => Navigator.pop(context, option),
                                child: Text(
                                  '${option.name} (${option.locale})',
                                ),
                              )
                            : ListTile(
                                title: Text(option.display),
                                onTap: () => Navigator.pop(context, option),
                              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.system ? '取消' : '确定'),
        ),
      ],
    );
  }
}
