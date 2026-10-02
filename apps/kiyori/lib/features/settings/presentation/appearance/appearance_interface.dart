import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_color_picker.dart';
import 'appearance_components.dart';

class AppearanceCharacterBinding extends StatelessWidget {
  const AppearanceCharacterBinding({this.name = '', super.key});
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: PrimaryColors.of(context).card,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFEDF1F5),
          child: Icon(
            Icons.person,
            size: 24,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前角色: $name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PrimaryColors.of(context).accent,
                ),
              ),
              const AppearanceDescription('主题设置将自动绑定到此角色卡'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.link, color: IconTone.link.iconFor(context), size: 20),
      ],
    ),
  );
}

class AppearanceColorSelection extends StatelessWidget {
  const AppearanceColorSelection({
    required this.title,
    required this.color,
    required this.onTap,
    super.key,
  });
  final String title;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: PrimaryColors.of(context).muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class AppearanceInterface extends StatefulWidget {
  const AppearanceInterface({super.key});
  @override
  State<AppearanceInterface> createState() => _AppearanceInterfaceState();
}

class _AppearanceInterfaceState extends State<AppearanceInterface> {
  bool transparent = false, overlay = false;
  Color history = PrimaryColors.text, pip = PrimaryColors.text;
  Future<void> editColor(bool isHistory) async {
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => AppearanceColorPicker(
        title: isHistory ? '选择历史记录图标颜色' : '选择悬浮窗图标颜色',
        initial: isHistory ? history : pip,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isHistory) {
        history = result;
      } else {
        pip = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppearanceCharacterBinding(),
      const AppearanceSectionTitle('AI 界面', Icons.tune, IconTone.settings),
      AppearanceCard(
        children: [
          AppearanceSwitch(
            '透明聊天栏',
            '开启后聊天顶栏将变为透明',
            value: transparent,
            textEndPadding: 16,
            onChanged: (v) => setState(() => transparent = v),
          ),
          if (transparent) ...[
            const AppearanceDivider(),
            AppearanceSwitch(
              '覆盖模式',
              '开启后，透明顶栏将作为覆盖层显示，不会挤占消息空间',
              value: overlay,
              textEndPadding: 16,
              onChanged: (v) => setState(() => overlay = v),
            ),
          ],
          const AppearanceDivider(),
          const Text(
            '聊天顶栏图标颜色',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          AppearanceColorSelection(
            title: '历史记录图标颜色',
            color: history,
            onTap: () => editColor(true),
          ),
          const SizedBox(height: 8),
          AppearanceColorSelection(
            title: '悬浮窗图标颜色',
            color: pip,
            onTap: () => editColor(false),
          ),
        ],
      ),
    ],
  );
}
