import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AgentChatInputSection 的默认非浮动边缘：亮色外扩五层，暗色仅顶部高光。
class ChatInputSurface extends StatelessWidget {
  const ChatInputSurface({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dark = c.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: CustomPaint(
        foregroundPainter: _InputEdge(dark: dark, foreground: c.onSurface),
        child: Container(
          key: const Key('chat-input-surface'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? Color.lerp(c.surface, c.onSurface, .08) : c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InputEdge extends CustomPainter {
  const _InputEdge({required this.dark, required this.foreground});
  final bool dark;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(20);
    final shape = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: radius,
      topRight: radius,
    );
    canvas.save();
    if (!dark) {
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(6)),
          Path()..addRRect(shape),
        ),
      );
      for (var i = 1; i <= 5; i++) {
        final ratio = i / 5;
        final expansion = 6 * ratio;
        final expanded = RRect.fromRectAndCorners(
          (Offset.zero & size).inflate(expansion),
          topLeft: Radius.circular(20 + expansion),
          topRight: Radius.circular(20 + expansion),
        );
        canvas.drawRRect(
          expanded,
          Paint()..color = Colors.black.withValues(alpha: .025 * (1 - ratio)),
        );
      }
    } else {
      canvas.clipRRect(shape);
      final edge = Path()
        ..moveTo(0, 20)
        ..arcTo(const Rect.fromLTWH(0, 0, 40, 40), math.pi, math.pi / 2, false)
        ..lineTo(size.width - 20, 0)
        ..arcTo(
          Rect.fromLTWH(size.width - 40, 0, 40, 40),
          -math.pi / 2,
          math.pi / 2,
          false,
        );
      for (var i = 1; i <= 4; i++) {
        final ratio = i / 4;
        canvas.drawPath(
          edge,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 + 2 * ratio * 2
            ..color = foreground.withValues(alpha: .015 * (1 - ratio)),
        );
      }
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = foreground.withValues(alpha: .05),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InputEdge oldDelegate) =>
      dark != oldDelegate.dark || foreground != oldDelegate.foreground;
}
