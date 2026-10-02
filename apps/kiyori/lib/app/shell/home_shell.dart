import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/assistant/presentation/chat_page.dart';
import '../../features/browser/presentation/browser_page.dart';
import '../../features/files/presentation/files_page.dart';
import '../../features/toolbox/presentation/toolbox_page.dart';
import 'settings_navigation.dart';
import 'bottom_navigation.dart';
import 'home_page.dart';
import 'minus_one_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  SettingsNavigation get navigation =>
      SettingsNavigation(Navigator.of(context));

  final pager = PageController(initialPage: 1);
  int settled = 1;
  int destination = 0;
  int browserReturn = 0;
  final visitedPages = <int, Widget>{};
  bool preloadReady = false;
  late final pages = <Widget>[
    MinusOnePage(onClose: () => go(1)),
    HomePage(openAi: () => go(2)),
    const ChatPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 首帧先显示首页；随后准备相邻轻量页面，避免第一次手指移动才布局。
    // 这里只预热 UI，不允许页面 build 启动网络、文件扫描或业务任务。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => preloadReady = true);
    });
  }

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
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
    if (destination == 1) {
      select(browserReturn);
    } else if (destination != 0) {
      select(0);
    } else {
      go(1);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: destination == 0 && settled == 1,
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
                    children: pages,
                  ),
                ),
              ),
            ),
            if (destination == 1) BrowserPage(onBack: back),
            for (final entry in visitedPages.entries)
              Offstage(
                key: ValueKey(entry.key),
                offstage: destination != entry.key,
                child: TickerMode(
                  enabled: destination == entry.key,
                  child: entry.value,
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
          ],
        ),
      ),
    ),
  );
}
