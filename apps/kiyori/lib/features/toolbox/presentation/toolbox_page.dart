import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'toolbox_presentation.dart';

/// ToolboxCatalog + ScreenRouteRegistry 的内置顺序；不读取旧数据或启动工具。
class ToolboxPage extends StatefulWidget {
  const ToolboxPage({
    this.onSettings = emptyAction,
    this.onSpeech = emptyAction,
    super.key,
  });
  final VoidCallback onSettings;
  final VoidCallback onSpeech;
  @override
  State<ToolboxPage> createState() => _ToolboxPageState();
}

class _ToolboxPageState extends State<ToolboxPage> {
  final collapsed = <int>{};
  @override
  Widget build(BuildContext context) => PrimaryPage(
    title: '工具箱',
    actions: [
      SizedBox(
        width: 96,
        child: PrimaryHeaderActions(
          searchLabel: '搜索工具',
          settingsLabel: '工具箱设置',
          onSettings: widget.onSettings,
        ),
      ),
    ],
    child: ListView.separated(
      key: const PageStorageKey('toolbox-list'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 86),
      itemCount: ToolboxPresentation.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = ToolboxPresentation.groups[index];
        final closed = collapsed.contains(index);
        return PrimaryCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  expanded: !closed,
                  child: PrimarySectionTitle(
                    group.$1,
                    onTap: () => setState(
                      () => closed
                          ? collapsed.remove(index)
                          : collapsed.add(index),
                    ),
                    trailing: Row(
                      children: [
                        if (closed)
                          Text(
                            '${group.$2.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: PrimaryColors.of(context).secondary,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            closed ? Icons.expand_more : Icons.expand_less,
                            size: 20,
                            color: PrimaryColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!closed)
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      for (final tool in group.$2)
                        _ToolChip(
                          tool,
                          onTap: tool == ToolboxPresentation.speech
                              ? widget.onSpeech
                              : emptyAction,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip(this.tool, {required this.onTap});
  final ToolPresentation tool;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      onLongPress: emptyAction,
      borderRadius: BorderRadius.circular(100),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tool.$3.containerFor(context),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: tool.$3.iconFor(context).withValues(alpha: .16),
                width: .5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tool.$2, size: 18, color: tool.$3.iconFor(context)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tool.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
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
