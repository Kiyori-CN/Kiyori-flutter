import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'prompt_dialog.dart';
import 'prompt_presentation.dart';

/// 一次选择会话。目录更新仅删除失效选择，新标签不擅自加入当前导出集合。
class TagExportDialog extends StatefulWidget {
  const TagExportDialog({required this.session, super.key});
  final PromptDialogState session;
  @override
  State<TagExportDialog> createState() => _TagExportDialogState();
}

class _TagExportDialogState extends State<TagExportDialog> {
  late final selected = <String, Object?>{
    for (final tag in widget.session.snapshot.tags)
      tag.id: widget.session.identity('tag:${tag.id}'),
  };
  List<PromptTagPresentation> get tags =>
      widget.session.snapshot.tags.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  void didUpdateWidget(covariant TagExportDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.session.snapshot.tags.map((tag) => tag.id).toSet();
    selected.removeWhere(
      (id, token) =>
          !ids.contains(id) ||
          !identical(token, widget.session.identity('tag:$id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.session.snapshot.tagsExporting;
    final current = tags;
    return AlertDialog(
      title: const Text('选择要导出的标签'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          selected.clear();
                          for (final tag in current) {
                            selected[tag.id] = widget.session.identity(
                              'tag:${tag.id}',
                            );
                          }
                        }),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('全选', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => setState(selected.clear),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tag in current)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Builder(
                          builder: (context) {
                            final checked = selected.containsKey(tag.id);
                            void toggle() => setState(() {
                              if (checked) {
                                selected.remove(tag.id);
                              } else {
                                selected[tag.id] = widget.session.identity(
                                  'tag:${tag.id}',
                                );
                              }
                            });
                            return InkWell(
                              onTap: busy ? null : toggle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: busy ? null : (_) => toggle(),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tag.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (tag.description.trim().isNotEmpty)
                                            Text(
                                              tag.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: busy || selected.isEmpty ? null : emptyAction,
          child: const Text('导出'),
        ),
      ],
    );
  }
}
