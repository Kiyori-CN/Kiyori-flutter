import 'package:flutter/material.dart';

/// KiyoriSearchField 的 42px 最小高度、14px 圆角与中性描边。
/// 提示留在文本位置，输入后隐藏，不使用浮动标签改变几何。
class KiyoriSearchField extends StatelessWidget {
  const KiyoriSearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.showSearchIcon = false,
    this.showClear = false,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool showSearchIcon, showClear;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outline),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: showSearchIcon ? const Icon(Icons.search_outlined) : null,
          suffixIcon: showClear
              ? ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: () {
                            controller.clear();
                            onChanged?.call('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                )
              : null,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 42),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 5,
          ),
          filled: true,
          fillColor: colors.surface,
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
