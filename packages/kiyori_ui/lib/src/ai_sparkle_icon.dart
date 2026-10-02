import 'package:flutter/material.dart';

/// KiyoriActionIcons.aiAssistant 的原始 24 单位路径。
class AiSparkleIcon extends StatelessWidget {
  const AiSparkleIcon({required this.color, this.size = 24, super.key});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Sparkle(color));
}

class _Sparkle extends CustomPainter {
  const _Sparkle(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 2)
        ..cubicTo(13.3, 8.7, 15.3, 10.7, 22, 12)
        ..cubicTo(15.3, 13.3, 13.3, 15.3, 12, 22)
        ..cubicTo(10.7, 15.3, 8.7, 13.3, 2, 12)
        ..cubicTo(8.7, 10.7, 10.7, 8.7, 12, 2)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Sparkle oldDelegate) => color != oldDelegate.color;
}
