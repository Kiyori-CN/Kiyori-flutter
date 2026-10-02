import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 原 ColorPickerDialog 的三种手动输入、色盘、亮度、透明度和预设。
/// 返回颜色只更新调用方的页面草稿；不访问剪贴板或保存偏好。
class AppearanceColorPicker extends StatefulWidget {
  const AppearanceColorPicker({
    required this.title,
    required this.initial,
    super.key,
  });
  final String title;
  final Color initial;
  @override
  State<AppearanceColorPicker> createState() => _AppearanceColorPickerState();
}

class _AppearanceColorPickerState extends State<AppearanceColorPicker> {
  late HSVColor color;
  String mode = 'HEX';
  final hex = TextEditingController();
  final rgb = List.generate(3, (_) => TextEditingController());
  final hsv = List.generate(3, (_) => TextEditingController());
  static const presets = [
    0xFF6200EE,
    0xFF3700B3,
    0xFF03DAC6,
    0xFF018786,
    0xFF1976D2,
    0xFF0D47A1,
    0xFF1E88E5,
    0xFFD32F2F,
    0xFF7B1FA2,
    0xFF388E3C,
    0xFFE64A19,
    0xFFF57C00,
    0xFF5D4037,
    0xFF455A64,
  ];
  @override
  void initState() {
    super.initState();
    color = HSVColor.fromColor(widget.initial);
    sync();
  }

  @override
  void dispose() {
    for (final c in [hex, ...rgb, ...hsv]) {
      c.dispose();
    }
    super.dispose();
  }

  void sync() {
    final picked = color.toColor();
    hex.text =
        '#${(picked.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final channels = [picked.r, picked.g, picked.b];
    for (var i = 0; i < 3; i++) {
      rgb[i].text = (channels[i] * 255).round().toString();
    }
    hsv[0].text = color.hue.toInt().toString();
    hsv[1].text = (color.saturation * 100).toInt().toString();
    hsv[2].text = (color.value * 100).toInt().toString();
  }

