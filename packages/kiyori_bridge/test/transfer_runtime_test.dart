import 'dart:async';
import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

void main() {
  for (final listening in [false, true]) {
    test(
      'runtime close releases ${listening ? "subscribed" : "unconsumed"} transfer and persists partial state',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'kiyori-transfer-ffi-',
        );
        var runtime = await NativeRuntimeClient.open(
          dataDirectory: directory.path,
        );
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final entered = Completer<void>();
        final release = Completer<void>();
        StreamSubscription<TransferSnapshot>? subscription;
        server.listen((request) async {
          await request.drain<void>();
          request.response.bufferOutput = false;
          request.response.contentLength = 6;
          request.response.add([97, 98, 99]);
          await request.response.flush();
          entered.complete();
          await release.future;
          try {
            await request.response.close();
          } catch (_) {
            /* 取消已关闭客户端 */
          }
        });
        try {
          final id = await runtime.createTransfer(
            TransferSpec(
              owner: 'fixture',
              name: 'fixture',
              files: [
                TransferFile(
                  path: 'model.bin',
                  url: 'http://127.0.0.1:${server.port}/file',
                  size: BigInt.from(6),
                  sha256: 'bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721',
                ),
              ],
            ),
          );
          final run = await runtime.startTransfer(id);
          if (listening) {
            subscription = run.events.listen((_) {});
            subscription.pause();
          }
          await entered.future.timeout(const Duration(seconds: 3));
          await runtime.close().timeout(const Duration(seconds: 3));
          await subscription?.cancel();
          runtime = await NativeRuntimeClient.open(
            dataDirectory: directory.path,
          );
          final task = (await runtime.transfers()).single;
          expect(task.phase, 'paused');
          expect(task.id, id);
          await runtime.deleteTransfer(id);
          expect(await runtime.transfers(), isEmpty);
        } finally {
          release.complete();
          await runtime.close();
          await server.close(force: true);
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
