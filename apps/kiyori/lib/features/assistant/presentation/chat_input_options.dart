import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_dialogs.dart';
import 'chat_model_popup.dart';
import 'chat_memory_folders.dart';
import 'chat_info_popup.dart';
import 'chat_option_toggle.dart';

const _attachmentItems = <(IconData, String, IconTone)>[
  (Icons.image_outlined, '照片', IconTone.image),
  (Icons.photo_camera_outlined, '拍照', IconTone.image),
  (Icons.memory, '记忆', IconTone.memory),
  (Icons.description_outlined, '文件', IconTone.document),
  (Icons.screenshot_monitor, '屏幕内容', IconTone.image),
  (Icons.notifications_outlined, '当前通知', IconTone.warning),
  (Icons.location_on_outlined, '当前位置', IconTone.neutral),
  (Icons.auto_awesome_outlined, '包', IconTone.ai),
];

/// CLASSIC的附件是输入行之后的内联面板，与AGENT弹卡共享动作及状态边界。
class ChatClassicAttachments extends StatefulWidget {
  const ChatClassicAttachments({
    required this.owner,
    required this.visible,
    required this.onDismiss,
    this.onRoute,
    super.key,
  });
  final ChatController owner;
  final bool visible;
  final VoidCallback onDismiss;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  @override
  State<ChatClassicAttachments> createState() => _ClassicAttachmentsState();
}

class _ClassicAttachmentsState extends State<ChatClassicAttachments>
    with TickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.visible ? 1 : 0,
  );
  late final fade = AnimationController(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  @override
  void didUpdateWidget(ChatClassicAttachments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      final target = widget.visible ? 1.0 : 0.0;
      animation.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
      );
      // Compose的tween(200)尺寸变化与fadeIn/fadeOut默认弹簧分别驱动。
      fade.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 400, damping: 40),
          fade.value,
          target,
          fade.velocity,
          tolerance: const Tolerance(distance: .01, velocity: .625),
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    animation.dispose();
    fade.dispose();
    super.dispose();
  }

  Future<void> attachMemory() async {
    final owner = widget.owner;
    final id = owner.draftId;
    final route = ModalRoute.of(context)!;
    final selection = showChatMemoryFolders(
      context,
      owner,
      onRoute: widget.onRoute,
    );
    // 旧面板在打开选择器时收起。回调由常驻宿主持有，不能随折叠内容释放。
    widget.onDismiss();
    final paths = await selection;
    if (!mounted ||
        widget.owner != owner ||
        !route.isActive ||
        owner.draftId != id ||
        paths == null) {
      return;
    }
    owner.attachMemoryFolders(paths);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([animation, fade]),
    builder: (context, _) => ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: animation.value,
        child: Opacity(
          opacity: fade.value,
          child: !widget.visible && animation.value == 0 && fade.value == 0
              ? const SizedBox(width: double.infinity)
              : _InputOptions(
                  owner: widget.owner,
                  attachments: true,
                  inline: true,
                  onDismiss: widget.onDismiss,
                  onAttachMemory: attachMemory,
                  onRoute: widget.onRoute,
                ),
        ),
      ),
    ),
  );
}

Future<void> showChatInputOptions(
  BuildContext context,
  ChatController owner, {
  bool attachments = false,
  ValueChanged<ModalRoute<dynamic>>? onRoute,
  VoidCallback? onMemory,
  VoidCallback? onTools,
  VoidCallback? onModels,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: attachments ? '关闭附件' : '关闭设置选项',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, _, _) {
    onRoute?.call(ModalRoute.of(context)!);
    return _InputOptions(
      owner: owner,
      attachments: attachments,
      onRoute: onRoute,
      onMemory: onMemory,
      onTools: onTools,
      onModels: onModels,
    );
  },
);

class _InputOptions extends StatefulWidget {
  const _InputOptions({
    required this.owner,
    required this.attachments,
    this.onRoute,
    this.onMemory,
    this.onTools,
    this.onModels,
    this.inline = false,
    this.onDismiss,
    this.onAttachMemory,
  });
  final ChatController owner;
  final bool attachments;
  final bool inline;
  final VoidCallback? onDismiss;
  final VoidCallback? onAttachMemory;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  final VoidCallback? onMemory, onTools, onModels;
  @override
  State<_InputOptions> createState() => _InputOptionsState();
}

class _InputOptionsState extends State<_InputOptions> {
  final expanded = <String>{};
  void attachmentAction(String name) {
    if (name == '记忆') {
      if (widget.onAttachMemory != null) {
        widget.onAttachMemory!();
      } else {
        memoryFolders();
      }
    } else if (name == '包') {
      showPackages();
    } else {
      info(name, '$name附件的设备读取与发送尚未接入。当前草稿保持不变。');
    }
  }

