import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori/features/assistant/presentation/models/function_models_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/assistant_fixtures.dart';
import 'support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'function snapshots show load failure and media warnings without requests',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> mount(FunctionModelsPresentation snapshot) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: FunctionModelsPage(
              key: ValueKey(snapshot),
              snapshot: snapshot,
            ),
          ),
        );
        await tester.pump();
      }

      await mount(
        const FunctionModelsPresentation(
          loading: FunctionModelLoadState.loading,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await mount(
        const FunctionModelsPresentation(
          loading: FunctionModelLoadState.failed,
        ),
      );
      expect(find.text('功能模型配置加载失败'), findsOneWidget);
      const status = '未验证：模型响应不能确认图片识别能力，请检查配置后重新测试。';
      await mount(
        const FunctionModelsPresentation(
          configs: [
            ModelConfigPresentation(
              id: 'default',
              name: '默认配置',
              models: ['autoglm', '常规模型'],
              image: false,
            ),
          ],
          results: {
            AssistantFunction.image: FunctionTestPresentation(
              FunctionTestOutcome.unverified,
              status,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      final expand = find.byKey(const ValueKey('function-expand-chat'));
      await revealFunction(tester, expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final config = find.byKey(const ValueKey('function-config-chat-default'));
      await revealFunction(tester, config);
      await tester.tap(config);
      await tester.pumpAndSettle();
      final model = find.byKey(const ValueKey('function-model-chat-default-0'));
      await revealFunction(tester, model);
      await tester.tap(model);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      final image = find.byKey(const ValueKey('function-expand-image'));
      await revealFunction(tester, image);
      expect(find.textContaining('警告：当前所选模型未启用“支持识图”'), findsOneWidget);
      final more = find.descendant(of: image, matching: find.byTooltip('展开'));
      await revealFunction(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byTooltip('收起'), findsOneWidget);
      expect(tester.widget<Text>(find.text(status)).maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'function selection survives scroll and actions stay empty $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const FunctionModelsPage(snapshot: functionSnapshot),
            ),
          );
          await tester.pumpAndSettle();
          final expand = find.byKey(const ValueKey('function-expand-chat'));
          await revealFunction(tester, expand);
          await tester.tap(expand);
          await tester.pumpAndSettle();
          final config = find.byKey(
            const ValueKey('function-config-chat-multi'),
          );
          await revealFunction(tester, config);
          await tester.tap(config);
          await tester.pumpAndSettle();
          final model = find.byKey(
            const ValueKey('function-model-chat-multi-1'),
          );
          await revealFunction(tester, model);
          await tester.tap(model);
          await tester.pumpAndSettle();
          await revealFunction(tester, expand, up: true);
          expect(find.text('模型: 模型三'), findsOneWidget);
          final test = find.descendant(of: expand, matching: find.text('测试'));
          await tester.tap(test);
          await tester.pumpAndSettle();
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          final reset = find.text('重置所有功能至默认配置');
          await revealFunction(tester, reset);
          await tester.tap(reset);
          await tester.pumpAndSettle();
          await tester.tap(find.text('恢复默认'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          await revealFunction(tester, expand, up: true);
          expect(find.text('模型: 模型三'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
