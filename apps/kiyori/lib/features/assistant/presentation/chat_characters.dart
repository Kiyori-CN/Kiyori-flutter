import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_panel_route.dart';

class ChatCharacters extends StatefulWidget {
  const ChatCharacters({
    required this.owner,
    required this.onManage,
    this.onRoute,
    super.key,
  });
  final ChatController owner;
  final VoidCallback onManage;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<ChatCharacters> createState() => _ChatCharactersState();
}

class _ChatCharactersState extends State<ChatCharacters> {
  int sort = 0;
  String? error;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.owner,
    builder: (context, _) {
      final owner = widget.owner;
      final cards = [...?owner.prompts?.characters];
      if (sort == 1) {
        cards.sort(
          (a, b) =>
              a.draft.name.toLowerCase().compareTo(b.draft.name.toLowerCase()),
        );
      }
      if (sort == 2) cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final groups = owner.prompts?.groups ?? [];
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
            child: chatPanelTransition(
              context,
              Material(
                key: const Key('chat-character-panel'),
                borderRadius: BorderRadius.circular(16),
                elevation: 16,
                color: colors.surface,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '选择角色',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${cards.length + groups.length} 个角色',
                            style: const TextStyle(fontSize: 12),
                          ),
                          PopupMenuButton<int>(
                            tooltip: '角色排序',
                            constraints: const BoxConstraints(minWidth: 160),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(40, 40),
                            ),
                            elevation: 0,
                            color: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: colors.outlineVariant,
                                width: .5,
                              ),
                            ),
                            icon: const Icon(Icons.sort, size: 18),
                            onSelected: (value) => setState(() => sort = value),
                            itemBuilder: (context) => [
                              for (final entry in [
                                '默认排序',
                                '按名称排序',
                                '按创建时间排序',
                              ].indexed)
                                PopupMenuItem(
                                  value: entry.$1,
                                  child: Builder(
                                    builder: (context) {
                                      widget.onRoute?.call(
                                        ModalRoute.of(context)!,
                                      );
                                      return Text(entry.$2);
                                    },
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            tooltip: '编辑角色卡',
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            iconSize: 18,
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onManage();
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      if (error != null || owner.error != null)
                        Text(
                          error ?? owner.error!,
                          style: TextStyle(color: colors.error),
                        ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (groups.isNotEmpty) ...[
                                const Text(
                                  '角色群组',
                                  style: TextStyle(fontSize: 12),
                                ),
                                for (final group in groups)
                                  tile(
                                    context,
                                    group.draft.name,
                                    group.draft.description,
                                    Icons.groups_rounded,
                                    false,
                                    () => setState(
                                      () => error = '群组自动对话尚未接入，请选择单个角色',
                                    ),
                                  ),
                              ],
                              const Text('角色卡', style: TextStyle(fontSize: 12)),
                              for (final card in cards)
                                tile(
                                  context,
                                  card.draft.name,
                                  card.draft.description,
                                  Icons.person_rounded,
                                  card.id == owner.character?.id,
                                  () async {
                                    if (owner.busy) return;
                                    await owner.chooseCharacter(card.id);
                                    if (context.mounted &&
                                        owner.error == null) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              fromTop: true,
            ),
          ),
        ),
      );
    },
  );

  Widget tile(
    BuildContext context,
    String name,
    String description,
    IconData icon,
    bool selected,
    VoidCallback tap,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selectedBackground = Color(
      colors.brightness == Brightness.dark ? 0xFF163044 : 0xFFE8F3FE,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selected ? selectedBackground : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            width: selected ? 1 : .5,
            color: selected
                ? colors.primary.withValues(alpha: .3)
                : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: selectedBackground,
                  child: Icon(icon, size: 18, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? colors.primary : colors.onSurface,
                        ),
                      ),
                      if (description.trim().isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: colors.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
