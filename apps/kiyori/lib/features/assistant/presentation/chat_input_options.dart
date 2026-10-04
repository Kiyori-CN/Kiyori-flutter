import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_dialogs.dart';
import 'chat_model_popup.dart';
import 'chat_memory_folders.dart';
import 'chat_info_popup.dart';
import 'chat_option_toggle.dart';

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
  });
  final ChatController owner;
  final bool attachments;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  final VoidCallback? onMemory, onTools, onModels;
  @override
  State<_InputOptions> createState() => _InputOptionsState();
}

class _InputOptionsState extends State<_InputOptions> {
  final expanded = <String>{};
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
                      for (final item in <(IconData, String)>[
                        (Icons.image_outlined, '图片'),
                        (Icons.photo_camera_outlined, '拍照'),
                        (Icons.memory, '记忆'),
                        (Icons.description_outlined, '文件'),
                        (Icons.screenshot_monitor, '屏幕内容'),
                        (Icons.notifications_outlined, '通知'),
                        (Icons.location_on_outlined, '位置'),
                        (Icons.auto_awesome_outlined, '工具包'),
                      ])
                        InkWell(
                          onTap: () => item.$2 == '记忆'
                              ? memoryFolders()
                              : item.$2 == '工具包'
                              ? showPackages()
                              : info(
                                  item.$2,
                                  '${item.$2}附件的设备读取与发送尚未接入。当前草稿保持不变。',
                                ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(item.$1, size: 16),
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
    route.navigator?.removeRoute(route);
  }

  Future<void> showPackages() => showDialog<void>(
    context: context,
    builder: (context) {
      widget.onRoute?.call(ModalRoute.of(context)!);
      return AlertDialog(
        title: const Text('选择工具包'),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: '搜索工具包、技能或 MCP',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              SizedBox(height: 24),
              Text('暂无可用工具包'),
            ],
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
