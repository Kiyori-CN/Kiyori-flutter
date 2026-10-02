import 'package:flutter/material.dart';

import 'appearance_components.dart';

/// 仅输入栏展示草稿，玻璃外观互斥来自原 ThemeSettingsInputTab。
class AppearanceInput extends StatefulWidget {
  const AppearanceInput({super.key});
  @override
  State<AppearanceInput> createState() => _AppearanceInputState();
}

class _AppearanceInputState extends State<AppearanceInput> {
  bool agent = true,
      transparent = false,
      floating = false,
      frosted = false,
      water = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppearanceCard(
        children: [
          const Text(
            '输入框样式',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const AppearanceDescription('选择消息输入区域的样式'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppearanceChoice(
                  '经典样式',
                  selected: !agent,
                  onTap: () => setState(() => agent = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppearanceChoice(
                  'Agent样式',
                  selected: agent,
                  onTap: () => setState(() => agent = true),
                ),
              ),
            ],
          ),
        ],
      ),
      AppearanceCard(
        children: [
          const Text(
            '输入框设置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          AppearanceSwitch(
            '透明输入框',
            '开启后聊天输入框将变为透明',
            value: transparent,
            bottom: 8,
            onChanged: (v) => setState(() => transparent = v),
          ),
          const AppearanceDivider(),
          AppearanceSwitch(
            '输入框悬浮',
            '开启后，输入框将从贴底布局改为悬浮的全圆角矩形，两种输入样式都会生效',
            value: floating,
            bottom: 8,
            onChanged: (v) => setState(() => floating = v),
          ),
          if (transparent) ...[
            const AppearanceDivider(),
            AppearanceSwitch(
              '磨砂玻璃输入框',
              '开启后，透明输入框会显示 iOS 风格磨砂玻璃效果',
              value: frosted,
              bottom: 8,
              onChanged: (v) => setState(() {
                frosted = v;
                if (v) water = false;
              }),
            ),
            const AppearanceDivider(),
            AppearanceSwitch(
              '水玻璃输入框',
              '开启后，透明输入框会显示水玻璃效果',
              value: water,
              bottom: 8,
              onChanged: (v) => setState(() {
                water = v;
                if (v) frosted = false;
              }),
            ),
          ],
        ],
      ),
    ],
  );
}
