part of 'chat_history_page.dart';

class _HistoryBatch extends StatefulWidget {
  const _HistoryBatch(this.snapshot);
  final ChatHistoryPresentation snapshot;
  @override
  State<_HistoryBatch> createState() => _HistoryBatchState();
}

class _HistoryBatchState extends State<_HistoryBatch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final search = TextEditingController();
  final groupName = TextEditingController();
  final selected = <String>{};
  String? character, characterGroup;
  bool unbindCharacter = false, unbindGroup = false;
  late List<ChatHistoryItem> filtered;
  late Map<String, String> groupNames;

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void didUpdateWidget(_HistoryBatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      selected.retainAll(widget.snapshot.chats.map((e) => e.id));
      if (!widget.snapshot.characters.any((e) => e.name == character)) {
        character = null;
      }
      if (!widget.snapshot.groups.any((e) => e.id == characterGroup)) {
        characterGroup = null;
      }
      _filter();
    }
  }

  @override
  void dispose() {
    search.dispose();
    groupName.dispose();
    super.dispose();
  }

  String? groupLabel(String? id) => groupNames[id];

  void _filter() {
    groupNames = {
      for (final entry in widget.snapshot.groups) entry.id: entry.name,
    };
    final query = search.text.trim().toLowerCase();
    filtered = widget.snapshot.chats
        .where(
          (e) => [
            e.title,
            e.group,
            e.character,
            groupLabel(e.characterGroupId),
          ].any((text) => (text ?? '').toLowerCase().contains(query)),
        )
        .toList();
    int optionalCompare(String? a, String? b) {
      final emptyA = a?.trim().isEmpty ?? true;
      final emptyB = b?.trim().isEmpty ?? true;
      if (emptyA != emptyB) return emptyA ? 1 : -1;
      return (a ?? '').compareTo(b ?? '');
    }

    filtered.sort((a, b) {
      final unboundA = a.characterGroupId?.trim().isEmpty ?? true;
      final unboundB = b.characterGroupId?.trim().isEmpty ?? true;
      if (unboundA != unboundB) return unboundA ? 1 : -1;
      // 旧版先区分有无群聊 ID；缺失名称的绑定仍排在未绑定记录之前。
      final group = (groupLabel(a.characterGroupId) ?? '').compareTo(
        groupLabel(b.characterGroupId) ?? '',
      );
      if (group != 0) return group;
      final card = optionalCompare(a.character, b.character);
      if (card != 0) return card;
      final folder = optionalCompare(a.group, b.group);
      return folder != 0 ? folder : b.updatedAt.compareTo(a.updatedAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final canSubmit =
        selected.isNotEmpty &&
        (unbindCharacter ||
            unbindGroup ||
            character != null ||
            characterGroup != null ||
            groupName.text.trim().isNotEmpty);
    final apply =
        (unbindCharacter || unbindGroup) && groupName.text.trim().isNotEmpty
        ? '应用更改'
        : unbindGroup
        ? '移除角色群聊绑定'
        : unbindCharacter
        ? '移除角色卡绑定'
        : characterGroup != null
        ? '应用角色群聊'
        : groupName.text.trim().isNotEmpty && character == null
        ? '应用分组'
        : '应用角色卡';
    return BackupCard(
      children: [
        const _HistoryHeader(
          '历史记录批量归类',
          '选择多个聊天记录并批量调整角色卡绑定或分组',
          Icons.playlist_add_check,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('筛选聊天记录', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            KiyoriSearchField(
              controller: search,
              hint: '按标题、分组、角色卡或角色群聊搜索',
              showSearchIcon: true,
              onChanged: (_) => setState(_filter),
            ),
          ],
        ),
        if (widget.snapshot.chats.isEmpty)
          const BackupText('暂无聊天记录，无法进行批量操作。')
        else ...[
          if (filtered.isEmpty)
            const BackupText('没有匹配的聊天记录，请调整筛选条件。')
          else ...[
            _SelectionBar(
              '已选择 ${selected.length} / ${filtered.length} 条',
              onAll: () =>
                  setState(() => selected.addAll(filtered.map((e) => e.id))),
              onClear: selected.isEmpty ? null : () => setState(selected.clear),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: .3),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final subtitle =
                        '${entry.group == null ? '' : '分组：${entry.group} · '}${entry.characterGroupId?.isNotEmpty == true
                            ? '角色群聊：${groupLabel(entry.characterGroupId) ?? '缺失角色群聊（${entry.characterGroupId}）'}'
                            : entry.character?.isNotEmpty == true
                            ? '角色卡：${entry.character}'
                            : '未绑定角色卡'}';
                    void toggle() => setState(
                      () => selected.contains(entry.id)
                          ? selected.remove(entry.id)
                          : selected.add(entry.id),
                    );
                    return InkWell(
                      key: ValueKey('history-${entry.id}'),
                      onTap: toggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: selected.contains(entry.id),
                              onChanged: (_) => toggle(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title.isEmpty ? '未命名对话' : entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: PrimaryColors.of(context)
                                          .secondary,
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
            ),
          ],
          _HistoryButton(
            '为已选 ${selected.length} 条聊天重建记忆',
            Icons.refresh_outlined,
            onPressed: selected.isEmpty
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => _MemoryRebuildDialog(selected.length),
                  ),
          ),
          _HistoryButton(
            '删除选中的聊天记录 (${selected.length})',
            Icons.delete_outline,
            destructive: true,
            onPressed: selected.isEmpty
                ? null
                : () => _showDelete(
                    context,
                    '确定要删除选中的 ${selected.length} 条聊天记录吗？\n\n已锁定的对话会被跳过，此操作不可撤销。',
                  ),
          ),
          Column(
            children: [
              _TargetDropdown(
                label: '目标角色卡（可选）',
                hint: '请选择一个角色卡或取消绑定',
                selected: unbindCharacter ? '' : character,
                entries: {
                  for (final e in widget.snapshot.characters) e.name: e.name,
                },
                unbindLabel: '移除角色卡绑定',
                emptyLabel: '暂无可用角色卡',
                onSelected: (value) => setState(() {
                  unbindCharacter = value.isEmpty;
                  character = value.isEmpty ? null : value;
                  characterGroup = null;
                  unbindGroup = false;
                }),
              ),
              const SizedBox(height: 12),
              _TargetDropdown(
                label: '目标角色群聊（可选）',
                hint: '请选择一个角色群聊或取消绑定',
                selected: unbindGroup ? '' : characterGroup,
                entries: {for (final e in widget.snapshot.groups) e.id: e.name},
                unbindLabel: '移除角色群聊绑定',
                emptyLabel: '暂无可用角色群聊',
                onSelected: (value) => setState(() {
                  unbindGroup = value.isEmpty;
                  characterGroup = value.isEmpty ? null : value;
                  character = null;
                  unbindCharacter = false;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: groupName,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '目标分组（可选）',
                  hintText: '分组名称（留空不修改）',
                  prefixIcon: Icon(Icons.folder),
                ),
              ),
              const SizedBox(height: 12),
              const BackupText(
                '批量将所选对话绑定到指定角色卡或分组。可以仅修改分组而不切换角色卡，也可以同时修改两者。',
                small: true,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: canSubmit ? emptyAction : null,
                    child: Text(apply),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => setState(selected.clear),
                    child: const Text('取消选择'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TargetDropdown extends StatelessWidget {
  const _TargetDropdown({
    required this.label,
    required this.hint,
    required this.selected,
    required this.entries,
    required this.unbindLabel,
    required this.emptyLabel,
    required this.onSelected,
  });
  final String label, hint, unbindLabel, emptyLabel;
  final String? selected;
  final Map<String, String> entries;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey(label),
    tooltip: label,
    onSelected: onSelected,
    itemBuilder: (_) => [
      PopupMenuItem(value: '', child: Text(unbindLabel)),
      if (entries.isEmpty)
        PopupMenuItem(enabled: false, child: Text(emptyLabel)),
      for (final e in entries.entries)
        PopupMenuItem(value: e.key, child: Text(e.value)),
    ],
    child: InputDecorator(
      isEmpty: selected == null,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(
        selected == '' ? unbindLabel : entries[selected] ?? '',
        style: const TextStyle(fontSize: 16),
      ),
    ),
  );
}
