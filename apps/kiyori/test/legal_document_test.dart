import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/settings/presentation/legal_document.dart';
import 'package:kiyori/features/settings/presentation/legal_document_page.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'settings_detail_test.dart' show reveal;

void main() {
  for (final document in LegalDocument.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'legal contents reaches final chapter without truncation ${document.name} / $scale',
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
              home: LegalDocumentPage(document: document),
            ),
          );
          await reveal(tester, find.text('浏览目录 · 15 个章节'));
          await tester.tap(find.text('浏览目录 · 15 个章节'));
          await tester.pumpAndSettle();
          final finalChip = find.widgetWithText(
            ActionChip,
            document.sections.last.title,
          );
          await Scrollable.ensureVisible(
            tester.element(finalChip),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(finalChip);
          await tester.pumpAndSettle();
          final title = find.text(document.sections.last.title).last;
          expect(title.hitTestable(), findsOneWidget);
          expect(find.text(document.sections.last.body), findsOneWidget);
          expect(find.byType(SelectionArea), findsOneWidget);
          final paragraph = tester.widget<Text>(
            find.text(document.sections.last.body),
          );
          expect(paragraph.maxLines, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
