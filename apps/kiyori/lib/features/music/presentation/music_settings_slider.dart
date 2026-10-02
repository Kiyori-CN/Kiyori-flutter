import 'package:flutter/material.dart';

/// MusicThinSlider 的 2px 轨道、10px 圆点；沿用 Slider 手势与可访问性。
class MusicSettingsSlider extends StatefulWidget {
  const MusicSettingsSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.decimals = 0,
    super.key,
  });
  final String title, unit;
  final double value, min, max;
  final int decimals;
  @override
  State<MusicSettingsSlider> createState() => _MusicSettingsSliderState();
}

class _MusicSettingsSliderState extends State<MusicSettingsSlider> {
  late double draft = widget.value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.title} · ${draft.toStringAsFixed(widget.decimals)}${widget.unit}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 5,
              elevation: 0,
              pressedElevation: 0,
            ),
            trackShape: const _ThinTrackShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: .14),
          ),
          child: Slider(
            value: draft,
            min: widget.min,
            max: widget.max,
            semanticFormatterCallback: (value) =>
                '${value.toStringAsFixed(widget.decimals)}${widget.unit}',
            onChanged: (value) => setState(() => draft = value),
          ),
        ),
      ],
    ),
  );
}

/// Flutter 默认激活轨额外增粗 2px；旧音乐滑块两段都保持 2px。
class _ThinTrackShape extends RoundedRectSliderTrackShape {
  const _ThinTrackShape();
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 0,
  }) => super.paint(
    context,
    offset,
    parentBox: parentBox,
    sliderTheme: sliderTheme,
    enableAnimation: enableAnimation,
    thumbCenter: thumbCenter,
    secondaryOffset: secondaryOffset,
    isEnabled: isEnabled,
    isDiscrete: isDiscrete,
    textDirection: textDirection,
    additionalActiveTrackHeight: 0,
  );
}
