import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// ThemeSettings*Sections 的原卡片几何；仅供外观编辑器复用。
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

class AppearanceSectionTitle extends StatelessWidget {
  const AppearanceSectionTitle(this.title, this.icon, this.tone, {super.key});
  final String title;
  final IconData icon;
  final IconTone tone;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: tone.icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PrimaryColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: PrimaryColors.divider),
      const SizedBox(height: 8),
    ],
  );
}

class AppearanceDescription extends StatelessWidget {
  const AppearanceDescription(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: PrimaryColors.secondary),
  );
}

class AppearanceSwitch extends StatelessWidget {
  const AppearanceSwitch(
    this.title,
    this.description, {
    required this.value,
    required this.onChanged,
    this.textEndPadding = 0,
    this.bottom = 0,
    super.key,
  });
  final String title, description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double textEndPadding, bottom;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: textEndPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                AppearanceDescription(description),
              ],
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class AppearanceChoice extends StatelessWidget {
  const AppearanceChoice(
    this.title, {
    required this.selected,
    required this.onTap,
    this.themeMode = false,
    this.icon,
    super.key,
  });
  final String title;
  final bool selected, themeMode;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? (themeMode ? colors.primary : colors.onPrimaryContainer)
        : colors.onSurface;
    return Material(
      color: selected
          ? (themeMode
                ? colors.primary.withValues(alpha: .2)
                : colors.primaryContainer)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(themeMode ? 14 : 8),
        side: themeMode && !selected
            ? BorderSide.none
            : BorderSide(
                color: selected ? colors.primary : colors.outline,
                width: themeMode ? 2 : 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: foreground, size: 20),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: foreground,
                    fontWeight: themeMode && selected
                        ? FontWeight.bold
                        : FontWeight.normal,
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

class AppearanceDivider extends StatelessWidget {
  const AppearanceDivider({this.space = 8, super.key});
  final double space;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: space),
    child: const Divider(height: 1, color: PrimaryColors.divider),
  );
}
