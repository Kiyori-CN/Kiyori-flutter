import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/persistent_models_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

class ControlledSecrets implements SecretStore {
  ControlledSecrets(this.inner);
  final SecretStore inner;
  bool failWrite = false, failDelete = false;
  Completer<void>? gate;
  final entered = Completer<void>();
  @override
  Future<void> writeNew(String reference, String value) async {
    if (!entered.isCompleted) entered.complete();
    if (gate != null) await gate!.future;
    if (failWrite) throw const SecretStoreException('write_failed');
    await inner.writeNew(reference, value);
  }

  @override
  Future<String?> read(String reference) => inner.read(reference);
  @override
  Future<void> delete(String reference) async {
    if (failDelete) throw const SecretStoreException('delete_failed');
    await inner.delete(reference);
  }
}

void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  test('real native configuration and DPAPI rollback, retry, stale revisions and reopen', () async {
    final directory = Directory.systemTemp.createTempSync(
      'kiyori-model-business-',
    );
    final runtime = await NativeRuntimeClient.open(
      dataDirectory: directory.path,
    );
    final secrets = ControlledSecrets(
      WindowsSecretStore(Directory('${directory.path}/secrets')),
    );
    final owner = ModelsController(() async => runtime, () async => secrets);
    try {
      await owner.load();
      var base = owner.catalog!.configs.single;
      final abandoned = await runtime.beginModelSecrets();
      final orphan = await abandoned.reserve(base.id, base.revision);
      await secrets.writeNew(orphan, 'unfinished-fixture');
      await owner.load();
      expect(owner.cleanupWarning, isNotNull);
      expect(await secrets.read(orphan), 'unfinished-fixture');
      await abandoned.close();
      await owner.load();
      expect(await secrets.read(orphan), isNull);
      expect(owner.cleanupWarning, isNull);
      const first = ModelCredentials(
        apiKey: 'fixture-key-one',
        headers: {'Authorization': 'fixture-header-one'},
        usePool: true,
        keys: [
          ModelPoolKey(
            id: 'fixture-id',
            key: 'fixture-pool-one',
            name: 'API Key one',
            enabled: false,
          ),
        ],
      );
      base = await owner.save(
        base,
        base.draft,
        const ModelCredentials(),
        first,
      );
      expect((await owner.readCredentials(base)).apiKey, first.apiKey);
      expect(
        (await owner.readCredentials(base)).keys.single.toJson(),
        first.keys.single.toJson(),
      );
      secrets.failWrite = true;
      await expectLater(
        owner.save(
          base,
          base.draft,
          first,
          const ModelCredentials(apiKey: 'fixture-failed'),
        ),
        throwsA(isA<SecretStoreException>()),
      );
      expect(
        (await runtime.modelCatalog()).configs.single.secretReference,
        base.secretReference,
      );
      expect((await owner.readCredentials(base)).apiKey, first.apiKey);
      secrets.failWrite = false;
      secrets.failDelete = true;
      final previous = base;
      base = await owner.save(
        base,
        base.draft,
        first,
        const ModelCredentials(apiKey: 'fixture-key-two'),
      );
      expect(owner.cleanupWarning, isNotNull);
      expect(
        await runtime.retiredModelSecrets(),
        contains(previous.secretReference),
      );
      await expectLater(
        owner.save(previous, previous.draft, first, first),
        throwsA(isA<BridgeError>()),
      );
      secrets.failDelete = false;
      await owner.cleanupRetired();
      expect(await runtime.retiredModelSecrets(), isEmpty);
      expect(await secrets.read(previous.secretReference!), isNull);
      expect((await owner.readCredentials(base)).apiKey, 'fixture-key-two');
      final bytes = File('${directory.path}/kiyori.sqlite3').readAsBytesSync();
      final raw = String.fromCharCodes(bytes);
      expect(raw, isNot(contains('fixture-key')));
      expect(raw, isNot(contains('fixture-header')));
      await runtime.close();
      final reopened = await NativeRuntimeClient.open(
        dataDirectory: directory.path,
      );
      try {
        expect(
          (await reopened.modelCatalog()).configs.single.secretReference,
          base.secretReference,
        );
      } finally {
        await reopened.close();
      }
    } finally {
      owner.dispose();
      await runtime.close();
      directory.deleteSync(recursive: true);
    }
  });

  test('edit flush drains input made during native secret write without duplicate revisions', () async {
    final directory = Directory.systemTemp.createTempSync(
      'kiyori-model-flight-',
    );
    final runtime = await NativeRuntimeClient.open(
      dataDirectory: directory.path,
    );
    final secrets = ControlledSecrets(
      WindowsSecretStore(Directory('${directory.path}/secrets')),
    )..gate = Completer<void>();
    final owner = ModelsController(() async => runtime, () async => secrets);
    ModelEditSession? session;
    try {
      await owner.load();
      session = ModelEditSession(
        owner,
        owner.catalog!.configs.single,
        const ModelCredentials(),
      );
      session.credentials = const ModelCredentials(apiKey: 'fixture-flight');
      final flight = session.flush();
      await secrets.entered.future;
      session.update(name: '输入发生于保存期间');
      session.changed();
      secrets.gate!.complete();
      expect(await flight, isTrue);
      expect(
        (await runtime.modelCatalog()).configs.single.draft.name,
        '输入发生于保存期间',
      );
      final revision = session.base.revision;
      expect(await session.flush(), isTrue);
      expect(session.base.revision, revision);
    } finally {
      session?.dispose();
      owner.dispose();
      await runtime.close();
      directory.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'real model page creates and auto saves isolated endpoint and credentials',
    (tester) async {
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Directory.systemTemp.createTempSync('kiyori-model-ui-');
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: directory.path),
      ))!;
      final owner = ModelsController(
        () async => runtime,
        () async => WindowsSecretStore(Directory('${directory.path}/secrets')),
      );
      final capture = GlobalKey();
      Future<void> settle() async {
        for (var i = 0; i < 80; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => RepaintBoundary(key: capture, child: child),
            theme: KiyoriTheme.light(),
            home: PersistentModelsPage(controller: owner, onManage: () {}),
          ),
        );
        await settle();
        if (output.isNotEmpty) {
          await captureUi(tester, capture, output, 'models-real-default');
        }
        await tester.enterText(
          find.byKey(const ValueKey('API端点')),
          'https://fixture.invalid/v1',
        );
        await tester.enterText(
          find.byKey(const ValueKey('API密钥')),
          'fixture-ui-secret',
        );
        await tester.pump(const Duration(milliseconds: 750));
        await settle();
        final catalog = (await tester.runAsync(runtime.modelCatalog))!;
        expect(
          catalog.configs.single.draft.endpoint,
          'https://fixture.invalid/v1',
        );
        final credentials = (await tester.runAsync(
          () => owner.readCredentials(catalog.configs.single),
        ))!;
        expect(credentials.apiKey, 'fixture-ui-secret');
        await tester.tap(find.text('新建'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, '配置名称'), '第二配置');
        await tester.tap(find.text('创建'));
        await settle();
        expect(owner.catalog!.configs.length, 2);
        final second = owner.catalog!.configs.last;
        expect(second.draft.endpoint, isEmpty);
        expect(second.secretReference, isNull);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('API端点')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('API密钥')))
              .controller!
              .text,
          isEmpty,
        );
        expect(find.text('保存失败'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        owner.dispose();
        await tester.runAsync(runtime.close);
        directory.deleteSync(recursive: true);
      }
    },
  );
}
