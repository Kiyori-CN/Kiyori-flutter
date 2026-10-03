import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/api_provider_presentation.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_connection.dart';
import 'package:kiyori/features/assistant/presentation/models/model_api_page.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_test_helpers.dart';

void main() {
  testWidgets('protocol value and explanation stay below its title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KiyoriTheme.light(), home: const ModelApiPage()),
    );
    await tester.pumpAndSettle();
    await revealModel(tester, find.text('API协议'));
    final title = tester.getRect(find.text('API协议'));
    final value = tester.getRect(find.text('OpenAI Chat Completions'));
    expect(value.top, greaterThanOrEqualTo(title.bottom));
    expect(value.left, title.left);
    expect(find.text(ModelApiProtocol.chat.summary), findsOneWidget);
    await tester.tap(find.text('API协议'));
    await tester.pumpAndSettle();
    expect(find.text('选择API协议'), findsOneWidget);
    expect(find.text('OpenAI Responses API'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'provider switch preserves custom endpoint and key draft is masked off focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: KiyoriTheme.light(), home: const ModelApiPage()),
      );
      await tester.pumpAndSettle();
      final endpoint = find.byKey(const ValueKey('API端点'));
      await revealModel(tester, endpoint);
      await tester.enterText(endpoint, 'https://custom.example.com/private');
      final key = find.byKey(const ValueKey('API密钥'));
      await revealModel(tester, key);
      await tester.enterText(key, 'abcd12345678wxyz');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(key);
      expect(
        field.controller!
            .buildTextSpan(context: tester.element(key), withComposing: false)
            .toPlainText(),
        'abcd********wxyz',
      );
      await revealModel(tester, find.text('API提供方'));
      await tester.tap(find.text('API提供方'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'GPT 系列');
      await tester.pumpAndSettle();
      final openai = find.byKey(const ValueKey('provider-OPENAI'));
      await tester.ensureVisible(openai);
      await tester.pumpAndSettle();
      await tester.tap(openai);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(endpoint).controller!.text,
        'https://custom.example.com/private',
      );
      expect(field.controller!.text, 'abcd12345678wxyz');
      expect(find.text('deepseek-v4-flash'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'configuration switching retains drafts and removed selection reconciles',
    (tester) async {
      const data = [
        ModelConfigPresentation(id: 'default', name: '默认配置'),
        ModelConfigPresentation(id: 'second', name: '第二配置'),
      ];
      Future<void> mount(List<ModelConfigPresentation> configs) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            home: ModelApiPage(configurations: configs),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(data);
      final endpoint = find.byKey(const ValueKey('API端点'));
      await revealModel(tester, endpoint);
      await tester.enterText(endpoint, 'https://first.example.com');
      await revealModel(tester, find.text('默认配置'));
      await tester.tap(find.text('默认配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第二配置'));
      await tester.pumpAndSettle();
      expect(find.text('重命名'), findsOneWidget);
      await tester.tap(find.text('第二配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认配置').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(endpoint).controller!.text,
        'https://first.example.com',
      );
      await mount([data.last]);
      expect(find.text('第二配置'), findsOneWidget);
      await mount(const []);
      expect(tester.takeException(), isNull);
    },
  );
  test('endpoint preview mirrors protocol suffixes without requests', () {
    expect(
      completeModelEndpointPreview(
        'https://example.com',
        ModelApiProtocol.chat,
      ),
      'https://example.com/v1/chat/completions',
    );
    expect(
      completeModelEndpointPreview(
        'https://example.com/custom/v1/',
        ModelApiProtocol.responses,
      ),
      'https://example.com/custom/v1/responses',
    );
    expect(
      completeModelEndpointPreview(
        'https://example.com/anthropic',
        ModelApiProtocol.messages,
      ),
      'https://example.com/anthropic/v1/messages',
    );
    expect(
      completeModelEndpointPreview(
        'https://example.com/#',
        ModelApiProtocol.chat,
      ),
      'https://example.com/',
    );
    expect(
      completeModelEndpointPreview('invalid', ModelApiProtocol.chat),
      'invalid',
    );
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'model API draft, expansions and dialog lifecycle $size/$scale',
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
              home: const ModelApiPage(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('新建'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, '测试配置');
          await tester.tap(find.text('创建'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          final endpoint = find.byKey(const ValueKey('API端点'));
          await revealModel(tester, endpoint);
          await tester.enterText(endpoint, 'https://custom.example.com/v1');
          await tester.pumpAndSettle();
          expect(
            find.text('实际请求地址: https://custom.example.com/v1/chat/completions'),
            findsOneWidget,
          );
          final key = find.byKey(const ValueKey('API密钥'));
          await revealModel(tester, key);
          await tester.enterText(key, 'abcd 1234\n5678wxyz');
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(key).controller!.text,
            'abcd12345678wxyz',
          );
          await revealModel(tester, find.text('上下文设置'));
          await tester.tap(find.text('上下文设置'));
          await tester.pumpAndSettle();
          final length = find.byKey(const ValueKey('上下文长度'));
          await revealModel(tester, length);
          await tester.enterText(length, '0');
          await tester.pumpAndSettle();
          expect(find.text('请输入有效的上下文长度'), findsOneWidget);
          await tester.enterText(length, '128');
          await tester.pumpAndSettle();
          await revealModel(tester, find.text('模型参数设置'));
          await tester.tap(find.text('模型参数设置'));
          await tester.pumpAndSettle();
          await revealModel(tester, find.byTooltip('展开最大生成Token数'));
          await tester.tap(find.byTooltip('展开最大生成Token数'));
          await tester.pumpAndSettle();
          expect(find.text('默认值: 4096'), findsOneWidget);
          await revealModel(tester, find.byType(TabBar));
          await tester.drag(find.byType(TabBar), const Offset(-130, 0));
          await tester.pumpAndSettle();
          await tester.tap(find.text('创造性参数'));
          await tester.pumpAndSettle();
          expect(find.text('温度推荐设置'), findsOneWidget);
          await revealModel(tester, find.text('自定义请求头'));
          await tester.tap(find.text('自定义请求头'));
          await tester.pumpAndSettle();
          await revealModel(tester, find.text('添加请求头'));
          await tester.tap(find.text('添加请求头'));
          await tester.pumpAndSettle();
          await revealModel(tester, find.byTooltip('删除请求头'));
          await tester.tap(find.byTooltip('删除请求头'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('删除请求头'), findsNothing);
          await revealModel(tester, find.text('请求队列控制'));
          await tester.tap(find.text('请求队列控制'));
          await tester.pumpAndSettle();
          await revealModel(tester, find.byKey(const ValueKey('最大并发请求数')));
          await tester.enterText(find.byKey(const ValueKey('最大并发请求数')), '8');
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 240,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
