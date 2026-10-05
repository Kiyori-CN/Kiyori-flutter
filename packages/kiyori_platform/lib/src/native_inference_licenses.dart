import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// 静态推理库不在pub依赖树中，随产品保存准确的上游许可证全文。
void registerNativeInferenceLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    const entries = {
      'MNN': ['MNN', 'jinja.cpp'],
      'llama.cpp': ['llama.cpp', 'ggml'],
      'llamafile': ['llamafile sgemm'],
      'half': ['half'],
      'flatbuffers': ['FlatBuffers'],
      'RapidJSON': ['RapidJSON'],
      'nlohmann-json': ['nlohmann/json'],
    };
    for (final entry in entries.entries) {
      final text = await rootBundle.loadString(
        'packages/kiyori_platform/assets/licenses/${entry.key}.txt',
      );
      yield LicenseEntryWithLineBreaks(entry.value, text);
    }
  });
}
