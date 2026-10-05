import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'binary audit save preserves bytes and cancellation never writes',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'kiyori-audit-export-',
      );
      final file = File('${directory.path}/fixture.zip');
      final bytes = Uint8List.fromList([0x50, 0x4b, 0, 255, 10]);
      final exchange = PlatformAuditExchange(
        windows: true,
        select: (name, mime) async {
          expect(name, 'audit.zip');
          expect(mime, 'application/zip');
          return file.path;
        },
      );
      try {
        expect(
          await exchange.save(
            bytes,
            name: 'audit.zip',
            mime: 'application/zip',
          ),
          isTrue,
        );
        expect(file.readAsBytesSync(), bytes);
        final cancel = PlatformAuditExchange(
          windows: true,
          select: (_, _) async => null,
        );
        expect(
          await cancel.save(
            Uint8List.fromList([9]),
            name: 'audit.zip',
            mime: 'application/zip',
          ),
          isFalse,
        );
        expect(file.readAsBytesSync(), bytes);
        await expectLater(
          exchange.save(bytes, name: '../bad.zip', mime: 'application/zip'),
          throwsA(isA<TextExchangeException>()),
        );
        await expectLater(
          exchange.save(
            bytes,
            name: 'bad.exe',
            mime: 'application/x-msdownload',
          ),
          throwsA(isA<TextExchangeException>()),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
  test('audit picker busy guard releases after cancel and channel failures stay redacted', () async {
    final gate = Completer<String?>();
    final exchange = PlatformAuditExchange(
      windows: true,
      select: (_, _) => gate.future,
    );
    final bytes = Uint8List(2);
    final pending = exchange.save(
      bytes,
      name: 'x.zip',
      mime: 'application/zip',
    );
    await expectLater(
      exchange.save(bytes, name: 'x.zip', mime: 'application/zip'),
      throwsA(
        isA<TextExchangeException>().having((e) => e.code, 'busy', 'busy'),
      ),
    );
    gate.complete(null);
    expect(await pending, isFalse);
    const channel = MethodChannel('kiyori/text_exchange');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final mobile = PlatformAuditExchange(windows: false);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'exportAudit');
      expect(call.arguments['bytes'], bytes);
      return true;
    });
    expect(
      await mobile.save(bytes, name: 'x.zip', mime: 'application/zip'),
      isTrue,
    );
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(
        code: 'private-path',
        message: 'private fixture',
      ),
    );
    await expectLater(
      mobile.save(bytes, name: 'x.zip', mime: 'application/zip'),
      throwsA(
        isA<TextExchangeException>().having(
          (e) => e.toString(),
          'redacted',
          'TextExchangeException(io_failed)',
        ),
      ),
    );
  });
}
