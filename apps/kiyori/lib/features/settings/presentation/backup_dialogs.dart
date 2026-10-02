import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

typedef BackupChoice = ({String id, String title});

/// 弹窗只选择展示项；导出/删除最终动作继续空点击。
class BackupDeleteDialog extends StatelessWidget {
  const BackupDeleteDialog({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
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
  );
}

class BackupChatSelection extends StatefulWidget {
  const BackupChatSelection(this.chats, {super.key});
  final List<BackupChoice> chats;
  @override
  State<BackupChatSelection> createState() => _ChatSelectionState();
}

class _ChatSelectionState extends State<BackupChatSelection> {
  final selected = <String>{};
  @override
  void didUpdateWidget(covariant BackupChatSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected.retainAll(widget.chats.map((chat) => chat.id));
  }

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
  const BackupFormatDialog({
    this.importing = false,
    this.selectedChatIds = const {},
    super.key,
  });
  final bool importing;
  final Set<String> selectedChatIds;
  @override
  State<BackupFormatDialog> createState() => _BackupFormatDialogState();
}

class _BackupFormatDialogState extends State<BackupFormatDialog> {
  late int selected = widget.importing ? 1 : 0;
  static const exportFormats = [
    ('JSON（推荐）', 'Kiyori 原生格式，完整保留消息切换等所有数据'),
    ('Markdown', '轻量级标记格式，便于阅读和编辑'),
    ('HTML', '网页格式，适合在浏览器中查看'),
    ('纯文本', '简单的文本格式，便于分享'),
  ];
  static const importFormats = [
    ('Kiyori 对话审计包', '导入单个 .kiyori-audit 完整审计包，并验证路径、哈希链、payload 与签名'),
    ('Kiyori JSON（推荐）', '本应用的原生格式，完整保留消息切换等所有数据'),
    ('ChatGPT', 'OpenAI ChatGPT conversations.json 导出格式'),
    ('ChatBox', 'ChatBox 桌面应用导出格式'),
    ('Markdown', '轻量级标记格式，便于阅读和编辑'),
    ('通用 JSON', '标准 role-content 结构的 JSON（支持 Claude、LibreChat 等）'),
  ];
  List<(String, String)> get formats =>
      widget.importing ? importFormats : exportFormats;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.importing ? '选择导入格式' : '选择导出格式'),
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
            Text(
              widget.importing ? '请选择要导入的聊天记录格式：' : '请选择要导出的聊天记录格式：',
              style: const TextStyle(fontSize: 14),
            ),
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
      TextButton(
        onPressed: emptyAction,
        child: Text(widget.importing ? '导入' : '导出'),
      ),
    ],
  );
}

class BackupProfileDialog extends StatefulWidget {
  const BackupProfileDialog({
    this.profiles = const [],
    this.selectedId = 'default',
    this.title = '选择要导出的配置',
    this.returnSelection = false,
    super.key,
  });
  final List<BackupChoice> profiles;
  final String selectedId;
  final String title;
  final bool returnSelection;
  @override
  State<BackupProfileDialog> createState() => _BackupProfileDialogState();
}

class _BackupProfileDialogState extends State<BackupProfileDialog> {
  late String? selected = widget.profiles.any((p) => p.id == widget.selectedId)
      ? widget.selectedId
      : null;
  @override
  void didUpdateWidget(covariant BackupProfileDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      selected = widget.selectedId;
    }
    if (!widget.profiles.any((profile) => profile.id == selected)) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
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
      TextButton(
        onPressed: selected == null
            ? null
            : widget.returnSelection
            ? () => Navigator.pop(context, selected)
            : emptyAction,
        child: const Text('确认'),
      ),
    ],
  );
}

class BackupMemoryStrategyDialog extends StatefulWidget {
  const BackupMemoryStrategyDialog({super.key});
  @override
  State<BackupMemoryStrategyDialog> createState() =>
      _BackupMemoryStrategyDialogState();
}

class _BackupMemoryStrategyDialogState
    extends State<BackupMemoryStrategyDialog> {
  int selected = 0;
  static const options = [
    ('跳过（推荐）', '保留现有记忆，不导入重复数据'),
    ('更新', '用导入的数据更新现有记忆'),
    ('创建新记录', '即使UUID相同也创建新记忆（可能导致重复）'),
  ];
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择导入策略'),
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
            const Text('遇到重复的记忆（UUID相同）时如何处理？'),
            const SizedBox(height: 16),
            for (var i = 0; i < options.length; i++)
              _ChoiceCard(
                selected: selected == i,
                onTap: () => setState(() => selected = i),
                leading: Radio<int>(value: i),
                title: options[i].$1,
                description: options[i].$2,
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
      const TextButton(onPressed: emptyAction, child: Text('导入')),
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
