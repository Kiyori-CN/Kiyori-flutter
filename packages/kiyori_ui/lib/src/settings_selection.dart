import 'package:flutter/material.dart';

import 'primary_page.dart';
import 'modal_drawer.dart';

class SettingsOption {
  const SettingsOption(this.label, {this.description, this.selected = false});
  final String label;
  final String? description;
  final bool selected;
}

/// 原选择器只在抽屉退出后返回选择，副作用由调用方负责。
Future<int?> showSettingsSelection(
  BuildContext context, {
  required String title,
  required String current,
  required List<SettingsOption> options,
}) => showKiyoriModalDrawer<int>(
  context,
  builder: (context, dismiss) => _SettingsSelection(
    title: title,
    current: current,
    options: options,
    dismiss: dismiss,
  ),
);

class _SettingsSelection extends StatelessWidget {
  const _SettingsSelection({
    required this.title,
    required this.current,
    required this.options,
    required this.dismiss,
  });
  final String title, current;
  final List<SettingsOption> options;
  final Future<void> Function([int?]) dismiss;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          '当前：$current',
          style: const TextStyle(fontSize: 12, color: PrimaryColors.secondary),
        ),
      ),
      const Divider(height: .6, color: PrimaryColors.divider),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 4),
          itemCount: options.length,
          separatorBuilder: (_, _) =>
              const Divider(height: .6, color: PrimaryColors.divider),
          itemBuilder: (context, index) {
            final option = options[index];
            return Semantics(
              selected: option.selected,
              button: true,
              child: InkWell(
                onTap: () => dismiss(index),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: option.selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (option.description != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      option.description!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 17 / 12,
                                        color: PrimaryColors.secondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (option.selected)
                          const Icon(
                            Icons.check,
                            color: PrimaryColors.accent,
                            size: 21,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      InkWell(
        onTap: dismiss,
        child: const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 17),
            child: Text(
              '取消',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
    ],
  );
}
