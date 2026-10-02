import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

typedef BackupChoice = ({String id, String title});

/// 弹窗只选择展示项；导出/删除最终动作继续空点击。
Future<void> showBackupChatSelection(
  BuildContext context,
  List<BackupChoice> chats,
) async {
  final selected = await showDialog<Set<String>>(
    context: context,
    builder: (_) => _ChatSelection(chats),
  );
  if (selected == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const BackupFormatDialog(),
  );
}

Future<void> showBackupDeleteConfirmation(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const SingleChildScrollView(
          child: Text('删除所有聊天记录将无法恢复。建议在执行此操作前先导出备份。\n\n确定要删除吗？'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: emptyAction,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );

class _ChatSelection extends StatefulWidget {
  const _ChatSelection(this.chats);
  final List<BackupChoice> chats;
  @override
  State<_ChatSelection> createState() => _ChatSelectionState();
}

class _ChatSelectionState extends State<_ChatSelection> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择要导出的聊天'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请选择要包含在备份文件中的聊天记录。', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '已选择 ${selected.length} / ${widget.chats.length} 条',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: widget.chats.isEmpty
                    ? null
                    : () => setState(
                        () => selected.addAll(widget.chats.map((c) => c.id)),
                      ),
                child: const Text('全选'),
              ),
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => setState(selected.clear),
                child: const Text('清除选择'),
              ),
            ],
          ),
          if (widget.chats.isNotEmpty)
            SizedBox(
              height:
                  (widget.chats.length *
                          80.0 *
                          MediaQuery.textScalerOf(context).scale(1))
                      .clamp(0.0, 360.0),
              child: ListView.builder(
                itemCount: widget.chats.length,
                itemBuilder: (context, index) {
                  final chat = widget.chats[index];
                  final checked = selected.contains(chat.id);
                  void toggle() => setState(
                    () => checked
                        ? selected.remove(chat.id)
                        : selected.add(chat.id),
                  );
                  return _ChoiceCard(
                    selected: checked,
                    onTap: toggle,
                    leading: Checkbox(
                      value: checked,
                      onChanged: (_) => toggle(),
                    ),
                    title: chat.title.trim().isEmpty ? '未命名对话' : chat.title,
                    maxLines: 2,
                  );
                },
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: selected.isEmpty
            ? null
            : () => Navigator.pop(context, selected),
        child: const Text('确认'),
      ),
    ],
  );
}

class BackupFormatDialog extends StatefulWidget {
  const BackupFormatDialog({super.key});
  @override
  State<BackupFormatDialog> createState() => _BackupFormatDialogState();
}

class _BackupFormatDialogState extends State<BackupFormatDialog> {
  int selected = 0;
  static const formats = [
    ('JSON（推荐）', 'Kiyori 原生格式，完整保留消息切换等所有数据'),
    ('Markdown', '轻量级标记格式，便于阅读和编辑'),
    ('HTML', '网页格式，适合在浏览器中查看'),
    ('纯文本', '简单的文本格式，便于分享'),
  ];
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择导出格式'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: RadioGroup<int>(
        groupValue: selected,
        onChanged: (value) => setState(() => selected = value!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择要导出的聊天记录格式：', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            for (var i = 0; i < formats.length; i++)
              _ChoiceCard(
                selected: selected == i,
                onTap: () => setState(() => selected = i),
                leading: Radio<int>(value: i),
                title: formats[i].$1,
                description: formats[i].$2,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(onPressed: emptyAction, child: const Text('导出')),
    ],
  );
}

class BackupProfileDialog extends StatefulWidget {
  const BackupProfileDialog({
    this.profiles = const [],
    this.selectedId = 'default',
    super.key,
  });
  final List<BackupChoice> profiles;
  final String selectedId;
  @override
  State<BackupProfileDialog> createState() => _BackupProfileDialogState();
}

class _BackupProfileDialogState extends State<BackupProfileDialog> {
  late String selected = widget.selectedId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择要导出的配置'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) => setState(() => selected = value!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in widget.profiles)
              _ChoiceCard(
                selected: selected == profile.id,
                onTap: () => setState(() => selected = profile.id),
                leading: Radio<String>(value: profile.id),
                title: profile.title,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      const TextButton(onPressed: emptyAction, child: Text('确认')),
    ],
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    this.description,
    this.maxLines,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? description;
  final int? maxLines;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected
          ? colors.primaryContainer.withValues(alpha: .3)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: selected ? 2 : 1,
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: maxLines,
                      overflow: maxLines == null ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
