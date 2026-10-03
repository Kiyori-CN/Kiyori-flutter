import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'diary_labels.dart';
import 'diary_status.dart';
import 'knowledge_controller.dart';

class DiaryDetail extends StatefulWidget {
  const DiaryDetail({
    required this.controller,
    required this.record,
    required this.document,
    required this.onMenu,
    super.key,
  });
  final KnowledgeController controller;
  final MemoryRecord record;
  final DiaryDocument document;
  final void Function(BuildContext, Future<bool> Function()) onMenu;
  @override
  State<DiaryDetail> createState() => _DiaryDetailState();
}

class _DiaryDetailState extends State<DiaryDetail> {
  final draft = TextEditingController();
  final closingSummary = TextEditingController();
  String phase = 'progress';
  bool accepted = false;
  DialogRoute<bool>? confirmation;
  bool get busy => widget.controller.saving;
  bool get dirty =>
      draft.text.trim().isNotEmpty || closingSummary.text.trim().isNotEmpty;

  Future<bool> confirm({
    required String title,
    required Widget content,
    String action = '确认',
  }) async {
    if (!mounted || confirmation != null) return false;
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    confirmation = route;
    final value = await Navigator.of(context).push(route);
    await route.completed;
    if (identical(confirmation, route)) confirmation = null;
    return mounted &&
        value == true &&
        (ModalRoute.of(context)?.isCurrent ?? false);
  }

  Future<bool> canLeave() async {
    if (!mounted || busy || confirmation != null) return false;
    if (dirty &&
        !await confirm(
          title: '放弃未保存的修改？',
          content: const Text('本次续写或收尾总结尚未保存，离开后会丢失。'),
          action: '放弃修改',
        )) {
      return false;
    }
    return mounted && !busy;
  }

  Future<void> close() async {
    if (!await canLeave() || !mounted) return;
    setState(() => accepted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> append() async {
    if (busy || widget.record.archived) return;
    final saved = await widget.controller.appendDiary(
      widget.record,
      draft.text,
      phase,
    );
    if (saved && mounted) setState(draft.clear);
  }

  Future<void> endDiary() async {
    if (busy || widget.record.archived) return;
    final confirmed = await confirm(
      title: '结束这篇日记？',
      action: '结束日记',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('会追加一条收尾记录。之后仍可继续续写，续写后重新标记为进行中。'),
          TextField(
            controller: closingSummary,
            decoration: const InputDecoration(labelText: '收尾总结（可留空）'),
          ),
        ],
      ),
    );
    if (confirmed && mounted) {
      final saved = await widget.controller.appendDiary(
        widget.record,
        closingSummary.text,
        'closed',
      );
      if (saved && mounted) setState(closingSummary.clear);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final route = confirmation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive ?? false) route!.navigator?.removeRoute(route);
      draft.dispose();
      closingSummary.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final closed = record.diary?.closed ?? false;
    final writable = !busy && !record.archived;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: accepted || (!busy && !dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(close());
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .92,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                  child: Row(
                    children: [
                      Text('日记', style: TextStyle(color: colors.primary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DiaryStatus(closed: closed),
                        ),
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: '更多操作',
                          onPressed: busy
                              ? null
                              : () => widget.onMenu(context, canLeave),
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: busy ? null : () => unawaited(close()),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: widget.document.entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              record.draft.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '开始于 ${DateTime.fromMillisecondsSinceEpoch(record.createdAt).toLocal().toString().substring(0, 16)} · ${widget.document.entries.length} 条记录 · ${record.draft.folder.isEmpty ? '根目录' : record.draft.folder}',
                            ),
                            if (record.draft.tags.isNotEmpty)
                              Text(
                                record.draft.tags.map((t) => '#$t').join('  '),
                              ),
                            if (record.archived)
                              const Text('已归档的日记不参与检索，也不能续写。恢复后即可继续记录。')
                            else if (closed)
                              const Text('这篇日记已完结。继续追加会重新标记为进行中。'),
                            if (widget.controller.error != null)
                              Text(
                                widget.controller.error!,
                                style: TextStyle(color: colors.error),
                              ),
                            if (widget.document.preface.isNotEmpty) ...[
                              const Text('开篇'),
                              SelectableText(widget.document.preface),
                              const Divider(),
                            ],
                            if (widget.document.entries.isEmpty)
                              const Text('还没有记录，写下第一条。'),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                      final entry = widget.document.entries[index - 1];
                      final accent = entry.phase == 'closed'
                          ? colors.tertiary
                          : colors.primary;
                      return Stack(
                        children: [
                          if (index < widget.document.entries.length)
                            Positioned(
                              left: 4,
                              top: 19,
                              bottom: 4,
                              child: VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: colors.outlineVariant,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Text('${entry.date} ${entry.time}'),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                alpha: .12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              diaryPhaseLabel(
                                                entry.phase,
                                                entry.rawPhase,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(color: accent),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (entry.body.isNotEmpty)
                                        SelectableText(entry.body),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final value in diaryPhases.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(value.value),
                                      selected: phase == value.key,
                                      onSelected: writable
                                          ? (_) => setState(
                                              () => phase = value.key,
                                            )
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 84,
                              maxHeight: 160,
                            ),
                            child: TextField(
                              controller: draft,
                              enabled: writable,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: '记下这次的进展、决策或证据',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              if (!closed)
                                TextButton(
                                  onPressed: writable
                                      ? () => unawaited(endDiary())
                                      : null,
                                  child: const Text('结束日记'),
                                ),
                              FilledButton.icon(
                                onPressed:
                                    writable && draft.text.trim().isNotEmpty
                                    ? () => unawaited(append())
                                    : null,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(busy ? '保存中' : '追加记录'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
