import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/assistant/presentation/chat_page.dart';
import '../../features/assistant/presentation/chat_controller.dart';
import '../../features/assistant/presentation/ai_drawer.dart';
import '../../features/browser/presentation/browser_page.dart';
import '../../features/files/presentation/files_page.dart';
import '../../features/toolbox/presentation/toolbox_page.dart';
import '../../features/toolbox/presentation/toolbox_presentation.dart';
import '../../features/workflows/presentation/workflow_controller.dart';
import '../../features/workflows/presentation/workflow_page.dart';
import '../../features/knowledge/presentation/knowledge_controller.dart';
import '../../features/assistant/presentation/prompts/prompts_controller.dart';
import '../../features/assistant/presentation/models/models_controller.dart';
import '../../features/knowledge/presentation/knowledge_page.dart';
import 'settings_navigation.dart';
import 'bottom_navigation.dart';
import 'home_page.dart';
import 'minus_one_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    this.workflows,
    this.knowledge,
    this.prompts,
    this.models,
    this.chat,
    super.key,
  });
  final ModelsController? models;
  final ChatController? chat;
  final PromptsController? prompts;
  final WorkflowController? workflows;
  final KnowledgeController? knowledge;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  SettingsNavigation get navigation => SettingsNavigation(
    Navigator.of(context),
    prompts: widget.prompts,
    models: widget.models,
    chat: widget.chat,
  );

  final pager = PageController(initialPage: 1);
  int settled = 1;
  int destination = 0;
  int browserReturn = 0;
  final visitedPages = <int, Widget>{};
  bool preloadReady = false;
  bool aiDrawerOpen = false;
  String? selectedAiEntry = 'main.ai_chat';
  Widget? aiToolbox;
  Widget? aiWorkflows;
  Widget? aiKnowledge;
  final knowledgeKey = GlobalKey<KnowledgePageState>();
  final workflowKey = GlobalKey<WorkflowPageState>();
  late final drawerPlugins = <AiDrawerEntry>[];
  late final pages = <Widget>[
    MinusOnePage(onClose: () => go(1)),
    HomePage(openAi: () => go(2)),
    ChatPage(
      onOpenDrawer: openAiDrawer,
      controller: widget.chat,
      onOpenModels: navigation.openModels,
      onOpenCharacters: navigation.openCharacters,
      onOpenTools: navigation.openToolboxSettings,
      onOpenMemory: () {
        final knowledge = widget.knowledge;
        if (knowledge != null) {
          navigation.openPage(
            KnowledgePage(
              controller: knowledge,
              onMenu: () => Navigator.of(context).maybePop(),
            ),
          );
        }
      },
    ),
  ];

  void openAiDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => aiDrawerOpen = true);
    final workflows = widget.workflows;
    if (workflows != null && !workflows.loaded && !workflows.loading) {
      unawaited(workflows.load());
    }
  }

  void closeAiDrawer() => setState(() => aiDrawerOpen = false);

  void selectAiEntry(AiDrawerEntry entry) {
    final same = selectedAiEntry == entry.id;
    setState(() => aiDrawerOpen = false);
    if (same) return;
    switch (entry.id) {
      case 'main.ai_chat':
        selectedAiEntry = entry.id;
        go(2);
      case 'main.toolbox':
        selectedAiEntry = entry.id;
        aiToolbox ??= ToolboxPage(
          onMenu: openAiDrawer,
          onSettings: navigation.openToolboxSettings,
          onSpeech: navigation.openSpeechTool,
        );
        go(2);
      case 'main.settings':
        navigation.openPage(
          Scaffold(
            body: navigation.buildSettingsPage(
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        );
      case 'main.workflow':
        final workflows = widget.workflows;
        if (workflows == null) return;
        selectedAiEntry = entry.id;
        aiWorkflows ??= WorkflowPage(
          key: workflowKey,
          controller: workflows,
          onMenu: openAiDrawer,
        );
        go(2);
      case 'main.memory_base':
        final knowledge = widget.knowledge;
        if (knowledge == null) return;
        selectedAiEntry = entry.id;
        aiKnowledge ??= KnowledgePage(
          key: knowledgeKey,
          controller: knowledge,
          onMenu: openAiDrawer,
        );
        go(2);
      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.workflows?.addListener(_workflowsChanged);
    // 首帧先显示首页；随后准备相邻轻量页面，避免第一次手指移动才布局。
    // 这里只预热 UI，不允许页面 build 启动网络、文件扫描或业务任务。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => preloadReady = true);
    });
  }

  @override
  void dispose() {
    widget.workflows?.removeListener(_workflowsChanged);
    pager.dispose();
    super.dispose();
  }

  void _workflowsChanged() {
    if (mounted) setState(() {});
  }

  void go(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      pager.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
      ),
    );
  }

  void select(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (value == 1) browserReturn = destination;
      destination = value;
      // 按访问创建轻量 UI，保留滚动与折叠；隐藏页不启动业务也不响应输入。
      if (value > 1) {
        visitedPages.putIfAbsent(
          value,
          () => switch (value) {
            2 => ToolboxPage(
              onSettings: navigation.openToolboxSettings,
              onSpeech: navigation.openSpeechTool,
            ),
            3 => FilesPage(onSettings: navigation.openFileSettings),
            _ => navigation.buildSettingsPage(),
          },
        );
      }
    });
    if (value == 0) go(1);
  }

  void back() {
    if (aiDrawerOpen) {
      closeAiDrawer();
    } else if (destination == 0 &&
        settled == 2 &&
        selectedAiEntry == 'main.memory_base' &&
        (knowledgeKey.currentState?.handleBack() ?? false)) {
      return;
    } else if (destination == 0 &&
        settled == 2 &&
        selectedAiEntry == 'main.workflow' &&
        (workflowKey.currentState?.handleBack() ?? false)) {
      return;
    } else if (destination == 1) {
      select(browserReturn);
    } else if (destination != 0) {
      select(0);
    } else {
      go(1);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !aiDrawerOpen && destination == 0 && settled == 1,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Offstage(
              offstage: destination != 0,
              child: ExcludeFocus(
                excluding: destination != 0,
                child: TickerMode(
                  enabled: destination == 0,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: PageView(
                      controller: pager,
                      // 保留系统手势仲裁阈值，但胜出后从按下点计算跟手位移。
                      dragStartBehavior: DragStartBehavior.down,
                      allowImplicitScrolling: preloadReady,
                      onPageChanged: (value) => setState(() => settled = value),
                      children: [
                        for (var index = 0; index < pages.length; index++)
                          ExcludeFocus(
                            excluding: settled != index || aiDrawerOpen,
                            child: index == 2
                                ? Stack(
                                    children: [
                                      Offstage(
                                        offstage:
                                            selectedAiEntry != 'main.ai_chat',
                                        child: ExcludeFocus(
                                          excluding:
                                              selectedAiEntry != 'main.ai_chat',
                                          child: pages[index],
                                        ),
                                      ),
                                      if (aiToolbox != null)
                                        Offstage(
                                          offstage:
                                              selectedAiEntry != 'main.toolbox',
                                          child: ExcludeFocus(
                                            excluding:
                                                selectedAiEntry !=
                                                'main.toolbox',
                                            child: aiToolbox!,
                                          ),
                                        ),
                                      if (aiWorkflows != null)
                                        Offstage(
                                          offstage:
                                              selectedAiEntry !=
                                              'main.workflow',
                                          child: ExcludeFocus(
                                            excluding:
                                                selectedAiEntry !=
                                                'main.workflow',
                                            child: TickerMode(
                                              enabled:
                                                  settled == 2 &&
                                                  selectedAiEntry ==
                                                      'main.workflow',
                                              child: aiWorkflows!,
                                            ),
                                          ),
                                        ),
                                      if (aiKnowledge != null)
                                        Offstage(
                                          offstage:
                                              selectedAiEntry !=
                                              'main.memory_base',
                                          child: ExcludeFocus(
                                            excluding:
                                                selectedAiEntry !=
                                                'main.memory_base',
                                            child: TickerMode(
                                              enabled:
                                                  settled == 2 &&
                                                  selectedAiEntry ==
                                                      'main.memory_base',
                                              child: aiKnowledge!,
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                : pages[index],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (destination == 1) BrowserPage(onBack: back),
            for (final entry in visitedPages.entries)
              Offstage(
                key: ValueKey(entry.key),
                offstage: destination != entry.key,
                child: ExcludeFocus(
                  excluding: destination != entry.key,
                  child: TickerMode(
                    enabled: destination == entry.key,
                    child: entry.value,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: pager,
                child: RepaintBoundary(
                  child: HomeBottomNavigation(
                    selected: destination,
                    onSelected: select,
                  ),
                ),
                builder: (context, child) {
                  final position = pager.hasClients ? pager.page ?? 1 : 1.0;
                  final alpha = destination == 1
                      ? 0.0
                      : destination != 0
                      ? 1.0
                      : (1 - (position - 1).abs()).clamp(0.0, 1.0);
                  return IgnorePointer(
                    ignoring: alpha < .999,
                    child: ExcludeSemantics(
                      excluding: alpha < .999,
                      child: Opacity(
                        key: const Key('bar-opacity'),
                        opacity: alpha,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            AiDrawer(
              toolboxCount: ToolboxPresentation.all.length,
              workflowCount: widget.workflows?.loaded == true
                  ? widget.workflows!.records.length
                  : null,
              open: aiDrawerOpen,
              selected: selectedAiEntry,
              plugins: drawerPlugins,
              onDismiss: closeAiDrawer,
              onClose: () {
                closeAiDrawer();
                go(1);
              },
              onSelect: selectAiEntry,
            ),
          ],
        ),
      ),
    ),
  );
}
