import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'appearance_bubble_editors.dart';
import 'appearance_chat_details.dart';
import 'appearance_color_picker.dart';
import 'appearance_components.dart';
import 'appearance_interface.dart';
import 'appearance_media_presentation.dart';
import 'appearance_nine_slice.dart';

class AppearanceChat extends StatefulWidget {
  const AppearanceChat({
    this.snapshot = const AppearanceMediaPresentation(),
    this.persistedBubble,
    this.onBubble,
    super.key,
  });
  final AppearanceMediaPresentation snapshot;
  final bool? persistedBubble;
  final Future<bool> Function(bool)? onBubble;
  @override
  State<AppearanceChat> createState() => _AppearanceChatState();
}

class _AppearanceChatState extends State<AppearanceChat> {
  bool bubble = false,
      follow = true,
      avatars = true,
      wide = false,
      tiled = true;
  final glass = [false, false, false, false, false, false];
  final rounded = [true, true];
  final fonts = [BubbleFontDraft(), BubbleFontDraft()];
  final images = [BubbleImageDraft(), BubbleImageDraft()];
  @override
  void initState() {
    super.initState();
    bubble = widget.persistedBubble ?? widget.snapshot.bubble;
    tiled = widget.snapshot.tiled;
    images[0].read(widget.snapshot.userBubble);
    images[1].read(widget.snapshot.aiBubble);
    fonts[0].read(widget.snapshot.userFont);
    fonts[1].read(widget.snapshot.aiFont);
  }

  @override
  void didUpdateWidget(covariant AppearanceChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.snapshot;
    final next = widget.snapshot;
    if (!old.userBubble.sameSettings(next.userBubble)) {
      images[0].read(next.userBubble);
    } else {
      images[0].media = next.userBubble.media;
    }
    if (!old.aiBubble.sameSettings(next.aiBubble)) {
      images[1].read(next.aiBubble);
    } else {
      images[1].media = next.aiBubble.media;
    }
    if (old.bubble != next.bubble) bubble = next.bubble;
    if (widget.persistedBubble != null) bubble = widget.persistedBubble!;
    if (old.tiled != next.tiled) tiled = next.tiled;
    if (!old.userFont.sameSettings(next.userFont)) {
      fonts[0].read(next.userFont);
    } else {
      fonts[0].registeredFamily = next.userFont.family;
    }
    if (!old.aiFont.sameSettings(next.aiFont)) {
      fonts[1].read(next.aiFont);
    } else {
      fonts[1].registeredFamily = next.aiFont.family;
    }
  }

  void refreshDraft() => setState(() {});
  Future<void> chooseBubble(bool value) async {
    if (widget.onBubble != null && !await widget.onBubble!(value)) return;
    if (mounted) setState(() => bubble = value);
  }

