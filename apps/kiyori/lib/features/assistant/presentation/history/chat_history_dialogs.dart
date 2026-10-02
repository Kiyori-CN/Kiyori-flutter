part of 'chat_history_page.dart';

void _showDelete(BuildContext context, String message) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('确认删除'),
    scrollable: true,
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(onPressed: emptyAction, child: const Text('删除')),
    ],
  ),
);

void _showMissing(
  BuildContext context,
  HistoryStatistic stat,
  String name,
  bool group,
  List<HistoryIdentity> identities,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(group ? '缺失角色群聊条目' : '缺失角色卡条目'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('「$name」下共有 ${stat.chats} 条对话，请选择操作：'),
          if (identities.isEmpty) ...[
            const SizedBox(height: 8),
            BackupText(
              group ? '暂无可用角色群聊，请先创建一个角色群聊。' : '暂无可用角色卡，请先创建一个角色卡。',
              small: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: group
              ? emptyAction
              : () {
                  Navigator.of(dialogContext).pop();
                  _showDelete(
                    context,
                    '确定要删除「$name」下的 ${stat.chats} 条残留对话吗？\n\n已锁定的对话会被跳过，此操作不可撤销。',
                  );
                },
          child: Text(
            group ? '移除角色群聊绑定' : '删除残留对话',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: identities.isEmpty
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _AssignDialog(stat.chats, group, identities),
                  );
                },
          child: Text(group ? '归类到角色群聊' : '归类到角色卡'),
        ),
      ],
    ),
  );
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog(this.count, this.group, this.identities);
  final int count;
  final bool group;
  final List<HistoryIdentity> identities;
  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late String? selected = widget.identities.firstOrNull?.id;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.group ? '归类到角色群聊' : '归类到角色卡'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.group
                ? '共有 ${widget.count} 条聊天记录需要重新绑定角色群聊。请选择目标角色群聊：'
                : '共有 ${widget.count} 条聊天记录未绑定角色卡。请选择要归类到的目标角色卡：',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) => setState(() => selected = value),
            child: Column(
              children: [
                for (final entry in widget.identities)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: selected == entry.id
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: .3)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          width: selected == entry.id ? 2 : 1,
                          color: selected == entry.id
                              ? PrimaryColors.accent
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => setState(() => selected = entry.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Radio<String>(value: entry.id),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 22,
                                child: Text(
                                  entry.name.isEmpty
                                      ? '角'
                                      : entry.name.characters.first,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(entry.name)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
      TextButton(
        onPressed: selected == null ? null : emptyAction,
        child: const Text('归类'),
      ),
    ],
  );
}

class _MemoryRebuildDialog extends StatefulWidget {
  const _MemoryRebuildDialog(this.count);
  final int count;
  @override
  State<_MemoryRebuildDialog> createState() => _MemoryRebuildDialogState();
}

class _MemoryRebuildDialogState extends State<_MemoryRebuildDialog> {
  int window = 32;
  DateTimeRange? dates;
  String format(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('按窗口重建聊天记忆'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('将按顺序分析已选择的 ${widget.count} 条聊天。每个窗口独立写入现有记忆库，单个窗口失败不会停止后续窗口。'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final result = await showDialog<DateTimeRange>(
                context: context,
                builder: (context) => Localizations.override(
                  context: context,
                  locale: const Locale('zh', 'CN'),
                  delegates: GlobalMaterialLocalizations.delegates,
                  child: _HistoryDateDialog(initial: dates),
                ),
              );
              if (mounted && result != null) setState(() => dates = result);
            },
            child: Text(
              dates == null
                  ? '全部日期（点击选择范围）'
                  : '${format(dates!.start)} — ${format(dates!.end)}',
            ),
          ),
          if (dates != null)
            TextButton(
              onPressed: () => setState(() => dates = null),
              child: const Text('全部日期（点击选择范围）'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: window,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '每个窗口的消息数',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final n in [16, 24, 32, 48])
                DropdownMenuItem(value: n, child: Text('$n 条消息')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => window = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(onPressed: emptyAction, child: const Text('开始重建')),
    ],
  );
}
