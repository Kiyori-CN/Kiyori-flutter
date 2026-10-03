import 'dart:convert';

const maxTextExchangeBytes = 1048576;

/// 单次用户选择的文本交换，不保存路径、持久权限或明文缓存。
abstract interface class TextExchange {
  Future<String?> importText();
  Future<bool> exportText(String text, {required String suggestedName});
}

class TextExchangeException implements Exception {
  const TextExchangeException(this.code);
  final String code;
  @override
  String toString() => 'TextExchangeException($code)';
}

void validateTextExport(String text, String name) {
  if (name.isEmpty || name.contains(RegExp(r'[\\/:\x00]'))) {
    throw const TextExchangeException('invalid_name');
  }
  if (utf8.encode(text).length > maxTextExchangeBytes) {
    throw const TextExchangeException('too_large');
  }
}
