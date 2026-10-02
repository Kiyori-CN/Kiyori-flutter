import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// ModelApiSettingsSection 及参数/高级页的原控件几何。
class ModelSettingsCard extends StatelessWidget {
  const ModelSettingsCard({
    required this.children,
    this.radius = 12,
    this.spacing = 12,
    super.key,
  });
  final List<Widget> children;
  final double radius, spacing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

class ModelSettingsHeading extends StatelessWidget {
  const ModelSettingsHeading(
    this.title,
    this.icon,
    this.tone, {
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final IconTone tone;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 24, color: tone.icon),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class ModelSettingsBanner extends StatelessWidget {
  const ModelSettingsBanner(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ModelSettingsField extends StatelessWidget {
  const ModelSettingsField(
    this.title,
    this.controller, {
    this.subtitle,
    this.hint = '',
    this.unit,
    this.trailing,
    this.enabled = true,
    this.multiline = false,
    this.obscure = false,
    this.focusNode,
    this.formatters,
    this.onChanged,
    this.keyboardType,
    super.key,
  });
  final String title, hint;
  final String? subtitle, unit;
  final TextEditingController controller;
  final Widget? trailing;
  final bool enabled, multiline, obscure;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey(title),
                    controller: controller,
                    enabled: enabled,
                    focusNode: focusNode,
                    obscureText: obscure,
                    maxLines: multiline ? null : 1,
                    inputFormatters: formatters,
                    keyboardType: keyboardType,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled ? colors.primary : colors.onSurfaceVariant,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      suffixText: unit,
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(
                        alpha: .65,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ModelSettingsSelector extends StatelessWidget {
  const ModelSettingsSelector(
    this.title,
    this.value, {
    required this.onTap,
    this.subtitle = '',
    this.summary,
    super.key,
  });
  final String title, value, subtitle;
  final String? summary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest
        .withValues(alpha: .45),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  if (summary != null) ...[
                    Text(
                      value,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (summary == null)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    ),
  );
}

class ModelSettingsSwitch extends StatelessWidget {
  const ModelSettingsSwitch(
    this.title,
    this.subtitle,
    this.value, {
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final String title, subtitle;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest
        .withValues(alpha: .35),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    ),
  );
}

class ModelSettingsExpansion extends StatelessWidget {
  const ModelSettingsExpansion(
    this.title,
    this.icon,
    this.tone, {
    required this.expanded,
    required this.onTap,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final IconTone tone;
  final bool expanded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: ModelSettingsHeading(title, icon, tone, subtitle: subtitle),
        ),
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          semanticLabel: expanded ? '收起' : '展开',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    ),
  );
}
