import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 原语言清单快照；点击不修改 locale 或重启应用。
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({this.selected = 'zh', super.key});
  final String selected;
  static const languages = [
    ('system', 'Follow system', '跟随系统'),
    ('zh', 'Chinese', '中文'),
    ('en', 'English', 'English'),
    ('ko', 'Korean', '한국어'),
    ('es', 'Spanish', 'Español'),
    ('ms', 'Malay', 'Bahasa Melayu'),
    ('id', 'Indonesian', 'Bahasa Indonesia'),
    ('pt-BR', 'Portuguese (Brazil)', 'Português (Brasil)'),
  ];
  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '语言设置',
    onBack: () => Navigator.maybePop(context),
    body: ListView(
      primary: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            '选择语言',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        for (final language in languages) ...[
          InkWell(
            onTap: emptyAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.language, color: IconTone.browser.icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(language.$2, style: const TextStyle(fontSize: 16)),
                        Text(
                          language.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            color: PrimaryColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (language.$1 == selected)
                    const Icon(Icons.check, color: PrimaryColors.accent),
                ],
              ),
            ),
          ),
          Divider(
            height: .5,
            thickness: .5,
            color: PrimaryColors.text.withValues(alpha: .1),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '更改语言后，应用将自动重启以应用新的语言设置',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
