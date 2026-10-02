import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 正文来自旧 values/strings.xml；完整保留格式/制作/结构说明。
class AvatarGuides extends StatefulWidget {
  const AvatarGuides({super.key});
  @override
  State<AvatarGuides> createState() => _AvatarGuidesState();
}

class _AvatarGuidesState extends State<AvatarGuides> {
  bool how = false, structure = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _guide(context, '如何制作和导入模型?', how, () => setState(() => how = !how), [
        Text(
          "本应用支持多种虚拟形象格式，包括DragonBones。以下是制作和导入模型的说明。",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "支持格式",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "- DragonBones：骨骼 .json + *_tex.json + *_tex.png\n- WebP：一个或多个 .webp 文件\n- MP4：一个或多个 .mp4 文件\n- MMD：.pmx 或 .pmd 模型，可选 .vmd 动作\n- glTF：.glb 或 .gltf（如有引用还需 .bin/贴图等资源）\n- FBX：.fbx（直传仅限自包含资源）",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 12),
        Text(
          "导入方式",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "- 直接选文件：.glb / .gltf / .mp4 / .fbx\n- ZIP 导入：DragonBones、WebP、MP4、MMD、多文件 glTF，或带外置贴图/资源的 FBX 包",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 12),
        Text(
          "1. 制作模型：",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "    · 您可以使用多种工具来创建您的虚拟形象模型。\n    · 对于DragonBones，推荐使用新版在线编辑器，也可使用旧版 v5.6.3 离线编辑器。",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 12),
        Text(
          "2. 导出文件：",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "    · 请遵循您所选格式的导出指南。\n    · 对于DragonBones，导出数据时类型请选择 JSON，版本请选择 5.5（当前还不支持 6.0 运行时）。\n    · 导出的核心文件为：*_ske.json、*_tex.json、*_tex.png。",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 12),
        Text(
          "3. 配置交互：",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "    · 如需实现头部跟随，请添加 IK 约束，并将其目标骨骼命名为 ik_target。\n    · idle 动画：请确保有一个命名为 idle 的动画，作为基础待机动画，会自动循环播放。\n    · 随机动画：可添加如 blink（眨眼）、shake_head（摇头）、wag_tail（摇尾巴）等动画，\n      系统会随机自动触发这些动画，丰富宠物表现。",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 12),
        Text(
          "4. 打包与导入：",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          "    · 将导出的三个文件打包成一个 .zip 文件后导入。",
          style: const TextStyle(fontSize: 12, height: 2),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer
                .withValues(alpha: .5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "重要提示：旧版编辑器下载页面中，Windows和Mac的下载链接放反了，请注意选择正确的链接下载。",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: emptyAction, child: const Text('下载旧版编辑器')),
            FilledButton(onPressed: emptyAction, child: const Text('访问在线编辑器')),
          ],
        ),
      ]),
      const SizedBox(height: 8),
      _guide(
        context,
        '导入结构指南',
        structure,
        () => setState(() => structure = !structure),
        [
          const Text(
            "这是“导入包”的目录结构（ZIP 或选中文件内部），不是应用内部存储。\n\nDragonBones（.zip）\n  my_dragonbones.zip\n    any_folder_name/\n      hero_ske.json\n      hero_tex.json\n      hero_tex.png\n  要求：ske/tex json/png 文件名前缀一致。\n\nWebP（.zip）\n  my_webp.zip\n    any_folder_name/\n      idle.webp\n      talking.webp\n      happy.webp\n  要求：至少包含一个 .webp 文件。\n\nMP4\n  方式 A（直接文件）:\n    avatar.mp4\n  方式 B（.zip）:\n    my_mp4.zip\n      any_folder_name/\n        idle.mp4\n        talking.mp4\n        happy.mp4\n  要求：至少包含一个 .mp4 文件。\n\nMMD（.zip）\n  my_mmd.zip\n    any_folder_name/\n      character.pmx（或 .pmd）\n      motions/idle.vmd（可选）\n      textures/...\n  要求：保持 PMX/PMD 引用的相对路径不变。\n\nglTF\n  方式 A（直接文件）:\n    avatar.glb\n  方式 B（多文件 glTF 使用 .zip）:\n    my_gltf.zip\n      any_folder_name/\n        avatar.gltf\n        avatar.bin\n        textures/...\n  要求：保持 .gltf 引用的相对路径不变。\n\nFBX\n  方式 A（直接文件，仅限自包含资源）:\n    avatar.fbx\n  方式 B（外置贴图/资源请使用 .zip）:\n    my_fbx.zip\n      any_folder_name/\n        avatar.fbx\n        textures/...\n  要求：直接上传 .fbx 仅支持内嵌资源；若模型引用外置贴图或其他资源，请保持相对路径并放进 ZIP。",
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ],
  );
  Widget _guide(
    BuildContext context,
    String title,
    bool expanded,
    VoidCallback onTap,
    List<Widget> body,
  ) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest
        .withValues(alpha: .35),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Text(
              '$title（点击${expanded ? '收起' : '展开'}）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (expanded) ...[const SizedBox(height: 8), ...body],
        ],
      ),
    ),
  );
}
