import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'knowledge_controller.dart';
import 'diary_labels.dart';

const memoryCategories = {
  'other': '其他',
  'preference': '偏好',
  'fact': '事实',
  'decision': '决策',
  'experience': '经验',
  'event': '事件',
};

class MemoryEditor extends StatefulWidget {
  const MemoryEditor({
    required this.controller,
    required this.space,
    required this.kind,
    required this.folder,
    required this.dismiss,
    this.record,
    super.key,
  });
  final KnowledgeController controller;
  final String space, kind, folder;
  final MemoryRecord? record;
  final Future<void> Function() dismiss;
  @override
  State<MemoryEditor> createState() => MemoryEditorState();
}

class MemoryEditorState extends State<MemoryEditor> {
  late final title = TextEditingController(text: widget.record?.draft.title);
  late final content = TextEditingController(
    text: widget.record?.draft.content,
  );
  late final folder = TextEditingController(
    text: widget.record?.draft.folder ?? widget.folder,
  );
  late final source = TextEditingController(
    text: widget.record?.draft.source == 'user_input'
        ? ''
        : widget.record?.draft.source,
  );
  final tagDraft = TextEditingController();
  late final tags = [...?widget.record?.draft.tags];
  late String category = widget.record?.draft.category ?? 'other';
  late double credibility = widget.record?.draft.credibility ?? .8,
      importance = widget.record?.draft.importance ?? .5;
  bool advanced = false, _accepted = false;
  String diaryPhase = 'plan';
  DialogRoute<bool>? _discard;
  final _popups = <ModalRoute<dynamic>>[];
  bool _invalidated = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_catalogChanged);
  }

  void _catalogChanged() {
    final snapshot = widget.controller.snapshot;
    if (snapshot == null || _invalidated) return;
    if (snapshot.activeSpace != widget.space ||
        (widget.record != null &&
            (widget.controller.detail?.id != widget.record!.id ||
                widget.controller.detail?.spaceId != widget.space))) {
      _invalidated = true;
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool get dirty =>
      title.text != (widget.record?.draft.title ?? '') ||
      content.text != (widget.record?.draft.content ?? '') ||
      folder.text != (widget.record?.draft.folder ?? widget.folder) ||
      source.text !=
          (widget.record?.draft.source == 'user_input'
              ? ''
              : widget.record?.draft.source ?? '') ||
      category != (widget.record?.draft.category ?? 'other') ||
      credibility != (widget.record?.draft.credibility ?? .8) ||
      importance != (widget.record?.draft.importance ?? .5) ||
      !listEquals(tags, widget.record?.draft.tags ?? const []) ||
      (widget.kind == 'diary' &&
          widget.record == null &&
          diaryPhase != 'plan') ||
      tagDraft.text.trim().isNotEmpty;
  bool canDismiss() {
    if (widget.controller.saving) return false;
    if (_accepted || !dirty) return true;
    if (mounted && _discard == null) unawaited(_confirmDiscard());
    return false;
  }

  Future<void> _confirmDiscard() async {
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('本次修改尚未保存，离开后会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    _discard = route;
    final confirmed = await Navigator.of(context).push(route);
    if (identical(_discard, route)) _discard = null;
    if (confirmed == true &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _accepted = true;
      await widget.dismiss();
    }
  }

  Future<void> _choose(
    BuildContext anchor,
    List<(String, String)> options,
    ValueChanged<String> selected,
  ) async {
    if (_invalidated || widget.controller.saving) return;
    final button = anchor.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    ModalRoute<dynamic>? owned;
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final option in options)
          PopupMenuItem(
            value: option.$1,
            child: Builder(
              builder: (context) {
                final route = ModalRoute.of(context);
                if (owned == null && route != null) {
                  owned = route;
                  if (mounted && !_invalidated) {
                    _popups.add(route);
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (route.isActive) route.navigator?.removeRoute(route);
                    });
                    WidgetsBinding.instance.ensureVisualUpdate();
                  }
                }
                return Text(option.$2);
              },
            ),
          ),
      ],
    );
    _popups.remove(owned);
    if (choice != null &&
        mounted &&
        !_invalidated &&
        !widget.controller.saving) {
      setState(() => selected(choice));
    }
  }

  void _addTag() {
    final value = tagDraft.text.trim();
    setState(() {
      if (value.isNotEmpty && !tags.contains(value)) tags.add(value);
      tagDraft.clear();
    });
  }

  Future<void> _save() async {
    if (_invalidated ||
        widget.controller.saving ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    final draft = MemoryDraft(
      kind: widget.kind,
      title: title.text,
      content: content.text,
      category: category,
      source: source.text,
      folder: folder.text,
      credibility: credibility,
      importance: importance,
      tags: {
        ...tags,
        if (tagDraft.text.trim().isNotEmpty) tagDraft.text.trim(),
      }.toList(),
    );
    final saved = widget.kind == 'diary' && widget.record == null
        ? await widget.controller.createDiary(widget.space, draft, diaryPhase)
        : await widget.controller.save(widget.space, widget.record?.id, draft);
    if (saved && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      _accepted = true;
      await widget.dismiss();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_catalogChanged);
    final route = _discard;
    final popups = _popups.reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final popup in popups) {
        if (popup.isActive) popup.navigator?.removeRoute(popup);
      }
      if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    for (final controller in [title, content, folder, source, tagDraft]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    Widget? trailing,
  }) => TextField(
    controller: controller,
    enabled: !widget.controller.saving,
    minLines: minLines,
    maxLines: maxLines,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: trailing,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.saving;
      return SettingsTheme(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.record != null
                          ? widget.kind == 'diary'
                                ? '编辑全文'
                                : '编辑记忆'
                          : widget.kind == 'knowledge'
                          ? '新建笔记'
                          : widget.kind == 'diary'
                          ? '新建日记'
                          : '新建记忆',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => unawaited(widget.dismiss()),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    field(title, '标题'),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 160,
                        maxHeight: 280,
                      ),
                      child: field(
                        content,
                        widget.kind == 'diary' && widget.record == null
                            ? '开篇'
                            : '内容',
                        minLines: 6,
                        maxLines: 10,
                      ),
                    ),
                    if (widget.kind == 'diary') ...[
                      Text(
                        widget.record == null
                            ? '先写下这次要做什么、判断依据是什么，之后逐条续写。'
                            : '编辑全文会改写历史记录。日常记录请用下方的续写。',
                      ),
                      if (widget.record == null) ...[
                        const Text('阶段'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final entry in diaryPhases.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: diaryPhase == entry.key,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(
                                        () => diaryPhase = entry.key,
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ],
                    if (widget.kind != 'diary')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Builder(
                          builder: (context) => OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => unawaited(
                                    _choose(context, [
                                      for (final item
                                          in memoryCategories.entries)
                                        (item.key, item.value),
                                    ], (value) => category = value),
                                  ),
                            child: Text('主题 · ${memoryCategories[category]}'),
                          ),
                        ),
                      ),
                    if (widget.controller.error != null)
                      Text(
                        widget.controller.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Builder(
                      builder: (context) => field(
                        folder,
                        '文件夹路径',
                        trailing: IconButton(
                          tooltip: '选择文件夹',
                          onPressed: busy
                              ? null
                              : () => unawaited(
                                  _choose(context, [
                                    ('', '根目录'),
                                    for (final path
                                        in widget
                                                .controller
                                                .snapshot
                                                ?.folders ??
                                            <String>[])
                                      (path, path),
                                  ], (value) => folder.text = value),
                                ),
                          icon: const Icon(Icons.expand_more),
                        ),
                      ),
                    ),
                    const Text('标签'),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags)
                          InputChip(
                            label: Text(tag),
                            onDeleted: busy
                                ? null
                                : () => setState(() => tags.remove(tag)),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: field(tagDraft, '添加标签')),
                        IconButton(
                          tooltip: '添加标签',
                          onPressed: busy ? null : _addTag,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    field(source, '来源'),
                    TextButton(
                      onPressed: () => setState(() => advanced = !advanced),
                      child: Text(advanced ? '收起高级属性' : '高级属性'),
                    ),
                    if (advanced) ...[
                      Text('可信度: ${credibility.toStringAsFixed(2)}'),
                      Slider(
                        value: credibility,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => credibility = v),
                      ),
                      Text('重要性: ${importance.toStringAsFixed(2)}'),
                      Slider(
                        value: importance,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => importance = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => unawaited(widget.dismiss()),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        busy ||
                            title.text.trim().isEmpty ||
                            content.text.trim().isEmpty
                        ? null
                        : _save,
                    child: Text(busy ? '正在保存…' : '保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
