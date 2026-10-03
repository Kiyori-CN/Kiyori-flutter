import 'dart:convert';

/// 仅供显式模型编辑和请求执行短暂持有，不进入配置目录或诊断文本。
class ModelCredentials {
  const ModelCredentials({
    this.apiKey = '',
    this.headers = const {},
    this.usePool = false,
    this.keys = const [],
    this.rotation = 'ROUND_ROBIN',
  });
  final String apiKey;
  final Map<String, String> headers;
  final bool usePool;
  final List<String> keys;
  final String rotation;

  String encode() {
    for (final entry in headers.entries) {
      if (!RegExp(r"^[!#$%&'*+.^_`|~0-9a-zA-Z-]+$").hasMatch(entry.key) ||
          entry.value.contains(RegExp(r'[\r\n\x00]'))) {
        throw const FormatException('请求头名称或值无效');
      }
    }
    if (rotation != 'ROUND_ROBIN' && rotation != 'RANDOM') {
      throw const FormatException('密钥轮换方式无效');
    }
    return jsonEncode({
      'version': 1,
      'apiKey': apiKey,
      'headers': headers,
      'usePool': usePool,
      'keys': keys,
      'rotation': rotation,
    });
  }

  static ModelCredentials decode(String value) {
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1) throw const FormatException();
      final result = ModelCredentials(
        apiKey: data['apiKey'] as String,
        headers: Map<String, String>.from(data['headers'] as Map),
        usePool: data['usePool'] as bool,
        keys: List<String>.from(data['keys'] as List),
        rotation: data['rotation'] as String,
      );
      result.encode();
      return result;
    } catch (_) {
      // JSON解析器的原错误可能携带凭据正文。
      throw const FormatException('安全凭据无法读取，请保留原数据并重试');
    }
  }
}
