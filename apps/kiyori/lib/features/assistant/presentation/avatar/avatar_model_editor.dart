import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'avatar_mood_editor.dart';
import 'avatar_presentation.dart';

class AvatarModelEditor extends StatefulWidget {
  const AvatarModelEditor({
    required this.snapshot,
    required this.current,
    required this.draft,
    required this.onSelect,
    super.key,
  });
  final AvatarPresentation snapshot;
  final AvatarModelPresentation? current;
  final AvatarDraft? draft;
  final ValueChanged<String> onSelect;
  @override
  State<AvatarModelEditor> createState() => _AvatarModelEditorState();
}

class _AvatarModelEditorState extends State<AvatarModelEditor> {
  final selector = GlobalKey();
  final routes = <ModalRoute<dynamic>>{};
  final generations = <String, Object>{};
  bool selecting = false;

  @override
  void initState() {
    super.initState();
    reconcile();
  }

  @override
  void didUpdateWidget(covariant AvatarModelEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    reconcile();
  }

  void reconcile() {
    final ids = widget.snapshot.models.map((m) => m.id).toSet();
    final removed = generations.keys.any((id) => !ids.contains(id));
    generations.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      generations.putIfAbsent(id, Object.new);
    }
    if (removed) closeOwnedRoutes();
  }

  void closeOwnedRoutes() {
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
    closeOwnedRoutes();
    super.dispose();
  }

  Future<void> editModel(String id, bool delete) async {
    final token = generations[id];
    final model = widget.snapshot.models.where((m) => m.id == id).firstOrNull;
    if (model == null) return;
    final input = TextEditingController(text: model.name);
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(delete ? '确认删除模型？' : '重命名模型'),
        content: delete
            ? const Text('删除后不可恢复，确定要删除该模型吗？')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('输入新的模型显示名称'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: input,
                    decoration: settingsFieldDecoration(context, label: '模型名称'),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ValueListenableBuilder(
            valueListenable: input,
            builder: (context, value, _) => TextButton(
              onPressed: !delete && value.text.trim().isEmpty
                  ? null
                  : () {
                      if (!mounted || generations[id] != token) return;
                      // 外层写入尚无owner，仅关闭；目录事实仍由snapshot提供。
                      Navigator.pop(context);
                    },
              child: Text(
                delete ? '删除' : '重命名',
                style: delete
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
    routes.add(route);
    try {
      await Navigator.of(context).push(route);
    } finally {
      routes.remove(route);
      await route.completed;
      input.dispose();
    }
  }

  Future<void> choose() async {
    if (selecting || widget.snapshot.models.isEmpty) return;
    final box = selector.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final tokens = Map.of(generations);
    ModalRoute<dynamic>? owned;
    setState(() => selecting = true);
    final choice = await showMenu<(String, String)>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        for (final model in widget.snapshot.models)
          PopupMenuItem(
            value: (model.id, 'select'),
            child: Builder(
              builder: (context) {
                final route = ModalRoute.of(context)!;
                if (owned == null) {
                  owned = route;
                  if (mounted && tokens[model.id] == generations[model.id]) {
                    routes.add(route);
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (route.isActive) route.navigator?.removeRoute(route);
                    });
                    WidgetsBinding.instance.ensureVisualUpdate();
                  }
                }
                return Row(
                  children: [
                    Expanded(child: Text(model.name)),
                    IconButton(
                      tooltip: '重命名${model.name}',
                      onPressed: () =>
                          Navigator.pop(context, (model.id, 'rename')),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '删除${model.name}',
                      onPressed: () =>
                          Navigator.pop(context, (model.id, 'delete')),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
    routes.remove(owned);
    if (!mounted) return;
    setState(() => selecting = false);
    if (choice == null ||
        tokens[choice.$1] != generations[choice.$1] ||
        !generations.containsKey(choice.$1)) {
      return;
    }
    if (choice.$2 == 'select') {
      widget.onSelect(choice.$1);
    } else {
      await editModel(choice.$1, choice.$2 == 'delete');
    }
  }

  Widget slider(
    String id,
    String label,
    double min,
    double max,
    double initial, {
    int decimals = 1,
    String suffix = '',
  }) {
    final draft = widget.draft!;
    final value = (draft.values[id] ?? initial).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${value.toStringAsFixed(decimals)}$suffix',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          key: ValueKey('avatar-$id'),
          value: value,
          min: min,
          max: max,
          onChanged: (v) => setState(() => draft.values[id] = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.current;
    final type = model?.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model != null) ...[
          AvatarMoodEditor(model: model, draft: widget.draft!),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: selector,
                onTap: widget.snapshot.models.isEmpty ? null : choose,
                child: InputDecorator(
                  decoration: settingsFieldDecoration(context, label: '当前模型')
                      .copyWith(
                        enabled: widget.snapshot.models.isNotEmpty,
                        suffixIcon: Icon(
                          selecting
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                        ),
                      ),
                  child: Text(
                    model?.name ?? '选择模型',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '导入模型',
              onPressed: emptyAction,
              icon: const Icon(Icons.add_photo_alternate),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '支持：DragonBones（.json + _tex.json + _tex.png）、WebP（.webp）、MP4（.mp4）、MMD（.pmx/.pmd + 可选 .vmd）、glTF（.glb/.gltf）、FBX（.fbx）。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 2),
        const Text(
          '直接文件导入支持 .glb/.gltf/.mp4/.fbx；DragonBones、WebP、MP4、MMD、多文件 glTF，或带外置贴图/资源的 FBX 请导入 .zip。',
          style: TextStyle(fontSize: 12),
        ),
        if (model != null) ...[
          const SizedBox(height: 6),
          slider('scale', '缩放: ', .1, 2, 1, decimals: 2),
          slider('x', 'X轴位移: ', -500, 500, 0),
          slider('y', 'Y轴位移: ', -500, 500, 0),
          if (type == AvatarModelType.mmd ||
              type == AvatarModelType.gltf ||
              type == AvatarModelType.fbx) ...[
            slider(
              'pitch',
              '${type == AvatarModelType.gltf ? 'glTF' : type!.label} 相机俯仰（',
              type == AvatarModelType.mmd ? -90 : -89,
              type == AvatarModelType.mmd ? 90 : 89,
              type == AvatarModelType.mmd ? 0 : 8,
              suffix: ' deg）',
            ),
            slider(
              'yaw',
              '${type == AvatarModelType.gltf ? 'glTF' : type!.label} 相机偏航（',
              -180,
              180,
              0,
              suffix: ' deg）',
            ),
            slider(
              'distance',
              '${type == AvatarModelType.gltf ? 'glTF' : type!.label} 相机距离（',
              type == AvatarModelType.gltf ? 0 : .02,
              type == AvatarModelType.gltf ? 10 : 12,
              type == AvatarModelType.gltf ? .5 : 1,
              decimals: type == AvatarModelType.mmd ? 2 : 3,
              suffix: 'x）',
            ),
            slider(
              'pivot',
              '${type == AvatarModelType.gltf ? 'glTF' : type!.label} 环绕中心高度（',
              -2,
              2,
              0,
              decimals: 2,
              suffix: '）',
            ),
          ],
        ],
      ],
    );
  }
}
