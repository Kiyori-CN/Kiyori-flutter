import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'tag_market_presentation.dart';
import 'tag_market_presets.dart';

class TagMarketPage extends StatefulWidget {
  const TagMarketPage({this.presets = tagMarketPresets, super.key});
  final List<TagMarketPreset> presets;
  @override
  State<TagMarketPage> createState() => _TagMarketPageState();
}

class _TagMarketPageState extends State<TagMarketPage> {
  late final catalog = ValueNotifier(widget.presets);
  final _routes = <DialogRoute<void>, String>{};
  @override
  void didUpdateWidget(covariant TagMarketPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stale = _routes.entries
        .where(
          (entry) => !widget.presets.any((preset) => preset.id == entry.value),
        )
        .map((entry) => entry.key)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in stale.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      if (mounted) catalog.value = widget.presets;
    });
  }

  Future<void> _add(TagMarketPreset preset) async {
    if (_routes.isNotEmpty) return;
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => ValueListenableBuilder(
        valueListenable: catalog,
        builder: (_, values, _) => SettingsTheme(
          child: _AddMarketTag(
            preset:
                values.where((item) => item.id == preset.id).firstOrNull ??
                preset,
          ),
        ),
      ),
    );
    _routes[route] = preset.id;
    try {
      await Navigator.of(context).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  @override
  void dispose() {
    final routes = _routes.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      catalog.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TagMarketPreset>>{};
    for (final preset in widget.presets) {
      groups.putIfAbsent(preset.category, () => []).add(preset);
    }
    final entries = <Object>[
      for (final group in groups.entries) ...[group.key, ...group.value],
    ];
    return SettingsWorkspacePage(
      title: '标签市场',
      onBack: () => Navigator.maybePop(context),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry is String) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                entry,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          final preset = entry as TagMarketPreset;
          return _PresetCard(
            key: ValueKey(preset.id),
            preset: preset,
            onAdd: () => _add(preset),
          );
        },
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.onAdd, super.key});
  final TagMarketPreset preset;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primary = PrimaryColors.of(context);
    final tone = preset.icon == Icons.favorite
        ? IconTone.favorite
        : preset.icon == Icons.shield
        ? IconTone.security
        : preset.icon == Icons.book
        ? IconTone.reading
        : preset.icon == Icons.label
        ? IconTone.storage
        : IconTone.ai;
    return Card(
      margin: EdgeInsets.zero,
      color: primary.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(preset.icon, size: 20, color: tone.iconFor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          preset.type,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 旧默认两行40px；大字保留全文，不将固定高度变成裁切器。
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Text(
                preset.description,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              '标签内容:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 100 * MediaQuery.textScalerOf(context).scale(1),
              ),
              child: Text(
                preset.content,
                maxLines: 6,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('market-add-${preset.id}'),
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加标签'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMarketTag extends StatefulWidget {
  const _AddMarketTag({required this.preset});
  final TagMarketPreset preset;
  @override
  State<_AddMarketTag> createState() => _AddMarketTagState();
}

class _AddMarketTagState extends State<_AddMarketTag> {
  late final name = TextEditingController(text: widget.preset.name);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加标签'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("将 '${widget.preset.name}' 添加到你的标签库中。"),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: '标签名称',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      const FilledButton(onPressed: emptyAction, child: Text('添加')),
    ],
  );
}
