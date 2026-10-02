import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tts_presentation.dart';

class TtsDraft {
  TtsDraft(TtsProfilePresentation profile)
    : source = profile,
      engine = profile.engine,
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
  TtsProfilePresentation source;
  TextEditingController operator [](String key) => fields[key]!;

  void update(TtsProfilePresentation next) {
    final old = source;
    if (old.engine != next.engine) engine = next.engine;
    if (old.rate != next.rate) rate = next.rate;
    if (old.pitch != next.pitch) pitch = next.pitch;
    if (old.method != next.method) method = next.method;
    if (old.locale != next.locale) locale = next.locale;
    if (old.apiKey != next.apiKey) keyVisible = false;
    for (final value in [
      ('endpoint', old.endpoint, next.endpoint),
      ('key', old.apiKey, next.apiKey),
      ('headers', old.headers, next.headers),
      ('body', old.body, next.body),
      ('contentType', old.contentType, next.contentType),
      ('voice', old.voice, next.voice),
      ('model', old.model, next.model),
      ('pipeline', old.pipeline, next.pipeline),
      ('packagePath', old.packagePath, next.packagePath),
      ('speaker', old.speaker, next.speaker),
      ('options', old.options, next.options),
    ]) {
      if (value.$2 != value.$3) this[value.$1].text = value.$3;
    }
    if (!listEquals(old.cleaners, next.cleaners)) {
      final removed = cleaners.toList();
      cleaners
        ..clear()
        ..addAll(
          next.cleaners.map((text) => TextEditingController(text: text)),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in removed) {
          controller.dispose();
        }
      });
    }
    source = next;
  }

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
