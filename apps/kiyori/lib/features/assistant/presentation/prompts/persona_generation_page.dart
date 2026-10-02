import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'persona_presentation.dart';
import 'prompt_presentation.dart';

class PersonaGenerationPage extends StatefulWidget {
  const PersonaGenerationPage({
    this.snapshot = const PersonaPresentation(),
    super.key,
  });
  final PersonaPresentation snapshot;
  @override
  State<PersonaGenerationPage> createState() => _PersonaGenerationPageState();
}

class _PersonaGenerationPageState extends State<PersonaGenerationPage> {
  final scaffold = GlobalKey<ScaffoldState>();
  final _drafts = <String, PersonaCardDraft>{};
  final _identities = <String, Object>{};
  final _routes = <ModalRoute<dynamic>, String?>{};
  final _emptyInput = TextEditingController();
  final messagesScroll = ScrollController();
  String? selectedId;
  String? _limitPrompt;
  List<CharacterPresentation> get cards => widget.snapshot.catalog.cards;
  CharacterPresentation? get current =>
      cards.where((card) => card.id == selectedId).firstOrNull;
  PersonaCardDraft? get draft => _drafts[selectedId];

  @override
  void initState() {
    super.initState();
    selectedId = widget.snapshot.catalog.activeCardId;
    _reconcile();
    _showLimit();
  }

