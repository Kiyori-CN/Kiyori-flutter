import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class SpeechProfileOption {
  const SpeechProfileOption(this.id, this.name);
  final String id, name;
}

class SpeechProfiles extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const SizedBox.shrink();
    final active = profiles
        .where((profile) => profile.id == selected)
        .firstOrNull;
    void edit([SpeechProfileOption? profile]) => showDialog<void>(
      context: context,
      builder: (_) =>
          _SpeechProfileName(profile: profile, canCreate: active != null),
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
                  key: ValueKey(selected),
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
                    if (value != null) onSelect(value);
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
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
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
