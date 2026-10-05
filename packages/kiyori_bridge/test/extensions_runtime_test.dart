import 'dart:convert';
import 'dart:io';

import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:test/test.dart';

// 合成源码包，无网络/凭据；真实ZIP、QuickJS、FFI、SQLite与取消链均执行。
const packageBytes =
    'UEsDBBQAAAAAANBYRV1cGMmqmgAAAJoAAAANAAAAbWFuaWZlc3QuanNvbnsic2NoZW1hX3ZlcnNpb24iOjEsInRvb2xwa2dfaWQiOiJjb20ua2l5b3JpLmZpeHR1cmUiLCJ2ZXJzaW9uIjoiMS4wLjAiLCJtYWluIjoiZGlzdC9tYWluLmpzIiwiZGlzcGxheV9uYW1lIjp7InpoIjoi5ZCI5oiQ5YyFIn0sImVuYWJsZWRfYnlfZGVmYXVsdCI6dHJ1ZX1QSwMEFAAAAAAA0FhFXU+ZjLPTAQAA0wEAAAwAAABkaXN0L21haW4uanNleHBvcnRzLnJlZ2lzdGVyVG9vbFBrZz0oKT0+VG9vbFBrZy5yZWdpc3RlckFpUHJvdmlkZXIoe2lkOidmaXh0dXJlJyxkaXNwbGF5TmFtZTon5ZCI5oiQ5L6b5bqU5ZWGJyxkZXNjcmlwdGlvbjon55yf5a6e5a6J6KOF6aqM5pS2JyxsaXN0TW9kZWxzOntmdW5jdGlvbjooKT0+WydmaXh0dXJlLW1vZGVsJ119LHNlbmRNZXNzYWdlOntmdW5jdGlvbjooe2V2ZW50UGF5bG9hZH0pPT57aWYoZXZlbnRQYXlsb2FkLndhaXQpd2hpbGUodHJ1ZSl7fTtzZW5kSW50ZXJtZWRpYXRlUmVzdWx0KHt0ZXh0OifkvaAnfSk7c2VuZEludGVybWVkaWF0ZVJlc3VsdCh7dGV4dDon5aW9J30pO3JldHVybiB7Y29udGVudDon5L2g5aW9Jyx1c2FnZTp7aW5wdXQ6MixvdXRwdXQ6MX19O319LHRlc3RDb25uZWN0aW9uOntmdW5jdGlvbjooKT0+KHtzdWNjZXNzOnRydWV9KX0sY2FsY3VsYXRlSW5wdXRUb2tlbnM6e2Z1bmN0aW9uOigpPT43fX0pO1BLAQIUABQAAAAAANBYRV1cGMmqmgAAAJoAAAANAAAAAAAAAAAAAAAAAAAAAABtYW5pZmVzdC5qc29uUEsBAhQAFAAAAAAA0FhFXU+ZjLPTAQAA0wEAAAwAAAAAAAAAAAAAAAAAxQAAAGRpc3QvbWFpbi5qc1BLBQYAAAAAAgACAHUAAADCAgAAAAA=';

Future<ExtensionPackage> install(RuntimeClient runtime) async {
  final importer = await runtime.beginExtensionImport();
  try {
    await importer.append(base64Decode(packageBytes));
    return await importer.finish();
  } finally {
    await importer.close();
  }
}

void main() {
  test('actual package install executes four handlers, revokes active VM and survives reopen', () async {
    final root = await Directory.systemTemp.createTemp('kiyori-extensions-');
    var runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
    try {
      final package = await install(runtime);
      expect(package.enabled, isTrue);
      expect(package.cleanupPending, 0);
      final details = await runtime.extensionDetails(
        package.id,
        package.revision,
      );
      expect(details.package.archiveHash, package.archiveHash);
      expect(details.apiVersion, '1.0');
      expect(details.authors, isEmpty);
      final provider = (await runtime.extensionProviders()).single;
      Future<List<ExtensionEvent>> invoke(ExtensionHandler handler) async {
        final run = await runtime.startExtension(
          provider.id,
          provider.revision,
          handler,
          '{}',
        );
        final events = <ExtensionEvent>[];
        try {
          while (true) {
            final event = await run.nextEvent();
            if (event == null) break;
            events.add(event);
          }
        } finally {
          await run.cancel();
        }
        expect(events.last.phase, ExtensionPhase.completed);
        return events;
      }

      expect(
        jsonDecode((await invoke(ExtensionHandler.listModels)).single.json!),
        ['fixture-model'],
      );
      expect(
        jsonDecode(
          (await invoke(ExtensionHandler.testConnection)).single.json!,
        ),
        {'success': true},
      );
      expect(
        jsonDecode(
          (await invoke(ExtensionHandler.calculateInputTokens)).single.json!,
        ),
        7,
      );
      final messages = await invoke(ExtensionHandler.sendMessage);
      expect(messages.map((e) => e.phase), [
        ExtensionPhase.intermediate,
        ExtensionPhase.intermediate,
        ExtensionPhase.completed,
      ]);
      expect(
        messages.take(2).map((e) => jsonDecode(e.json!)['text']).join(),
        '你好',
      );
      expect(jsonDecode(messages.last.json!)['content'], '你好');

      final active = await runtime.startExtension(
        provider.id,
        provider.revision,
        ExtensionHandler.sendMessage,
        '{"wait":true}',
      );
      final reading = active.nextEvent();
      expect(
        await runtime.changeExtension(
          package.id,
          package.revision,
          enabled: false,
        ),
        0,
      );
      expect((await reading)!.phase, ExtensionPhase.failed);
      await active.cancel();
      expect(await runtime.extensionProviders(), isEmpty);
      await runtime.close();
      runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
      final reopened = (await runtime.extensionPackages()).single;
      expect(reopened.enabled, isFalse);
      expect(reopened.revision, 2);
      expect(reopened.archiveHash, package.archiveHash);
      final upgraded = await install(runtime);
      expect(upgraded.enabled, isFalse);
      expect(upgraded.revision, 3);
      await runtime.changeExtension(upgraded.id, upgraded.revision);
      expect(await runtime.extensionPackages(), isEmpty);
      final reinstalled = await install(runtime);
      expect(reinstalled.revision, 5);
      await expectLater(
        runtime.startExtension(
          provider.id,
          1,
          ExtensionHandler.sendMessage,
          '{}',
        ),
        throwsA(isA<BridgeError>()),
      );
    } finally {
      await runtime.close();
      await root.delete(recursive: true);
    }
  });

  test(
    'runtime close settles unconsumed execution and partial import',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kiyori-extensions-close-',
      );
      final runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
      try {
        await install(runtime);
        final provider = (await runtime.extensionProviders()).single;
        await runtime.startExtension(
          provider.id,
          provider.revision,
          ExtensionHandler.sendMessage,
          '{"wait":true}',
        );
        final importer = await runtime.beginExtensionImport();
        await importer.append([1, 2, 3]);
        await runtime.close().timeout(const Duration(seconds: 3));
        expect(
          await File('${root.path}/extension-import.tmp').exists(),
          isFalse,
        );
        final reopened = await NativeRuntimeClient.open(
          dataDirectory: root.path,
        );
        try {
          expect((await reopened.extensionProviders()).single.id, provider.id);
        } finally {
          await reopened.close();
        }
      } finally {
        await runtime.close();
        await root.delete(recursive: true);
      }
    },
  );
}
