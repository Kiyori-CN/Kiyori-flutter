import 'package:flutter/material.dart';

import 'prompt_dialog.dart';
import 'prompt_presentation.dart';

class GroupCardEditor extends StatefulWidget {
  const GroupCardEditor({
    required this.group,
    required this.session,
    super.key,
  });
  final GroupPresentation group;
  final PromptDialogState session;
  @override
  State<GroupCardEditor> createState() => _GroupCardEditorState();
}

// 旧存储允许重复引用；每个出现项有局部身份，不能按角色 ID 删除所有同名成员。
class _Member {
  _Member(this.id, this.token);
  final String id;
  final Object? token;
}

class _GroupCardEditorState extends State<GroupCardEditor> {
  late final name = TextEditingController(text: widget.group.name);
  late final description = TextEditingController(
    text: widget.group.description,
  );
  late final List<_Member> members;
  final selector = GlobalKey();
  String? selected;
  Object? selectedToken;
  bool selecting = false;

  Object? token(String id) => widget.session.identity('card:$id');
  late List<CharacterPresentation> available;

  @override
  void initState() {
    super.initState();
    final ordered = widget.group.members.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.orderIndex.compareTo(b.$2.orderIndex);
        return order == 0 ? a.$1.compareTo(b.$1) : order;
      });
    members = [
      for (final entry in ordered)
        _Member(entry.$2.characterId, token(entry.$2.characterId)),
    ];
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant GroupCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
  }

  void _reconcile() {
    // 初始缺失引用按旧源显示 ID；曾存在的角色一旦移除，不借同 ID 新实体复活。
    members.removeWhere(
      (member) =>
          member.token != null && !identical(member.token, token(member.id)),
    );
    final existing = members.map((member) => member.id).toSet();
    available = widget.session.snapshot.cards
        .where((card) => !existing.contains(card.id))
        .toList();
    if (!available.any((card) => card.id == selected) ||
        !identical(selectedToken, selected == null ? null : token(selected!))) {
      selected = available.firstOrNull?.id;
      selectedToken = selected == null ? null : token(selected!);
    }
  }

  Future<void> choose() async {
    if (selecting || !widget.session.valid) return;
    final options = available;
    if (options.isEmpty) return;
    final tokens = {for (final card in options) card.id: token(card.id)};
    final box = selector.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    setState(() => selecting = true);
    final result = await widget.session.showPopup<String>(
      RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy + box.size.height, 0, 0),
        Offset.zero & overlay.size,
      ),
      [for (final card in options) (card.id, card.name)],
    );
    if (!mounted || !widget.session.valid) return;
    setState(() {
      selecting = false;
      if (result != null &&
          identical(tokens[result], token(result)) &&
          available.any((card) => card.id == result)) {
        selected = result;
        selectedToken = token(result);
      }
    });
  }

  void add() {
    final id = selected;
    if (!widget.session.valid ||
        id == null ||
        !identical(selectedToken, token(id)) ||
        !available.any((card) => card.id == id)) {
      return;
    }
    setState(() {
      members.add(_Member(id, token(id)));
      selected = null;
      _reconcile();
    });
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label,
    String id,
    int lines,
  ) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 32),
          child: TextField(
            key: ValueKey(id),
            controller: controller,
            style: const TextStyle(fontSize: 12),
            maxLines: lines,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            // 旧 GroupCardDialog 的两个展开回调为空，不能借角色编辑器新增流程。
            onPressed: () {},
            tooltip: '大屏编辑$label',
            icon: const Icon(Icons.open_in_full, size: 14),
            color: Theme.of(context).colorScheme.primary,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '成员列表',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (available.isNotEmpty) ...[
          InkWell(
            key: const ValueKey('group-member-selector'),
            onTap: choose,
            child: InputDecorator(
              key: selector,
              decoration: InputDecoration(
                labelText: '添加成员',
                labelStyle: const TextStyle(fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                suffixIcon: Icon(
                  selecting
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
              ),
              child: Text(
                widget.session.snapshot.card(selected ?? '')?.name ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('group-add-member'),
              onPressed: add,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('添加', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '请先添加至少一个角色卡成员',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
        for (final member in members)
          Card(
            key: ObjectKey(member),
            margin: const EdgeInsets.only(bottom: 6),
            color: colors.surfaceContainerHighest.withValues(alpha: .3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.session.snapshot.card(member.id)?.name ??
                          member.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        '移除${widget.session.snapshot.card(member.id)?.name ?? member.id}',
                    onPressed: () {
                      if (!widget.session.valid) return;
                      setState(() {
                        members.remove(member);
                        _reconcile();
                      });
                    },
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final media = MediaQuery.of(context);
    final compact =
        media.size.height - media.viewInsets.bottom < 650 ||
        media.textScaler.scale(1) > 1.3;
    return PromptFormDialog(
      actions: const PromptActions(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Column(
                children: [
                  InkWell(
                    onTap: () {},
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
                      child: widget.group.avatarAsset == null
                          ? Icon(
                              Icons.person,
                              size: 24,
                              color: colors.onSurfaceVariant,
                            )
                          : ClipOval(
                              child: Image.asset(
                                widget.group.avatarAsset!,
                                fit: BoxFit.cover,
                                cacheWidth: 96,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: Icon(
                      widget.group.avatarAsset == null
                          ? Icons.add
                          : Icons.refresh_outlined,
                      size: 12,
                    ),
                    label: Text(
                      widget.group.avatarAsset == null ? '添加' : '重置',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    field(name, '分组名称', 'group-name', 1),
                    field(description, '描述（可选）', 'group-description', 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (compact)
            body
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: body),
            ),
        ],
      ),
    );
  }
}
