import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'display_components.dart';

class LayoutAdjustmentPage extends StatelessWidget {
  const LayoutAdjustmentPage({super.key});
  static const entries = [
    ('聊天设置按钮右边距', '调整聊天设置按钮距离屏幕右边缘的距离，单位为dp', 2.0, 0.0, 50.0, 'dp'),
    ('聊天区域水平内边距', '调整聊天消息区域距离屏幕左右边缘的距离，单位为dp', 16.0, 0.0, 50.0, 'dp'),
    ('AI Markdown 行距倍率', '调整 AI 回复中 Markdown 正文的行距倍率', 1.0, .8, 2.0, 'x'),
    ('AI Markdown 字距', '调整 AI 回复中 Markdown 正文的字间距', 0.0, -1.0, 8.0, 'sp'),
    (
      'AI Markdown 段间距',
      '调整 AI 回复中 Markdown 段落之间额外增加的间距',
      12.0,
      0.0,
      48.0,
      'dp',
    ),
  ];
  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '布局调整',
    onBack: () => Navigator.maybePop(context),
    body: SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const DisplayDescription('在这里可以调整界面元素的位置和边距，自定义您的使用体验'),
          const _SectionTitle('布局调整设置', Icons.tune),
          _SectionCard(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i == 2) const Divider(),
                _FloatItem(entry: entries[i]),
              ],
            ],
          ),
          const _SectionTitle('AI Markdown 预览', Icons.visibility),
          const _SectionCard(
            children: [
              DisplayDescription(
                '下方示例会展示当前已保存的 AI Markdown 行距、字距与段间距效果。前三段之间的留白会直接反映段间距设置。',
              ),
              // 只投影原已保存默认值。编辑框是未提交草稿，保存尚未接入业务。
              _Preview(),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Icon(icon, color: PrimaryColors.of(context).secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: PrimaryColors.of(context).accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1F5).withValues(alpha: .22),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: children,
    ),
  );
}

class _FloatItem extends StatefulWidget {
  const _FloatItem({required this.entry});
  final (String, String, double, double, double, String) entry;
  @override
  State<_FloatItem> createState() => _FloatItemState();
}

class _FloatItemState extends State<_FloatItem> {
  late final input = TextEditingController(text: number(widget.entry.$3));
  bool error = false;
  static String number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  bool valid(String value) {
    final parsed = double.tryParse(value);
    return parsed != null &&
        parsed.isFinite &&
        parsed >= widget.entry.$4 &&
        parsed <= widget.entry.$5;
  }

  void validate() {
    setState(() => error = !valid(input.text));
    if (!error) {
      input.text = number(double.parse(input.text));
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF1F5).withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final label = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.entry.$2,
                  style: TextStyle(
                    fontSize: 11,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
              ],
            );
            final field = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: input,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: PrimaryColors.of(context).accent,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => validate(),
                    onChanged: (v) =>
                        setState(() => error = v.isNotEmpty && !valid(v)),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: error
                          ? Theme.of(context).colorScheme.errorContainer
                                .withValues(alpha: .65)
                          : PrimaryColors.of(context).card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    widget.entry.$6,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: PrimaryColors.of(context).accent,
                    ),
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 240 ||
                MediaQuery.textScalerOf(context).scale(14) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  label,
                  Align(alignment: Alignment.centerRight, child: field),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 12),
                field,
              ],
            );
          },
        ),
        if (error)
          Text(
            '无效值。请输入${widget.entry.$4.toStringAsFixed(1)}到${widget.entry.$5.toStringAsFixed(1)}之间的数字',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  input.text = number(widget.entry.$3);
                  error = false;
                });
                FocusScope.of(context).unfocus();
              },
              child: const Text('恢复默认'),
            ),
            TextButton(onPressed: validate, child: const Text('保存')),
          ],
        ),
      ],
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: PrimaryColors.of(context).text,
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('第一段预览：用来观察正文行距与字距。'),
        SizedBox(height: 12),
        Text('第二段预览：这一段专门用来观察段落之间的留白。'),
        SizedBox(height: 12),
        Text('第三段预览：如果你调整了段间距，这里和上一段之间的距离会立即变化。'),
        SizedBox(height: 12),
        Text('•  AI Markdown 列表项一'),
        Text('•  AI Markdown 列表项二'),
      ],
    ),
  );
}
