import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_platform/src/windows_model_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SAF contract token lifecycle, bounded read and native error redaction',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var closed = false;
      messenger.setMockMethodCallHandler(ChannelModelFilePicker.channel, (
        call,
      ) async {
        if (call.method == 'select') {
          return {'name': 'fixture.gguf', 'token': 'fixture'};
        }
        expect(call.arguments, {'token': 'fixture'});
        if (call.method == 'close') {
          closed = true;
          return null;
        }
        return Uint8List.fromList([1, 2, 3]);
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ChannelModelFilePicker.channel,
          null,
        ),
      );
      final source = (await const ChannelModelFilePicker().select())!;
      expect(await source.read(), [1, 2, 3]);
      await source.close();
      expect(closed, isTrue);
      await expectLater(source.read(), throwsA(isA<ModelFileException>()));
      messenger.setMockMethodCallHandler(
        ChannelModelFilePicker.channel,
        (_) async =>
            throw PlatformException(code: 'private-uri', message: 'not-public'),
      );
      await expectLater(
        const ChannelModelFilePicker().select(),
        throwsA(
          isA<ModelFileException>().having(
            (e) => e.toString(),
            'redacted',
            'ModelFileException(io_failed)',
          ),
        ),
      );
    },
  );
  test('selected Windows model streams bounded chunks, closes and preserves source', () async {
    final root = await Directory.systemTemp.createTemp('kiyori-model-file-');
    final file = File('${root.path}/fixture.gguf');
    final bytes = List.generate(modelFileChunkBytes + 7, (i) => i % 251);
    await file.writeAsBytes(bytes);
    final picker = WindowsModelFilePicker(select: () async => file.path);
    ModelFileSource? source;
    try {
      final cancelled = WindowsModelFilePicker(select: () async => null);
      expect(await cancelled.select(), isNull);
      source = await picker.select();
      expect(source!.name, 'fixture.gguf');
      await expectLater(picker.select(), throwsA(isA<ModelFileException>()));
      final first = await source.read(), last = await source.read();
      expect(first.length, modelFileChunkBytes);
      expect([...first, ...last], bytes);
      expect(await source.read(), isEmpty);
      await source.close();
      await source.close();
      await expectLater(source.read(), throwsA(isA<ModelFileException>()));
      expect(await file.readAsBytes(), bytes);
      expect(await cancelled.select(), isNull);
    } finally {
      await source?.close();
      await root.delete(recursive: true);
    }
  });
}
