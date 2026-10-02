import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/settings_navigation.dart';
import 'package:kiyori/features/assistant/presentation/models/api_provider_presentation.dart';
import 'package:kiyori/features/assistant/presentation/models/local_model_presentation.dart';
import 'package:kiyori/features/assistant/presentation/models/local_models_page.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

LocalModelPresentation model(
  LocalModelPhase phase, {
  String id = 'one',
  double progress = .36,
  bool downloaded = false,
}) => LocalModelPresentation(
  id: id,
  name: '测试模型-$id',
  sizeGb: 2.15,
  description: '多语言推理模型',
  tags: const ['推理', '视觉'],
  hasSource: true,
  phase: phase,
  downloaded: downloaded,
  progress: progress,
  transferred: '360 MB / 1 GB',
  speed: '2 MB/s',
  totalFiles: 3,
  currentFileIndex: 2,
  currentFile: 'model.mnn',
  error: '连接已断开',
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    LocalModelsPresentation snapshot,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: LocalModelsPage(snapshot: snapshot),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'local models search uses names descriptions and tags; actions do not fabricate state',
    (tester) async {
      await mount(
        tester,
        LocalModelsPresentation(models: [model(LocalModelPhase.idle)]),
      );
      await tester.tap(find.text('开始下载'));
      await tester.pump();
      expect(find.text('正在连接...'), findsNothing);
      await tester.enterText(find.byType(TextField), '视觉');
      await tester.pump();
      expect(find.text('测试模型-one'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('没有找到匹配的模型'), findsOneWidget);
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pump();
      expect(find.text('测试模型-one'), findsOneWidget);
      await mount(
        tester,
        const LocalModelsPresentation(
          models: [LocalModelPresentation(id: 'none', name: '无源', sizeGb: 0)],
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '开始下载'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete route survives reorder but releases on removal busy or host exit',
    (tester) async {
      final a = model(LocalModelPhase.completed, downloaded: true);
      final b = model(LocalModelPhase.paused, id: 'two');
      await mount(tester, LocalModelsPresentation(models: [a, b]));
      await tester.tap(find.byTooltip('删除模型').first);
      await tester.pumpAndSettle();
      await mount(tester, LocalModelsPresentation(models: [b, a]));
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, LocalModelsPresentation(models: [b]));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await mount(tester, LocalModelsPresentation(models: [a]));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byTooltip('删除模型'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        LocalModelsPresentation(models: [model(LocalModelPhase.connecting)]),
      );
      expect(find.byType(AlertDialog), findsNothing);
      await mount(tester, LocalModelsPresentation(models: [a]));
      await tester.tap(find.byTooltip('删除模型'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: Text('外部')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local model route returns to same configuration and preserves provider',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: KiyoriTheme.light(),
          home: const Scaffold(body: Text('来源')),
        ),
      );
      SettingsNavigation(navigator.currentState!).openModels();
      await tester.pumpAndSettle();
      final dynamic connection = tester.state(find.byType(ModelApiConnection));
      final provider = builtInApiProviders.firstWhere(
        (entry) => entry.id == 'MNN',
      );
      connection.selectProvider(provider, provider.defaultProtocol);
      await tester.pumpAndSettle();
      await revealModel(tester, find.text('本地模型下载'));
      await tester.tap(find.text('本地模型下载'));
      await tester.pumpAndSettle();
      expect(find.byType(LocalModelsPage), findsOneWidget);
      expect(find.text('暂无可用的本地模型'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ModelApiPage), findsOneWidget);
      final dynamic restored = tester.state(find.byType(ModelApiConnection));
      expect(identical(restored, connection), isTrue);
      expect(restored.provider.id, 'MNN');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'progress rejects nonfinite values and directory state has explicit precedence',
    (tester) async {
      for (final value in [double.nan, double.infinity, -1.0, 2.0]) {
        await mount(
          tester,
          LocalModelsPresentation(
            models: [model(LocalModelPhase.downloading, progress: value)],
          ),
        );
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          value == 2 ? 1 : 0,
        );
        expect(tester.takeException(), isNull);
      }
      await mount(
        tester,
        const LocalModelsPresentation(loading: true, error: true),
      );
      expect(find.text('加载模型列表中...'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '刷新模型列表',
              ),
            )
            .onPressed,
        isNull,
      );
      await mount(tester, const LocalModelsPresentation(error: true));
      expect(find.text('加载失败'), findsNWidgets(2));
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await mount(tester, const LocalModelsPresentation());
      expect(find.text('暂无可用的本地模型'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  const output = String.fromEnvironment('KIYORI_CAPTURE');
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('model states and keyboard fit $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        Future<void> show(LocalModelsPresentation snapshot, String name) async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
                  child: child!,
                ),
                home: LocalModelsPage(snapshot: snapshot),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'local-model-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
              animated: true,
            );
          }
          expect(tester.takeException(), isNull);
        }

        for (final phase in LocalModelPhase.values) {
          await show(
            LocalModelsPresentation(
              models: [
                model(phase, downloaded: phase == LocalModelPhase.completed),
              ],
            ),
            phase.name,
          );
        }
        await show(const LocalModelsPresentation(loading: true), 'loading');
        await show(const LocalModelsPresentation(error: true), 'error');
        await show(const LocalModelsPresentation(), 'empty');
        await show(
          LocalModelsPresentation(models: [model(LocalModelPhase.paused)]),
          'paused',
        );
        await tester.tap(find.byTooltip('删除模型'));
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'local-model-delete-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
        }
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '空搜索');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        if (output.isNotEmpty) {
          await captureUi(
            tester,
            boundary,
            output,
            'local-model-keyboard-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }
  }
}
