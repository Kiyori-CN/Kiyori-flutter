import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/knowledge/presentation/knowledge_controller.dart';

Future<void> settleNative(
  WidgetTester tester,
  KnowledgeController state,
) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (!state.loading && !state.saving && attempt > 20) break;
  }
  await tester.pumpAndSettle();
  expect(state.error, isNull);
  expect(state.loading || state.saving, isFalse);
  expect(tester.takeException(), isNull);
}
