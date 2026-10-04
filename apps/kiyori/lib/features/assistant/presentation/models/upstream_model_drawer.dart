import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'model_directory_controller.dart';

/// 与旧 UpstreamModelPickerSheet 保持同一选择语义，刷新不丢手工取消项。
class UpstreamModelDrawer extends StatefulWidget {
  const UpstreamModelDrawer({
    required this.directory,
    required this.existing,
    required this.refresh,
    required this.dismiss,
    super.key,
  });
  final ModelDirectoryController directory;
  final List<String> existing;
  final VoidCallback refresh;
  final Future<void> Function([Set<String>?]) dismiss;
  @override
  State<UpstreamModelDrawer> createState() => _UpstreamModelDrawerState();
}

class _UpstreamModelDrawerState extends State<UpstreamModelDrawer> {
  final search = TextEditingController();
  final selected = <String>{}, deselected = <String>{};
  late List<ModelEntry> models;
  late Set<String> existing;
  Set<String> available = const {};
  List<ModelEntry> filtered = const [];
  void reconcile() {
    models = widget.directory.models;
    available = models.map((m) => m.id).toSet();
    deselected.removeWhere((id) => !available.contains(id));
    selected.removeWhere((id) => !available.contains(id));
    selected.addAll(
      existing.where(
        (id) => available.contains(id) && !deselected.contains(id),
      ),
    );
    filter();
  }

  void filter() {
    final query = search.text.trim().toLowerCase();
    filtered = query.isEmpty
        ? models
        : models
              .where(
                (m) =>
                    m.id.toLowerCase().contains(query) ||
                    m.name.toLowerCase().contains(query),
              )
              .toList();
  }

  void changed() {
    if (mounted) setState(reconcile);
  }

  void searchChanged() => setState(filter);
  void choose(Iterable<String> ids, bool checked) => setState(() {
    for (final id in ids) {
      if (checked) {
        selected.add(id);
        deselected.remove(id);
      } else {
        selected.remove(id);
        if (existing.contains(id)) deselected.add(id);
      }
    }
  });
  @override
  void initState() {
    super.initState();
    existing = widget.existing.toSet();
    reconcile();
    widget.directory.addListener(changed);
    search.addListener(searchChanged);
  }

  @override
  void dispose() {
    widget.directory.removeListener(changed);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final added = selected.difference(existing).length;
    final removed = existing
        .where((id) => available.contains(id) && !selected.contains(id))
        .length;
    final all =
        filtered.isNotEmpty && filtered.every((m) => selected.contains(m.id));
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.cloud_download,
                  size: 22,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择上游模型',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '勾选需要保留或添加的模型；取消当前模型后，应用更改即可移除',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filledTonal(
                  tooltip: '刷新模型列表',
                  onPressed: widget.directory.loading ? null : widget.refresh,
                  icon: widget.directory.loading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: KiyoriSearchField(
              controller: search,
              hint: '搜索模型',
              showSearchIcon: true,
              showClear: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '已显示 ${filtered.length} 个模型${search.text.isEmpty ? '' : ' (已过滤)'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (filtered.isNotEmpty)
                  Flexible(
                    child: TextButton(
                      onPressed: () => choose(filtered.map((m) => m.id), !all),
                      child: Text(
                        all ? '取消选择当前结果' : '全选当前结果',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: colors.surfaceContainerHigh,
                          child: Icon(
                            Icons.format_list_bulleted,
                            size: 30,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.directory.error ?? '没有找到可用模型',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final model = filtered[index];
                    final existing = this.existing.contains(model.id),
                        checked = selected.contains(model.id);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filtered.length - 1 ? 0 : 6,
                      ),
                      child: Material(
                        color: existing && !checked
                            ? colors.errorContainer.withValues(alpha: .42)
                            : existing
                            ? colors.secondaryContainer.withValues(alpha: .55)
                            : checked
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            width: .7,
                            color: checked
                                ? colors.primary.withValues(alpha: .55)
                                : existing
                                ? colors.error.withValues(alpha: .45)
                                : colors.outlineVariant.withValues(alpha: .65),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => choose([model.id], !checked),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (value) =>
                                      choose([model.id], value!),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: checked || existing
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: existing && !checked
                                              ? colors.onErrorContainer
                                              : checked
                                              ? colors.onPrimaryContainer
                                              : colors.onSurface,
                                        ),
                                      ),
                                      if (model.name != model.id)
                                        Text(
                                          model.id,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (existing) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surface.withValues(
                                        alpha: .72,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      checked ? '当前列表' : '将移除',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: checked
                                            ? colors.onSurfaceVariant
                                            : colors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (added + removed > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '将添加 $added 个，移除 $removed 个',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        Divider(height: 1, color: colors.outlineVariant),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                height: 46,
                child: TextButton(
                  onPressed: () => widget.dismiss(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: added + removed == 0
                        ? null
                        : () => widget.dismiss(Set.of(selected)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '应用更改',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    // 抽屉动画早期及横屏/键盘下，固定区域可能比当前可见高度大；
    // 保留原尺寸并滚动到操作区，避免用压缩控件或溢出来掩盖不可达按钮。
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return SingleChildScrollView(
          child: SizedBox(
            height: math.max(constraints.maxHeight, 280 + 140 * scale),
            child: content,
          ),
        );
      },
    );
  }
}
