import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_dialogs.dart';
import 'chat_model_popup.dart';
import 'chat_memory_folders.dart';

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
  Future<void> info(String title, String description) => showDialog<void>(
    context: context,
    builder: (context) {
      widget.onRoute?.call(ModalRoute.of(context)!);
      return AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );

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
              Icon(icon, size: 16),
              IconButton(
                tooltip: '$title说明',
                iconSize: 16,
                onPressed: () => info(title, description),
                icon: const Icon(Icons.info_outline),
              ),
              Text('$title:', style: const TextStyle(fontSize: 13)),
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
              ),
            ],
          ),
        ),
      ),
      if (expanded.contains(title))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
    ],
  );

  Widget toggle(String title, String key, bool value, String description) =>
      Row(
        children: [
          IconButton(
            tooltip: '$title说明',
            iconSize: 16,
            onPressed: () => info(title, description),
            icon: const Icon(Icons.info_outline),
          ),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          Switch(
            value: value,
            onChanged: (v) => widget.owner.setPreference(key, '$v'),
          ),
        ],
      );

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
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                        Icons.memory,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  space.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          toggle(
                            '自动更新记忆',
                            'memory_auto',
                            p?.memoryAuto ?? true,
                            '记忆自动更新偏好；后台提取与定时任务尚未接入。',
                          ),
                          toggle(
                            '禁用用户偏好描述',
                            'disable_preferences',
                            p?.disablePreferences ?? false,
                            '控制记忆中的用户偏好描述；当前文字请求未注入记忆内容。',
                          ),
                          TextButton(
                            onPressed: () =>
                                info('手动更新记忆', '当前版本尚未接入对话记忆提取，原始消息保持不变。'),
                            child: const Text('手动更新记忆'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onMemory?.call();
                            },
                            child: const Text('管理记忆'),
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
                        '控制工具调用的默认权限；当前基本文字聊天尚未执行工具。',
                        [
                          Row(
                            children: [
                              const Text('权限', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              for (final entry in [
                                ('forbid', '禁用'),
                                ('ask', '询问'),
                                ('allow', '允许'),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(
                                        entry.$2,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      showCheckmark: false,
                                      selected: p?.permission == entry.$1,
                                      onSelected: (_) =>
                                          widget.owner.setPreference(
                                            'permission',
                                            entry.$1,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onTools?.call();
                            },
                            child: const Text('管理工具'),
                          ),
                        ],
                      ),
                      group(
                        '行为',
                        p?.disableStream == true ? '非流式' : '流式',
                        Icons.speed,
                        '控制回复显示与自动朗读。',
                        [
                          toggle(
                            '禁用流式输出',
                            'disable_stream',
                            p?.disableStream ?? false,
                            '开启后等待完整回复再显示；完成前停止会取消等待。',
                          ),
                          toggle(
                            '自动朗读消息',
                            'auto_read',
                            p?.autoRead ?? false,
                            '启用后AI回复自动朗读；当前语音播放能力尚未接入。',
                          ),
                        ],
                      ),
                      group(
                        '插件',
                        '0/0',
                        Icons.hub_outlined,
                        '插件可以向输入菜单注册附加开关。',
                        [],
                      ),
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
