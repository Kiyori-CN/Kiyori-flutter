import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_components.dart';

class AppearanceAvatars extends StatefulWidget {
  const AppearanceAvatars({super.key});
  @override
  State<AppearanceAvatars> createState() => _AppearanceAvatarsState();
}

class _AppearanceAvatarsState extends State<AppearanceAvatars> {
  final name = TextEditingController();
  bool square = false;
  int radius = 8;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppearanceSectionTitle('自定义头像', Icons.person, IconTone.account),
      AppearanceCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final label in ['用户头像', '全局用户头像'])
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: emptyAction,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PrimaryColors.accent,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 35,
                            color: PrimaryColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重置', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: AppearanceDescription(
              '说明：左侧的用户头像是角色卡专属设置，为空时将使用右侧的全局用户头像。全局用户头像在所有角色卡中共享使用。',
            ),
          ),
          const AppearanceDivider(),
          const Text(
            '全局用户名称',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: name,
            builder: (context, value, _) => TextField(
              controller: name,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: '用户名称',
                hintText: '请输入您的名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  onPressed: emptyAction,
                  tooltip: value.text.isEmpty ? '清除' : '保存',
                  icon: Icon(
                    value.text.isEmpty ? Icons.clear : Icons.save_outlined,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: AppearanceDescription(
              '设置一个全局用户名称，将在所有对话中被AI用来称呼您。这个名称在所有角色卡中共享使用。',
            ),
          ),
          const AppearanceDivider(),
          const Text(
            '头像形状',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppearanceChoice(
                  '圆形',
                  selected: !square,
                  onTap: () => setState(() => square = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppearanceChoice(
                  '方形',
                  selected: square,
                  onTap: () => setState(() => square = true),
                ),
              ),
            ],
          ),
          if (square) ...[
            const AppearanceDivider(),
            const Text(
              '头像圆角',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  Icons.remove,
                  '减小圆角',
                  () => setState(() => radius = (radius - 1).clamp(0, 16)),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$radius dp',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _RoundButton(
                  Icons.add,
                  '增大圆角',
                  () => setState(() => radius = (radius + 1).clamp(0, 16)),
                ),
              ],
            ),
          ],
        ],
      ),
    ],
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      child: Icon(icon, semanticLabel: label),
    ),
  );
}

class AppearanceDisplayOptions extends StatefulWidget {
  const AppearanceDisplayOptions({super.key});
  @override
  State<AppearanceDisplayOptions> createState() =>
      _AppearanceDisplayOptionsState();
}

class _AppearanceDisplayOptionsState extends State<AppearanceDisplayOptions> {
  static const rows = [
    ('显示思考过程', '切换AI响应中 <think> 标签的可见性', true),
    ('显示模型供应商', '在AI消息中显示模型供应商名称', false),
    ('显示模型名称', '在AI消息中显示使用的模型名称', false),
    ('显示角色卡名', '在AI消息中显示当前角色卡名称', true),
    ('显示用户名字', '在用户消息中显示用户名字', true),
    ('显示消息 Token 简报', '在 AI 消息底部显示简洁的 token 上下行与缓存信息', false),
    ('显示消息耗时简报', '在 AI 消息底部显示首包与生成耗时', false),
    ('显示消息时间', '在 AI 消息底部显示该条消息的时间', false),
    ('显示任务状态标签', '切换任务完成和等待状态标签的可见性', true),
    ('显示输入处理状态', '在输入框上方显示AI正在处理任务的状态', true),
    ('显示对话浮点动画', '在 AI 回复加载时显示对话区域的浮点动画', true),
  ];
  final values = rows.map((r) => r.$3).toList();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppearanceSectionTitle(
        '显示选项',
        Icons.color_lens,
        IconTone.appearance,
      ),
      AppearanceCard(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const AppearanceDivider(),
            AppearanceSwitch(
              rows[i].$1,
              rows[i].$2,
              value: values[i],
              bottom: i == 0 ? 8 : 0,
              onChanged: (v) => setState(() => values[i] = v),
            ),
          ],
        ],
      ),
    ],
  );
}
