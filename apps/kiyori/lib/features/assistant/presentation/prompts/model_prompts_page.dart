import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'character_card_editor.dart';
import 'group_card_editor.dart';
import 'group_card_tile.dart';
import 'prompt_dialog.dart';
import 'prompt_presentation.dart';
import 'prompts_controller.dart';
import 'tag_export_dialog.dart';

class ModelPromptsPage extends StatefulWidget {
  const ModelPromptsPage({
    this.snapshot = const PromptsPresentation(),
    this.controller,
    this.onOpenTagMarket = emptyAction,
    this.onOpenPersona = emptyAction,
    super.key,
  });
  final PromptsPresentation snapshot;
  final PromptsController? controller;
  final VoidCallback onOpenTagMarket;
  final VoidCallback onOpenPersona;
  @override
  State<ModelPromptsPage> createState() => _ModelPromptsPageState();
}

class _ModelPromptsPageState extends State<ModelPromptsPage> {
  late final catalog = ValueNotifier(widget.snapshot);
  final _routes = <DialogRoute<void>>[];
  final _identities = <String, Object>{};
  late List<CharacterPresentation> sortedCards;
  late List<PromptTagPresentation> sortedTags;
  late List<GroupPresentation> sortedGroups;
  late Map<String, String> cardNames;
  int tab = 0, sort = 0;

  @override
  void initState() {
    super.initState();
    _project();
  }

