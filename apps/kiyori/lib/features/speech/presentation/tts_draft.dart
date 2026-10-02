import 'dart:convert';

import 'package:flutter/material.dart';

import 'tts_presentation.dart';

class TtsDraft {
  TtsDraft(TtsProfilePresentation profile)
    : engine = profile.engine,
      rate = profile.rate,
      pitch = profile.pitch,
      method = profile.method,
      locale = profile.locale,
      fields = {
        'endpoint': TextEditingController(text: profile.endpoint),
        'key': TextEditingController(text: profile.apiKey),
        'headers': TextEditingController(text: profile.headers),
        'body': TextEditingController(text: profile.body),
        'contentType': TextEditingController(text: profile.contentType),
        'voice': TextEditingController(text: profile.voice),
        'model': TextEditingController(text: profile.model),
        'pipeline': TextEditingController(text: profile.pipeline),
        'packagePath': TextEditingController(text: profile.packagePath),
        'speaker': TextEditingController(text: profile.speaker),
        'options': TextEditingController(text: profile.options),
      },
      cleaners = profile.cleaners
          .map((text) => TextEditingController(text: text))
          .toList();
  TtsEngine engine;
  double rate, pitch;
  String method, locale;
  bool keyVisible = false;
  final Map<String, TextEditingController> fields;
  final List<TextEditingController> cleaners;
  TextEditingController operator [](String key) => fields[key]!;

  void selectEngine(TtsEngine value) {
    engine = value;
    if (value == TtsEngine.doubao) {
      this['endpoint'].text = 'https://openspeech.bytedance.com/api/v1/tts';
      this['voice'].text = 'BV700_V2_streaming';
      this['contentType'].text = 'application/json';
    }
  }

  void dispose() {
    for (final controller in [...fields.values, ...cleaners]) {
      controller.dispose();
    }
  }
}

// 仅验证输入外观，不执行管线或提供业务解析结果。
bool validSpeechJson(String text, {bool pipeline = false}) {
  if (text.trim().isEmpty) return true;
  bool stringMap(Object? value) =>
      value is Map && value.values.every((v) => v is String);
  try {
    final value = jsonDecode(text);
    if (!pipeline) return stringMap(value);
    return value is List &&
        value.every(
          (step) =>
              step is Map &&
              step['type'] is String &&
              (!step.containsKey('path') || step['path'] is String) &&
              (!step.containsKey('headers') || stringMap(step['headers'])),
        );
  } on FormatException {
    return false;
  }
}
