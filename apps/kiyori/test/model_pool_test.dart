import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_sections.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  testWidgets(
    'pool add edit delete and host removal release the owned key dialog',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: show,
              builder: (_, visible, _) => visible
                  ? const SingleChildScrollView(child: ModelAdvancedCard())
                  : const Text('removed'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加API密钥'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'fixture-one');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('API Key -one (...-one)'), findsOneWidget);
      expect(find.text('可用 0 · 不可用 0 · 未测试 1'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑API密钥'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'fixture-one',
      );
      await tester.enterText(find.byType(TextField), 'next');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('API Key next (...next)'), findsOneWidget);
      await tester.tap(find.byTooltip('删除API密钥'));
      await tester.pumpAndSettle();
      expect(find.text('API密钥池为空，点击下方按钮添加密钥'), findsOneWidget);
      await tester.tap(find.text('添加API密钥'));
      await tester.pumpAndSettle();
      show.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('removed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
