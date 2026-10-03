import 'package:flutter/material.dart';

import 'knowledge_controller.dart';
import 'memory_editor.dart';

/// 同一查询的组织选项，标签列表惰性构建，搜索草稿仅属于本次抽屉。
class KnowledgeFilterSheet extends StatefulWidget {
  const KnowledgeFilterSheet({
    required this.controller,
    required this.kind,
    required this.category,
    required this.tag,
    required this.archived,
    required this.sortTitle,
    required this.diaryClosed,
    required this.onDiaryStatus,
    required this.onCategory,
    required this.onTag,
    required this.onArchived,
    required this.onSort,
    required this.onReset,
    required this.onDone,
    super.key,
  });
  final KnowledgeController controller;
  final String kind;
  final String? category, tag;
  final bool archived, sortTitle;
  final bool? diaryClosed;
  final ValueChanged<bool?> onDiaryStatus;
  final ValueChanged<String?> onCategory, onTag;
  final ValueChanged<bool> onArchived, onSort;
  final VoidCallback onReset, onDone;
  @override
  State<KnowledgeFilterSheet> createState() => _KnowledgeFilterSheetState();
}

class _KnowledgeFilterSheetState extends State<KnowledgeFilterSheet> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ({
      ...?widget.controller.snapshot?.availableTags,
      ?widget.tag,
    }.toList()..sort());
    final matching = tags
        .where(
          (tag) => tag.toLowerCase().contains(search.text.trim().toLowerCase()),
        )
        .toList();
    final style = Theme.of(context).textTheme.titleSmall;
    return Column(
      children: [
        Expanded(
          child: RadioGroup<String?>(
            groupValue: widget.tag,
            onChanged: widget.onTag,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('排序方式', style: style),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('最近更新'),
                              selected: !widget.sortTitle,
                              onSelected: (_) => widget.onSort(false),
                            ),
                            ChoiceChip(
                              label: const Text('标题顺序'),
                              selected: widget.sortTitle,
                              onSelected: (_) => widget.onSort(true),
                            ),
                          ],
                        ),
                        if (widget.kind != 'diary') ...[
                          const SizedBox(height: 8),
                          Text('主题', style: style),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('全部主题'),
                                selected: widget.category == null,
                                onSelected: (_) => widget.onCategory(null),
                              ),
                              for (final item in memoryCategories.entries)
                                ChoiceChip(
                                  label: Text(item.value),
                                  selected: widget.category == item.key,
                                  onSelected: (_) =>
                                      widget.onCategory(item.key),
                                ),
                            ],
                          ),
                        ],
                        const Divider(),
                        if (widget.kind == 'diary') ...[
                          Text('日记状态', style: style),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('全部状态'),
                                selected: widget.diaryClosed == null,
                                onSelected: (_) => widget.onDiaryStatus(null),
                              ),
                              ChoiceChip(
                                label: const Text('进行中'),
                                selected: widget.diaryClosed == false,
                                onSelected: (_) => widget.onDiaryStatus(false),
                              ),
                              ChoiceChip(
                                label: const Text('已完结'),
                                selected: widget.diaryClosed == true,
                                onSelected: (_) => widget.onDiaryStatus(true),
                              ),
                            ],
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('只看已归档'),
                          subtitle: const Text('归档内容保留在库中，但不会参与日常和 AI 检索。'),
                          value: widget.archived,
                          onChanged: widget.onArchived,
                        ),
                        const Divider(),
                        Text('标签', style: style),
                        if (tags.length > 8 || search.text.isNotEmpty)
                          TextField(
                            controller: search,
                            decoration: const InputDecoration(
                              labelText: '查找标签',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: RadioListTile<String?>(
                    value: null,
                    title: Text('全部标签'),
                  ),
                ),
                SliverList.builder(
                  itemCount: matching.length,
                  itemBuilder: (context, index) => RadioListTile<String?>(
                    key: ValueKey(matching[index]),
                    value: matching[index],
                    title: Text(matching[index]),
                  ),
                ),
                if (matching.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        search.text.isEmpty ? '当前范围还没有标签' : '没有匹配的结果',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  search.clear();
                  widget.onReset();
                  setState(() {});
                },
                child: const Text('重置筛选'),
              ),
              FilledButton(onPressed: widget.onDone, child: const Text('完成')),
            ],
          ),
        ),
      ],
    );
  }
}
