import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// 旧DropdownMenuPositionProvider的候选顺序不能由Flutter默认夹边算法替代。
/// RawMenuAnchor继续拥有overlay生命周期与外部点击，领域层只投影旧位置和外观。
class HistoryBindingMenu extends StatefulWidget {
  const HistoryBindingMenu({
    required this.controller,
    required this.focus,
    required this.builder,
    required this.children,
    required this.onOpen,
    required this.onClose,
    this.viewport,
    super.key,
  });

  final MenuController controller;
  final FocusNode focus;
  final RawMenuAnchorChildBuilder builder;
  final List<Widget> children;
  final VoidCallback onOpen, onClose;
  // Dialog在子树清除viewInsets；由编辑宿主传原视口以保留真实键盘边界。
  final MediaQueryData? viewport;

  @override
  State<HistoryBindingMenu> createState() => _HistoryBindingMenuState();
}

class _HistoryBindingMenuState extends State<HistoryBindingMenu>
    with TickerProviderStateMixin {
  late final scale = AnimationController.unbounded(vsync: this, value: .8);
  late final alpha = AnimationController.unbounded(vsync: this);
  Alignment origin = Alignment.topLeft;
  int generation = 0;
  bool closing = false;

  Future<void> animate(bool open, VoidCallback overlay) async {
    final current = ++generation;
    setState(() => closing = !open);
    if (open) overlay();
    if (MediaQuery.disableAnimationsOf(context)) {
      scale.stop();
      alpha.stop();
      scale.value = open ? 1 : .8;
      alpha.value = open ? 1 : 0;
      if (!open) overlay();
      return;
    }
    // 旧Material3 1.4.0普通主题FastSpatial/FastEffects，保留反向瞬间的速度。
    final spatial = SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 1400, ratio: .9),
      scale.value,
      open ? 1 : .8,
      scale.velocity,
      tolerance: const Tolerance(distance: .01, velocity: .625),
    );
    final effects = SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 3800, ratio: 1),
      alpha.value,
      open ? 1 : 0,
      alpha.velocity,
      tolerance: const Tolerance(distance: .01, velocity: .625),
    );
    try {
      await Future.wait([
        scale.animateWith(spatial).orCancel,
        alpha.animateWith(effects).orCancel,
      ]);
      if (!mounted || generation != current) return;
      scale.value = open ? 1 : .8;
      alpha.value = open ? 1 : 0;
      if (!open) overlay();
    } on TickerCanceled {
      // 反向或实体释放撤销旧过渡，不能由旧关闭回调移除新菜单。
    }
  }

  @override
  void dispose() {
    generation++;
    scale.dispose();
    alpha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: widget.controller,
    childFocusNode: widget.focus,
    consumeOutsideTaps: true,
    onOpenRequested: (_, show) => unawaited(animate(true, show)),
    onCloseRequested: (hide) {
      if (!widget.controller.isOpen) {
        hide();
      } else {
        unawaited(animate(false, hide));
      }
    },
    onOpen: widget.onOpen,
    onClose: () {
      widget.focus.requestFocus();
      widget.onClose();
    },
    builder: widget.builder,
    overlayBuilder: (context, info) {
      final media = widget.viewport ?? MediaQuery.of(context);
      final safe = EdgeInsets.fromLTRB(
        math.max(media.viewPadding.left, media.viewInsets.left),
        math.max(media.viewPadding.top, media.viewInsets.top),
        math.max(media.viewPadding.right, media.viewInsets.right),
        math.max(media.viewPadding.bottom, media.viewInsets.bottom),
      );
      final bounds = Rect.fromLTRB(
        safe.left,
        safe.top,
        info.overlaySize.width - safe.right,
        info.overlaySize.height - safe.bottom,
      );
      return CustomSingleChildLayout(
        delegate: _HistoryMenuPosition(
          anchor: info.anchorRect,
          bounds: bounds,
          direction: Directionality.of(context),
          positioned: (value) => origin = value,
        ),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          consumeOutsideTaps: true,
          onTapOutside: (_) => widget.controller.close(),
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  widget.controller.close();
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    NextFocusIntent(),
                SingleActivator(LogicalKeyboardKey.arrowUp):
                    PreviousFocusIntent(),
              },
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: FocusScope(
                  autofocus: true,
                  child: Semantics(
                    scopesRoute: true,
                    explicitChildNodes: true,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([scale, alpha]),
                      builder: (context, child) => IgnorePointer(
                        ignoring: closing,
                        child: ExcludeSemantics(
                          excluding: closing,
                          child: Transform.scale(
                            key: const Key('history-binding-menu-transform'),
                            scale: scale.value,
                            alignment: origin,
                            child: Opacity(
                              opacity: alpha.value.clamp(0, 1),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      child: Material(
                        key: const Key('history-binding-menu'),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        surfaceTintColor: Colors.transparent,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.children,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HistoryMenuPosition extends SingleChildLayoutDelegate {
  const _HistoryMenuPosition({
    required this.anchor,
    required this.bounds,
    required this.direction,
    required this.positioned,
  });
  final Rect anchor, bounds;
  final TextDirection direction;
  final ValueChanged<Alignment> positioned;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: math.max(0, math.min(anchor.width, bounds.width)),
        maxWidth: math.max(0, math.min(anchor.width, bounds.width)),
        maxHeight: math.max(0, bounds.height - 96),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rtl = direction == TextDirection.rtl;
    final xs = [
      rtl ? anchor.right - childSize.width : anchor.left,
      rtl ? anchor.left : anchor.right - childSize.width,
      anchor.center.dx < bounds.center.dx
          ? bounds.left
          : bounds.right - childSize.width,
    ];
    final ys = [
      anchor.bottom,
      anchor.top - childSize.height,
      anchor.top - childSize.height / 2,
      anchor.center.dy < bounds.center.dy
          ? bounds.top + 48
          : bounds.bottom - 48 - childSize.height,
    ];
    final x = xs.firstWhere(
      (x) => x >= bounds.left && x + childSize.width <= bounds.right,
      orElse: () => xs.last,
    );
    final y = ys.firstWhere(
      (y) => y >= bounds.top + 48 && y + childSize.height <= bounds.bottom - 48,
      orElse: () => ys.last,
    );
    // 旧calculateTransformOrigin：边界相离用最近边，相交用交集中心。
    double pivot(double start, double extent, double a, double b) {
      if (start >= b) return -1;
      if (start + extent <= a) return 1;
      if (extent == 0) return 0;
      return ((math.max(start, a) + math.min(start + extent, b)) / 2 - start) /
              extent *
              2 -
          1;
    }

    positioned(
      Alignment(
        pivot(x, childSize.width, anchor.left, anchor.right),
        pivot(y, childSize.height, anchor.top, anchor.bottom),
      ),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_HistoryMenuPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      direction != oldDelegate.direction;
}