  final colors = [
    const Color(0xFFD8ECFF),
    const Color(0xFFD8ECFF),
    Colors.white,
    const Color(0xFF12324A),
    PrimaryColors.text,
  ];
  static const colorTitles = ['命令式用户消息框', '用户气泡', 'AI气泡', '用户文字', 'AI文字'];
  static const pickerTitles = [
    '选择命令式用户消息框颜色',
    '选择对话式用户气泡颜色',
    '选择对话式AI气泡颜色',
    '选择对话式用户文字颜色',
    '选择对话式AI文字颜色',
  ];
  Future<void> pick(int index) async {
    final value = await showDialog<Color>(
      context: context,
      builder: (_) => AppearanceColorPicker(
        title: pickerTitles[index],
        initial: colors[index],
      ),
    );
    if (mounted && value != null) setState(() => colors[index] = value);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppearanceSectionTitle(
        '聊天风格',
        Icons.color_lens,
        IconTone.appearance,
      ),
      AppearanceCard(
        children: [
          const Text(
            '选择聊天界面风格',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppearanceChoice(
                  '命令框',
                  selected: !bubble,
                  onTap: () => chooseBubble(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppearanceChoice(
                  '对话框',
                  selected: bubble,
                  onTap: () => chooseBubble(true),
                ),
              ),
            ],
          ),
          const AppearanceDivider(),
          if (!bubble) ...[
            AppearanceSwitch(
              '命令式用户消息框跟随主题色',
              '关闭后可自定义命令式用户消息框颜色（支持透明度）',
              value: follow,
              onChanged: (v) => setState(() => follow = v),
            ),
            const AppearanceDivider(),
            _glass(0, '命令式用户消息磨砂玻璃背景', '开启后，命令式用户消息背景会显示 iOS 风格磨砂玻璃效果'),
            const AppearanceDivider(),
            _glass(1, '命令式用户消息水玻璃背景', '开启后，命令式用户消息背景会显示水玻璃效果'),
            if (!follow)
              Padding(padding: const EdgeInsets.only(top: 8), child: _color(0)),
          ] else ...[
            AppearanceSwitch(
              '显示头像',
              '在气泡式聊天中显示用户和 AI 的头像',
              value: avatars,
              onChanged: (v) => setState(() => avatars = v),
            ),
            const AppearanceDivider(),
            AppearanceSwitch(
              '更宽的气泡',
              '打开后，气泡会显示在头像下方，角色名与头像同一水平线显示，从而获得更大的消息展示空间',
              value: wide,
              onChanged: (v) => setState(() => wide = v),
            ),
            const AppearanceDivider(),
            _glass(2, '气泡式用户消息磨砂玻璃背景', '开启后，气泡式用户消息背景会显示 iOS 风格磨砂玻璃效果'),
            const AppearanceDivider(),
            _glass(3, '气泡式用户消息水玻璃背景', '开启后，气泡式用户消息背景会显示水玻璃效果'),
            const AppearanceDivider(),
            _glass(4, '气泡式AI消息磨砂玻璃背景', '开启后，气泡式AI消息背景会显示 iOS 风格磨砂玻璃效果'),
            const AppearanceDivider(),
            _glass(5, '气泡式AI消息水玻璃背景', '开启后，气泡式AI消息背景会显示水玻璃效果'),
            const AppearanceDivider(),
            const Text('图片气泡渲染模式', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            const AppearanceDescription('可选择 .9 拉伸模式或九宫格平铺模式'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppearanceChoice(
                    '.9模式',
                    selected: !tiled,
                    onTap: () => setState(() => tiled = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppearanceChoice(
                    '九宫格平铺',
                    selected: tiled,
                    onTap: () => setState(() => tiled = true),
                  ),
                ),
              ],
            ),
            const AppearanceDivider(),
            const Text('启用圆角气泡', style: TextStyle(fontSize: 14)),
            const AppearanceDescription('关闭后消息气泡使用直角矩形'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 240 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18;
                final controls = [
                  for (var i = 0; i < 2; i++)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          i == 0 ? '用户' : 'AI',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Switch(
                          value: rounded[i],
                          onChanged: (v) => setState(() => rounded[i] = v),
                        ),
                      ],
                    ),
                ];
                return stacked
                    ? Column(children: controls)
                    : Row(
                        children: [
                          Expanded(child: controls[0]),
                          const SizedBox(width: 12),
                          Expanded(child: controls[1]),
                        ],
                      );
              },
            ),
            const AppearanceDivider(),
            const Text('对话式气泡颜色', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _color(1)),
                const SizedBox(width: 12),
                Expanded(child: _color(2)),
              ],
            ),
            const AppearanceDivider(),
            const Text('对话式文字样式', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _color(3)),
                const SizedBox(width: 12),
                Expanded(child: _color(4)),
              ],
            ),
            for (var i = 0; i < 2; i++)
              AppearanceBubbleFont(
                i == 0 ? '用户字体' : 'AI字体',
                draft: fonts[i],
                onChanged: refreshDraft,
              ),
            for (var i = 0; i < 2; i++) ...[
              AppearanceBubbleImage(
                i == 0 ? '用户气泡图片' : 'AI气泡图片',
                available: !glass[2 + i * 2] && !glass[3 + i * 2],
                draft: images[i],
                onChanged: refreshDraft,
              ),
              if (images[i].enabled &&
                  images[i].media != null &&
                  !glass[2 + i * 2] &&
                  !glass[3 + i * 2])
                AppearanceSourceGrid(
                  title: i == 0 ? '用户原图九宫格预览' : 'AI原图九宫格预览',
                  image: images[i].media!.image,
                  values: images[i].values,
                ),
            ],
          ],
          const AppearanceDivider(),
          _preview(),
        ],
      ),
      AppearanceAvatars(snapshot: widget.snapshot.avatars),
      const AppearanceDisplayOptions(),
    ],
  );
  Widget _color(int index) => AppearanceColorSelection(
    title: colorTitles[index],
    color: colors[index],
    onTap: () => pick(index),
  );
  Widget _glass(int index, String title, String description) =>
      AppearanceSwitch(
        title,
        description,
        value: glass[index],
        onChanged: (v) => setState(() {
          glass[index] = v;
          if (v) glass[index.isEven ? index + 1 : index - 1] = false;
        }),
      );
  Widget _preview() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .25),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('样式预览', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        if (!bubble) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: follow ? const Color(0xFFD8ECFF) : colors[0],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '这是用户消息预览',
              style: TextStyle(fontSize: 14, color: Color(0xFF12324A)),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '响应',
                  style: TextStyle(
                    fontSize: 11,
                    color: PrimaryColors.of(context).secondary,
                  ),
                ),
                SizedBox(height: 4),
                Text('这是AI消息预览', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ] else ...[
          _bubblePreview(true),
          const SizedBox(height: 10),
          _bubblePreview(false),
        ],
      ],
    ),
  );
  Widget _bubblePreview(bool user) {
    final fontFamily = fonts[user ? 0 : 1].family(Theme.of(context).platform);
    final imageDraft = images[user ? 0 : 1];
    final image =
        imageDraft.enabled && !glass[user ? 2 : 4] && !glass[user ? 3 : 5]
        ? imageDraft.media?.image
        : null;
    final shape = rounded[user ? 0 : 1]
        ? BorderRadius.only(
            topLeft: Radius.circular(user ? 20 : 4),
            topRight: Radius.circular(user ? 4 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          )
        : BorderRadius.zero;
    final text = Text(
      user ? '这是用户消息预览' : '这是AI消息预览',
      style: TextStyle(
        fontSize: 14,
        color: colors[user ? 3 : 4],
        fontFamily: fontFamily,
      ),
    );
    final padding = EdgeInsets.fromLTRB(
      imageDraft.values[9],
      12,
      imageDraft.values[10],
      12,
    );
    final message = ClipRRect(
      borderRadius: shape,
      child: Container(
        key: ValueKey(
          user ? 'appearance-user-preview' : 'appearance-ai-preview',
        ),
        constraints: BoxConstraints(maxWidth: wide ? 280 : 240, minHeight: 44),
        color: image == null ? colors[user ? 1 : 2] : null,
        padding: image == null ? padding : null,
        child: image == null
            ? text
            : AppearanceNineSlice(
                image: image,
                values: List.of(imageDraft.values),
                tiled: tiled,
                child: Padding(padding: padding, child: text),
              ),
      ),
    );
    final avatarImage = user
        ? widget.snapshot.avatars.user ?? widget.snapshot.avatars.globalUser
        : widget.snapshot.avatars.ai;
    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: avatarImage == null
          ? Icon(
              Icons.person,
              size: 18,
              color: PrimaryColors.of(context).secondary,
            )
          : ClipOval(
              child: RawImage(
                image: avatarImage.image,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
    );
    if (wide) {
      return Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (avatars) ...[
            Row(
              mainAxisAlignment: user
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!user) ...[avatar, const SizedBox(width: 8)],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user ? '用户名称' : '角色名称',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: fontFamily,
                        ),
                      ),
                      if (!user) ...[
                        const SizedBox(height: 2),
                        Text(
                          '示例模型 by 示例供应商',
                          style: TextStyle(
                            fontSize: 11,
                            color: PrimaryColors.of(context).secondary
                                .withValues(alpha: .75),
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (user) ...[const SizedBox(width: 8), avatar],
              ],
            ),
            const SizedBox(height: 8),
          ],
          message,
        ],
      );
    }
    return Row(
      mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!user && avatars) ...[avatar, const SizedBox(width: 8)],
        Flexible(child: message),
        if (user && avatars) ...[const SizedBox(width: 8), avatar],
      ],
    );
  }
}
