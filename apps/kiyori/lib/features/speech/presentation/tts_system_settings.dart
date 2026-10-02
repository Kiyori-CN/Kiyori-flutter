import 'package:flutter/material.dart';

import 'tts_draft.dart';
import 'tts_fields.dart';
import 'tts_presentation.dart';
import 'tts_strings.dart';

class TtsSystemSettings extends StatefulWidget {
  const TtsSystemSettings({
    required this.draft,
    required this.catalog,
    this.clearVoiceWithSystemLocale = false,
    super.key,
  });
  final TtsDraft draft;
  final TtsCatalogPresentation catalog;
  final bool clearVoiceWithSystemLocale;
  @override
  State<TtsSystemSettings> createState() => _TtsSystemSettingsState();
}

class _TtsSystemSettingsState extends State<TtsSystemSettings> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final voices = widget.catalog.systemVoices;
    final selected = voices.where((v) => v.id == d['voice'].text).firstOrNull;
    final locales =
        voices.map((v) => v.locale).where((v) => v.isNotEmpty).toSet().toList()
          ..sort();
    if (d.locale.isNotEmpty && !locales.contains(d.locale)) {
      locales.add(d.locale);
    }
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ttsHeading(ttsText('simple_tts_settings')),
        const SizedBox(height: 8),
        Text(
          ttsText('simple_tts_desc'),
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(d.locale),
          initialValue: d.locale,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: ttsText('simple_tts_locale'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(ttsText('simple_tts_locale_follow_system')),
            ),
            for (final locale in locales)
              DropdownMenuItem(value: locale, child: Text(locale)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                d.locale = value;
                if ((value.isEmpty && widget.clearVoiceWithSystemLocale) ||
                    (value.isNotEmpty &&
                        selected?.locale.toLowerCase() !=
                            value.toLowerCase())) {
                  d['voice'].clear();
                }
              });
            }
          },
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(
            labelText: ttsText('simple_tts_voice'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (d['voice'].text.isNotEmpty)
                  IconButton(
                    tooltip: ttsText('simple_tts_voice_clear'),
                    onPressed: () => setState(d['voice'].clear),
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: ttsText('simple_tts_voice_select'),
                  icon: const Icon(Icons.format_list_bulleted),
                  onPressed: () async {
                    final choice = await showDialog<SpeechVoiceOption>(
                      context: context,
                      builder: (_) => TtsOptionDialog(
                        title: ttsText('simple_tts_voice_select'),
                        options: voices
                            .where(
                              (v) =>
                                  d.locale.isEmpty ||
                                  v.locale.toLowerCase() ==
                                      d.locale.toLowerCase(),
                            )
                            .toList(),
                        search: false,
                        system: true,
                      ),
                    );
                    if (!mounted || choice == null) return;
                    setState(() {
                      d['voice'].text = choice.id;
                      if (d.locale.isEmpty && choice.id.isNotEmpty) {
                        d.locale = choice.locale;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          child: Text(
            selected == null
                ? ttsText('simple_tts_voice_default')
                : '${selected.name} (${selected.locale})',
          ),
        ),
        if (widget.catalog.systemLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ttsText('simple_tts_loading'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.catalog.systemError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(fontSize: 12, color: colors.error),
            ),
          ),
      ],
    );
  }
}
