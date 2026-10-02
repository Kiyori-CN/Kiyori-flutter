import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_components.dart';

class AppearanceInsetCard extends StatelessWidget {
  const AppearanceInsetCard({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1F5).withValues(alpha: .35),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

/// 聊天面板拥有草稿，切换命令框或标签不会丢失尚未保存的样式。
class BubbleFontDraft {
  bool enabled = false, file = false;
  String font = '默认字体';
  String? family(TargetPlatform platform) {
    if (!enabled || file) return null;
    final desktop = platform == TargetPlatform.windows;
    return switch (font) {
      '衬线体 (Serif)' => desktop ? 'Times New Roman' : 'serif',
      '无衬线体 (Sans Serif)' => desktop ? 'Arial' : 'sans-serif',
      '等宽字体 (Monospace)' => desktop ? 'Consolas' : 'monospace',
      '手写体 (Cursive)' => desktop ? 'Comic Sans MS' : 'cursive',
      _ => null,
    };
  }
}

class AppearanceBubbleFont extends StatelessWidget {
  const AppearanceBubbleFont(
    this.title, {
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final String title;
  final BubbleFontDraft draft;
  final VoidCallback onChanged;
  void update(VoidCallback change) {
    change();
    onChanged();
  }

  @override
  Widget build(BuildContext context) => AppearanceInsetCard(
    children: [
      AppearanceSwitch(
        title,
        '使用系统字体或自定义字体文件',
        value: draft.enabled,
        onChanged: (v) => update(() => draft.enabled = v),
      ),
      if (draft.enabled) ...[
        const SizedBox(height: 12),
        const Text(
          '字体类型',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('系统字体'),
              selected: !draft.file,
              onSelected: (_) => update(() => draft.file = false),
            ),
            FilterChip(
              label: const Text('自定义文件'),
              selected: draft.file,
              onSelected: (_) => update(() => draft.file = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!draft.file)
          RadioGroup<String>(
            groupValue: draft.font,
            onChanged: (v) => update(() => draft.font = v!),
            child: Column(
              children: [
                for (final name in [
                  '默认字体',
                  '衬线体 (Serif)',
                  '无衬线体 (Sans Serif)',
                  '等宽字体 (Monospace)',
                  '手写体 (Cursive)',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Radio<String>(value: name),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: emptyAction,
                  child: const Text('选择字体文件'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: emptyAction,
                  child: const Text('清除字体'),
                ),
              ),
            ],
          ),
        ],
      ],
    ],
  );
}

class BubbleImageDraft {
  bool enabled = false;
  final values = <double>[0, 0, 0, 0, .35, .65, .35, .65, 1, 12, 12];
}

class AppearanceBubbleImage extends StatelessWidget {
  const AppearanceBubbleImage(
    this.title, {
    required this.available,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final String title;
  final bool available;
  final BubbleImageDraft draft;
  final VoidCallback onChanged;
  List<double> get values => draft.values;
  void update(VoidCallback change) {
    change();
    onChanged();
  }

  static const names = [
    '左裁剪',
    '上裁剪',
    '右裁剪',
    '下裁剪',
    '水平重复起点',
    '水平重复终点',
    '垂直重复起点',
    '垂直重复终点',
    '整图缩放',
    '左内边距',
    '右内边距',
  ];
  @override
  Widget build(BuildContext context) => AppearanceInsetCard(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                AppearanceDescription(
                  !available && title == 'AI气泡图片'
                      ? '当前已开启AI气泡磨砂玻璃或水玻璃背景，AI气泡图片不会生效'
                      : '启用后使用图片气泡，并支持裁剪与中段重复拉伸',
                ),
              ],
            ),
          ),
          Switch(
            value: draft.enabled && available,
            onChanged: available
                ? (v) => update(() => draft.enabled = v)
                : null,
          ),
        ],
      ),
      if (draft.enabled && available) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: emptyAction,
                child: const Text('选择图片'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: emptyAction,
                child: const Text('清空图片'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const AppearanceDescription('未选择图片'),
        for (final pair in [(0, 1), (2, 3), (4, 5), (6, 7)])
          _pair(pair.$1, pair.$2),
        _slider(8),
        _pair(9, 10),
      ],
    ],
  );
  Widget _pair(int a, int b) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 240 ||
          MediaQuery.textScalerOf(context).scale(12) > 18) {
        return Column(children: [_slider(a), _slider(b)]);
      }
      return Row(
        children: [
          Expanded(child: _slider(a)),
          const SizedBox(width: 12),
          Expanded(child: _slider(b)),
        ],
      );
    },
  );
  Widget _slider(int index) {
    final min = index < 4 || index >= 9
        ? 0.0
        : index == 8
        ? .2
        : index == 4 || index == 6
        ? .05
        : (values[index - 1] + .01).clamp(.06, .95);
    final max = index < 4
        ? .45
        : index >= 9
        ? 32.0
        : index == 8
        ? 3.0
        : index == 4 || index == 6
        ? .9
        : .95;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: AppearanceDescription(names[index])),
              Text(
                index >= 9
                    ? '${values[index].round()}dp'
                    : '${(values[index] * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: PrimaryColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: values[index].clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => update(() {
              values[index] = (index == 4 || index == 6)
                  ? v.clamp(min, values[index + 1] - .01)
                  : v;
            }),
          ),
        ],
      ),
    );
  }
}
