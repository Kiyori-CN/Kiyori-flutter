import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_credentials.dart';
import 'package:kiyori/features/assistant/presentation/models/model_directory_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/model_edit_session.dart';
import 'package:kiyori/features/assistant/presentation/models/model_tags_editor.dart';
import 'package:kiyori/features/assistant/presentation/models/models_controller.dart';
import 'package:kiyori/features/assistant/presentation/models/upstream_model_drawer.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/src/windows_secret_store.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';

Future<void> advance(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'configured directory and probes consume the same persisted key cursor',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kiyori-directory-pool-',
      );
      final runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final observed = <String>[];
      server.listen((request) async {
        expect(request.uri.path, '/proxy/v1/models');
        observed.add(request.headers.value('authorization')!);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'one'},
            ],
          }),
        );
        await request.response.close();
      });
      final controller = ModelDirectoryController(() async => runtime);
      try {
        var config = (await runtime.modelCatalog()).configs.single;
        final draft = ModelConfigDraft(
          name: config.draft.name,
          provider: config.draft.provider,
          protocol: 'chat',
          endpoint:
              'http://127.0.0.1:${server.port}/proxy/v1/chat/completions#',
          models: config.draft.models,
          options: config.draft.options,
        );
        await runtime.saveModelConfig(
          config.id,
          config.revision,
          draft,
          null,
          null,
        );
        config = (await runtime.modelCatalog()).configs.single;
        final credentials = ModelCredentials.decode(
          jsonEncode({
            'version': 3,
            'apiKey': 'fallback-unused',
            'headers': {},
            'usePool': true,
            'rotation': 'ROUND_ROBIN',
            'keys': [
              {
                'id': 'a',
                'name': 'A',
                'key': 'directory-a',
                'enabled': true,
                'availability': 'AVAILABLE',
              },
              {
                'id': 'disabled',
                'name': 'disabled',
                'key': 'disabled',
                'enabled': false,
                'availability': 'AVAILABLE',
              },
              {
                'id': 'b',
                'name': 'B',
                'key': 'directory-b',
                'enabled': true,
                'availability': 'AVAILABLE',
              },
              {
                'id': 'bad',
                'name': 'bad',
                'key': 'bad',
                'enabled': true,
                'availability': 'UNAVAILABLE',
              },
            ],
          }),
        );
        expect(
          await controller.refresh(draft, credentials, config: config),
          isTrue,
        );
        expect(
          await controller.refresh(draft, credentials, config: config),
          isTrue,
        );
        expect(
          await controller.refresh(draft, credentials, config: config),
          isTrue,
        );
        expect(observed, [
          'Bearer directory-a',
          'Bearer directory-b',
          'Bearer directory-a',
        ]);
        expect(
          (await runtime.modelCatalog()).configs.single.revision,
          config.revision,
        );
        await runtime.saveModelConfig(
          config.id,
          config.revision,
          draft,
          null,
          null,
        );
        expect(
          await controller.refresh(draft, credentials, config: config),
          isFalse,
        );
        expect(observed, hasLength(3));
        expect(controller.models.single.id, 'one');
      } finally {
        controller.dispose();
        await runtime.close();
        await server.close(force: true);
        await root.delete(recursive: true);
      }
    },
  );

  test('real directory FFI refresh failure keeps complete previous snapshot and cancel rejects late results', () async {
    final root = await Directory.systemTemp.createTemp('kiyori-directory-');
    final runtime = await NativeRuntimeClient.open(dataDirectory: root.path);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final entered = Completer<void>(), release = Completer<void>();
    var mode = 0;
    server.listen((request) async {
      expect(request.uri.path, '/proxy/v1/models');
      expect(
        request.headers.value('authorization'),
        'Bearer synthetic-directory-key',
      );
      if (mode == 2) {
        entered.complete();
        await release.future;
      }
      request.response.headers.contentType = ContentType.json;
      if (mode == 1) {
        request.response.statusCode = 500;
        request.response.write('private provider response');
      } else {
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'one', 'name': '模型一'},
              {'id': 'two'},
            ],
          }),
        );
      }
      await request.response.close();
    });
    final controller = ModelDirectoryController(() async => runtime);
    try {
      final initial = (await runtime.modelCatalog()).configs.single.draft;
      final input = ModelConfigDraft(
        name: initial.name,
        provider: initial.provider,
        protocol: 'chat',
        endpoint: 'http://127.0.0.1:${server.port}/proxy/v1/chat/completions#',
        models: initial.models,
        options: initial.options,
      );
      const credentials = ModelCredentials(apiKey: 'synthetic-directory-key');
      expect(await controller.refresh(input, credentials), isTrue);
      expect(controller.models.map((m) => m.id), ['one', 'two']);
      mode = 1;
      expect(await controller.refresh(input, credentials), isFalse);
      expect(controller.models.map((m) => m.id), ['one', 'two']);
      expect(controller.error, contains('HTTP 500'));
      expect(controller.error, isNot(contains('private')));
      mode = 2;
      final pending = controller.refresh(input, credentials);
      await entered.future.timeout(const Duration(seconds: 5));
      await controller.cancel();
      release.complete();
      expect(await pending, isFalse);
      expect(controller.loading, isFalse);
      expect(controller.models.map((m) => m.id), ['one', 'two']);
    } finally {
      if (!release.isCompleted) release.complete();
      controller.dispose();
      await runtime.close();
      await server.close(force: true);
      await root.delete(recursive: true);
    }
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'upstream picker selects filtered result, preserves custom models, and shows removals $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final directory = ModelDirectoryController(
            () async => throw StateError('no network expected'),
          );
          directory.models = const [
            ModelEntry(id: 'one', name: '甲'),
            ModelEntry(id: 'two', name: '乙'),
            ModelEntry(id: 'three', name: '丙'),
          ];
          Set<String>? result;
          const capture = String.fromEnvironment('KIYORI_CAPTURE');
          if (capture.isNotEmpty) await loadCaptureFonts(tester);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: scale == 2 ? KiyoriTheme.dark() : KiyoriTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showKiyoriModalDrawer<Set<String>>(
                          context,
                          builder: (context, dismiss) => UpstreamModelDrawer(
                            directory: directory,
                            existing: const ['one', 'custom'],
                            refresh: () {},
                            dismiss: dismiss,
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '展开 / 收起',
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '甲');
          await tester.pumpAndSettle();
          await tester.tap(find.text('取消选择当前结果'));
          await tester.pumpAndSettle();
          expect(find.text('将移除'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'two');
          await tester.pumpAndSettle();
          await tester.tap(find.text('全选当前结果'));
          await tester.pumpAndSettle();
          expect(find.text('将添加 1 个，移除 1 个'), findsOneWidget);
          if (capture.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              capture,
              'upstream-${size.width.toInt()}-$scale',
            );
          }
          await tester.ensureVisible(find.text('应用更改'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('应用更改'));
          await tester.pumpAndSettle();
          expect(result, {'two'});
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          directory.dispose();
        },
      );
    }
  }

  testWidgets('model tags copy actual names and clear with draft undo', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var models = ['one', 'two'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ModelTagsEditor(
              models: models,
              onChanged: (next) => setState(() => models = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    expect(copied, 'one');
    await tester.tap(find.byTooltip('更多模型操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制全部'));
    await tester.pumpAndSettle();
    expect(copied, 'one\ntwo');
    ScaffoldMessenger.of(tester.element(find.byType(ModelTagsEditor)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多模型操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空全部'));
    await tester.pumpAndSettle();
    expect(models, isEmpty);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(models, ['one', 'two']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real page deletes bound model only after confirmation and undo restores Rust function bindings',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final root = Directory.systemTemp.createTempSync('kiyori-model-name-ui-');
      final runtime = (await tester.runAsync(
        () => NativeRuntimeClient.open(dataDirectory: root.path),
      ))!;
      final owner = ModelsController(
        () async => runtime,
        () async => WindowsSecretStore(Directory('${root.path}/secrets')),
      );
      late ModelEditSession session;
      await tester.runAsync(() async {
        await owner.load();
        final initial = owner.catalog!.configs.single;
        final old = initial.draft;
        final draft = ModelConfigDraft(
          name: old.name,
          provider: old.provider,
          protocol: old.protocol,
          endpoint: old.endpoint,
          models: [...old.models, 'second'],
          options: old.options,
        );
        final saved = await owner.save(
          initial,
          draft,
          const ModelCredentials(),
          const ModelCredentials(),
        );
        session = ModelEditSession(owner, saved, const ModelCredentials());
      });
      final first = session.draft.models.first;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModelApiConnection(session: session),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('删除模型 $first'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('删除模型 $first'));
        await advance(
          tester,
          () => find.text('删除已绑定的模型？').evaluate().isNotEmpty,
        );
        expect(session.draft.models, [first, 'second']);
        await tester.tap(find.widgetWithText(TextButton, '删除'));
        await advance(tester, () => session.draft.models.length == 1);
        expect(session.draft.models, ['second']);
        expect(
          (await tester.runAsync(runtime.modelCatalog))!.functions
              .every((f) => f.modelName == 'second'),
          isTrue,
        );
        await tester.tap(find.text('撤销'));
        await advance(tester, () => session.draft.models.length == 2);
        expect(
          (await tester.runAsync(runtime.modelCatalog))!.functions
              .every((f) => f.modelName == first),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        owner.dispose();
        await tester.runAsync(runtime.close);
        root.deleteSync(recursive: true);
      }
    },
  );
}
