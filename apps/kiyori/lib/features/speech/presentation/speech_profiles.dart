import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class SpeechProfileOption {
  const SpeechProfileOption(this.id, this.name);
  final String id, name;
}

class SpeechProfiles extends StatefulWidget {
  const SpeechProfiles({
    required this.profiles,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<SpeechProfileOption> profiles;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  State<SpeechProfiles> createState() => _SpeechProfilesState();
}

class _SpeechProfilesState extends State<SpeechProfiles> {
  DialogRoute<void>? _route;
  SpeechProfileOption? _target;
  void _close() {
    final route = _route;
    _route = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(covariant SpeechProfiles oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (oldWidget.selected != widget.selected ||
        (target != null &&
            !widget.profiles.any(
              (profile) =>
                  profile.id == target.id && profile.name == target.name,
            ))) {
      _close();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  Future<void> _show(WidgetBuilder builder, SpeechProfileOption? target) async {
    if (_route != null) return;
    final route = DialogRoute<void>(context: context, builder: builder);
    _target = target;
    _route = route;
    await Navigator.of(context).push(route);
    if (identical(_route, route)) _route = null;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profiles;
    final selected = widget.selected;
    if (profiles.isEmpty) return const SizedBox.shrink();
    final active = profiles
        .where((profile) => profile.id == selected)
        .firstOrNull;
    void edit([SpeechProfileOption? profile]) => _show(
      (_) => _SpeechProfileName(profile: profile, canCreate: active != null),
      profile ?? active,
    );
    return SettingsGroup(
      title: '语音服务配置',
      description: '分别保存并切换文字转语音与语音识别的服务配置。',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey((
                    selected,
                    profiles.map((p) => p.id).join('\u0000'),
                  )),
                  initialValue: active?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '当前配置',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final profile in profiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(profile.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null &&
                        widget.profiles.any((p) => p.id == value)) {
                      widget.onSelect(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '新建语音配置',
                onPressed: edit,
                icon: const Icon(Icons.add),
              ),
              if (active != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '重命名语音配置',
                  onPressed: () => edit(active),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ],
          ),
        ),
        for (final profile in profiles.where(
          (profile) => profile.id != selected,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: '重命名语音配置',
                  onPressed: () => edit(profile),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除语音配置',
                  onPressed: () => _show(
                    (context) => AlertDialog(
                      title: const Text('删除语音配置'),
                      content: Text('确定删除语音配置“${profile.name}”吗？活动配置不能删除。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        TextButton(onPressed: () {}, child: const Text('删除')),
                      ],
                    ),
                    profile,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpeechProfileName extends StatefulWidget {
  const _SpeechProfileName({required this.profile, required this.canCreate});
  final SpeechProfileOption? profile;
  final bool canCreate;
  @override
  State<_SpeechProfileName> createState() => _SpeechProfileNameState();
}

class _SpeechProfileNameState extends State<_SpeechProfileName> {
  late final name = TextEditingController(text: widget.profile?.name ?? '');
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.profile == null ? '新建语音配置' : '重命名语音配置'),
    scrollable: true,
    content: TextField(
      controller: name,
      decoration: InputDecoration(
        labelText: '配置名称',
        hintText: widget.profile == null ? '例如: 工作、学习、娱乐...' : null,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      ValueListenableBuilder(
        valueListenable: name,
        builder: (context, value, _) => TextButton(
          onPressed:
              value.text.trim().isNotEmpty &&
                  (widget.profile != null || widget.canCreate)
              ? () {}
              : null,
          child: Text(widget.profile == null ? '创建' : '保存'),
        ),
      ),
    ],
  );
}
