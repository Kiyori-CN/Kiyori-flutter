import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

enum PlayerExperienceSection {
  subtitle('字幕样式'),
  audio('声音处理'),
  danmaku('弹幕设置'),
  controls('界面与播放');

  const PlayerExperienceSection(this.title);
  final String title;
}

/// 原 PlayerExperienceSettingsContent 的紧凑布局。只保留输入草稿与滑块预览；
/// 设置开关、选项和保存为空点击，不建立第二个播放器设置 owner。
class PlayerExperiencePage extends StatelessWidget {
  const PlayerExperiencePage({required this.section, super.key});
  final PlayerExperienceSection section;

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: section.title,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Theme(
          data: Theme.of(context).copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: 12, height: 17 / 12),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: 12, height: 17 / 12),
              ),
            ),
          ),
          child: _PanelColumn(
            children: switch (section) {
              PlayerExperienceSection.subtitle => [
                const _Section('文字与排版', 'ASS 默认保留原有排版；位图字幕不支持文字样式。'),
                const Text(
                  '字幕大小',
                  style: TextStyle(fontSize: 12, height: 17 / 12),
                ),
                const _Choices(['80%', '100%', '120%', '150%'], selected: 1),
                const _ValueSlider(
                  '垂直位置',
                  value: 95,
                  min: 0,
                  max: 100,
                  unit: '%',
                ),
                const _ValueSlider('描边', value: 2, min: 0, max: 5),
                const _Choices(['白色', '暖黄', '青色', '浅绿']),
                const _Section('字幕字体', '使用设备字库；ASS 需开启样式覆盖才改变字体'),
                const _Choices(['中文默认', '无衬线', '衬线', '等宽']),
                const _Toggle('粗体', '提高文字辨识度', false),
                const _Toggle('字幕背景', '在复杂画面上使用半透明深色背景', false),
                const _Toggle('覆盖 ASS 样式', '可能改变字幕作者设计的定位与效果', false),
                const _Toggle('优先中文字幕', '新视频按语言优先选择轨道', true),
                const _Toggle(
                  '同名字幕自动加载',
                  '仅限可直接访问路径的本地视频；系统文档 URI 请手动导入',
                  true,
                ),
                TextButton(
                  onPressed: emptyAction,
                  child: const Text('恢复默认字幕样式'),
                ),
              ],
              PlayerExperienceSection.audio => [
                const _Section('输出声道', '自动保持设备兼容的声道布局'),
                const _Choices(['自动', '立体声', '单声道']),
                const _Toggle('响度均衡', '减小对白与高音量片段之间的音量差', false),
                const _Toggle('音量增强', '提高播放增益；过高音量可能产生失真', false),
              ],
              PlayerExperienceSection.danmaku => [
                const _Toggle('显示弹幕', '为已加载的弹幕启用显示', true),
                const _ValueSlider(
                  '文字大小',
                  value: 22,
                  min: 12,
                  max: 36,
                  unit: ' sp',
                ),
                const _ValueSlider(
                  '不透明度',
                  value: 85,
                  min: 10,
                  max: 100,
                  unit: '%',
                ),
                const _ValueSlider(
                  '显示区域',
                  value: 50,
                  min: 25,
                  max: 100,
                  unit: '%',
                ),
                const _ValueSlider(
                  '滚动时长',
                  value: 8,
                  min: 4,
                  max: 16,
                  unit: ' 秒',
                ),
                const _Section('类型与过滤', '显示密集时优先保持行间不重叠'),
                const _Toggle('滚动弹幕', '从画面两侧滚动', true),
                const _Toggle('顶部弹幕', '固定显示在区域上方', true),
                const _Toggle('底部弹幕', '固定显示在区域下方', true),
                const _Toggle('相同内容去重', '五秒内相同内容只显示一次', true),
                const _BlockedWords(),
                TextButton(
                  onPressed: emptyAction,
                  child: const Text('恢复默认弹幕样式'),
                ),
              ],
              PlayerExperienceSection.controls => [
                const _Section('控制栏', '设置会同步到播放界面'),
                const _Toggle('显示时钟', '顶部状态信息', true),
                const _Toggle('显示电量', '顶部状态信息', true),
                const _Toggle('显示网速', '设备实时流量速率', true),
                const _Toggle('按钮背景', '为返回与旋转按钮增加柔和衬底', true),
                const _Toggle('常驻进度线', '隐藏控制栏后显示底部细线', false),
                const _ValueSlider(
                  '自动隐藏控制栏',
                  value: 4,
                  min: 2,
                  max: 10,
                  unit: ' 秒',
                ),
                const _Section('片头与片尾', '适用于有时长的视频；设为 0 关闭。只在新视频开始或到达结尾时触发。'),
                const _ValueSlider(
                  '跳过片头',
                  value: 0,
                  min: 0,
                  max: 300,
                  unit: ' 秒',
                ),
                const _ValueSlider(
                  '跳过片尾',
                  value: 0,
                  min: 0,
                  max: 300,
                  unit: ' 秒',
                ),
                const _Toggle('自动连播', '当前视频自然结束后播放下一项', true),
                const _Choices(['停留', '关闭', '单集循环'], selected: 1),
              ],
            },
          ),
        ),
      ),
    ],
  );
}

