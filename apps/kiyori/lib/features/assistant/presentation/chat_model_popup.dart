import 'package:flutter/material.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';

import 'chat_controller.dart';
import 'chat_dialogs.dart';
import 'chat_info_popup.dart';
import 'chat_option_toggle.dart';

/// AGENT 输入栏弹出卡：透明宿主、右下300宽、420最大高。
class ChatModelPopup extends StatefulWidget {
  const ChatModelPopup({
    required this.owner,
    required this.onManage,
    this.onRoute,
    this.embedded = false,
    super.key,
  });
  final ChatController owner;
  final VoidCallback onManage;
  final ValueChanged<ModalRoute<dynamic>>? onRoute;
  final bool embedded;
  @override
  State<ChatModelPopup> createState() => _ChatModelPopupState();
}

class _ChatModelPopupState extends State<ChatModelPopup> {
  String? expanded;
  bool selecting = false;
  bool thinkingExpanded = false;
  double? quality;
  bool qualitySaving = false;
  Future<void> choose(ModelConfig config, String model) async {
    if (selecting || widget.owner.changing) return;
    final route = ModalRoute.of(context)!;
    final character = widget.owner.character?.id;
    selecting = true;
    try {
      if (widget.owner.character?.draft.modelConfig != null &&
          !await confirmChatAction(
            context,
            '修改角色绑定模型？',
            '此角色将使用所选模型配置。',
            onRoute: widget.onRoute,
          )) {
        return;
      }
      if (!mounted ||
          !route.isActive ||
          character != widget.owner.character?.id) {
        return;
      }
      await widget.owner.chooseModel(config.id, model);
      if (mounted && route.isActive && widget.owner.error == null) {
        route.navigator?.removeRoute(route);
      }
    } finally {
      selecting = false;
    }
  }

  Future<void> info(String title, String detail) =>
      showChatInfoPopup(context, title, detail, onRoute: widget.onRoute);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.owner,
    builder: (context, _) {
      final owner = widget.owner;
      final colors = Theme.of(context).colorScheme;
      final config = owner.modelConfig;
      return host(
        context,
        colors,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => thinkingExpanded = !thinkingExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: .7),
                    ),
                    IconButton(
                      tooltip: '思考设置说明',
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      iconSize: 16,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colors.onSurfaceVariant.withValues(
                          alpha: .7,
                        ),
                      ),
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => info(
                        '思考设置',
                        '统一管理模型推理开关和思考程度。具体支持能力由当前供应商、API 协议和模型决定；Kiyori Flutter 只发送该模型合同允许的参数。',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('思考:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        owner.preferences?.thinking == true ? 'mode' : 'off',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    Icon(
                      thinkingExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (thinkingExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ChatOptionToggle(
                      title: '思考模式',
                      icon: Icons.psychology_outlined,
                      horizontalPadding: 8,
                      value: owner.preferences?.thinking ?? false,
                      onChanged: owner.savingPreference
                          ? null
                          : (v) => owner.setPreference('thinking', '$v'),
                      onInfo: () => info('思考模式', '开启后请求模型推理；具体支持由供应商、协议和模型决定。'),
                    ),
                    if (owner.preferences?.thinking == true) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Text('思考程度', style: TextStyle(fontSize: 13)),
                          ),
                          Text(
                            ['低', '中', '高', '极高', '最高'][(quality?.round() ??
                                    owner.preferences?.thinkingQuality ??
                                    2) -
                                1],
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: 1,
                        max: 5,
                        divisions: 4,
                        value:
                            quality ??
                            (owner.preferences?.thinkingQuality ?? 2)
                                .toDouble(),
                        onChanged: !owner.savingPreference && !qualitySaving
                            ? (v) => setState(() => quality = v)
                            : null,
                        onChangeEnd: !owner.savingPreference && !qualitySaving
                            ? (v) async {
                                setState(() => qualitySaving = true);
                                await owner.setPreference(
                                  'thinking_quality',
                                  '${v.round()}',
                                );
                                if (mounted) {
                                  setState(() {
                                    qualitySaving = false;
                                    quality = null;
                                  });
                                }
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            if (owner.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  owner.error!,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ChatOptionToggle(
              title: 'Max模式',
              icon: Icons.whatshot_outlined,
              onInfo: () => info(
                'MAX模式',
                'Max Mode（超大上下文模式）开启后将使用 ${config?.draft.options.maxContextLength ?? 200}k 上下文窗口，关闭则回到 ${config?.draft.options.contextLength ?? 64}k。您可以在设置中自定义这些数值。',
              ),
              value: config?.draft.options.maxContextMode ?? false,
              onChanged: config == null || owner.changing
                  ? null
                  : owner.setMaxContext,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.data_object, size: 16),
                  IconButton(
                    tooltip: '模型说明',
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    iconSize: 16,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colors.onSurfaceVariant.withValues(
                        alpha: .7,
                      ),
                    ),
                    onPressed: () =>
                        info('模型配置', '在这里选择一个已经配置好的模型，或者点击下方的管理配置去新建或修改模型'),
                    icon: const Icon(Icons.info_outline),
                  ),
                  const SizedBox(width: 8),
                  const Text('模型:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      owner.modelName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  if (owner.models?.configs.isEmpty ?? true)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('没有可用的模型', style: TextStyle(fontSize: 12)),
                    ),
                  for (final item
                      in owner.models?.configs ?? <ModelConfig>[]) ...[
                    Material(
                      color: owner.modelConfigId == item.id
                          ? colors.primary.withValues(alpha: .1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: () {
                          if (item.draft.models.length > 1) {
                            setState(
                              () => expanded = expanded == item.id
                                  ? null
                                  : item.id,
                            );
                          } else if (item.draft.models.isNotEmpty) {
                            choose(item, item.draft.models.single);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.draft.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: owner.modelConfigId == item.id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: owner.modelConfigId == item.id
                                        ? colors.primary
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (item.draft.models.length > 1) ...[
                                Text(
                                  '${item.draft.models.length} 个模型',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                Icon(
                                  expanded == item.id
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                ),
                              ] else
                                Flexible(
                                  child: Text(
                                    item.draft.models.firstOrNull ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (expanded == item.id)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final model in item.draft.models)
                              Material(
                                color:
                                    owner.modelConfigId == item.id &&
                                        owner.modelName == model
                                    ? colors.primary.withValues(alpha: .15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                child: InkWell(
                                  onTap: () => choose(item, model),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      model,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onManage();
                    },
                    child: const Text('管理配置', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget host(BuildContext context, ColorScheme colors, Widget content) {
    if (widget.embedded) return content;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: 12,
          left: 8,
          bottom:
              44 +
              MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: Material(
          key: const Key('chat-model-popup'),
          color: colors.surfaceContainerHigh,
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
