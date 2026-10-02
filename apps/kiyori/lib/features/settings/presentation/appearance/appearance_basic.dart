import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_components.dart';

/// ThemeSettingsBasicTab：主题和全局字体不写入角色卡。
class AppearanceBasic extends StatefulWidget {
  const AppearanceBasic({super.key});
  @override
  State<AppearanceBasic> createState() => _AppearanceBasicState();
}

class _AppearanceBasicState extends State<AppearanceBasic> {
  bool system = false, hidden = false, customFont = false;
  String mode = 'light', fontType = 'system', font = '默认字体';
  double scale = 1;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppearanceCard(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette,
                  size: 20,
                  color: PrimaryColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiyori 固定配色',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppearanceDescription(
                      '浅色、深色与跟随系统主题仍然保留；AI 背景、消息、头像和输入区可在其他标签中单独调整。',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      const AppearanceSectionTitle(
        '主题模式',
        Icons.brightness_4,
        IconTone.appearance,
      ),
      AppearanceCard(
        children: [
          const Text(
            '系统主题',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          AppearanceSwitch(
            '跟随系统主题',
            '开启后会根据系统深色模式自动切换主题',
            value: system,
            onChanged: (v) => setState(() => system = v),
            bottom: 16,
          ),
          if (!system) ...[
            const AppearanceDivider(),
            const Text('选择主题', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppearanceChoice(
                    '浅色主题',
                    selected: mode == 'light',
                    themeMode: true,
                    onTap: () => setState(() => mode = 'light'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppearanceChoice(
                    '深色主题',
                    selected: mode == 'dark',
                    themeMode: true,
                    onTap: () => setState(() => mode = 'dark'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      const AppearanceSectionTitle(
        '状态栏',
        Icons.visibility_off,
        IconTone.neutral,
      ),
      AppearanceCard(
        children: [
          AppearanceSwitch(
            '隐藏状态栏',
            '开启后将完全隐藏状态栏，获得更大的显示空间',
            value: hidden,
            onChanged: (v) => setState(() => hidden = v),
            textEndPadding: 16,
          ),
        ],
      ),
      const AppearanceSectionTitle(
        '字体设置',
        Icons.text_fields,
        IconTone.document,
      ),
      AppearanceCard(
        children: [
          AppearanceSwitch(
            '启用自定义字体',
            '使用系统字体或自定义字体文件',
            value: customFont,
            onChanged: (v) => setState(() => customFont = v),
            bottom: 16,
          ),
          if (customFont) ...[
            const AppearanceDivider(),
            const Text(
              '字体类型',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('系统字体'),
                  selected: fontType == 'system',
                  onSelected: (_) => setState(() => fontType = 'system'),
                ),
                FilterChip(
                  label: const Text('自定义文件'),
                  selected: fontType == 'file',
                  onSelected: (_) => setState(() => fontType = 'file'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (fontType == 'system') ...[
              const Text(
                '选择系统字体',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: font,
                onChanged: (v) => setState(() => font = v!),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () => setState(() => font = name),
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
                      ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                '自定义字体文件',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const AppearanceDescription('支持 .ttf、.otf 和 .ttc 字体文件'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: emptyAction,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('选择字体文件'),
                ),
              ),
            ],
            const AppearanceDivider(space: 16),
            Text(
              '字体大小缩放 (${scale.toStringAsFixed(1)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Slider(
              value: scale,
              min: .8,
              max: 1.5,
              divisions: 7,
              onChanged: (v) => setState(() => scale = v),
            ),
          ],
        ],
      ),
    ],
  );
}
