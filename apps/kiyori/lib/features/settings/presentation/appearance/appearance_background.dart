import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_components.dart';

/// 无媒体默认态及展开草稿。不创建播放器、读取图片或打开系统选择器。
class AppearanceBackground extends StatefulWidget {
  const AppearanceBackground({super.key});
  @override
  State<AppearanceBackground> createState() => _AppearanceBackgroundState();
}

class _AppearanceBackgroundState extends State<AppearanceBackground> {
  bool enabled = false, video = false, blur = false;
  double opacity = .3, radius = 10;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppearanceSectionTitle('背景定制', Icons.image, IconTone.image),
      AppearanceCard(
        children: [
          const Text(
            '背景媒体设置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          AppearanceSwitch(
            '使用自定义背景',
            '开启后可以选择自定义背景图片或视频',
            value: enabled,
            bottom: 16,
            onChanged: (v) => setState(() => enabled = v),
          ),
          if (enabled) ...[
            const AppearanceDivider(),
            const Text('媒体类型', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppearanceChoice(
                    '图片',
                    selected: !video,
                    themeMode: true,
                    icon: Icons.image,
                    onTap: () => setState(() => video = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppearanceChoice(
                    '视频',
                    selected: video,
                    themeMode: true,
                    icon: Icons.videocam,
                    onTap: () => setState(() => video = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 134,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF1F5),
                border: Border.all(color: PrimaryColors.of(context).muted),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '点击选择按钮来添加背景',
                textAlign: TextAlign.center,
                style: TextStyle(color: PrimaryColors.of(context).secondary),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: emptyAction,
                child: Text(video ? '选择视频' : '选择图片'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '背景不透明度: ${(opacity * 100).toInt()}%',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: Slider(
                value: opacity,
                min: .1,
                onChanged: (v) => setState(() => opacity = v),
              ),
            ),
            const SizedBox(height: 16),
            const AppearanceDivider(),
            AppearanceSwitch(
              '背景模糊',
              '为背景图片或视频添加高斯模糊效果',
              value: blur,
              bottom: 8,
              onChanged: (v) => setState(() => blur = v),
            ),
            if (blur) ...[
              const SizedBox(height: 8),
              Text(
                '模糊半径: ${radius.toInt()}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: Slider(
                  value: radius,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() => radius = v),
                ),
              ),
            ],
          ],
        ],
      ),
    ],
  );
}
