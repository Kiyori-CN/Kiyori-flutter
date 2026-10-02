import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'primary_page.dart';
import 'shell_action.dart';

/// 长表单使用独立滚动正文和固定操作区；不嵌套第二个内容列表。
class SettingsWorkspacePage extends StatelessWidget {
  const SettingsWorkspacePage({
    required this.title,
    required this.body,
    this.footer,
    this.headerAction,
    required this.onBack,
    super.key,
  });
  final String title;
  final Widget body;
  final Widget? footer;
  final Widget? headerAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final background = PrimaryColors.of(context).background;
    // 旧工作台独立覆盖 KiyoriSettingsTheme，不能直接继承应用普通卡片色。
    return SettingsTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: background,
          body: SafeArea(
            top: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final top = MediaQuery.paddingOf(context).top;
                    final progress = (constraints.scrollOffset / 72).clamp(
                      0.0,
                      1.0,
                    );
                    return _WorkspaceHeaderSliver(
                      top: top,
                      child: _WorkspaceHeader(
                        title,
                        top,
                        onBack,
                        progress,
                        headerAction,
                      ),
                    );
                  },
                ),
              ],
              body: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: body,
                      ),
                    ),
                  ),
                  if (footer != null)
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 840),
                          child: footer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader(
    this.title,
    this.top,
    this.onBack,
    this.progress,
    this.action,
  );
  final String title;
  final double top;
  final VoidCallback onBack;
  final Widget? action;
  final double progress;
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('settings-workspace-header'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: top + 8,
            left: 4,
            child: ShellAction(
              Icons.arrow_back,
              '返回',
              size: 48,
              iconSize: 21,
              color: Theme.of(context).colorScheme.onSurface,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: top + 60 - 40 * progress,
            left: 32 + 22 * progress,
            right: action == null ? 16 : 64,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 26 - 6 * progress,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null)
            Positioned(
              top: top + 8,
              right: 8,
              width: 48,
              height: 48,
              child: action!,
            ),
        ],
      ),
    );
  }
}

/// 旧工作台消耗 72px 滚动，但标题高度只缩短 64px。
/// 标准 pinned header 将两者绑定为同一值；这里显式分离滚动和绘制几何。
/// 正文由 NestedScrollView 管理，标题变化只布局标题，不重建表单。
class _WorkspaceHeaderSliver extends SingleChildRenderObjectWidget {
  const _WorkspaceHeaderSliver({required this.top, required super.child});
  final double top;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWorkspaceHeader(top);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWorkspaceHeader renderObject,
  ) {
    renderObject.top = top;
  }
}

class _RenderWorkspaceHeader extends RenderSliverSingleBoxAdapter {
  _RenderWorkspaceHeader(this._top);
  double _top;
  set top(double value) {
    if (_top == value) return;
    _top = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final progress = (constraints.scrollOffset / 72).clamp(0.0, 1.0);
    final height = _top + 128 - 64 * progress;
    child!.layout(
      constraints.asBoxConstraints(minExtent: height, maxExtent: height),
      parentUsesSize: true,
    );
    final remaining = (constraints.remainingPaintExtent - constraints.overlap)
        .clamp(0.0, double.infinity);
    final visible = height.clamp(0.0, remaining);
    geometry = SliverGeometry(
      scrollExtent: _top + 64 + 72,
      paintOrigin: constraints.overlap,
      paintExtent: visible,
      layoutExtent: visible,
      maxPaintExtent: _top + 128,
      maxScrollObstructionExtent: _top + 64,
      cacheExtent: visible > 0 ? visible - constraints.cacheOrigin : 0,
      hasVisualOverflow: true,
    );
    final parentData = child!.parentData! as SliverPhysicalParentData;
    parentData.paintOffset = Offset.zero;
  }

  @override
  double childMainAxisPosition(RenderBox child) => 0;
}
