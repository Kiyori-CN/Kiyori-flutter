import 'package:flutter/material.dart';

import 'prompt_presentation.dart';

/// 角色目录复用提示词owner；消息与生成阶段由助手owner提供，UI不解析或执行工具文本。
class PersonaPresentation {
  const PersonaPresentation({
    this.catalog = const PromptsPresentation(),
    this.messages = const {},
    this.generating = const {},
    this.limitPromptId,
  });
  final PromptsPresentation catalog;
  final Map<String, List<PersonaMessage>> messages;
  final Set<String> generating;
  final String? limitPromptId;
}

class PersonaMessage {
  const PersonaMessage({
    required this.id,
    required this.content,
    required this.time,
    this.user = false,
  });
  final String id, content, time;
  final bool user;
}

class PersonaCardDraft {
  PersonaCardDraft(CharacterPresentation card)
    : source = values(card),
      fields = values(card)
          .map((value) => TextEditingController(text: value))
          .toList();
  List<String> source;
  final List<TextEditingController> fields;
  final input = TextEditingController();
  static List<String> values(CharacterPresentation card) => [
    card.name,
    card.description,
    card.setting,
    card.opening,
    card.chat,
    card.voice,
    card.custom,
    card.marks,
  ];
  void update(CharacterPresentation card) {
    final next = values(card);
    for (var i = 0; i < next.length; i++) {
      if (next[i] != source[i]) fields[i].text = next[i];
    }
    source = next;
  }

  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    input.dispose();
  }
}
