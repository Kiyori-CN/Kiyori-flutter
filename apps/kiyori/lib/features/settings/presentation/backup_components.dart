import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// BackupCards / BackupManagementCards 的纯展示组件，不拥有备份操作。
class BackupCard extends StatelessWidget {
  const BackupCard({required this.children, this.spacing = 16, super.key});
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    color: PrimaryColors.of(context).card,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class BackupHeader extends StatelessWidget {
  const BackupHeader(
    this.title,
    this.subtitle,
    this.icon,
    this.tone, {
    super.key,
  });
  final String title, subtitle;
  final IconData icon;
  final IconTone tone;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tone.containerFor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: tone.iconFor(context), size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            BackupText(subtitle, small: true),
          ],
        ),
      ),
    ],
  );
}

class BackupText extends StatelessWidget {
  const BackupText(this.text, {this.small = false, super.key});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: small ? 12 : 14,
      color: PrimaryColors.of(context).secondary,
    ),
  );
}

class BackupButton extends StatelessWidget {
  const BackupButton(
    this.label,
    this.icon, {
    this.onPressed = emptyAction,
    this.destructive = false,
    this.warning = false,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive, warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: destructive
            ? colors.errorContainer
            : warning
            ? colors.tertiaryContainer
            : null,
        foregroundColor: destructive
            ? colors.error
            : warning
            ? colors.tertiary
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class BackupStat extends StatelessWidget {
  const BackupStat(
    this.label,
    this.count,
    this.icon,
    this.color, {
    this.file = false,
    super.key,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool file;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: file
          ? color.withValues(alpha: .1)
          : Color(
              Theme.of(context).brightness == Brightness.dark
                  ? 0xFF242A31
                  : 0xFFEDF1F5,
            ).withValues(alpha: .6),
      borderRadius: BorderRadius.circular(file ? 14 : 12),
      border: file ? Border.all(color: color.withValues(alpha: .3)) : null,
    ),
    padding: EdgeInsets.symmetric(horizontal: file ? 12 : 16, vertical: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: file ? 22 : 16,
                  fontWeight: file ? FontWeight.bold : FontWeight.w600,
                  color: file ? color : null,
                ),
              ),
              BackupText(label, small: true),
            ],
          ),
        ),
      ],
    ),
  );
}
