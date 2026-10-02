import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyori/app/shell/home_shell.dart';
import 'package:kiyori/features/workflows/presentation/workflow_controller.dart';
import 'package:kiyori/features/workflows/presentation/workflow_page.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'support/fake_runtime.dart';
import 'support/ui_capture.dart';

class WorkflowClient extends FakeClient {
  final rows = <WorkflowRecord>[];
  Future<List<WorkflowRecord>> Function()? read;
  Completer<void>? creation;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<List<WorkflowRecord>> listWorkflows() async =>
      read != null ? read!() : List.of(rows);
  @override
  Future<WorkflowRecord> createWorkflow(String name, String description) async {
    writes++;
    await creation?.future;
    if (failWrite) throw StateError('storage unavailable');
    final row = WorkflowRecord(
      id: 'id-$writes',
      name: name.trim(),
      description: description,
      createdAt: writes,
      updatedAt: writes,
      enabled: true,
    );
    rows.insert(0, row);
    return row;
  }

  @override
  Future<bool> deleteWorkflow(String id) async {
    if (failWrite) throw StateError('storage unavailable');
    final count = rows.length;
    rows.removeWhere((row) => row.id == id);
    return rows.length != count;
  }

  @override
  Future<int> deleteWorkflows(List<String> ids) async {
    final count = rows.length;
    rows.removeWhere((row) => ids.contains(row.id));
    return count - rows.length;
  }

  @override
  Future<WorkflowRecord> updateWorkflow({
    required String id,
    required String name,
    required String description,
    required bool enabled,
  }) async {
    final old = rows.singleWhere((row) => row.id == id);
    final row = WorkflowRecord(
      id: id,
      name: name,
      description: description,
      enabled: enabled,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt + 1,
    );
    rows.remove(old);
    rows.insert(0, row);
    return row;
  }
}

