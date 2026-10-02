import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'emoji_dialogs.dart';
import 'emoji_presentation.dart';

class CustomEmojiPage extends StatefulWidget {
  const CustomEmojiPage({required this.snapshot, super.key});
  final EmojiLibraryPresentation snapshot;
  @override
  State<CustomEmojiPage> createState() => _CustomEmojiPageState();
}

class _CustomEmojiPageState extends State<CustomEmojiPage> {
  late String selected = widget.snapshot.categories.firstOrNull ?? 'happy';
  @override
  void didUpdateWidget(CustomEmojiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.snapshot.categories.contains(selected)) {
      selected = widget.snapshot.categories.firstOrNull ?? 'happy';
    }
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '自定义表情',
    onBack: () => Navigator.of(context).maybePop(),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final emojis = widget.snapshot.emojis
            .where((emoji) => emoji.category == selected)
            .toList();
        Widget button(
          String label,
          IconData icon,
          VoidCallback? action, {
          bool danger = false,
        }) => OutlinedButton(
          onPressed: action,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundColor: danger ? colors.error : null,
            side: danger ? BorderSide(color: colors.error) : null,
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 4),
              Flexible(child: Text(label)),
            ],
          ),
        );
        final target = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.link, size: 20, color: IconTone.link.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '绑定到当前角色目标',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      widget.snapshot.targetName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final category = Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            key: ValueKey('emoji-category-$selected'),
            initialValue: widget.snapshot.categories.contains(selected)
                ? selected
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '选择类别',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              for (final category in widget.snapshot.categories)
                DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Flexible(child: Text(category)),
                      if (!builtinEmotions.contains(category)) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFD64F73),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => selected = value);
            },
          ),
        );
        final controls = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final create = button(
                '创建分组',
                Icons.add,
                () => showDialog<void>(
                  context: context,
                  builder: (_) => const CreateEmojiCategoryDialog(),
                ),
              );
              final delete = button(
                '删除分组',
                Icons.delete_outline,
                builtinEmotions.contains(selected)
                    ? null
                    : () => showEmojiConfirmation(
                        context,
                        title: '删除类别',
                        message: '确认删除类别"$selected"及其所有表情吗？',
                        action: '删除',
                      ),
                danger: true,
              );
              final reset = button(
                '恢复默认',
                Icons.restore,
                () => showEmojiConfirmation(
                  context,
                  title: '重置为默认表情',
                  message: '此操作将删除所有自定义表情，并恢复为默认表情。此操作不可撤销，确定要继续吗？',
                  action: '确定重置',
                  danger: true,
                ),
                danger: true,
              );
              if (constraints.maxWidth <
                  MediaQuery.textScalerOf(context).scale(360)) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [create, delete, reset],
                );
              }
              return Row(
                children: [
                  create,
                  const SizedBox(width: 8),
                  delete,
                  const Spacer(),
                  reset,
                ],
              );
            },
          ),
        );
        Widget tile(EmojiPresentation emoji) => LayoutBuilder(
          builder: (context, constraints) {
            final image = Image(
              image: ResizeImage.resizeIfNeeded(
                (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                null,
                emoji.image,
              ),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: emoji.category,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Material(
                color: colors.surfaceContainerHighest,
                child: InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image(
                            image: emoji.image,
                            fit: BoxFit.contain,
                            semanticLabel: '表情预览',
                          ),
                        ),
                      ),
                    ),
                  ),
                  onLongPress: () => showEmojiConfirmation(
                    context,
                    title: '删除表情',
                    message: '确认删除此表情吗？',
                    action: '删除',
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        final grid = SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) => tile(emojis[index]),
          ),
        );
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight <
                    250 + MediaQuery.textScalerOf(context).scale(100);
                final content = CustomScrollView(
                  key: PageStorageKey('emoji-grid-$selected'),
                  slivers: [
                    if (compact)
                      SliverToBoxAdapter(
                        child: Column(children: [target, category, controls]),
                      ),
                    if (emojis.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '点击右下角按钮添加表情',
                              style: TextStyle(
                                fontSize: 16,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      grid,
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
                if (compact) {
                  return Column(
                    children: [
                      Expanded(child: content),
                      if (widget.snapshot.loading)
                        const LinearProgressIndicator(),
                    ],
                  );
                }
                return Column(
                  children: [
                    target,
                    category,
                    controls,
                    Expanded(child: content),
                    if (widget.snapshot.loading)
                      const LinearProgressIndicator(),
                  ],
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {},
                tooltip: '添加表情',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    ),
  );
}
