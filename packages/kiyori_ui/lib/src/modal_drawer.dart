import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

typedef KiyoriDrawerBuilder<T> = Widget Function(
  BuildContext context,
  Future<void> Function([T?]) dismiss,
);

/// 共享原三态模态抽屉，统一动画、遮罩、系统返回与安全区。
Future<T?> showKiyoriModalDrawer<T>(
  BuildContext context, {
  required KiyoriDrawerBuilder<T> builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierColor: Colors.transparent,
  barrierDismissible: false,
  transitionDuration: Duration.zero,
  pageBuilder: (_, _, _) => _ModalDrawer<T>(builder: builder),
);

class _ModalDrawer<T> extends StatefulWidget {
  const _ModalDrawer({required this.builder});
  final KiyoriDrawerBuilder<T> builder;
  @override
  State<_ModalDrawer<T>> createState() => _ModalDrawerState<T>();
}

class _ModalDrawerState<T> extends State<_ModalDrawer<T>>
    with SingleTickerProviderStateMixin {
  late final _extent = AnimationController.unbounded(vsync: this, value: 0);
  bool _closing = false;
  bool _canPop = false;
  double _partial = .64;
  double _height = 1;
  double _dragStart = 0;
  bool _expanded = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animate(_partial);
    });
  }

  Future<void> _animate(double value, [double velocity = 0]) async {
    try {
      await _extent
          .animateWith(
            SpringSimulation(
              const SpringDescription(
                mass: 1,
                stiffness: 1500,
                damping: 77.4596669,
              ),
              _extent.value,
              value,
              velocity,
            ),
          )
          .orCancel;
    } on TickerCanceled {
      // Drag interruption and route disposal intentionally cancel this motion.
    }
  }

  Future<void> _dismiss([T? choice]) async {
    if (_closing) return;
    _closing = true;
    await _animate(0);
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(choice);
    });
  }

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final previousPartial = _partial;
    final minimumViewport =
        150 + media.textScaler.scale(64) + media.padding.bottom;
    _height = (media.size.height - media.padding.top).clamp(1, double.infinity);
    _partial = media.size.width < 600
        ? (media.size.width > media.size.height ? .78 : .64)
        : media.size.width < 840
        ? .68
        : .72;
    _partial = math.max(_partial, math.min(1, minimumViewport / _height));
    if (media.viewInsets.bottom > 0) {
      _partial = _partial.clamp(
        ((media.viewInsets.bottom + 240) / _height).clamp(0, 1),
        1,
      );
    }
    if ((previousPartial - _partial).abs() > .001 && !_closing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing && !_dragging) {
          _animate(_expanded ? 1 : _partial);
        }
      });
    }
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: AnimatedBuilder(
        animation: _extent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: widget.builder(context, _dismiss),
          ),
        ),
        builder: (context, content) {
          final extent = _extent.value.clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _dismiss,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .32 * extent),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _height * extent,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 退出时只裁剪连续移动的内容，避免小于某高度突然清空。
                        // 大字保留标题和取消区的布局预算，列表仍独立滚动。
                        return OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: minimumViewport + media.viewInsets.bottom,
                          maxHeight: math.max(
                            minimumViewport + media.viewInsets.bottom,
                            constraints.maxHeight,
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) {
                                  _extent.stop();
                                  _dragging = true;
                                  _dragStart = extent;
                                },
                                onVerticalDragUpdate: (details) {
                                  _extent.value =
                                      (_extent.value -
                                              details.delta.dy / _height)
                                          .clamp(0, 1);
                                },
                                onVerticalDragEnd: (details) {
                                  _dragging = false;
                                  final velocity = details.primaryVelocity ?? 0;
                                  final expanding = velocity.abs() >= 900
                                      ? velocity < 0
                                      : _extent.value > _dragStart;
                                  final target = expanding
                                      ? (_extent.value < _partial - .05
                                            ? _partial
                                            : 1.0)
                                      : (_extent.value > _partial + .05
                                            ? _partial
                                            : 0.0);
                                  if (target == 0) {
                                    _dismiss();
                                  } else {
                                    _expanded = target == 1;
                                    _animate(target, -velocity / _height);
                                  }
                                },
                                onVerticalDragCancel: () {
                                  _dragging = false;
                                  _animate(_expanded ? 1 : _partial);
                                },
                                child: Semantics(
                                  button: true,
                                  label: '展开 / 收起',
                                  child: InkWell(
                                    onTap: () {
                                      _expanded = extent <= .9;
                                      _animate(_expanded ? 1 : _partial);
                                    },
                                    child: SizedBox(
                                      height: 28,
                                      width: double.infinity,
                                      child: Center(
                                        child: Container(
                                          width: 38,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(child: content!),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
