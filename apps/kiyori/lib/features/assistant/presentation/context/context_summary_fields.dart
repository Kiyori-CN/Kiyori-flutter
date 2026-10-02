part of 'context_summary_page.dart';

class _ContextSurface extends StatelessWidget {
  const _ContextSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}

class _ContextDescription extends StatelessWidget {
  const _ContextDescription(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, color: PrimaryColors.of(context).secondary),
  );
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      _ContextSurface(child: _ContextDescription(text));
}

class _ContextTitle extends StatelessWidget {
  const _ContextTitle(this.text, this.icon, this.tone);
  final String text;
  final IconData icon;
  final IconTone tone;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, color: tone.iconFor(context), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
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

class _ContextSwitch extends StatelessWidget {
  const _ContextSwitch(
    this.title,
    this.subtitle,
    this.value, {
    required this.onChanged,
    this.enabled = true,
  });
  final String title, subtitle;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => _ContextSurface(
    child: Opacity(
      opacity: enabled ? 1 : .38,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                _ContextDescription(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    ),
  );
}

class _ContextNumber extends StatelessWidget {
  const _ContextNumber(
    this.title,
    this.subtitle,
    this.controller, {
    this.unit,
    this.decimal = false,
    this.enabled = true,
    this.onChanged,
  });
  final String title, subtitle;
  final String? unit;
  final TextEditingController controller;
  final bool decimal, enabled;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => _ContextSurface(
    child: Opacity(
      opacity: enabled ? 1 : .38,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              _ContextDescription(subtitle),
            ],
          );
          final field = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: decimal ? 88 : 72,
                child: TextField(
                  key: ValueKey(title),
                  controller: controller,
                  enabled: enabled,
                  onChanged: (_) => onChanged?.call(),
                  inputFormatters: [
                    decimal
                        ? const _ContextDecimalFormatter()
                        : FilteringTextInputFormatter.digitsOnly,
                  ],
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: decimal,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PrimaryColors.of(context).accent,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: PrimaryColors.of(context).accent,
                    ),
                  ),
                ),
            ],
          );
          if (constraints.maxWidth < 260 &&
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: field),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 12),
              field,
            ],
          );
        },
      ),
    ),
  );
}

class _ContextDecimalFormatter extends TextInputFormatter {
  const _ContextDecimalFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var dotSeen = false;
    final text = StringBuffer();
    final offsets = <int>[0];
    for (final code in newValue.text.codeUnits) {
      if (code >= 48 && code <= 57) {
        text.writeCharCode(code);
      } else if (code == 46 && !dotSeen) {
        dotSeen = true;
        text.write(text.isEmpty ? '0.' : '.');
      }
      offsets.add(text.length);
    }
    final value = text.toString();
    if (value == newValue.text) return newValue;
    return TextEditingValue(
      text: value,
      selection: newValue.selection.isValid
          ? TextSelection(
              baseOffset:
                  offsets[newValue.selection.baseOffset.clamp(
                    0,
                    offsets.length - 1,
                  )],
              extentOffset:
                  offsets[newValue.selection.extentOffset.clamp(
                    0,
                    offsets.length - 1,
                  )],
            )
          : TextSelection.collapsed(offset: value.length),
    );
  }
}

class _ContextError extends StatelessWidget {
  const _ContextError(this.error);
  final ValueListenable<String?> error;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: error,
    builder: (context, value, _) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
  );
}
