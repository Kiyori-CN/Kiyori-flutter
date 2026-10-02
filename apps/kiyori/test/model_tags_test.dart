import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_tags_editor.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'model tags deduplicate pasted names and reorder draft $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var models = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: KiyoriTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ModelTagsEditor(
                      models: models,
                      onChanged: (value) => setState(() => models = value),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('添加模型'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'one,two\nthree，one');
          await tester.pumpAndSettle();
          expect(find.text('添加 (3)'), findsOneWidget);
          await tester.tap(find.text('添加 (3)'));
          await tester.pumpAndSettle();
          expect(models, ['one', 'two', 'three']);
          final more = find.byTooltip('更多模型操作');
          await tester.ensureVisible(more);
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
          await tester.tap(find.text('模型排序'));
          await tester.pumpAndSettle();
          final handle = find.byKey(const ValueKey('model-drag-one'));
          final target = find.byKey(const ValueKey('model-drag-two'));
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == '展开 / 收起',
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(handle);
          await tester.pumpAndSettle();
          final from = tester.getCenter(handle), to = tester.getCenter(target);
          final gesture = await tester.startGesture(to);
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveBy(const Offset(0, 1));
          await tester.pump();
          for (var step = 1; step <= 20; step++) {
            await gesture.moveTo(
              Offset.lerp(to, from - const Offset(0, 20), step / 20)!,
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pump(const Duration(milliseconds: 400));
          await gesture.moveBy(const Offset(0, 1));
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          await tester.tap(find.text('完成排序'));
          await tester.pumpAndSettle();
          expect(models.first, 'two');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
