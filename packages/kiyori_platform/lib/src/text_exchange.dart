import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'windows_text_exchange.dart';
import 'text_exchange_contract.dart';
export 'text_exchange_contract.dart';

TextExchange createTextExchange() =>
    Platform.isWindows ? WindowsTextExchange() : ChannelTextExchange();

class ChannelTextExchange implements TextExchange {
  const ChannelTextExchange();
  static const channel = MethodChannel('kiyori/text_exchange');
  Future<T?> _invoke<T>(String method, [Map<String, Object>? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const TextExchangeException('unsupported');
    } on PlatformException catch (error) {
      const known = {
        'busy',
        'detached',
        'cancelled',
        'too_large',
        'invalid_utf8',
        'invalid_name',
        'unsupported',
      };
      throw TextExchangeException(
        known.contains(error.code) ? error.code : 'io_failed',
      );
    } catch (_) {
      throw const TextExchangeException('io_failed');
    }
  }

  @override
  Future<String?> importText() async {
    final text = await _invoke<String>('importText');
    if (text != null && utf8.encode(text).length > maxTextExchangeBytes) {
      throw const TextExchangeException('too_large');
    }
    return text;
  }

  @override
  Future<bool> exportText(String text, {required String suggestedName}) async {
    validateTextExport(text, suggestedName);
    return await _invoke<bool>('exportText', {
          'text': text,
          'suggestedName': suggestedName,
        }) ??
        false;
  }
}
