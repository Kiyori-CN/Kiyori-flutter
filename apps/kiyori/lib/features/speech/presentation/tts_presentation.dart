import 'speech_profiles.dart';
import 'tts_strings.dart';

enum TtsEngine {
  simple,
  http,
  openaiWs,
  siliconflow,
  minimax,
  mimo,
  doubao,
  openai,
  vits;

  String get label =>
      ttsText('tts_type_${this == openaiWs ? 'openai_ws' : name}');
}

class SpeechVoiceOption {
  const SpeechVoiceOption(this.id, this.name, {this.locale = ''});
  final String id, name, locale;
  String get display => name == id ? name : '$name ($id)';
}

bool sameSpeechOptions(List<SpeechVoiceOption> a, List<SpeechVoiceOption> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].name != b[i].name ||
        a[i].locale != b[i].locale) {
      return false;
    }
  }
  return true;
}

/// 目录和运行状态由外层提供，UI 不读取系统音色或刷新远程目录。
class TtsCatalogPresentation {
  const TtsCatalogPresentation({
    this.systemVoices = const [],
    this.systemLoading = false,
    this.systemError,
    this.models = const [],
    this.modelsLoading = false,
    this.modelsError,
    this.voices = const [],
    this.voicesLoading = false,
    this.voicesError,
    this.saveError,
  });
  final List<SpeechVoiceOption> systemVoices, models, voices;
  final bool systemLoading, modelsLoading, voicesLoading;
  final String? systemError, modelsError, voicesError, saveError;
  static const openAiVoices = [
    SpeechVoiceOption('alloy', 'alloy'),
    SpeechVoiceOption('echo', 'echo'),
    SpeechVoiceOption('fable', 'fable'),
    SpeechVoiceOption('onyx', 'onyx'),
    SpeechVoiceOption('nova', 'nova'),
    SpeechVoiceOption('shimmer', 'shimmer'),
  ];
  static const realtimeVoices = [
    SpeechVoiceOption('alloy', 'alloy'),
    SpeechVoiceOption('ash', 'ash'),
    SpeechVoiceOption('ballad', 'ballad'),
    SpeechVoiceOption('cedar', 'cedar'),
    SpeechVoiceOption('coral', 'coral'),
    SpeechVoiceOption('echo', 'echo'),
    SpeechVoiceOption('marin', 'marin'),
    SpeechVoiceOption('sage', 'sage'),
    SpeechVoiceOption('shimmer', 'shimmer'),
    SpeechVoiceOption('verse', 'verse'),
  ];
  static const siliconVoices = [
    SpeechVoiceOption('alex', 'Alex - 沉稳男声'),
    SpeechVoiceOption('benjamin', 'Benjamin - 低沉男声'),
    SpeechVoiceOption('charles', 'Charles - 磁性男声'),
    SpeechVoiceOption('david', 'David - 欢快男声'),
    SpeechVoiceOption('anna', 'Anna - 沉稳女声'),
    SpeechVoiceOption('bella', 'Bella - 激情女声'),
    SpeechVoiceOption('claire', 'Claire - 温柔女声'),
    SpeechVoiceOption('diana', 'Diana - 欢快女声'),
  ];
  static const mimoVoices = [
    SpeechVoiceOption('mimo_default', 'MiMo Default'),
    SpeechVoiceOption('冰糖', '冰糖'),
    SpeechVoiceOption('茉莉', '茉莉'),
    SpeechVoiceOption('苏打', '苏打'),
    SpeechVoiceOption('白桦', '白桦'),
    SpeechVoiceOption('Mia', 'Mia'),
    SpeechVoiceOption('Chloe', 'Chloe'),
    SpeechVoiceOption('Milo', 'Milo'),
    SpeechVoiceOption('Dean', 'Dean'),
  ];
}

class TtsProfilePresentation {
  const TtsProfilePresentation({
    required this.id,
    required this.name,
    this.engine = TtsEngine.simple,
    this.endpoint = '',
    this.apiKey = '',
    this.headers = '{}',
    this.method = 'GET',
    this.body = '',
    this.contentType = 'application/json',
    this.locale = '',
    this.voice = '',
    this.model = '',
    this.pipeline = '[]',
    this.packagePath = '',
    this.speaker = '',
    this.options = '{}',
    this.rate = 1,
    this.pitch = 1,
    this.cleaners = const [r'\([^)]+\)', '（[^）]+）'],
  });
  final String id, name, endpoint, apiKey, headers, method, body, contentType;
  final String locale, voice, model, pipeline, packagePath, speaker, options;
  final TtsEngine engine;
  final double rate, pitch;
  final List<String> cleaners;
  SpeechProfileOption get option => SpeechProfileOption(id, name);

  // 保留旧首次初始化的展示值；此地址不参与任何网络请求。
  static const initial = TtsProfilePresentation(
    id: 'builtin-next-tts',
    name: 'Next 内置语音',
    engine: TtsEngine.http,
    endpoint: 'http://5.45.99.149:8075/tts?t={text}&v={voice}&r={rate}&p=0.0&s=&api_key=',
    contentType: 'audio/mpeg',
    locale: 'zh-CN',
    voice: 'zh-CN-XiaoxiaoNeural',
  );
}