  void _reconcile() {
    _identities.removeWhere((id, _) => !cards.any((card) => card.id == id));
    for (final card in cards) {
      _identities.putIfAbsent(card.id, Object.new);
    }
    final removed = _drafts.keys
        .where((id) => !cards.any((card) => card.id == id))
        .toList();
    for (final id in removed) {
      final old = _drafts.remove(id)!;
      _removeRoutes(
        _routes.entries
            .where((entry) => entry.value == id)
            .map((entry) => entry.key),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    if (current == null) selectedId = cards.firstOrNull?.id;
    if (current case final card?) {
      _drafts.putIfAbsent(card.id, () => PersonaCardDraft(card));
    }
    for (final card in cards) {
      _drafts[card.id]?.update(card);
    }
  }

  @override
  void didUpdateWidget(covariant PersonaGenerationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = selectedId;
    if (oldWidget.snapshot.catalog.activeCardId !=
        widget.snapshot.catalog.activeCardId) {
      selectedId = widget.snapshot.catalog.activeCardId;
    }
    _reconcile();
    if (before != selectedId) _removeRoutes(_routes.keys);
    final oldCount = oldWidget.snapshot.messages[selectedId]?.length ?? 0;
    final nextCount = widget.snapshot.messages[selectedId]?.length ?? 0;
    if (oldCount != nextCount || before != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && messagesScroll.hasClients) {
          messagesScroll.jumpTo(messagesScroll.position.maxScrollExtent);
        }
      });
    }
    _showLimit();
  }

  void _removeRoutes(Iterable<ModalRoute<dynamic>> routes) {
    final values = routes.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in values.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _dialog(WidgetBuilder builder, {String? id}) {
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => SettingsTheme(child: builder(context)),
    );
    _routes[route] = id;
    unawaited(
      Navigator.of(context)
          .push(route)
          .whenComplete(() => _routes.remove(route)),
    );
  }

  void _showLimit() {
    final id = widget.snapshot.limitPromptId;
    if (id == null || id == _limitPrompt) return;
    _limitPrompt = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.snapshot.limitPromptId != id) return;
      _dialog(
        (context) => AlertDialog(
          title: const Text('对话数量已达上限'),
          scrollable: true,
          content: const Text('当前对话数量已达 40 条上限。\n为了保持对话质量和性能，请清空历史记录后继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clear();
              },
              child: const Text('去清空'),
            ),
          ],
        ),
        id: selectedId,
      );
    });
  }

  void _clear() => _dialog(
    (context) => AlertDialog(
      title: const Text('清除所有聊天记录'),
      scrollable: true,
      content: const Text('确定要清空当前角色卡的对话记录吗？此操作不可撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const TextButton(onPressed: emptyAction, child: Text('清空')),
      ],
    ),
    id: selectedId,
  );

  Future<void> _chooseCard(BuildContext anchor) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final choices = <({bool forCreate, String id, Object token})>[
      for (final card in cards)
        (forCreate: false, id: card.id, token: _identities[card.id]!),
    ];
    choices.add((forCreate: true, id: '', token: Object()));
    ModalRoute<dynamic>? owned;
    final choice = await showMenu<({bool forCreate, String id, Object token})>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        for (final value in choices)
          PopupMenuItem(
            value: value,
            child: Builder(
              builder: (context) {
                final route = ModalRoute.of(context)!;
                if (owned == null) {
                  owned = route;
                  if (mounted) {
                    _routes[route] = selectedId;
                  } else {
                    _removeRoutes([route]);
                  }
                }
                return Text(
                  value.forCreate
                      ? '+ 新建角色卡'
                      : cards
                                .where((card) => card.id == value.id)
                                .firstOrNull
                                ?.name ??
                            '',
                );
              },
            ),
          ),
      ],
    );
    _routes.remove(owned);
    if (!mounted || choice == null) return;
    if (choice.forCreate) {
      _dialog((_) => const _NewPersonaDialog());
      return;
    }
    if (!identical(_identities[choice.id], choice.token)) return;
    setState(() {
      selectedId = choice.id;
      _reconcile();
    });
    if (messagesScroll.hasClients) messagesScroll.jumpTo(0);
  }

  @override
  void dispose() {
    _removeRoutes(_routes.keys);
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _emptyInput.dispose();
    messagesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '人设生成',
    onBack: () => Navigator.maybePop(context),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final messages =
            widget.snapshot.messages[selectedId] ??
            [
              PersonaMessage(
                id: 'welcome',
                content: current == null
                    ? '请在侧边栏选择或创建一个角色卡以开始。'
                    : "🎭 欢迎使用角色卡生成助手！\n\n我们现在来编辑 '${current!.name}' 吧！\n请告诉我你想创建什么角色，或者想修改哪个部分？",
                time: '',
              ),
            ];
        final generating = widget.snapshot.generating.contains(selectedId);
        final enabled = !generating && messages.length < 40;
        return Scaffold(
          key: scaffold,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawer: Drawer(
            width: (MediaQuery.sizeOf(context).width - 56).clamp(0.0, 360.0),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => scaffold.currentState!.closeDrawer(),
                        tooltip: '关闭',
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '角色卡配置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) => InkWell(
                        key: const ValueKey('persona-card-selector'),
                        onTap: () => _chooseCard(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '当前角色卡',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(current?.name ?? '无角色卡'),
                        ),
                      ),
                    ),
                    if (current?.isDefault == false) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _dialog(
                          (context) => AlertDialog(
                            title: const Text('删除角色卡'),
                            scrollable: true,
                            content: const Text('确定删除当前角色卡吗？此操作不可撤销。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              const TextButton(
                                onPressed: emptyAction,
                                child: Text('删除'),
                              ),
                            ],
                          ),
                          id: selectedId,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除当前角色卡'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      '当前角色卡内容',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (draft != null)
                      for (var i = 0; i < 8; i++) ...[
                        TextField(
                          key: ValueKey('persona-field-$i'),
                          controller: draft!.fields[i],
                          minLines: 1,
                          maxLines: [1, 3, 6, 4, 6, 6, 6, 4][i],
                          decoration: InputDecoration(
                            labelText: [
                              '角色名称',
                              '角色描述',
                              '角色设定',
                              '开场白',
                              '其他内容（聊天）',
                              '其他内容（语音）',
                              '高级自定义提示词',
                              '备注信息（不会被拼接到提示词）',
                            ][i],
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (i < 7) const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _clear,
                      tooltip: '清除所有聊天记录',
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                    const Spacer(),
                    Flexible(
                      child: TextButton(
                        onPressed: () => scaffold.currentState!.openDrawer(),
                        child: Text(current?.name ?? '无角色卡'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: messagesScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const SizedBox(height: 80);
                    }
                    final message = messages[index];
                    return Align(
                      alignment: message.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        key: ValueKey(message.id),
                        color: message.user
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                message.content,
                                style: TextStyle(
                                  color: message.user
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (message.time.isNotEmpty)
                                Text(
                                  message.time,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          TextField(
                            key: const ValueKey('persona-input'),
                            controller: draft?.input ?? _emptyInput,
                            enabled: enabled,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: generating ? '正在生成…' : '描述你想要的角色…',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                20,
                                12,
                                12,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: IgnorePointer(
                              child: Text(
                                '${messages.length}/40',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: messages.length >= 40
                                      ? colors.error
                                      : colors.onSurfaceVariant.withValues(
                                          alpha: .6,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: enabled ? emptyAction : null,
                      tooltip: generating ? '生成中' : '发送',
                      icon: Icon(
                        generating ? Icons.hourglass_bottom : Icons.send,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _NewPersonaDialog extends StatefulWidget {
  const _NewPersonaDialog();
  @override
  State<_NewPersonaDialog> createState() => _NewPersonaDialogState();
}

class _NewPersonaDialogState extends State<_NewPersonaDialog> {
  final name = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新建角色卡'),
    scrollable: true,
    content: TextField(
      controller: name,
      maxLines: 1,
      decoration: const InputDecoration(
        labelText: '角色卡名称',
        hintText: '例如：小昔-校园版',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      const TextButton(onPressed: emptyAction, child: Text('创建')),
    ],
  );
}
