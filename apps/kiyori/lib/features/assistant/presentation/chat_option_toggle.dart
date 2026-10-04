import 'package:flutter/material.dart';

class ChatOptionToggle extends StatelessWidget {
  const ChatOptionToggle({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.onInfo,
    super.key,
  });
  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value
                  ? c.primary
                  : c.onSurfaceVariant.withValues(alpha: .7),
            ),
            IconButton(
              tooltip: '$title说明',
              onPressed: onInfo,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                Icons.info_outline,
                size: 16,
                color: c.onSurfaceVariant.withValues(alpha: .7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Transform.scale(
              scale: .65,
              child: Switch(
                value: value,
                onChanged: onChanged,
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? c.primary
                      : c.outline,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? c.primaryContainer
                      : c.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
