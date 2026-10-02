import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'avatar_presentation.dart';

class AvatarMoodEditor extends StatefulWidget {
  const AvatarMoodEditor({required this.model, required this.draft, super.key});
  final AvatarModelPresentation model;
  final AvatarDraft draft;
  @override
  State<AvatarMoodEditor> createState() => _AvatarMoodEditorState();
}

class _AvatarMoodEditorState extends State<AvatarMoodEditor> {
  bool expanded = false;
  final routes = <ModalRoute<dynamic>>{};

  void registerPopup(BuildContext context) {
    final route = ModalRoute.of(context)!;
    if (!mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } else if (routes.add(route)) {
      unawaited(route.completed.then((_) => routes.remove(route)));
    }
  }

  @override
  void didUpdateWidget(covariant AvatarMoodEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = widget.model.customMoods.map((m) => m.key).toSet();
    if (oldWidget.model.customMoods.any((m) => !keys.contains(m.key))) {
      removeRoutes();
    }
  }

  void removeRoutes() {
    final owned = routes.toList();
    routes.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in owned.reversed) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    removeRoutes();
    super.dispose();
  }

  Future<void> dialog(WidgetBuilder builder) async {
    final route = DialogRoute<void>(context: context, builder: builder);
    routes.add(route);
    try {
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      routes.remove(route);
    }
  }

  Future<void> edit(AvatarMoodPresentation? mood) async {
    await dialog((context) => _MoodForm(mood: mood));
  }

  Future<void> delete(AvatarMoodPresentation mood) async {
    await dialog(
      (context) => AlertDialog(
        scrollable: true,
        title: const Text('删除自定义类型'),
        content: Text('确定删除自定义情绪“${mood.key}”吗？对应的动作映射也会被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Mood 触发映射',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(expanded ? '收起' : '展开'),
          ),
        ],
      ),
      const Text(
        '桌宠和语音头像返回的 <mood> 会优先匹配这里的 trigger。只有绑定了动画的自定义类型才会拼接进提示词。',
        style: TextStyle(fontSize: 12),
      ),
      if (expanded) ...[
        if (widget.model.animations.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('当前虚拟形象没有可用动作', style: TextStyle(fontSize: 12)),
          ),
        for (final mood in avatarBuiltInMoods) card(mood),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '自定义类型',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextButton(
              onPressed: () => edit(null),
              child: const Text('添加自定义类型'),
            ),
          ],
        ),
        if (widget.model.customMoods.isEmpty)
          const Text('还没有自定义类型', style: TextStyle(fontSize: 12)),
        for (final mood in widget.model.customMoods) card(mood, custom: true),
      ],
    ],
  );

  Widget card(AvatarMoodPresentation mood, {bool custom = false}) {
    final selected = widget.draft.mappings[mood.key];
    final actions = widget.model.animations.toSet().toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .35),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mood.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '触发键：${mood.key}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(mood.hint, style: const TextStyle(fontSize: 12)),
                        if (mood.fallback != null)
                          Text(
                            '回退表情：${mood.fallback}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (custom)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '编辑自定义类型',
                          onPressed: () => edit(mood),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '删除自定义类型',
                          onPressed: () => delete(mood),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // PopupMenuButton 保留未知的已选动作文字，目录变化不触发 Dropdown 的 value 断言。
              PopupMenuButton<String>(
                enabled: actions.isNotEmpty,
                onSelected: (value) {
                  if (widget.model.animations.contains(value)) {
                    setState(() => widget.draft.mappings[mood.key] = value);
                  }
                },
                itemBuilder: (_) => [
                  for (final action in actions)
                    PopupMenuItem(
                      value: action,
                      child: Builder(
                        builder: (context) {
                          registerPopup(context);
                          return Text(action);
                        },
                      ),
                    ),
                ],
                child: InputDecorator(
                  decoration: settingsFieldDecoration(context, label: '绑定动作')
                      .copyWith(
                        enabled: actions.isNotEmpty,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                  child: Text(
                    selected ?? '未绑定',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: selected == null ? null : emptyAction,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('预览'),
                  ),
                  TextButton(
                    onPressed: selected == null
                        ? null
                        : () => setState(
                            () => widget.draft.mappings.remove(mood.key),
                          ),
                    child: const Text('清除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodForm extends StatefulWidget {
  const _MoodForm({this.mood});
  final AvatarMoodPresentation? mood;
  @override
  State<_MoodForm> createState() => _MoodFormState();
}

class _MoodFormState extends State<_MoodForm> {
  late final keyInput = TextEditingController(text: widget.mood?.key);
  late final hintInput = TextEditingController(text: widget.mood?.hint);
  @override
  void dispose() {
    keyInput.dispose();
    hintInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([keyInput, hintInput]),
    builder: (context, _) {
      final normalized = keyInput.text
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_\-]'), '_')
          .replaceAll(RegExp('_+'), '_')
          .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
      return AlertDialog(
        scrollable: true,
        title: Text(widget.mood == null ? '添加自定义类型' : '编辑自定义类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: keyInput,
              decoration: settingsFieldDecoration(context, label: '类型键'),
            ),
            const SizedBox(height: 8),
            Text(
              '仅允许小写字母、数字、_ 和 -。规范化后的 key：${normalized.isEmpty ? '<空>' : normalized}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hintInput,
              maxLines: null,
              decoration: settingsFieldDecoration(context, label: '提示词说明'),
            ),
            const SizedBox(height: 8),
            const Text(
              '这个提示会被拼接进桌宠/语音头像的 mood 规则里，引导模型在什么场景下使用该类型。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed:
                keyInput.text.trim().isEmpty || hintInput.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context),
            child: Text(widget.mood == null ? '添加' : '保存'),
          ),
        ],
      );
    },
  );
}
