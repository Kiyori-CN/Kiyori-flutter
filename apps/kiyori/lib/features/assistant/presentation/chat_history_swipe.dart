import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 对照旧me.saket.swipe 1.2.0：96固定阈值、禁用方向1/10阻力、400ms回位。
/// 动画只反馈操作意图，目录删除仍由真实事务结果驱动。
class HistorySwipe extends StatefulWidget {
  const HistorySwipe({
    required this.child,
    required this.edit,
    required this.delete,
    super.key,
  });
  final Widget child;
  final VoidCallback? edit, delete;
  @override
  State<HistorySwipe> createState() => _HistorySwipeState();
}

class _HistorySwipeState extends State<HistorySwipe>
    with TickerProviderStateMixin {
  late final reset = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  double offset = 0, startOffset = 0;
  bool swipedRight = true;
  bool get resetting => reset.isAnimating;
  @override
  void initState() {
    super.initState();
    reset.addListener(
      () => setState(
        () => offset =
            startOffset * (1 - Curves.fastOutSlowIn.transform(reset.value)),
      ),
    );
  }

  @override
  void dispose() {
    reset.dispose();
    ripple.dispose();
    super.dispose();
  }

  void settle({bool canceled = false}) {
    final right = offset > 0;
    final action = right ? widget.edit : widget.delete;
    if (!canceled && offset.abs() > 96 && action != null) {
      swipedRight = right;
      ripple.forward(from: 0);
      action();
    }
    startOffset = offset;
    reset.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final right = offset > 0;
    final action = right ? widget.edit : widget.delete;
    final active = offset.abs() > 96;
    final color = right ? colors.primary : colors.error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.start,
        onHorizontalDragStart: resetting ? null : (_) {},
        onHorizontalDragUpdate: resetting
            ? null
            : (d) => setState(() {
                final target = offset + d.delta.dx;
                final allowed = target > 0
                    ? widget.edit != null
                    : widget.delete != null;
                offset += allowed ? d.delta.dx : d.delta.dx / 10;
              }),
        onHorizontalDragEnd: resetting ? null : (_) => settle(),
        onHorizontalDragCancel: () => settle(canceled: true),
        child: LayoutBuilder(
          builder: (context, bounds) => Stack(
            children: [
              if (offset != 0 && action != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: active ? color : const Color(0xFF444444),
                  ),
                ),
              Transform.translate(
                offset: Offset(offset.roundToDouble(), 0),
                child: AnimatedBuilder(
                  animation: ripple,
                  child: widget.child,
                  builder: (context, child) => CustomPaint(
                    foregroundPainter: _SwipeRipple(
                      progress: ripple.value,
                      right: swipedRight,
                      color: swipedRight ? colors.primary : colors.error,
                    ),
                    child: child,
                  ),
                ),
              ),
              if (offset != 0 && action != null)
                Positioned(
                  left: right ? offset - 56 : bounds.maxWidth + offset,
                  top: 0,
                  bottom: 0,
                  width: 56,
                  child: IgnorePointer(
                    child: Center(
                      child: Icon(
                        right ? Icons.edit_outlined : Icons.delete_outline,
                        size: 24,
                        color: right ? colors.onPrimary : colors.onError,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeRipple extends CustomPainter {
  _SwipeRipple({
    required this.progress,
    required this.right,
    required this.color,
  });
  final double progress;
  final bool right;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final radius =
        size.height +
        size.width *
            Curves.fastOutSlowIn.transform((progress * 1.5).clamp(0, 1));
    final fade = progress < 1 / 3
        ? 1
        : 1 -
              Curves.fastOutSlowIn.transform(
                ((progress - 1 / 3) * 1.5).clamp(0, 1),
              );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawCircle(
      Offset(right ? -size.height : size.width + size.height, size.height / 2),
      math.max(0, radius),
      Paint()..color = color.withValues(alpha: .25 * fade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwipeRipple old) =>
      progress != old.progress || right != old.right || color != old.color;
}