  @override
  void didUpdateWidget(covariant ModelPromptsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _project();
      final next = widget.snapshot;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) catalog.value = next;
      });
    }
  }

  void _project() {
    final ids = {
      ...widget.snapshot.cards.map((e) => 'card:${e.id}'),
      ...widget.snapshot.tags.map((e) => 'tag:${e.id}'),
      ...widget.snapshot.groups.map((e) => 'group:${e.id}'),
    };
    _identities.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _identities.putIfAbsent(id, Object.new);
    }
    sortedCards = widget.snapshot.cards.toList();
    if (sort == 1) {
      sortedCards.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    if (sort == 2) {
      sortedCards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    sortedTags = widget.snapshot.tags.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    sortedGroups = widget.snapshot.groups.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    cardNames = {for (final card in widget.snapshot.cards) card.id: card.name};
  }

  @override
  void dispose() {
    final routes = _routes.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    catalog.dispose();
    super.dispose();
  }

  void _dialog({
    required Widget Function(BuildContext, PromptDialogState) builder,
    String? identity,
    Object? token,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => PromptDialog(
        catalog: catalog,
        identityToken: (id) => _identities[id],
        exists: (_) =>
            mounted &&
            (identity == null || identical(_identities[identity], token)),
        builder: builder,
      ),
    );
    _routes.add(route);
    unawaited(
      Navigator.of(context)
          .push(route)
          .whenComplete(() => _routes.remove(route)),
    );
  }

  void _edit(CharacterPresentation card) {
    final identity = card.id.isEmpty ? null : 'card:${card.id}';
    _dialog(
      identity: identity,
      token: _identities[identity],
      builder: (_, session) => CharacterCardEditor(
        key: ValueKey(card.id),
        card: card,
        session: session,
        onSave: widget.controller?.saveCharacter,
      ),
    );
  }

  void _confirmation(
    String title,
    String message,
    String action, {
    String? identity,
    Object? token,
    Future<void> Function()? onConfirm,
  }) => _dialog(
    identity: identity,
    token: token,
    builder: (context, session) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (session.error != null)
            Text(
              session.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => session.submit(onConfirm),
          child: Text(session.saving ? '处理中…' : action),
        ),
      ],
    ),
  );

  void _groupAction(String id, Object token, String action) {
    final identity = 'group:$id';
    if (!mounted || !identical(_identities[identity], token)) return;
    final group = widget.snapshot.group(id);
    if (group == null) return;
    if (action == '编辑') {
      _dialog(
        identity: identity,
        token: token,
        builder: (_, session) => GroupCardEditor(
          key: ValueKey(id),
          group: group,
          session: session,
          onSave: widget.controller?.saveGroup,
        ),
      );
    } else if (action == '删除') {
      _confirmation(
        '删除群组',
        '确定删除群组「${group.name}」吗？',
        '删除',
        identity: identity,
        token: token,
        onConfirm: widget.controller == null
            ? null
            : () => widget.controller!.delete('group', id, group.revision),
      );
    } else if (action == '复制') {
      _run(() => widget.controller?.duplicate('group', id, group.revision));
    } else if (action == '设为活跃') {
      _run(() => widget.controller?.activate('group', id));
    }
  }

  void _cardAction(String id, Object token, String action) {
    if (!mounted || !identical(_identities['card:$id'], token)) return;
    final card = widget.snapshot.card(id);
    if (card == null) return;
    switch (action) {
      case '编辑':
        _edit(card);
      case '删除':
        _confirmation(
          '删除角色卡',
          '确定要删除角色卡「${card.name}」吗？此操作不可撤销。',
          '删除',
          identity: 'card:$id',
          token: token,
          onConfirm: widget.controller == null
              ? null
              : () => widget.controller!.delete('character', id, card.revision),
        );
      case '重置':
        _confirmation(
          '重置默认角色卡',
          '确定要重置默认角色卡吗？这将恢复默认的名称、设定和提示词，并重置头像和主题。',
          '重置',
          identity: 'card:$id',
          token: token,
          onConfirm: widget.controller == null
              ? null
              : () => widget.controller!.reset(card.revision),
        );
      case '导出':
        _dialog(
          identity: 'card:$id',
          token: token,
          builder: (context, session) => _ExportModeDialog(
            name: card.name,
            onColorCode: () {
              if (!session.valid) return;
              Navigator.pop(context);
              _dialog(
                identity: 'card:$id',
                token: token,
                builder: (_, _) => _ColorCodeDialog(name: card.name),
              );
            },
          ),
        );
      case '复制':
        _run(
          () => widget.controller?.duplicate('character', id, card.revision),
        );
      case '设为活跃':
        _run(() => widget.controller?.activate('character', id));
      default:
        break;
    }
  }

  Future<void> _run(Future<void>? Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，内容可能已变化，请重新加载后重试。')));
      }
    }
  }

  Widget _icon(IconData icon, String label, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    tooltip: label,
    icon: Icon(icon, size: 18),
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    padding: EdgeInsets.zero,
  );

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '角色卡和提示词',
    onBack: () => Navigator.maybePop(context),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Material(
                        color: tab == i
                            ? colors.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          key: ValueKey('prompt-tab-$i'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => tab = i);
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 42),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    [
                                      Icons.person,
                                      Icons.label,
                                      Icons.people,
                                    ][i],
                                    size: 18,
                                    color: tab == i
                                        ? colors.onPrimaryContainer
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      ['角色卡', '标签', '群组'][i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tab == i
                                            ? colors.onPrimaryContainer
                                            : colors.onSurfaceVariant,
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
                  ],
                ],
              ),
            ),
            Expanded(
              child: switch (tab) {
                0 => ListView.separated(
                  key: const PageStorageKey('characters'),
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedCards.length + 1,
                  // 惰性列表重排时保留菜单宿主的 State；Key 本身不足以提供新索引。
                  findItemIndexCallback: (key) {
                    final index = sortedCards.indexWhere(
                      (e) => ValueKey(e.id) == key,
                    );
                    return index < 0 ? null : index + 1;
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) return _cardHeader(context);
                    final card = sortedCards[index - 1];
                    final token = _identities['card:${card.id}']!;
                    return _CharacterTile(
                      key: ValueKey(card.id),
                      card: card,
                      tags: widget.snapshot.tags,
                      active:
                          widget.snapshot.activeGroupId == null &&
                          widget.snapshot.activeCardId == card.id,
                      onAction: (action) => _cardAction(card.id, token, action),
                    );
                  },
                ),
                1 => ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '标签管理',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _tag(
                            const PromptTagPresentation(id: '', name: ''),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            '新建标签',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              widget.snapshot.tagsImporting ||
                                  widget.snapshot.tagsExporting
                              ? null
                              : emptyAction,
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 14,
                          ),
                          label: const Text('导入'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              widget.snapshot.tagsImporting ||
                                  widget.snapshot.tagsExporting
                              ? null
                              : _exportTags,
                          icon: const Icon(Icons.share_outlined, size: 14),
                          label: const Text('导出'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              widget.snapshot.tagsImporting ||
                                  widget.snapshot.tagsExporting
                              ? null
                              : widget.onOpenTagMarket,
                          icon: const Icon(Icons.store, size: 14),
                          label: const Text('标签市场'),
                        ),
                      ],
                    ),
                    if (widget.snapshot.tagsImporting ||
                        widget.snapshot.tagsExporting)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '处理中...',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (sortedTags.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '标签',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    for (final tag in sortedTags)
                      Card(
                        key: ValueKey(tag.id),
                        color: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tag.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (tag.description.isNotEmpty)
                                      Text(
                                        tag.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    if (tag.content.isNotEmpty)
                                      Text(
                                        '内容：${_preview(tag.content, 50)}...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _icon(
                                Icons.edit_outlined,
                                '编辑${tag.name}',
                                () => _tag(tag),
                              ),
                              _icon(
                                Icons.delete_outline,
                                '删除${tag.name}',
                                () => _confirmation(
                                  '删除标签',
                                  '确定要删除标签「${tag.name}」吗？此操作不可撤销。',
                                  '删除',
                                  identity: 'tag:${tag.id}',
                                  token: _identities['tag:${tag.id}'],
                                  onConfirm: widget.controller == null
                                      ? null
                                      : () => widget.controller!.delete(
                                          'tag',
                                          tag.id,
                                          tag.revision,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                _ => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '群组',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _icon(Icons.add, '创建群组', () {
                            if (widget.controller == null) return;
                            _dialog(
                              builder: (_, session) => GroupCardEditor(
                                group: const GroupPresentation(
                                  id: '',
                                  name: '',
                                ),
                                session: session,
                                onSave: widget.controller?.saveGroup,
                              ),
                            );
                          }),
                        ],
                      ),
                      Expanded(
                        child: sortedGroups.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无群组',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                key: const PageStorageKey('groups'),
                                padding: const EdgeInsets.only(top: 8),
                                itemCount: sortedGroups.length,
                                findItemIndexCallback: (key) {
                                  final index = sortedGroups.indexWhere(
                                    (group) => ValueKey(group.id) == key,
                                  );
                                  return index < 0 ? null : index;
                                },
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final group = sortedGroups[index];
                                  final token =
                                      _identities['group:${group.id}']!;
                                  return GroupCardTile(
                                    key: ValueKey(group.id),
                                    group: group,
                                    active:
                                        widget.snapshot.activeGroupId ==
                                        group.id,
                                    memberNames: [
                                      for (final member in group.members)
                                        ?cardNames[member.characterId],
                                    ],
                                    onAction: (action) =>
                                        _groupAction(group.id, token, action),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ],
        );
      },
    ),
  );

  Widget _cardHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '角色卡管理',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          _icon(Icons.add, '新建', () => _edit(CharacterPresentation.newDraft)),
          const SizedBox(width: 6),
          _icon(Icons.auto_awesome, 'AI创作', widget.onOpenPersona),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: '导入酒馆角色卡',
            icon: const Icon(Icons.file_download_outlined, size: 18),
            onSelected: (_) {},
            itemBuilder: (_) => [
              for (final entry in [
                ('导入酒馆角色卡', Icons.file_download_outlined),
                ('导入多维码', Icons.image),
                ('扫描多维码', Icons.photo_camera),
              ])
                PopupMenuItem(
                  value: entry.$1,
                  child: Row(
                    children: [
                      Icon(entry.$2, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.$1)),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: '排序',
            icon: const Icon(Icons.sort, size: 18),
            onSelected: (value) => setState(() {
              sort = value;
              _project();
            }),
            itemBuilder: (_) => [
              for (var i = 0; i < 3; i++)
                PopupMenuItem(
                  value: i,
                  child: Text(['默认顺序', '按名称', '按最近更新时间'][i]),
                ),
            ],
          ),
        ],
      ),
    ],
  );

  void _tag(PromptTagPresentation tag) => _dialog(
    identity: tag.id.isEmpty ? null : 'tag:${tag.id}',
    token: _identities['tag:${tag.id}'],
    builder: (_, session) => _TagEditor(
      key: ValueKey(tag.id),
      tag: tag,
      session: session,
      onSave: widget.controller?.saveTag,
    ),
  );

  void _exportTags() {
    if (sortedTags.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可导出的标签')));
      return;
    }
    _dialog(builder: (_, session) => TagExportDialog(session: session));
  }
}

