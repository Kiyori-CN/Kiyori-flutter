import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'reply_preferences_presentation.dart';

class ReplyPreferencesPage extends StatefulWidget {
  const ReplyPreferencesPage({
    required this.onCustomEmoji,
    this.snapshot = const ReplyPreferencesPresentation(),
    super.key,
  });
  final VoidCallback onCustomEmoji;
  final ReplyPreferencesPresentation snapshot;
  @override
  State<ReplyPreferencesPage> createState() => _ReplyPreferencesPageState();
}

class _ReplyPreferencesPageState extends State<ReplyPreferencesPage> {
  late bool enabled = widget.snapshot.enabled,
      merge = widget.snapshot.mergeSend,
      punctuation = widget.snapshot.removePunctuation,
      emoticons = widget.snapshot.emoticons,
      selfie = widget.snapshot.selfie;
  late final delay = ValueNotifier(widget.snapshot.charDelay.clamp(200, 1000));
  late final mergeDelay = ValueNotifier(
    widget.snapshot.mergeDelay.clamp(500, 10000),
  );
  late final prompt = TextEditingController(text: widget.snapshot.customPrompt);
  late final appearance = TextEditingController(
    text: widget.snapshot.selfiePrompt,
  );
  @override
  void dispose() {
    delay.dispose();
    mergeDelay.dispose();
    prompt.dispose();
    appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '回复与表情',
    onBack: () => Navigator.of(context).maybePop(),
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        Text title(String text, {double size = 16}) => Text(
          text,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w500),
        );
        Text detail(String text, {Color? color}) => Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color ?? colors.onSurface.withValues(alpha: .7),
          ),
        );
        Widget toggle(
          String name,
          String description,
          bool value,
          ValueChanged<bool> change, {
          Widget? extra,
        }) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title(name),
                  const SizedBox(height: 4),
                  detail(description),
                  if (extra != null) ...[const SizedBox(height: 4), extra],
                ],
              ),
            ),
            Switch(value: value, onChanged: change),
          ],
        );
        InputDecoration field(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
        );
        return ListView(
          key: const PageStorageKey('reply-preferences'),
          padding: const EdgeInsets.all(16),
          children: [
            _ReplyCard(
              color: colors.secondaryContainer,
              children: [
                Row(
                  children: [
                    Icon(Icons.face, size: 24, color: IconTone.account.icon),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Waifu模式',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '启用后，AI的回复将按标点分割逐句发送，营造更自然的对话体验。',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSecondaryContainer.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
            _ReplyCard(
              color: colors.primaryContainer.withValues(alpha: .6),
              border: colors.primary.withValues(alpha: .3),
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 20, color: IconTone.link.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          detail(
                            '绑定到角色卡',
                            color: colors.onPrimaryContainer.withValues(
                              alpha: .7,
                            ),
                          ),
                          Text(
                            widget.snapshot.targetName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _ReplyCard(
              children: [
                toggle(
                  '启用Waifu模式',
                  'AI回复将按标点分割发送',
                  enabled,
                  (v) => setState(() => enabled = v),
                ),
              ],
            ),
            _ReplyCard(
              children: [
                toggle(
                  '合并发送',
                  '连续发送多条短消息时，停顿后合成一条消息交给AI处理',
                  merge,
                  (v) => setState(() => merge = v),
                ),
                const SizedBox(height: 16),
                title('合并发送间隔', size: 14),
                const SizedBox(height: 4),
                detail('用户最后一次发送后等待多久再提交给AI'),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: mergeDelay,
                  builder: (context, value, _) => Column(
                    children: [
                      detail('当前：${value}ms', color: colors.primary),
                      const SizedBox(height: 12),
                      Slider(
                        key: const ValueKey('merge-delay'),
                        value: value.toDouble(),
                        min: 500,
                        max: 10000,
                        divisions: 95,
                        onChanged: (v) => mergeDelay.value = v.round(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _ReplyCard(
              children: [
                title('打字速度设置'),
                const SizedBox(height: 4),
                detail('控制每字符的延迟时间，模拟真人打字节奏'),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: delay,
                  builder: (context, value, _) => Column(
                    children: [
                      detail(
                        '当前速度：每秒 ${(1000 / value).toStringAsFixed(1)} 字符',
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(width: 30, child: detail('快')),
                          Expanded(
                            child: Slider(
                              key: const ValueKey('character-delay'),
                              value: value.toDouble(),
                              min: 200,
                              max: 1000,
                              divisions: 40,
                              onChanged: (v) => delay.value = v.round(),
                            ),
                          ),
                          SizedBox(width: 30, child: detail('慢')),
                        ],
                      ),
                      detail('当前：${value}ms/字符'),
                    ],
                  ),
                ),
              ],
            ),
            _ReplyCard(
              children: [
                toggle(
                  '移除句末标点符号',
                  '移除句子末尾的句号、问号、感叹号',
                  punctuation,
                  (v) => setState(() => punctuation = v),
                ),
              ],
            ),
            _ReplyCard(
              children: [
                title('Waifu模式提示词'),
                const SizedBox(height: 4),
                detail('自定义 Waifu 模式附加提示词。'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('reply-prompt'),
                  controller: prompt,
                  minLines: 4,
                  maxLines: 8,
                  decoration: field(
                    'Waifu模式提示词',
                    '例如：回复简短自然，不要卖萌，不要加语气词，不要写动作描写。',
                  ),
                ),
                const SizedBox(height: 8),
                detail(
                  '这段内容会作为 Waifu 模式的额外规则拼接到系统提示词中。',
                  color: colors.primary.withValues(alpha: .8),
                ),
              ],
            ),
            _ReplyCard(
              children: [
                toggle(
                  '启用表情包',
                  '在对话中插入情绪状态标签，增强表达效果',
                  emoticons,
                  (v) => setState(() => emoticons = v),
                  extra: detail(
                    '可用表情：crying, like_you, happy, surprised, miss_you, speechless, angry, confused, sad',
                    color: colors.primary.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
            _ReplyCard(
              color: colors.primaryContainer,
              onTap: widget.onCustomEmoji,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title('自定义表情'),
                          const SizedBox(height: 4),
                          detail(
                            '添加您喜欢的表情图片，AI将在Waifu模式中使用它们',
                            color: colors.onPrimaryContainer.withValues(
                              alpha: .7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: colors.onPrimaryContainer),
                  ],
                ),
              ],
            ),
            _ReplyCard(
              children: [
                toggle(
                  '启用自拍功能',
                  '允许AI生成角色自拍图片，需要配置外貌提示词',
                  selfie,
                  (v) => setState(() => selfie = v),
                ),
                if (selfie) ...[
                  const SizedBox(height: 16),
                  title('外貌提示词', size: 14),
                  const SizedBox(height: 8),
                  detail('描述角色的外貌特征，用于生成自拍图片'),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('selfie-prompt'),
                    controller: appearance,
                    minLines: 3,
                    maxLines: 6,
                    decoration: field(
                      '外貌描述',
                      '例如：long hair, purple eyes, sweater vest...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  detail(
                    '提示：使用英文关键词描述外貌特征，多个关键词用逗号分隔',
                    color: colors.primary.withValues(alpha: .8),
                  ),
                ],
              ],
            ),
            _ReplyCard(
              color: colors.tertiaryContainer,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: colors.tertiary, size: 20),
                    const SizedBox(width: 8),
                    title('功能说明', size: 14),
                  ],
                ),
                const SizedBox(height: 8),
                detail(
                  '• 普通模式：AI回复一次性全部发送\n• Waifu模式：AI回复按句子分割，每句独立气泡\n• 智能延迟：根据句子长度计算延迟时间\n• 合并发送：用户连续发送短消息时，停顿后合成一条消息交给AI\n• 自动清理：移除状态标签，只显示纯文本\n• 可选功能：合并发送、移除句末标点、编辑 Waifu 提示词、启用表情包\n• 适用场景：模拟更自然的对话节奏\n• 注意：此模式对工具调用的适配可能不佳',
                  color: colors.onTertiaryContainer.withValues(alpha: .8),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.children,
    this.color,
    this.border,
    this.onTap,
  });
  final List<Widget> children;
  final Color? color, border;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}