void main() {
  testWidgets(
    'batch selection clears and confirmed deletion refreshes directory',
    (tester) async {
      final client = WorkflowClient();
      await client.createWorkflow('一', '');
      await client.createWorkflow('二', '');
      final state = WorkflowController(() async => client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowPage(controller: state, onMenu: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建工作流'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('多选'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全选当前列表'));
      await tester.pumpAndSettle();
      expect(find.text('已选择 2 项'), findsOneWidget);
      await tester.tap(find.text('清空选择'));
      await tester.pumpAndSettle();
      expect(find.text('已选择 0 项'), findsOneWidget);
      await tester.tap(find.text('一'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建工作流'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除选中 (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(client.rows.single.name, '二');
      expect(find.text('已选择 0 项'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'only the latest read publishes and mutations invalidate stale reads',
    () async {
      final client = WorkflowClient();
      final state = WorkflowController(() async => client);
      addTearDown(state.dispose);
      final first = Completer<List<WorkflowRecord>>();
      client.read = () => first.future;
      final pending = state.load();
      await Future<void>.delayed(Duration.zero);
      client.read = null;
      final created = await state.create('工作流', '');
      expect(created, isNotNull);
      first.complete([]);
      await pending;
      expect(state.records.single.id, created!.id);
    },
  );

  test(
    'duplicate submission is ignored and refresh failure does not undo commit',
    () async {
      final client = WorkflowClient()..creation = Completer<void>();
      final state = WorkflowController(() async => client);
      addTearDown(state.dispose);
      final pending = state.create('once', '');
      expect(await state.create('twice', ''), isNull);
      client.read = () async => throw StateError('read failed');
      client.creation!.complete();
      expect(await pending, isNotNull);
      expect(client.writes, 1);
      expect(state.error, contains('操作已保存'));
      client.read = null;
      await state.load();
      expect(state.records.single.name, 'once');
    },
  );

  test('disposed projection ignores a late mutation result without cancelling committed data', () async {
    final client = WorkflowClient()..creation = Completer<void>();
    final state = WorkflowController(() async => client);
    final pending = state.create('保留', '');
    await Future<void>.delayed(Duration.zero);
    state.dispose();
    client.creation!.complete();
    expect(await pending, isNull);
    expect(client.rows.single.name, '保留');
  });

  testWidgets(
    'create, return, reopen and confirmed delete follow persisted snapshot',
    (tester) async {
      final client = WorkflowClient();
      final state = WorkflowController(() async => client);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: KiyoriTheme.light(),
          home: Scaffold(
            body: WorkflowPage(controller: state, onMenu: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('开始创建工作流'), findsOneWidget);
      await tester.tap(find.text('新建工作流'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name')),
        '持久定义',
      );
      await tester.enterText(
        find.byKey(const ValueKey('workflow-description')),
        '中文描述',
      );
      await tester.tap(find.widgetWithText(TextButton, '创建'));
      await tester.pumpAndSettle();
      expect(find.text('暂无节点'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('持久定义'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('打开操作菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除工作流'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(client.rows, hasLength(1));
      await tester.tap(find.byTooltip('打开操作菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除工作流'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(client.rows, isEmpty);
      expect(find.text('开始创建工作流'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('drawer and workflow directory consume the same owner', (
    tester,
  ) async {
    final client = WorkflowClient();
    final state = WorkflowController(() async => client);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: KiyoriTheme.light(),
        home: HomeShell(workflows: state),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(2);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('菜单').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main.workflow')));
    await tester.pumpAndSettle();
    expect(find.text('开始创建工作流'), findsOneWidget);
    await tester.tap(find.text('新建工作流'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('workflow-name')), '来源保持');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '创建'));
    await tester.pumpAndSettle();
    expect(find.text('暂无节点'), findsOneWidget);
    expect(
      tester.state<WorkflowPageState>(find.byType(WorkflowPage)).selectedId,
      client.rows.single.id,
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('来源保持'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'workflow editing, error draft and viewport ${size.width} $dark',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = size.width == 320
              ? 2
              : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final client = WorkflowClient();
          await client.createWorkflow('现有工作流', '保存的描述');
          final state = WorkflowController(() async => client);
          final boundary = GlobalKey();
          const output = String.fromEnvironment('KIYORI_CAPTURE');
          if (output.isNotEmpty) {
            await loadCaptureFonts(tester);
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? KiyoriTheme.dark() : KiyoriTheme.light(),
              builder: (_, child) =>
                  RepaintBoundary(key: boundary, child: child!),
              home: Scaffold(
                body: WorkflowPage(controller: state, onMenu: () {}),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'workflow-list-${size.width}-$dark',
            );
          }
          await tester.tap(find.text('现有工作流'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('打开操作菜单'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('编辑工作流'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('workflow-name')),
            '更新后的名称',
          );
          await tester.tap(find.widgetWithText(TextButton, '保存'));
          await tester.pumpAndSettle();
          expect(client.rows.single.name, '更新后的名称');
          await tester.tap(find.bySemanticsLabel('返回'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('创建工作流'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('新建空白'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('workflow-name')),
            '失败后保留草稿',
          );
          client.failWrite = true;
          await tester.pump();
          await tester.tap(find.widgetWithText(TextButton, '创建'));
          await tester.pumpAndSettle();
          expect(find.text('失败后保留草稿'), findsOneWidget);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(client.writes, 2);
          expect(state.error, isNotNull);
          if (output.isNotEmpty) {
            await captureUi(
              tester,
              boundary,
              output,
              'workflow-error-${size.width}-$dark',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          state.dispose();
        },
      );
    }
  }

  testWidgets(
    'closing a saving dialog prevents late navigation and preserves committed record',
    (tester) async {
      final client = WorkflowClient()..creation = Completer<void>();
      final state = WorkflowController(() async => client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowPage(controller: state, onMenu: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建工作流'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name')),
        '关闭中保存',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '创建'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '关闭'));
      await tester.pumpAndSettle();
      client.creation!.complete();
      await tester.pumpAndSettle();
      expect(find.text('暂无节点'), findsNothing);
      expect(find.text('关闭中保存'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