String _preview(String value, int length) =>
    value.characters.take(length).toString();

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.card,
    required this.tags,
    required this.active,
    required this.onAction,
    super.key,
  });
  final CharacterPresentation card;
  final List<PromptTagPresentation> tags;
  final bool active;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(width: .5, color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.surfaceContainerHighest,
                  child: card.avatarAsset == null
                      ? Icon(
                          Icons.account_circle,
                          size: 22,
                          color: colors.onSurfaceVariant,
                        )
                      : ClipOval(
                          child: Image.asset(
                            card.avatarAsset!,
                            width: 40,
                            height: 40,
                            cacheWidth: 80,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (active)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: colors.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '当前激活',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '${card.name}菜单',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    for (final entry in [
                      if (!active) ('设为活跃', Icons.check),
                      ('编辑', Icons.edit_outlined),
                      ('复制', Icons.content_copy_outlined),
                      ('导出', Icons.share_outlined),
                      if (card.isDefault)
                        ('重置', Icons.restore)
                      else
                        ('删除', Icons.delete_outline),
                    ])
                      PopupMenuItem(
                        value: entry.$1,
                        child: Row(
                          children: [
                            Icon(
                              entry.$2,
                              size: 20,
                              color: entry.$1 == '删除'
                                  ? colors.error
                                  : colors.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              entry.$1,
                              style: TextStyle(
                                color: entry.$1 == '删除'
                                    ? colors.error
                                    : colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (card.setting.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '角色设定：${_preview(card.setting, 40)}...',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            if (card.chat.isNotEmpty)
              Text(
                '其他内容（聊天）：${_preview(card.chat, 40)}...',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            if (card.tagIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final id in card.tagIds.take(3))
                      if (tags.any((e) => e.id == id))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tags.firstWhere((e) => e.id == id).name,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                    if (card.tagIds.length > 3)
                      Text(
                        '+${card.tagIds.length - 3}',
                        style: const TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
            if (card.custom.isNotEmpty)
              Text(
                '高级自定义：${_preview(card.custom, 40)}...',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagEditor extends StatefulWidget {
  const _TagEditor({
    required this.tag,
    required this.session,
    this.onSave,
    super.key,
  });
  final PromptTagPresentation tag;
  final PromptDialogState session;
  final Future<void> Function(PromptTagPresentation)? onSave;
  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  late final fields = [
    widget.tag.name,
    widget.tag.description,
    widget.tag.content,
  ].map((e) => TextEditingController(text: e)).toList();
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.tag.id.isEmpty ? '新建标签' : '编辑标签'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                key: ValueKey('tag-field-$i'),
                controller: fields[i],
                minLines: i == 2 ? 4 : 1,
                maxLines: i == 2 ? 12 : 1,
                decoration: InputDecoration(
                  labelText: ['标签名称', '描述（可选）', '提示词内容'][i],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (widget.session.error != null)
            Text(
              widget.session.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => widget.session.submit(
          widget.onSave == null
              ? null
              : () => widget.onSave!(
                  PromptTagPresentation(
                    id: widget.tag.id,
                    revision: widget.tag.revision,
                    name: fields[0].text,
                    description: fields[1].text,
                    content: fields[2].text,
                  ),
                ),
        ),
        child: Text(widget.session.saving ? '保存中…' : '保存'),
      ),
    ],
  );
}

class _ExportModeDialog extends StatelessWidget {
  const _ExportModeDialog({required this.name, required this.onColorCode});
  final String name;
  final VoidCallback onColorCode;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('导出'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(name)),
          const SizedBox(height: 12),
          for (final entry in [
            (
              '酒馆 JSON',
              '导出为 .json 并保存到 Download/Kiyori-Android/exports',
              Icons.data_object,
            ),
            (
              '酒馆 PNG',
              '导出为可导入酒馆的图片，并保存到 Download/Kiyori-Android/exports',
              Icons.image,
            ),
            ('多维码', '进入多维码预览，可选颜色数并保存', Icons.qr_code_2),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card.outlined(
                child: ListTile(
                  title: Text(entry.$1),
                  subtitle: Text(entry.$2),
                  leading: Icon(entry.$3),
                  onTap: entry.$1 == '多维码' ? onColorCode : () {},
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    ],
  );
}

class _ColorCodeDialog extends StatefulWidget {
  const _ColorCodeDialog({required this.name});
  final String name;
  @override
  State<_ColorCodeDialog> createState() => _ColorCodeDialogState();
}

class _ColorCodeDialogState extends State<_ColorCodeDialog> {
  int colors = 8;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('导出'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.name),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final count in [2, 4, 8, 16])
              if (colors == count)
                FilledButton(onPressed: () {}, child: Text('$count色'))
              else
                OutlinedButton(
                  onPressed: () => setState(() => colors = count),
                  child: Text('$count色'),
                ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
      FilledButton(onPressed: () {}, child: const Text('保存')),
    ],
  );
}