  void select(HSVColor next) => setState(() {
    color = next;
    sync();
  });
  void apply() {
    if (mode == 'HEX') {
      var text = hex.text.trim().replaceFirst(RegExp('^#'), '');
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return;
      if (text.length == 3) text = text.split('').map((c) => '$c$c').join();
      if (text.length != 6 && text.length != 8) return;
      final argb = int.tryParse(text, radix: 16);
      if (argb != null) {
        select(
          HSVColor.fromColor(
            Color(text.length == 6 ? argb | 0xFF000000 : argb),
          ),
        );
      }
    } else {
      final values = (mode == 'RGB' ? rgb : hsv)
          .map((c) => int.tryParse(c.text))
          .toList();
      if (values.any((v) => v == null)) return;
      if (mode == 'RGB') {
        select(
          HSVColor.fromColor(
            Color.fromARGB(
              255,
              values[0]!.clamp(0, 255),
              values[1]!.clamp(0, 255),
              values[2]!.clamp(0, 255),
            ),
          ),
        );
      } else {
        select(
          HSVColor.fromAHSV(
            1,
            values[0]!.clamp(0, 360).toDouble(),
            values[1]!.clamp(0, 100) / 100,
            values[2]!.clamp(0, 100) / 100,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = color.toColor();
    final luma = .299 * picked.r + .587 * picked.g + .114 * picked.b;
    final high = luma < .3 || luma > .7;
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: picked,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: PrimaryColors.of(context).muted,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            width: 120,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: picked,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '示例文本',
                              style: TextStyle(
                                fontSize: 14,
                                color: luma > .5 ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            high ? '高对比度' : '低对比度',
                            style: TextStyle(
                              fontSize: 12,
                              color: high
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F5).withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '手动输入颜色',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in ['HEX', 'RGB', 'HSV'])
                            FilterChip(
                              label: Text(value),
                              selected: mode == value,
                              onSelected: (_) => setState(() => mode = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (mode == 'HEX')
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: hex,
                                maxLines: 1,
                                decoration: InputDecoration(
                                  labelText: 'HEX',
                                  hintText: '#FF0000',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    onPressed: emptyAction,
                                    tooltip: '粘贴',
                                    icon: const Icon(Icons.content_paste),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: apply,
                              child: const Text('应用'),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: (mode == 'RGB' ? rgb : hsv)[i],
                                  keyboardType: TextInputType.number,
                                  maxLines: 1,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: (mode == 'RGB'
                                        ? ['R', 'G', 'B']
                                        : ['H', 'S%', 'V%'])[i],
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (mode == 'HSV')
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'H: 0-360°, S: 0-100%, V: 0-100%',
                              style: TextStyle(
                                fontSize: 12,
                                color: PrimaryColors.of(context).secondary,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: apply,
                            child: Text('应用 $mode'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(
                    painter: _AlphaTiles(picked),
                    size: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox.square(
                    dimension: 204,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        void change(Offset point) {
                          final center = Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          );
                          final d = point - center;
                          final hue =
                              (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) %
                              360;
                          select(
                            color
                                .withHue(hue)
                                .withSaturation(
                                  (d.distance / (constraints.maxWidth / 2))
                                      .clamp(0, 1),
                                ),
                          );
                        }

                        return Semantics(
                          label: '色相和饱和度',
                          child: GestureDetector(
                            onPanDown: (d) => change(d.localPosition),
                            onPanUpdate: (d) => change(d.localPosition),
                            child: CustomPaint(painter: _HueWheel(color)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ColorTrack(
                  label: '亮度',
                  value: color.value,
                  start: Colors.black,
                  end: color.withValue(1).withAlpha(1).toColor(),
                  onChanged: (v) => select(color.withValue(v)),
                ),
                _ColorTrack(
                  label: '透明度',
                  value: color.alpha,
                  start: picked.withValues(alpha: 0),
                  end: picked.withValues(alpha: 1),
                  onChanged: (v) => select(color.withAlpha(v)),
                  alpha: true,
                ),
                const SizedBox(height: 16),
                const Text('推荐颜色', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    for (final argb in presets)
                      Semantics(
                        label:
                            '#${argb.toRadixString(16).substring(2).toUpperCase()}',
                        button: true,
                        child: InkWell(
                          onTap: () => select(HSVColor.fromColor(Color(argb))),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(argb),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, picked),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _ColorTrack extends StatelessWidget {
  const _ColorTrack({
    required this.label,
    required this.value,
    required this.start,
    required this.end,
    required this.onChanged,
    this.alpha = false,
  });
  final String label;
  final double value;
  final Color start, end;
  final ValueChanged<double> onChanged;
  final bool alpha;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: label,
          value: '${(value * 100).round()}%',
          increasedValue: '${((value + .01).clamp(0, 1) * 100).round()}%',
          decreasedValue: '${((value - .01).clamp(0, 1) * 100).round()}%',
          onIncrease: () => onChanged((value + .01).clamp(0, 1)),
          onDecrease: () => onChanged((value - .01).clamp(0, 1)),
          child: GestureDetector(
            onPanDown: (d) => onChanged(
              (d.localPosition.dx / constraints.maxWidth).clamp(0, 1),
            ),
            onPanUpdate: (d) => onChanged(
              (d.localPosition.dx / constraints.maxWidth).clamp(0, 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  if (alpha)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AlphaTiles(Colors.transparent),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [start, end]),
                    ),
                  ),
                  Positioned(
                    left: (value * (constraints.maxWidth - 18)).clamp(
                      0,
                      constraints.maxWidth - 18,
                    ),
                    top: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AlphaTiles extends CustomPainter {
  const _AlphaTiles(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (double y = 0; y < size.height; y += 8) {
      for (double x = 0; x < size.width; x += 8) {
        paint.color = ((x ~/ 8 + y ~/ 8) % 2 == 0)
            ? Colors.white
            : const Color(0xFFCCCCCC);
        canvas.drawRect(Rect.fromLTWH(x, y, 8, 8), paint);
      }
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AlphaTiles oldDelegate) => oldDelegate.color != color;
}

class _HueWheel extends CustomPainter {
  const _HueWheel(this.color);
  final HSVColor color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    final angle = color.hue * math.pi / 180;
    final point =
        center +
        Offset(math.cos(angle), math.sin(angle)) * radius * color.saturation;
    canvas.drawCircle(
      point,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..color = Colors.black.withValues(alpha: .4)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HueWheel oldDelegate) => oldDelegate.color != color;
}