  Widget inlineAttachments(BuildContext context) => Material(
    key: const Key('chat-classic-attachments'),
    color: Theme.of(context).colorScheme.surface,
    elevation: 1,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .1),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final item in _attachmentItems.skip(row * 4).take(4))
                      InkWell(
                        onTap: () => attachmentAction(item.$2),
                        child: SizedBox(
                          width: 70,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: item.$3.containerFor(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.$1,
                                    size: 24,
                                    color: item.$3.iconFor(context),
                                    semanticLabel: item.$2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 20 / 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
  Future<void> info(String title, String description) =>
      showChatInfoPopup(context, title, description, onRoute: widget.onRoute);

  Widget group(
    String title,
    String value,
    IconData icon,
    String description,
    List<Widget> children,
  ) => Column(
    children: [
      InkWell(
        onTap: () => setState(
          () => expanded.contains(title)
              ? expanded.remove(title)
              : expanded.add(title),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: .7),
              ),
              IconButton(
                tooltip: '$title说明',
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                iconSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: .7),
                onPressed: () => info(title, description),
                icon: const Icon(Icons.info_outline),
              ),
              const SizedBox(width: 8),
              Text(
                title == '记忆' || title == '模型' ? '$title:' : title,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                expanded.contains(title)
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: .7),
              ),
            ],
          ),
        ),
      ),
      if (expanded.contains(title))
        Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .5),
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: title == '记忆' || title == '工具' ? 8 : 0,
          ),
          child: Column(children: children),
        ),
    ],
  );

  Widget toggle(String title, String key, bool value, String description) =>
      ChatOptionToggle(
        title: title,
        icon: switch (key) {
          'memory_auto' => Icons.save_outlined,
          'disable_preferences' => Icons.data_object,
          'disable_stream' => value ? Icons.block : Icons.speed,
          _ => value ? Icons.volume_up_outlined : Icons.volume_off_outlined,
        },
        value: value,
        onInfo: () => info(title, description),
        onChanged: (v) => widget.owner.setPreference(key, '$v'),
      );

  Widget manage(String title, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
  );

  Widget permission(String value, String label, String selected) {
    final c = Theme.of(context).colorScheme;
    final active = value == selected;
    return Expanded(
      child: Material(
        color: active ? c.primary : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? c.primary : c.outline.withValues(alpha: .65),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.owner.setPreference('permission', value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? c.onPrimary : c.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.owner,
    builder: (context, _) {
      final p = widget.owner.preferences;
      if (widget.inline) return inlineAttachments(context);
      final classic = p?.inputStyle == 'classic' && !widget.attachments;
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(
            right: 12,
            left: 8,
            bottom:
                (classic ? 76 : 44) +
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: Material(
            key: Key(
              widget.attachments ? 'chat-attachments' : 'chat-input-options',
            ),
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.attachments
                    ? 200
                    : classic
                    ? 280
                    : 300,
                maxHeight: 420,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.attachments)
                      for (final item in _attachmentItems)
                        InkWell(
                          onTap: () => attachmentAction(item.$2),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.$1,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: .7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.$2,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                    else ...[
                      group(
                        '记忆',
                        widget.owner.knowledge?.spaces
                                .where(
                                  (space) =>
                                      space.id ==
                                      (widget
                                              .owner
                                              .character
                                              ?.draft
                                              .memorySpace ??
                                          widget.owner.knowledge?.activeSpace),
                                )
                                .firstOrNull
                                ?.name ??
                            '未选择',
                        Icons.data_object,
                        '选择当前对话使用的独立记忆空间',
                        [
                          for (final space
                              in widget.owner.knowledge?.spaces ?? [])
                            InkWell(
                              onTap: () async {
                                final selected =
                                    widget.owner.character?.draft.memorySpace ??
                                    widget.owner.knowledge?.activeSpace;
                                if (selected == space.id) return;
                                if (widget.owner.character?.draft.memorySpace !=
                                        null &&
                                    !await confirmChatAction(
                                      context,
                                      '切换角色卡绑定的记忆？',
                                      '这会修改当前角色卡使用的记忆配置。',
                                      onRoute: widget.onRoute,
                                    )) {
                                  return;
                                }
                                if (!context.mounted) return;
                                final route = ModalRoute.of(context)!;
                                if (await widget.owner.chooseMemory(space.id) &&
                                    route.isActive) {
                                  route.navigator?.removeRoute(route);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color:
                                      (widget
                                                  .owner
                                                  .character
                                                  ?.draft
                                                  .memorySpace ??
                                              widget
                                                  .owner
                                                  .knowledge
                                                  ?.activeSpace) ==
                                          space.id
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .1)
                                      : Colors.transparent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  space.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        (widget
                                                    .owner
                                                    .character
                                                    ?.draft
                                                    .memorySpace ??
                                                widget
                                                    .owner
                                                    .knowledge
                                                    ?.activeSpace) ==
                                            space.id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color:
                                        (widget
                                                    .owner
                                                    .character
                                                    ?.draft
                                                    .memorySpace ??
                                                widget
                                                    .owner
                                                    .knowledge
                                                    ?.activeSpace) ==
                                            space.id
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                  ),
                                ),
                              ),
                            ),
                          manage('管理配置', () {
                            Navigator.pop(context);
                            widget.onMemory?.call();
                          }),
                          toggle(
                            '自动保存记忆',
                            'memory_auto',
                            p?.memoryAuto ?? true,
                            '记忆自动更新偏好；后台提取与定时任务尚未接入。',
                          ),
                          toggle(
                            '禁用用户偏好描述',
                            'disable_preferences',
                            p?.disablePreferences ?? false,
                            '禁用后，系统提示词中不再注入 user.md 用户资料',
                          ),
                          InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.save_outlined,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: .7),
                                  ),
                                  IconButton(
                                    tooltip: '手动触发记忆保存说明',
                                    constraints: const BoxConstraints.tightFor(
                                      width: 40,
                                      height: 40,
                                    ),
                                    onPressed: () => info(
                                      '手动触发记忆保存',
                                      '需要立即补存本次对话的有价值内容时，可手动触发记忆保存，直接写入长期记忆库。',
                                    ),
                                    icon: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .7),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      '手动触发记忆保存',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (classic)
                        group(
                          '模型',
                          widget.owner.modelName,
                          Icons.smart_toy_outlined,
                          '选择用于对话的模型、思考方式与上下文模式。',
                          [
                            ChatModelPopup(
                              owner: widget.owner,
                              embedded: true,
                              onManage: widget.onModels ?? () {},
                              onRoute: widget.onRoute,
                            ),
                          ],
                        ),
                      group(
                        '工具',
                        switch (p?.permission) {
                          'allow' => '允许',
                          'forbid' => '禁用',
                          _ => '询问',
                        },
                        Icons.security,
                        '用于控制 AI 工具调用时的全局默认策略：开启后，默认直接执行所有工具调用而不再弹出确认；你在“设置 - 工具权限管理”中为单个工具设置的例外规则仍然会优先生效。关闭后，默认对所有工具调用都弹出确认。',
                        [
                          Row(
                            children: [
                              Text(
                                '权限级别',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              permission(
                                'forbid',
                                '禁用',
                                p?.permission ?? 'ask',
                              ),
                              const SizedBox(width: 6),
                              permission('ask', '询问', p?.permission ?? 'ask'),
                              const SizedBox(width: 6),
                              permission('allow', '允许', p?.permission ?? 'ask'),
                            ],
                          ),
                          manage('管理工具', () {
                            Navigator.pop(context);
                            widget.onTools?.call();
                          }),
                        ],
                      ),
                      group(
                        '行为',
                        p?.disableStream == true ? '非流式' : '流式',
                        Icons.speed,
                        '禁用后，AI回复将一次性完整显示，而不是逐字流式显示',
                        [
                          toggle(
                            '禁用流式输出',
                            'disable_stream',
                            p?.disableStream ?? false,
                            '禁用后，AI回复将一次性完整显示，而不是逐字流式显示',
                          ),
                          toggle(
                            '自动朗读消息',
                            'auto_read',
                            p?.autoRead ?? false,
                            '启用后，AI回复会自动朗读',
                          ),
                        ],
                      ),
                      group('插件', '0/0', Icons.hub_outlined, '管理包', []),
                      if (widget.owner.error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            widget.owner.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Future<void> memoryFolders() async {
    final route = ModalRoute.of(context)!;
    final owner = widget.owner;
    final id = owner.draftId;
    final paths = await showChatMemoryFolders(
      context,
      owner,
      onRoute: widget.onRoute,
    );
    if (!mounted || !route.isActive || id != owner.draftId || paths == null) {
      return;
    }
    owner.attachMemoryFolders(paths);
    if (widget.inline) {
      widget.onDismiss?.call();
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> showPackages() => showDialog<void>(
    context: context,
    builder: (context) {
      widget.onRoute?.call(ModalRoute.of(context)!);
      return AlertDialog(
        title: const Text(
          '选择包',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            '暂无可用包',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}
