/// 明文只随当前调用存活；不枚举所有值，不提供全库删除或错误后清空。
abstract interface class SecretStore {
  Future<void> writeNew(String reference, String value);
  Future<String?> read(String reference);
  Future<void> delete(String reference);
}

class SecretStoreException implements Exception {
  const SecretStoreException(this.code);
  final String code;
  @override
  String toString() => 'SecretStoreException($code)';
}

void validateSecretReference(String reference) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(reference)) {
    throw const SecretStoreException('invalid_reference');
  }
}
