import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_platform/src/windows_text_exchange.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows text I/O is bounded, strict, cancellation preserving and contains no private error detail', () async {
    final directory = Directory.systemTemp.createTempSync('kiyori-exchange-');
    final file = File('${directory.path}/fixture.txt');
    final owner = WindowsTextExchange(select: (save, name) async => file.path);
    try {
      file.writeAsStringSync('第一行\nfixture-one', encoding: utf8);
      expect(await owner.importText(), '第一行\nfixture-one');
      expect(
        await owner.exportText(
          '新正文\nfixture-two',
          suggestedName: 'fixture.txt',
        ),
        isTrue,
      );
      expect(file.readAsStringSync(), '新正文\nfixture-two');
      final cancelled = WindowsTextExchange(select: (_, _) async => null);
      expect(await cancelled.importText(), isNull);
      expect(
        await cancelled.exportText('not written', suggestedName: 'fixture.txt'),
        isFalse,
      );
      expect(file.readAsStringSync(), '新正文\nfixture-two');
      file.writeAsBytesSync([0xff]);
      await expectLater(
        owner.importText(),
        throwsA(
          isA<TextExchangeException>().having(
            (e) => e.code,
            'code',
            'invalid_utf8',
          ),
        ),
      );
      file.writeAsBytesSync(List.filled(maxTextExchangeBytes + 1, 65));
      await expectLater(
        owner.importText(),
        throwsA(
          isA<TextExchangeException>().having(
            (e) => e.code,
            'code',
            'too_large',
          ),
        ),
      );
      await expectLater(
        owner.exportText(
          'a' * (maxTextExchangeBytes + 1),
          suggestedName: 'fixture.txt',
        ),
        throwsA(isA<TextExchangeException>()),
      );
      file.deleteSync();
      await expectLater(
        owner.importText(),
        throwsA(
          isA<TextExchangeException>().having(
            (e) => e.toString(),
            'redacted',
            'TextExchangeException(io_failed)',
          ),
        ),
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
  test('global Windows dialog busy guard rejects overlap and releases after cancellation', () async {
    final gate = Completer<String?>();
    final owner = WindowsTextExchange(select: (_, _) => gate.future);
    final pending = owner.importText();
    await expectLater(
      owner.importText(),
      throwsA(
        isA<TextExchangeException>().having((e) => e.code, 'busy', 'busy'),
      ),
    );
    gate.complete(null);
    expect(await pending, isNull);
    expect(await owner.importText(), isNull);
  });
  test('mobile contract distinguishes cancel and unsupported and redacts native details', () async {
    const owner = ChannelTextExchange();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(ChannelTextExchange.channel, null),
    );
    messenger.setMockMethodCallHandler(ChannelTextExchange.channel, (
      call,
    ) async {
      if (call.method == 'importText') return null;
      expect(call.arguments, {
        'text': 'fixture',
        'suggestedName': 'fixture.txt',
      });
      return true;
    });
    expect(await owner.importText(), isNull);
    expect(
      await owner.exportText('fixture', suggestedName: 'fixture.txt'),
      isTrue,
    );
    messenger.setMockMethodCallHandler(
      ChannelTextExchange.channel,
      (_) async => throw PlatformException(
        code: 'private-path',
        message: 'fixture-secret',
      ),
    );
    await expectLater(
      owner.importText(),
      throwsA(
        isA<TextExchangeException>().having(
          (e) => e.toString(),
          'redacted',
          'TextExchangeException(io_failed)',
        ),
      ),
    );
    messenger.setMockMethodCallHandler(ChannelTextExchange.channel, null);
    await expectLater(
      owner.importText(),
      throwsA(
        isA<TextExchangeException>().having(
          (e) => e.code,
          'unsupported',
          'unsupported',
        ),
      ),
    );
  });
}