class _PanelColumn extends StatelessWidget {
  const _PanelColumn({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: children,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.detail);
  final String title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w500,
              color: PrimaryColors.of(context).accent,
            ),
          ),
        ),
        Text(
          detail,
          style: TextStyle(
            fontSize: 11,
            height: 15 / 11,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );
}

class _Choices extends StatelessWidget {
  const _Choices(this.options, {this.selected = 0});
  final List<String> options;
  final int selected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 2,
    children: [
      for (var i = 0; i < options.length; i++)
        FilterChip(
          label: Text(
            options[i],
            style: const TextStyle(fontSize: 12, height: 17 / 12),
          ),
          selected: i == selected,
          showCheckmark: false,
          onSelected: (_) {},
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
    ],
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.title, this.description, this.value);
  final String title, description;
  final bool value;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      child: InkWell(
        onTap: emptyAction,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13, height: 18 / 13),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          height: 15 / 11,
                          color: PrimaryColors.of(context).secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: .8,
                    child: Switch(
                      value: value,
                      onChanged: (_) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 原滑块在拖动时仅更新 draft，避免整个设置列表每帧重建。
class _ValueSlider extends StatefulWidget {
  const _ValueSlider(
    this.title, {
    required this.value,
    required this.min,
    required this.max,
    this.unit = '',
  });
  final String title, unit;
  final double value, min, max;
  @override
  State<_ValueSlider> createState() => _ValueSliderState();
}

class _ValueSliderState extends State<_ValueSlider> {
  late double draft = widget.value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 12, height: 17 / 12),
            ),
          ),
          Text(
            '${draft.toInt()}${widget.unit}',
            style: TextStyle(
              fontSize: 12,
              height: 17 / 12,
              color: PrimaryColors.of(context).accent,
            ),
          ),
        ],
      ),
      Slider(
        value: draft,
        min: widget.min,
        max: widget.max,
        label: widget.title,
        semanticFormatterCallback: (value) => '${value.toInt()}${widget.unit}',
        onChanged: (value) => setState(() => draft = value),
      ),
    ],
  );
}

class _BlockedWords extends StatefulWidget {
  const _BlockedWords();
  @override
  State<_BlockedWords> createState() => _BlockedWordsState();
}

class _BlockedWordsState extends State<_BlockedWords> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PanelColumn(
    children: [
      TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        style: const TextStyle(fontSize: 13, height: 18 / 13),
        inputFormatters: [LengthLimitingTextInputFormatter(4000)],
        decoration: const InputDecoration(
          labelText: '屏蔽词 · 每行一个',
          labelStyle: TextStyle(fontSize: 12),
          border: OutlineInputBorder(),
        ),
      ),
      ValueListenableBuilder(
        valueListenable: controller,
        builder: (_, value, _) => OutlinedButton(
          onPressed: value.text.isEmpty ? null : emptyAction,
          child: const Text('保存屏蔽词'),
        ),
      ),
    ],
  );
}
