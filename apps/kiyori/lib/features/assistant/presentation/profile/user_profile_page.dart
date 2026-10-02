import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'markdown_syntax.dart';
import 'profile_markdown_preview.dart';

class UserProfilePresentation {
  const UserProfilePresentation({
    this.markdown = '',
    this.archive,
    this.loading = false,
  });
  final String markdown;
  final String? archive;
  final bool loading;
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    this.snapshot = const UserProfilePresentation(),
    super.key,
  });
  final UserProfilePresentation snapshot;
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late final draft = MarkdownDraftController(text: widget.snapshot.markdown);
  final editorScroll = ScrollController();
  int tab = 0;
  bool canPop = false, confirming = false;
  bool get changed => draft.text != widget.snapshot.markdown;
  @override
  void dispose() {
    draft.dispose();
    editorScroll.dispose();
    super.dispose();
  }

  Future<void> back(BuildContext context) async {
    if (confirming) return;
    if (changed) {
      confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          content: const Text('返回后，本次对 user.md 的修改将丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      confirming = false;
      if (!mounted || discard != true) return;
    }
    setState(() => canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(this.context).maybePop();
    });
  }

  Future<void> reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认模板？'),
        content: const Text('当前草稿会被默认 user.md 模板替换；请检查内容并保存后再生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复默认模板'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      draft.clear();
      setState(() => tab = 0);
    }
  }

  void archive(BuildContext context) => showKiyoriModalDrawer<void>(
    context,
    builder: (context, dismiss) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const title = Text(
            'legacy-user-profiles.md',
            style: TextStyle(fontSize: 22),
          );
          final body = SelectableText(
            widget.snapshot.archive!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          );
          final copy = Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.copy),
              label: const Text('复制内容'),
            ),
          );
          // 半展开动画和大字下允许标题随正文滚动，避免固定标题挤掉正文。
          if (constraints.maxHeight <
              140 + MediaQuery.textScalerOf(context).scale(100)) {
            return ListView(
              children: [
                title,
                const SizedBox(height: 12),
                body,
                const SizedBox(height: 12),
                copy,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Expanded(child: SingleChildScrollView(child: body)),
              const SizedBox(height: 12),
              copy,
            ],
          );
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back(context);
    },
    child: SettingsWorkspacePage(
      title: '用户资料',
      onBack: () => back(context),
      body: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight <
                  190 + MediaQuery.textScalerOf(context).scale(80);
              final description = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      color: IconTone.document.iconFor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '唯一的用户资料文件。这里的 Markdown 会在启用时作为用户上下文发送给 AI。',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final controls = Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: draft,
                    builder: (context, value, _) => LayoutBuilder(
                      builder: (context, inner) {
                        final chips = [
                          FilterChip(
                            showCheckmark: false,
                            selected: tab == 0,
                            onSelected: (_) => setState(() => tab = 0),
                            label: const Text('编辑'),
                          ),
                          FilterChip(
                            showCheckmark: false,
                            selected: tab == 1,
                            onSelected: (_) => setState(() => tab = 1),
                            label: const Text('预览'),
                          ),
                        ];
                        final save = FilledButton.tonalIcon(
                          onPressed: changed && value.text.length <= 12000
                              ? () {}
                              : null,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('保存'),
                        );
                        if (inner.maxWidth < 330 ||
                            (inner.maxWidth < 400 &&
                                MediaQuery.textScalerOf(context).scale(14) >
                                    18)) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...chips,
                              if (changed)
                                Text(
                                  '未保存',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.primary,
                                  ),
                                ),
                              save,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            chips[0],
                            const SizedBox(width: 8),
                            chips[1],
                            const Spacer(),
                            if (changed) ...[
                              Text(
                                '未保存',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            save,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
              final editor = Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                child: widget.snapshot.loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(
                            child: IndexedStack(
                              index: tab,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: TextField(
                                    key: const ValueKey('user-md-editor'),
                                    controller: draft,
                                    scrollController: editorScroll,
                                    expands: true,
                                    minLines: null,
                                    maxLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      color: colors.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '介绍你的背景、习惯，以及希望 AI 如何与你交流…',
                                      hintStyle: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (tab == 1)
                                  ValueListenableBuilder(
                                    valueListenable: draft,
                                    builder: (context, value, _) =>
                                        value.text.trim().isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Text(
                                                'user.md 目前为空，填写内容后可在这里预览。',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          )
                                        : ProfileMarkdownPreview(
                                            text: value.text,
                                          ),
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ValueListenableBuilder(
                                    valueListenable: draft,
                                    builder: (context, value, _) => Text(
                                      '${value.text.length} / 12000',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: value.text.length > 12000
                                            ? colors.error
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: '更多',
                                  onSelected: (value) => value == 'reset'
                                      ? reset(context)
                                      : archive(context),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: ListTile(
                                        leading: Icon(Icons.restore),
                                        title: Text('恢复默认模板'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    if (widget.snapshot.archive != null)
                                      const PopupMenuItem(
                                        value: 'archive',
                                        child: ListTile(
                                          leading: Icon(Icons.archive),
                                          title: Text('旧档案'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
              if (compact) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      description,
                      const SizedBox(height: 10),
                      controls,
                      const SizedBox(height: 10),
                      SizedBox(height: 280, child: editor),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    description,
                    const SizedBox(height: 10),
                    controls,
                    const SizedBox(height: 10),
                    Expanded(child: editor),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
