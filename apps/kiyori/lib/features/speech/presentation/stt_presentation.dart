import 'speech_profiles.dart';

enum SttEngine {
  sherpa('Sherpa NCNN (本地)'),
  openai('OpenAI STT (远程)'),
  deepgram('Deepgram STT (远程)');

  const SttEngine(this.label);
  final String label;
}

class SttProfilePresentation {
  const SttProfilePresentation({
    required this.id,
    required this.name,
    this.engine = SttEngine.sherpa,
    this.endpoint = 'https://api.openai.com/v1/audio/transcriptions',
    this.apiKey = '',
    this.model = 'whisper-1',
  });
  final String id, name, endpoint, apiKey, model;
  final SttEngine engine;
  SpeechProfileOption get option => SpeechProfileOption(id, name);
}
