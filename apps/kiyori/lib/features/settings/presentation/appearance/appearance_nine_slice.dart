import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 旧BubbleImageBackgroundSurface的像素几何；细小图片保留至少一个中心像素。
class AppearanceSliceGeometry {
  AppearanceSliceGeometry(ui.Image image, List<double> values) {
    List<double> axis(
      int length,
      int cropStart,
      int cropEnd,
      int repeatStart,
      int repeatEnd,
    ) {
      final start = (length * values[cropStart].clamp(0, .45)).round().clamp(
        0,
        length - 1,
      );
      final end = (length * (1 - values[cropEnd].clamp(0, .45))).round().clamp(
        start + 1,
        length,
      );
      final size = end - start;
      final ratio = values[repeatStart].clamp(.05, .9);
      final first = size < 3 ? 0 : (size * ratio).round().clamp(1, size - 2);
      final last = size < 3
          ? size
          : (size * values[repeatEnd].clamp(ratio + .01, .95)).round().clamp(
              first + 1,
              size - 1,
            );
      return [
        start.toDouble(),
        (start + first).toDouble(),
        (start + last).toDouble(),
        end.toDouble(),
      ];
    }

    x = axis(image.width, 0, 2, 4, 5);
    y = axis(image.height, 1, 3, 6, 7);
  }
  late final List<double> x, y;
  Rect region(int column, int row) =>
      Rect.fromLTRB(x[column], y[row], x[column + 1], y[row + 1]);
  static List<double> destination(
    double length,
    double first,
    double last,
    double scale,
  ) {
    var left = (first * scale).roundToDouble();
    var right = (last * scale).roundToDouble();
    if (left + right >= length) {
      final target = math.max(0.0, length - 1);
      final ratio = target / math.max(1.0, left + right);
      left = (left * ratio).roundToDouble();
      right = math.min((right * ratio).roundToDouble(), target - left);
    }
    return [0, left, length - right, length];
  }
}

/// 裁剪小图只在源图/裁剪区改变时创建；着色器平铺避免每帧按像素遍历大量小块。
class AppearanceNineSlice extends StatefulWidget {
  const AppearanceNineSlice({
    required this.image,
    required this.values,
    required this.tiled,
    required this.child,
    super.key,
  });
  final ui.Image image;
  final List<double> values;
  final bool tiled;
  final Widget child;
  @override
  State<AppearanceNineSlice> createState() => _AppearanceNineSliceState();
}

class _AppearanceNineSliceState extends State<AppearanceNineSlice> {
  final slices = <ui.Image?>[];
  late AppearanceSliceGeometry geometry;
  late List<double> cropValues;
  void release() {
    for (final image in slices) {
      image?.dispose();
    }
    slices.clear();
  }

  void prepare() {
    release();
    cropValues = widget.values.take(8).toList();
    geometry = AppearanceSliceGeometry(widget.image, widget.values);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final source = geometry.region(column, row);
        if (source.isEmpty) {
          slices.add(null);
          continue;
        }
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          widget.image,
          source,
          Rect.fromLTWH(0, 0, source.width, source.height),
          Paint(),
        );
        final picture = recorder.endRecording();
        slices.add(
          picture.toImageSync(source.width.toInt(), source.height.toInt()),
        );
        picture.dispose();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void didUpdateWidget(covariant AppearanceNineSlice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.image, oldWidget.image) ||
        !listEquals(cropValues, widget.values.take(8).toList())) {
      prepare();
    }
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _NineSlicePainter(
      geometry,
      List.of(slices),
      widget.values[8].clamp(.2, 3),
      widget.tiled,
      MediaQuery.devicePixelRatioOf(context),
    ),
    child: widget.child,
  );
}

class _NineSlicePainter extends CustomPainter {
  _NineSlicePainter(
    this.geometry,
    this.slices,
    this.scale,
    this.tiled,
    this.pixelRatio,
  );
  final AppearanceSliceGeometry geometry;
  final List<ui.Image?> slices;
  final double scale, pixelRatio;
  final bool tiled;
  @override
  void paint(Canvas canvas, Size size) {
    final x = AppearanceSliceGeometry.destination(
      (size.width * pixelRatio).roundToDouble(),
      geometry.x[1] - geometry.x[0],
      geometry.x[3] - geometry.x[2],
      scale,
    );
    final y = AppearanceSliceGeometry.destination(
      (size.height * pixelRatio).roundToDouble(),
      geometry.y[1] - geometry.y[0],
      geometry.y[3] - geometry.y[2],
      scale,
    );
    canvas.save();
    canvas.scale(1 / pixelRatio);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final image = slices[row * 3 + column];
        final target = Rect.fromLTRB(
          x[column],
          y[row],
          x[column + 1],
          y[row + 1],
        );
        if (image == null || target.isEmpty) continue;
        if (!tiled || (row != 1 && column != 1)) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            target,
            Paint()..filterQuality = FilterQuality.low,
          );
        } else {
          final sx = column == 1
              ? math.max(1, (image.width * scale).round()) / image.width
              : target.width / image.width;
          final sy = row == 1
              ? math.max(1, (image.height * scale).round()) / image.height
              : target.height / image.height;
          final matrix = Float64List.fromList([
            sx,
            0,
            0,
            0,
            0,
            sy,
            0,
            0,
            0,
            0,
            1,
            0,
            target.left,
            target.top,
            0,
            1,
          ]);
          final shader = ui.ImageShader(
            image,
            column == 1 ? TileMode.repeated : TileMode.clamp,
            row == 1 ? TileMode.repeated : TileMode.clamp,
            matrix,
            filterQuality: FilterQuality.low,
          );
          canvas.drawRect(target, Paint()..shader = shader);
          shader.dispose();
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NineSlicePainter old) =>
      old.geometry != geometry ||
      old.scale != scale ||
      old.tiled != tiled ||
      old.pixelRatio != pixelRatio;
}

class AppearanceSourceGrid extends StatelessWidget {
  const AppearanceSourceGrid({
    required this.title,
    required this.image,
    required this.values,
    super.key,
  });
  final String title;
  final ui.Image? image;
  final List<double> values;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 84,
              child: CustomPaint(
                painter: _SourceGridPainter(image!, List.of(values)),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SourceGridPainter extends CustomPainter {
  _SourceGridPainter(this.image, this.values);
  final ui.Image image;
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / image.width,
      size.height / image.height,
    );
    final draw = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: image.width * scale,
      height: image.height * scale,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      draw,
      Paint()..filterQuality = FilterQuality.low,
    );
    final geometry = AppearanceSliceGeometry(image, values);
    final x = geometry.x.map((x) => draw.left + x * scale).toList();
    final y = geometry.y.map((y) => draw.top + y * scale).toList();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red.withValues(alpha: .4);
    canvas.drawRect(Rect.fromLTRB(x.first, y.first, x.last, y.last), paint);
    paint.color = Colors.red.withValues(alpha: .9);
    for (final value in x.skip(1).take(2)) {
      canvas.drawLine(Offset(value, y.first), Offset(value, y.last), paint);
    }
    for (final value in y.skip(1).take(2)) {
      canvas.drawLine(Offset(x.first, value), Offset(x.last, value), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SourceGridPainter old) =>
      old.image != image || !listEquals(old.values, values);
}
