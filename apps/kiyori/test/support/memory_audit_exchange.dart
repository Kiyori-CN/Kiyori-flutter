import 'dart:typed_data';

import 'package:kiyori_platform/kiyori_platform.dart';

/// 捕获真正核心导出的字节；测试不打开系统选择器或写用户文件。
class MemoryAuditExchange implements AuditExchange {
  Uint8List? bytes;
  String? mime;
  String? name;
  bool failNext = false;
  @override
  Future<bool> save(
    Uint8List bytes, {
    required String name,
    required String mime,
  }) async {
    if (failNext) {
      failNext = false;
      throw const TextExchangeException('io_failed');
    }
    this.bytes = Uint8List.fromList(bytes);
    this.mime = mime;
    this.name = name;
    return true;
  }
}
