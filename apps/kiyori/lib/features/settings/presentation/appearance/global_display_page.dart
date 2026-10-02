import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'display_components.dart';

/// 所有值都是旧默认展示草稿。权限仅由快照决定，不检查宿主或执行命令。
class GlobalDisplayPage extends StatefulWidget {
  const GlobalDisplayPage({this.rootPreferred = false, super.key});
  final bool rootPreferred;
  @override
  State<GlobalDisplayPage> createState() => _GlobalDisplayPageState();
}

class _GlobalDisplayPageState extends State<GlobalDisplayPage> {
  final toggles = [
    false,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    false,
    true,
    false,
  ];
  static const options = [
    ('显示帧率', '在屏幕上显示帧率性能指标'),
    ('启用回复通知', '当AI回复时发送系统通知'),
    ('回复通知提示音', '当回复通知触发时播放提示音'),
    ('回复通知震动', '当回复通知触发时进行震动提醒'),
    ('回车发送', '开启后，聊天输入框按回车会直接发送，键盘发送键也会显示为发送。'),
    ('超长粘贴文本转文件', '粘贴超过设定字符数的文本时，自动作为文本附件添加'),
    ('屏幕常亮', '保持屏幕常亮，防止在对话时自动锁屏'),
    ('新版导航动画', '开启后使用增强的页面切换动画。关闭后使用简洁的导航过渡。'),
    ('启动时新建空白聊天', '开启后，每次启动应用都会进入一个新的空白聊天界面，不再自动打开上一次聊天。'),
    ('无障碍适配模式', '为 TalkBack 等无障碍用户优化 UI 自动化行为，优先给出可朗读的操作步骤，谨慎执行自动点击。'),
    ('后台保活', '开启后保留前台通知，AI 空闲进入 idle 时也不自动关闭前台服务，适合需要长期后台驻留的场景。'),
    ('实验性虚拟屏幕', '使用基于虚拟屏幕的 ADB+Shizuku 自动化，功能仍在实验阶段，可能不稳定。'),
    ('运行时任务视图隐藏', 'AI 处理消息或执行工具时，从系统最近任务中隐藏应用任务卡片，避免在最近任务里被误滑关闭。'),
  ];
  static const collapseOptions = ['折叠多个只读工具', '折叠多个任意工具', '折叠全部工具'];
  int collapse = 1, bitrate = 1, indicator = 0, format = 1, rootMode = 0;
  double threshold = 3000,
      wait = 0,
      timeout = 10,
      quality = 75,
      resolution = 75;
  final name = TextEditingController();
  final su = TextEditingController(text: 'su');
  @override
  void dispose() {
    name.dispose();
    su.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsWorkspacePage(
    title: '显示与行为',
    onBack: () => Navigator.maybePop(context),
    body: SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DisplaySectionTitle('消息显示设置', Icons.message),
          DisplayBlock(
            children: [
              const DisplayTitle('折叠工具'),
              const SizedBox(height: 2),
              const DisplayDescription('设置消息中工具调用分组的默认折叠范围'),
              const SizedBox(height: 8),
              Text(
                collapseOptions[collapse],
                style: TextStyle(
                  fontSize: 12,
                  color: PrimaryColors.of(context).accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Slider(
                  value: collapse.toDouble(),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  onChanged: (v) => setState(() => collapse = v.round()),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => collapse = i),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            collapseOptions[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: collapse == i
                                  ? PrimaryColors.of(context).accent
                                  : PrimaryColors.of(context).secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: '全局用户名字',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: emptyAction,
                  tooltip: '保存',
                  icon: Icon(Icons.save_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DisplaySectionTitle('系统显示设置', Icons.settings_outlined),
          for (var i = 0; i < 9; i++) ...[
            toggle(i),
            if (i == 5 && toggles[5])
              DisplayBlock(
                children: [
                  const DisplayTitle('转换阈值'),
                  const DisplayDescription('粘贴文本超过此字符数时转为文件'),
                  DisplaySlider(
                    value: threshold,
                    min: 1000,
                    max: 100000,
                    divisions: 99,
                    label: '${threshold.round()} 字符',
                    onChanged: (v) =>
                        setState(() => threshold = (v / 1000).round() * 1000),
                  ),
                ],
              ),
          ],
          sliderBlock(
            'Visit Web 网页访问等待时间',
            '控制 visit_web 在提取页面内容后自动返回前的等待时长。设为 0 秒会立即返回。',
            wait,
            0,
            10,
            10,
            (v) => setState(() => wait = v.roundToDouble()),
          ),
          sliderBlock(
            '前置插件 Hook 超时',
            '限制发送路径上的 ToolPkg 聊天输入、Prompt 和摘要 Hook 链总等待时间。超时会跳过当前 Hook 并继续处理，默认 10 秒；不影响消息处理回复接管。',
            timeout,
            1,
            60,
            59,
            (v) => setState(() => timeout = v.roundToDouble()),
          ),
          const DisplaySectionTitle('自动化显示与行为', Icons.auto_awesome),
          for (var i = 9; i < options.length; i++) toggle(i),
          DisplayBlock(
            children: [
              const DisplayTitle('虚拟屏幕码率'),
              const SizedBox(height: 4),
              chips(
                ['1.5 Mbps', '3 Mbps', '5 Mbps', '10 Mbps', '20 Mbps'],
                bitrate,
                (i) => setState(() => bitrate = i),
              ),
            ],
          ),
          DisplayBlock(
            children: [
              const DisplayTitle('自动化状态指示样式'),
              const SizedBox(height: 4),
              chips(
                ['全屏彩虹边框', '顶部提示条'],
                indicator,
                (i) => setState(() => indicator = i),
              ),
            ],
          ),
          DisplayBlock(
            children: [
              const DisplayTitle('自动化截图设置'),
              const SizedBox(height: 8),
              const Text('图片格式', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              chips(
                ['PNG（无损，默认）', 'JPG（有损，体积更小）'],
                format,
                (i) => setState(() => format = i),
              ),
              const SizedBox(height: 12),
              const Text('画质（仅对 JPG 生效）', style: TextStyle(fontSize: 12)),
              DisplaySlider(
                value: quality,
                min: 50,
                max: 100,
                label: '${quality.round()}%',
                onChanged: (v) => setState(() => quality = v),
              ),
              const SizedBox(height: 12),
              const Text('分辨率缩放（发送前缩小截图）', style: TextStyle(fontSize: 12)),
              DisplaySlider(
                value: resolution,
                min: 50,
                max: 100,
                label: '${resolution.round()}%',
                onChanged: (v) => setState(() => resolution = v),
              ),
            ],
          ),
          if (widget.rootPreferred) ...[
            DisplayBlock(
              children: [
                const DisplayTitle('Root 执行模式'),
                const SizedBox(height: 2),
                const DisplayDescription('自动模式会按环境选择；手动模式可覆盖自动结果。'),
                const SizedBox(height: 8),
                chips(
                  ['自动选择', '手动 Magisk SU', '手动 KernelSU'],
                  rootMode,
                  (i) => setState(() => rootMode = i),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: su,
                  builder: (context, value, _) => TextField(
                    controller: su,
                    decoration: InputDecoration(
                      labelText: '自定义 su 命令（KernelSU 模式）',
                      helperText:
                          '仅在 KernelSU 模式生效，可填写 su 或 su --mount-master 等命令。',
                      helperMaxLines: 4,
                      border: const OutlineInputBorder(),
                      suffixIcon: value.text.trim() == 'su'
                          ? null
                          : const IconButton(
                              onPressed: emptyAction,
                              tooltip: '保存',
                              icon: Icon(Icons.save_outlined),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onSecondaryContainer,
            ),
            onPressed: emptyAction,
            icon: const Icon(Icons.restart_alt, size: 20),
            label: const Text('重置所有显示设置', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  Widget toggle(int i) => DisplayBlock(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DisplayTitle(options[i].$1),
                DisplayDescription(options[i].$2),
              ],
            ),
          ),
          Switch(
            value: toggles[i],
            onChanged: (v) => setState(() => toggles[i] = v),
          ),
        ],
      ),
    ],
  );
  Widget chips(List<String> labels, int selected, ValueChanged<int> onSelect) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            FilterChip(
              label: Text(labels[i]),
              selected: selected == i,
              onSelected: (_) => onSelect(i),
            ),
        ],
      );
  Widget sliderBlock(
    String title,
    String description,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) => DisplayBlock(
    children: [
      DisplayTitle(title),
      const SizedBox(height: 2),
      DisplayDescription(description),
      const SizedBox(height: 8),
      DisplaySlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.round()} 秒',
        onChanged: onChanged,
      ),
    ],
  );
}
