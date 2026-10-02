import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 标签与排序仅编辑传入的页面草稿，复制/获取/删除持久记录不在此处执行。
class ModelTagsEditor extends StatefulWidget {
  const ModelTagsEditor({
    required this.models,
    required this.onChanged,
    super.key,
  });
  final List<String> models;
  final ValueChanged<List<String>> onChanged;
  @override
  State<ModelTagsEditor> createState() => _ModelTagsEditorState();
}

class _ModelTagsEditorState extends State<ModelTagsEditor> {
  bool expanded = false;
  @override
  void didUpdateWidget(ModelTagsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.models.isEmpty) expanded = false;
  }

  Future<void> sort() async {
    final result = await showKiyoriModalDrawer<List<String>>(
      context,
      builder: (context, dismiss) => _ModelSortDrawer(widget.models, dismiss),
    );
    if (mounted && result != null) widget.onChanged(result);
  }

  Future<void> add() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _ModelAddDialog(),
    );
    if (mounted && result != null) {
      widget.onChanged({...widget.models, ...result}.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模型列表',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '第一项用于连接测试；点击标签复制模型名，长按进入排序',
                    style: TextStyle(
                      fontSize: 12,
                      color: PrimaryColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '共 ${widget.models.length} 个',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: colors.surfaceContainerHighest.withValues(
            alpha: widget.models.isEmpty ? .45 : .32,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              width: .7,
              color: colors.outlineVariant.withValues(
                alpha: widget.models.isEmpty ? .7 : .65,
              ),
            ),
          ),
          child: widget.models.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    children: [
                      Text(
                        '尚未添加模型',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '手动输入模型名称，或从上游搜索并添加',
                        style: TextStyle(
                          fontSize: 12,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const tagStyle = TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      );
                      double measure(String text, TextStyle style) {
                        final painter = TextPainter(
                          text: TextSpan(text: text, style: style),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout();
                        final width = painter.width;
                        painter.dispose();
                        return width;
                      }

                      final widths = [
                        for (var i = 0; i < widget.models.length; i++)
                          (measure(widget.models[i], tagStyle) +
                                  52 +
                                  (i == 0
                                      ? 26 +
                                            measure(
                                              '测试模型',
                                              const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )
                                      : 0))
                              .clamp(0.0, constraints.maxWidth),
                      ];
                      final rows = <List<int>>[[]];
                      final rowWidths = <double>[0];
                      var visible = 0;
                      for (var i = 0; i < widths.length; i++) {
                        final needed = widths[i] + (rows.last.isEmpty ? 0 : 7);
                        if (rowWidths.last + needed > constraints.maxWidth) {
                          if (!expanded && rows.length == 3) break;
                          rows.add([]);
                          rowWidths.add(0);
                        }
                        rowWidths.last +=
                            widths[i] + (rows.last.isEmpty ? 0 : 7);
                        rows.last.add(i);
                        visible++;
                      }
                      final indicator =
                          (measure(
                                    '还有 ${widget.models.length} 个',
                                    const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ) +
                                  24)
                              .clamp(0.0, constraints.maxWidth);
                      if (visible < widths.length) {
                        if (rows.length < 3) {
                          rows.add([]);
                          rowWidths.add(0);
                        }
                        while (rows.last.isNotEmpty &&
                            rowWidths.last + 7 + indicator >
                                constraints.maxWidth) {
                          final removed = rows.last.removeLast();
                          rowWidths.last -=
                              widths[removed] + (rows.last.isEmpty ? 0 : 7);
                          visible--;
                        }
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 8,
                              children: [
                                for (final i in rows[r])
                                  SizedBox(
                                    width: widths[i],
                                    child: Material(
                                      color: i == 0
                                          ? colors.primaryContainer
                                          : colors.surfaceContainerHigh,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          width: .8,
                                          color: i == 0
                                              ? colors.primary.withValues(
                                                  alpha: .55,
                                                )
                                              : colors.outlineVariant,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: emptyAction,
                                        onLongPress: widget.models.length > 1
                                            ? sort
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            10,
                                            4,
                                            2,
                                            4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (i == 0) ...[
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 15,
                                                  color: IconTone.success.icon,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '测试模型',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 7),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  widget.models[i],
                                                  style: tagStyle.copyWith(
                                                    color: i == 0
                                                        ? colors
                                                              .onPrimaryContainer
                                                        : colors.onSurface,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                height: 40,
                                                child: IconButton(
                                                  tooltip:
                                                      '删除模型 ${widget.models[i]}',
                                                  padding: EdgeInsets.zero,
                                                  onPressed: emptyAction,
                                                  icon: Icon(
                                                    Icons.clear,
                                                    size: 17,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (r == rows.length - 1 &&
                                    visible < widths.length)
                                  SizedBox(
                                    width: indicator,
                                    child: Material(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => expanded = true),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          child: Text(
                                            '还有 ${widths.length - visible} 个',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  colors.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (expanded)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => expanded = false),
                                icon: const Icon(Icons.expand_less, size: 16),
                                label: const Text('收起'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 94,
              child: OutlinedButton(
                onPressed: add,
                style: _buttonStyle(),
                child: _action('添加模型', Icons.add),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 106,
              child: FilledButton.tonal(
                onPressed: emptyAction,
                style: _buttonStyle(),
                child: _action('从上游获取', Icons.cloud_download),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: widget.models.isNotEmpty,
              tooltip: '更多模型操作',
              onSelected: (value) {
                if (value == 'sort') sort();
                if (value == 'clear') {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('清空模型列表？'),
                      scrollable: true,
                      content: Text(
                        '将移除当前配置中的全部 ${widget.models.length} 个模型。此操作可以立即撤销。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: emptyAction,
                          child: const Text('清空全部'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'sort',
                  enabled: widget.models.length > 1,
                  child: const _ModelMenuLabel('模型排序', Icons.reorder),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: _ModelMenuLabel('复制全部', Icons.content_copy),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: _ModelMenuLabel('清空全部', Icons.delete_sweep_outlined),
                ),
              ],
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(width: .8, color: colors.outlineVariant),
                ),
                child: const Icon(Icons.more_horiz, size: 19),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _buttonStyle() => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
  Widget _action(String text, IconData icon) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 17),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}

class _ModelMenuLabel extends StatelessWidget {
  const _ModelMenuLabel(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 12),
      Flexible(child: Text(text)),
    ],
  );
}

class _ModelAddDialog extends StatefulWidget {
  const _ModelAddDialog();
  @override
  State<_ModelAddDialog> createState() => _ModelAddDialogState();
}

class _ModelAddDialogState extends State<_ModelAddDialog> {
  final input = TextEditingController();
  List<String> parsed = [];
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加模型'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        children: [
          const Text(
            '输入一个模型名称；也可以使用逗号或换行一次粘贴多个模型',
            style: TextStyle(fontSize: 12, color: PrimaryColors.secondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: input,
            minLines: 3,
            maxLines: 7,
            onChanged: (value) => setState(
              () => parsed = value
                  .split(RegExp(r'[,，\r\n]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(),
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '例如：gpt-5\nclaude-sonnet-4',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: parsed.isEmpty
            ? null
            : () => Navigator.of(context).pop(parsed),
        child: Text(parsed.length > 1 ? '添加 (${parsed.length})' : '添加'),
      ),
    ],
  );
}

class _ModelSortDrawer extends StatefulWidget {
  const _ModelSortDrawer(this.models, this.dismiss);
  final List<String> models;
  final Future<void> Function([List<String>?]) dismiss;
  @override
  State<_ModelSortDrawer> createState() => _ModelSortDrawerState();
}

class _ModelSortDrawerState extends State<_ModelSortDrawer> {
  late final ordered = widget.models.toList();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('调整模型顺序', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 12),
        Expanded(
          child: ReorderableListView.builder(
            header: const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '拖动右侧手柄调整顺序，完成后第一项作为连接测试模型',
                style: TextStyle(fontSize: 14, color: PrimaryColors.secondary),
              ),
            ),
            buildDefaultDragHandles: false,
            itemCount: ordered.length,
            onReorderItem: (from, to) => setState(() {
              ordered.insert(to, ordered.removeAt(from));
            }),
            itemBuilder: (context, index) => Padding(
              key: ValueKey(ordered[index]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ordered[index],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: index == 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (index == 0)
                              const Text(
                                '测试模型',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PrimaryColors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ReorderableDelayedDragStartListener(
                        key: ValueKey('model-drag-${ordered[index]}'),
                        index: index,
                        child: Semantics(
                          label: '拖动模型 ${ordered[index]}',
                          child: const ColoredBox(
                            color: Colors.transparent,
                            child: Icon(
                              Icons.drag_handle,
                              size: 28,
                              color: PrimaryColors.secondary,
                            ),
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
        const SizedBox(height: 12),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => widget.dismiss(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => widget.dismiss(ordered),
              child: const Text('完成排序'),
            ),
          ],
        ),
      ],
    ),
  );
}
