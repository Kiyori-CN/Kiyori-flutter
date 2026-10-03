import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_sections.dart';
import 'package:kiyori_ui/kiyori_ui.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'support/ui_capture.dart';

class FixtureExchange implements TextExchange {
  String? input;
  String? exported;
  Completer<String?>? gate;
  bool fail = false;
  @override
  Future<String?> importText() async {
    if (fail) throw const TextExchangeException('fixture-private-error');
    return gate == null ? input : await gate!.future;
  }

  @override
  Future<bool> exportText(String text, {required String suggestedName}) async {
    expect(suggestedName, 'api_keys.txt');
    exported = text;
    return true;
  }
}

void main() {
  testWidgets(
    'pool imports large ordered lists, exports and scopes clear and late results',
    (tester) async {
      const output = String.fromEnvironment('KIYORI_CAPTURE');
      if (output.isNotEmpty) await loadCaptureFonts(tester);
      final capture = GlobalKey();
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final exchange = FixtureExchange()
        ..input = List.generate(21, (i) => 'fixture-$i').join('\n');
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => RepaintBoundary(key: capture, child: child),
          theme: KiyoriTheme.dark(),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: show,
              builder: (_, visible, _) => visible
                  ? SingleChildScrollView(
                      child: ModelAdvancedCard(exchange: exchange),
                    )
                  : const Text('removed'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('批量导入密钥'));
      await tester.pumpAndSettle();
      expect(find.text('已保存 21 个API密钥'), findsOneWidget);
      expect(find.text('添加API密钥'), findsNothing);
      expect(find.byTooltip('编辑API密钥'), findsNothing);
      if (output.isNotEmpty) {
        await captureUi(tester, capture, output, 'model-pool-large-dark');
      }
      await tester.tap(find.text('导出密钥'));
      await tester.pumpAndSettle();
      expect(exchange.exported, exchange.input);
      await tester.tap(find.text('清空密钥池'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('已保存 21 个API密钥'), findsOneWidget);
      await tester.tap(find.text('清空密钥池'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, '清空密钥池'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('API密钥池为空，点击下方按钮添加密钥'), findsOneWidget);
      exchange.fail = true;
      await tester.tap(find.text('批量导入密钥'));
      await tester.pumpAndSettle();
      expect(find.text('文件操作失败，请检查文本编码和访问权限后重试'), findsOneWidget);
      exchange.fail = false;
      exchange.gate = Completer<String?>();
      await tester.tap(find.text('批量导入密钥'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      show.value = false;
      await tester.pumpAndSettle();
      exchange.gate!.complete('late-fixture');
      await tester.pumpAndSettle();
      expect(find.text('removed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
