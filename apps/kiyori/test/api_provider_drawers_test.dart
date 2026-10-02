import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/assistant/presentation/models/api_provider_drawers.dart';
import 'package:kiyori/features/assistant/presentation/models/api_provider_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('provider search and protocol selection $size/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        ApiProviderPresentation? provider;
        ModelApiProtocol? protocol;
        await tester.pumpWidget(
          MaterialApp(
            theme: KiyoriTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        provider = await showApiProviderDrawer(
                          context,
                          selectedId: 'DEEPSEEK',
                        );
                      },
                      child: const Text('提供方'),
                    ),
                    TextButton(
                      onPressed: () async {
                        protocol = await showApiProtocolDrawer(
                          context,
                          provider: provider!,
                          selected: provider!.defaultProtocol,
                        );
                      },
                      child: const Text('协议'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('提供方'));
        await tester.pumpAndSettle();
        final search = find.byType(TextField);
        await tester.enterText(search, 'GPT 系列');
        await tester.pumpAndSettle();
        expect(find.text('国际供应商'), findsOneWidget);
        await tester.enterText(search, 'llama.cpp');
        await tester.pumpAndSettle();
        expect(find.text('国际供应商'), findsNothing);
        expect(
          find.byKey(const ValueKey('provider-LLAMA_CPP')),
          findsOneWidget,
        );
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 120 : 240,
        );
        await tester.pumpAndSettle();
        await tester.enterText(search, '深度求索');
        await tester.pumpAndSettle();
        final entry = find.text('深度求索（DeepSeek 系列）');
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(provider?.id, 'DEEPSEEK');
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(find.text('协议'));
        await tester.pumpAndSettle();
        final responses = find.text('OpenAI Responses API');
        for (var i = 0; i < 15 && responses.evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).last, const Offset(0, -80));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(responses);
        await tester.pumpAndSettle();
        await tester.tap(responses);
        await tester.pumpAndSettle();
        expect(protocol, ModelApiProtocol.responses);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
