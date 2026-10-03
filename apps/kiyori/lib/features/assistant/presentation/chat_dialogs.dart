import 'package:flutter/material.dart';

import 'chat_controller.dart';

Future<String?> editChatText(
  BuildContext context,
  String title,
  String initial,
) => showDialog<String>(
  context: context,
  builder: (_) => _ChatTextDialog(title: title, initial: initial),
);

class _ChatTextDialog extends StatefulWidget {
  const _ChatTextDialog({required this.title, required this.initial});
  final String title, initial;
  @override
  State<_ChatTextDialog> createState() => _ChatTextDialogState();
}

class _ChatTextDialogState extends State<_ChatTextDialog> {
  late final editor = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: editor,
        autofocus: true,
        minLines: 1,
        maxLines: 12,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, editor.text),
        child: const Text('确定'),
      ),
    ],
  );
}

Future<bool> confirmChatAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showChatHistory(BuildContext context, ChatController owner) async {
  await owner.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: AnimatedBuilder(
        animation: owner,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('聊天历史', style: TextStyle(fontSize: 20)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (await owner.create() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新建对话'),
                  ),
                ],
              ),
            ),
            if (owner.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  owner.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: owner.catalog?.conversations.isEmpty != false
                  ? const Center(child: Text('暂无聊天记录'))
                  : ListView.builder(
                      itemCount: owner.catalog!.conversations.length,
                      itemBuilder: (context, index) {
                        final item = owner.catalog!.conversations[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          selected: owner.snapshot?.conversation.id == item.id,
                          leading: const Icon(Icons.forum_outlined),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.characterName} · ${item.messageCount} 条消息',
                          ),
                          onTap: () async {
                            if (await owner.select(item.id) &&
                                context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          trailing: PopupMenuButton<String>(
                            tooltip: '会话操作',
                            onSelected: (action) async {
                              if (action == 'rename') {
                                final value = await editChatText(
                                  context,
                                  '重命名',
                                  item.title,
                                );
                                if (context.mounted && value != null) {
                                  await owner.change(item, 'rename', value);
                                }
                              } else if (await confirmChatAction(
                                    context,
                                    '删除对话？',
                                    '确定删除“${item.title}”及其全部消息？',
                                  ) &&
                                  context.mounted) {
                                await owner.change(item, 'delete', '');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showChatModels(
  BuildContext context,
  ChatController owner,
  VoidCallback onManage,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .6,
      child: AnimatedBuilder(
        animation: owner,
        builder: (context, _) => Column(
          children: [
            ListTile(
              title: const Text('选择模型'),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onManage();
                },
                child: const Text('管理模型'),
              ),
            ),
            if (owner.error != null)
              Text(
                owner.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final config in owner.models?.configs ?? [])
                    ExpansionTile(
                      title: Text(config.draft.name),
                      initiallyExpanded: true,
                      children: [
                        for (final model in config.draft.models)
                          ListTile(
                            title: Text(model),
                            selected: owner.modelName == model,
                            onTap: () async {
                              if (owner.character?.draft.modelConfig != null &&
                                  !await confirmChatAction(
                                    context,
                                    '修改角色绑定模型？',
                                    '此角色将使用所选模型配置。',
                                  )) {
                                return;
                              }
                              await owner.chooseModel(config.id, model);
                              if (context.mounted && owner.error == null) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                      ],
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

Future<void> showChatCharacters(
  BuildContext context,
  ChatController owner,
) async {
  await owner.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => AnimatedBuilder(
      animation: owner,
      builder: (context, _) => ListView(
        children: [
          const ListTile(title: Text('选择角色')),
          if (owner.error != null) Text(owner.error!),
          for (final card in owner.prompts?.characters ?? [])
            ListTile(
              title: Text(card.draft.name),
              selected: owner.character?.id == card.id,
              onTap: () async {
                await owner.chooseCharacter(card.id);
                if (context.mounted && owner.error == null) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    ),
  );
}
