import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/features/browser/presentation/browser_credentials_presentation.dart';
import 'package:kiyori/features/browser/presentation/browser_password_page.dart';
import 'package:kiyori/features/browser/presentation/browser_script_permissions_page.dart';
import 'package:kiyori/features/browser/presentation/browser_scripts_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/ui_capture.dart';
import 'support/ui_test_helpers.dart';

const credential = BrowserCredentialSummary(
  id: 'one',
  host: 'example.test',
  origin: 'https://example.test',
  pageUrl: 'https://example.test/login',
  username: '演示账号',
);
const second = BrowserCredentialSummary(
  id: 'two',
  host: 'second.test',
  origin: 'https://second.test',
  pageUrl: 'https://second.test/auth',
  username: '第二账号',
);
BrowserCredentialsPresentation vault({
  List<BrowserCredentialSummary> entries = const [credential, second],
  String secret = 'fixture-only-value',
}) => BrowserCredentialsPresentation(
  available: true,
  credentials: entries,
  securityDescription: '账号与密码使用平台安全存储保护，不进入当前备份。',
  details: {
    for (final item in entries)
      item.id: BrowserCredentialDetail(summary: item, password: secret),
  },
);
const scripts = BrowserScriptsPresentation(
  supported: true,
  allowed: true,
  scripts: [
    BrowserScriptPresentation(
      id: 'one',
      name: '示例脚本',
      enabled: true,
      world: BrowserScriptWorld.isolated,
      grants: ['GM_getValue', 'GM_getValue'],
      pageRules: ['https://a.test/*', 'https://b.test/*', 'https://c.test/*'],
      connects: ['api.test'],
    ),
    BrowserScriptPresentation(
      id: 'two',
      name: '待审查脚本',
      enabled: true,
      unknownGrants: ['unknown'],
    ),
    BrowserScriptPresentation(
      id: 'three',
      name: '受阻脚本',
      enabled: true,
      blockedReasons: ['不支持'],
      unknownGrants: ['unknown'],
    ),
  ],
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    BrowserCredentialsPresentation state,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: BrowserPasswordPage(snapshot: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await reveal(tester, find.text('example.test'));
    await tester.tap(find.text('example.test'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'credential details mask on entry and changed secret; search excludes secrets',
    (tester) async {
      await mount(tester, vault());
      await open(tester);
      expect(find.text('fixture-only-value'), findsNothing);
      await tester.tap(find.byTooltip('显示密码'));
      await tester.pump();
      expect(find.text('fixture-only-value'), findsOneWidget);
      await mount(tester, vault(secret: 'replacement-fixture'));
      expect(find.text('replacement-fixture'), findsNothing);
      expect(find.byTooltip('显示密码'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'replacement-fixture');
      await tester.pump();
      expect(find.text('没有匹配的网站或账号'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '/auth');
      await tester.pump();
      expect(find.text('second.test'), findsOneWidget);
      expect(find.text('example.test'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'credential edit draft retains on reorder and releases on deletion or vault lock',
    (tester) async {
      await mount(tester, vault());
      await open(tester);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final controller = tester.widget<TextField>(fields.first).controller!;
      await tester.enterText(fields.first, '本地草稿');
      await mount(tester, vault(entries: [second, credential]));
      expect(controller.text, '本地草稿');
      await tester.enterText(fields.first, ' ');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
            .onPressed,
        isNull,
      );
      await tester.enterText(fields.first, '有效账号');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await mount(tester, vault(entries: [second]));
      expect(find.byType(AlertDialog), findsNothing);
      expect(() => controller.addListener(() {}), throwsFlutterError);
      await mount(tester, vault());
      expect(find.byType(AlertDialog), findsNothing);
      await open(tester);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除网站密码？'), findsOneWidget);
      await mount(tester, const BrowserCredentialsPresentation());
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('removing credential page releases a just-opened detail route', (
    tester,
  ) async {
    await mount(tester, vault());
    await reveal(tester, find.text('example.test'));
    await tester.tap(find.text('example.test'));
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: const Scaffold(body: Text('外部')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'script permission summaries keep declaration and runtime precedence distinct',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: BrowserScriptPermissionsPage(
            snapshot: scripts,
            onOpenScript: (id) => selected = id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('示例脚本'));
      expect(find.textContaining('1 项权限'), findsOneWidget);
      await tester.tap(find.text('示例脚本'));
      expect(selected, 'one');
      await reveal(tester, find.text('受阻脚本'));
      expect(find.text('不可运行'), findsOneWidget);
      expect(find.text('需审查'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: const BrowserScriptPermissionsPage(
            snapshot: BrowserScriptsPresentation(allowed: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = tester.widget<SettingsRow>(
        find.widgetWithText(SettingsRow, '允许用户脚本'),
      );
      expect(row.enabled, isTrue);
      expect(row.checked, isTrue);
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
      testWidgets('browser credentials and permissions $size dark=$dark', (
        tester,
      ) async {
        if (output.isNotEmpty) await loadCaptureFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        Future<void> show(Widget child) async {
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
                home: child,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name) async {
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              '$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
            );
          }
          expect(tester.takeException(), isNull);
        }

        await show(BrowserPasswordPage(snapshot: vault()));
        await capture('credentials-list');
        await open(tester);
        await capture('credentials-detail');
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        final field = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .last;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, 'fixture-edited');
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await capture('credentials-edit-keyboard');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await show(
          const BrowserPasswordPage(
            snapshot: BrowserCredentialsPresentation(
              loading: true,
              securityDescription: '正在从平台安全存储解锁本机凭据，请稍候。',
            ),
          ),
        );
        await capture('credentials-loading');
        await show(const BrowserScriptPermissionsPage(snapshot: scripts));
        await reveal(tester, find.text('受阻脚本'));
        await capture('scripts-permissions');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
