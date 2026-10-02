import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/open_source_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'license search by name, license and address retains rows $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
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
            home: const OpenSourcePage(),
          ),
        );
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, ' libplacebo ');
        await tester.pumpAndSettle();
        expect(find.text('libplacebo'), findsOneWidget);
        expect(find.textContaining('当前清单 1 / 150 项'), findsOneWidget);
        await tester.enterText(search, 'https://github.com/ufbx');
        await tester.pumpAndSettle();
        expect(find.text('ufbx'), findsOneWidget);
        await tester.enterText(search, 'nonexistent-component');
        await tester.pumpAndSettle();
        expect(find.text('没有匹配的开源组件'), findsOneWidget);
        await tester.enterText(search, 'Apache-2.0');
        await tester.pumpAndSettle();
        expect(find.text('没有匹配的开源组件'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
