import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class DisplaySectionTitle extends StatelessWidget {
  const DisplaySectionTitle(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: PrimaryColors.of(context).secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: PrimaryColors.of(context).accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class DisplayBlock extends StatelessWidget {
  const DisplayBlock({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: PrimaryColors.of(context).card.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class DisplayDescription extends StatelessWidget {
  const DisplayDescription(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, color: PrimaryColors.of(context).secondary),
  );
}

class DisplayTitle extends StatelessWidget {
  const DisplayTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );
}

class DisplaySlider extends StatelessWidget {
  const DisplaySlider({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
    super.key,
  });
  final double value, min, max;
  final int? divisions;
  final String label;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        flex: 0,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    ],
  );
}
