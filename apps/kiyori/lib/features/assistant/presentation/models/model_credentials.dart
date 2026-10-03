import 'dart:convert';
import 'dart:math';

class ModelPoolKey {
  const ModelPoolKey({
    required this.id,
    required this.key,
    required this.name,
    this.enabled = true,
  });
  factory ModelPoolKey.create(String key) {
    final random = Random.secure();
    return ModelPoolKey(
      id: List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      key: key,
      name: 'API Key ${key.substring(key.length > 4 ? key.length - 4 : 0)}',
    );
  }
  final String id, key, name;
  final bool enabled;
  ModelPoolKey edited(String value) => ModelPoolKey(
    id: id,
    key: value,
    name: 'API Key ${value.substring(value.length > 4 ? value.length - 4 : 0)}',
    enabled: enabled,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'enabled': enabled,
  };
}

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
  final List<ModelPoolKey> keys;
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
    final identities = <String>{};
    for (final key in keys) {
      if (key.id.isEmpty || key.key.trim().isEmpty || !identities.add(key.id)) {
        throw const FormatException('密钥条目无效');
      }
    }
    return jsonEncode({
      'version': 2,
      'apiKey': apiKey,
      'headers': headers,
      'usePool': usePool,
      'keys': keys.map((key) => key.toJson()).toList(),
      'rotation': rotation,
    });
  }

  static ModelCredentials decode(String value) {
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 && data['version'] != 2) {
        throw const FormatException();
      }
      final result = ModelCredentials(
        apiKey: data['apiKey'] as String,
        headers: Map<String, String>.from(data['headers'] as Map),
        usePool: data['usePool'] as bool,
        keys: [
          for (final entry in (data['keys'] as List).indexed)
            if (data['version'] == 1)
              ModelPoolKey(
                id: 'legacy-${entry.$1}',
                key: entry.$2 as String,
                name: 'API Key ${entry.$1 + 1}',
              )
            else
              ModelPoolKey(
                id: entry.$2['id'] as String,
                key: entry.$2['key'] as String,
                name: entry.$2['name'] as String,
                enabled: entry.$2['enabled'] as bool,
              ),
        ],
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
