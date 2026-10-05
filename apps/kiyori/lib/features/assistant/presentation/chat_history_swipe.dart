import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

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
  bool? triggeredRight;
  int? primaryPointer;
  bool pointerCanceled = false;
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
    reset.addStatusListener((status) {
      if (status == AnimationStatus.completed && triggeredRight != null) {
        setState(() => triggeredRight = null);
      }
    });
  }

  @override
  void dispose() {
    reset.dispose();
    ripple.dispose();
    super.dispose();
  }

  void settle({bool canceled = false}) {
    if (resetting) return;
    final right = offset > 0;
    final action = right ? widget.edit : widget.delete;
    if (!canceled && offset.abs() > 96 && action != null) {
      swipedRight = right;
      triggeredRight = right;
      ripple.forward(from: 0);
      action();
    }
    startOffset = offset;
    reset.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 旧swipedAction在400ms回位完成前仍持有动作，越回96dp以内不恢复灰底。
    final right = triggeredRight ?? offset > 0;
    final action = right ? widget.edit : widget.delete;
    final hasAction = triggeredRight != null || action != null;
    final active = offset.abs() > 96;
    final color = right ? colors.primary : colors.error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Listener(
        onPointerDown: (event) {
          if (primaryPointer == null) {
            primaryPointer = event.pointer;
            pointerCanceled = false;
          }
        },
        onPointerUp: (event) {
          if (primaryPointer == event.pointer) primaryPointer = null;
        },
        onPointerCancel: (event) {
          if (primaryPointer == event.pointer) {
            // 已接受的Flutter拖动把PointerCancel送进onEnd；取消只能回位，不能触发动作。
            pointerCanceled = true;
            primaryPointer = null;
          }
        },
        child: GestureDetector(
          excludeFromSemantics: true,
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
          onHorizontalDragEnd: resetting
              ? null
              : (_) => settle(canceled: pointerCanceled),
          onHorizontalDragCancel: () => settle(canceled: true),
          child: LayoutBuilder(
            builder: (context, bounds) => Stack(
              children: [
                Positioned.fill(
                  child: _SwipeColor(
                    visible: offset != 0 && hasAction,
                    color: triggeredRight != null || active
                        ? color
                        : const Color(0xFF444444),
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
                if (offset != 0 && hasAction)
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
      ),
    );
  }
}

/// 旧animateColorAsState使用Oklab与临界阻尼弹簧；跨阈值/反向时保留当前值和速度。
/// 1500/1/0.01来自旧依赖Compose 1.11.4，不能用固定时长的sRGB淡入代替。
class _SwipeColor extends StatefulWidget {
  const _SwipeColor({required this.color, required this.visible});
  final Color color;
  final bool visible;
  @override
  State<_SwipeColor> createState() => _SwipeColorState();
}

class _SwipeColorState extends State<_SwipeColor>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker = createTicker(tick);
  late List<double> values;
  final velocities = List.filled(4, 0.0);
  List<SpringSimulation> simulations = [];
  double duration = 0;
  @override
  void initState() {
    super.initState();
    values = _oklab(widget.color);
  }

  @override
  void didUpdateWidget(_SwipeColor old) {
    super.didUpdateWidget(old);
    if (old.color == widget.color) return;
    final target = _oklab(widget.color);
    final spring = SpringDescription(
      mass: 1,
      stiffness: 1500,
      damping: 2 * math.sqrt(1500),
    );
    simulations = [
      for (var i = 0; i < 4; i++)
        SpringSimulation(spring, values[i], target[i], velocities[i]),
    ];
    duration = 0;
    for (var i = 0; i < 4; i++) {
      final displacement = values[i] - target[i];
      final omega = math.sqrt(1500);
      final coefficient = velocities[i] + omega * displacement;
      double distance(double t) =>
          ((displacement + coefficient * t) * math.exp(-omega * t)).abs();
      // 临界阻尼最多有一次极值；从极值后求最后一次进入0.01的时刻。
      final extreme = coefficient == 0
          ? 0.0
          : velocities[i] / (omega * coefficient);
      var low = math.max(0.0, extreme), high = math.max(.001, low);
      if (distance(low) <= .01) continue;
      while (distance(high) > .01) {
        high = high * 2 + .001;
      }
      for (var n = 0; n < 24; n++) {
        final mid = (low + high) / 2;
        if (distance(mid) > .01) {
          low = mid;
        } else {
          high = mid;
        }
      }
      duration = math.max(duration, (high * 1000).floor() / 1000);
    }
    ticker.stop();
    ticker.start();
  }

  void tick(Duration elapsed) {
    final t = elapsed.inMilliseconds / 1000;
    setState(() {
      if (t >= duration) {
        values = _oklab(widget.color);
        velocities.fillRange(0, 4, 0);
        ticker.stop();
      } else {
        for (var i = 0; i < 4; i++) {
          values[i] = simulations[i].x(t);
          velocities[i] = simulations[i].dx(t);
        }
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.visible
        ? (ticker.isActive ? _srgb(values) : widget.color)
        : Colors.transparent,
  );
}

List<double> _oklab(Color color) {
  double linear(double v) =>
      v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  double cubeRoot(double v) => math.pow(v, 1 / 3).toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = cubeRoot(.4122214708 * r + .5363325363 * g + .0514459929 * b);
  final m = cubeRoot(.2119034982 * r + .6806995451 * g + .1073969566 * b);
  final s = cubeRoot(.0883024619 * r + .2817188376 * g + .6299787005 * b);
  return [
    color.a,
    .2104542553 * l + .7936177850 * m - .0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + .4505937099 * s,
    .0259040371 * l + .7827717662 * m - .8086757660 * s,
  ];
}

Color _srgb(List<double> value) {
  final light = value[1].clamp(0.0, 1.0),
      a = value[2].clamp(-.5, .5),
      b = value[3].clamp(-.5, .5);
  double cube(double x) => x * x * x;
  final l = cube(light + .3963377774 * a + .2158037573 * b);
  final m = cube(light - .1055613458 * a - .0638541728 * b);
  final s = cube(light - .0894841775 * a - 1.2914855480 * b);
  double gamma(double x) =>
      (x <= .0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - .055)
          .clamp(0.0, 1.0)
          .toDouble();
  return Color.from(
    alpha: value[0].clamp(0.0, 1.0),
    red: gamma(4.0767416621 * l - 3.3077115913 * m + .2309699292 * s),
    green: gamma(-1.2684380046 * l + 2.6097574011 * m - .3413193965 * s),
    blue: gamma(-.0041960863 * l - .7034186147 * m + 1.7076147010 * s),
  );
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
