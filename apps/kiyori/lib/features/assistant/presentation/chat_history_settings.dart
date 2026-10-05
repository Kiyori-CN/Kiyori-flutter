import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'chat_controller.dart';
import 'chat_history_widgets.dart';

Future<void> showHistorySettings(
  BuildContext context,
  ChatController owner, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showKiyoriModalDrawer<void>(
  context,
  onRoute: onRoute,
  builder: (context, dismiss) => AnimatedBuilder(
    animation: owner,
    builder: (context, _) {
      final p = owner.preferences;
      final colors = Theme.of(context).colorScheme;
      Widget heading(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          color: colors.onSurfaceVariant,
        ),
      );
      Widget toggle(
        String title,
        String description,
        bool value,
        String key,
      ) => Semantics(
        label: '$title\n$description',
        toggled: value,
        enabled: !owner.savingPreference,
        excludeSemantics: true,
        onTap: owner.savingPreference
            ? null
            : () => owner.setPreference(key, '${!value}'),
        child: Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: owner.savingPreference
                ? null
                : () => owner.setPreference(key, '${!value}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 14, height: 20 / 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: (_) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return HistoryDrawer(
        title: '聊天记录设置',
        close: () => dismiss(),
        footer: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => dismiss(),
            child: const Text('完成'),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('显示模式'),
                const SizedBox(height: 8),
                for (final mode in [
                  ('character', '按角色卡分类', '角色卡-文件夹-对话三级分类'),
                  ('folder', '按文件夹分类', '显示为文件夹+对话（全部角色卡）'),
                  ('current', '仅显示当前角色卡', '仅显示当前角色卡下的文件夹和对话'),
                ]) ...[
                  Semantics(
                    label: '${mode.$2}\n${mode.$3}',
                    checked: p?.historyMode == mode.$1,
                    inMutuallyExclusiveGroup: true,
                    enabled: !owner.savingPreference,
                    excludeSemantics: true,
                    onTap: owner.savingPreference
                        ? null
                        : () => owner.setPreference('history_mode', mode.$1),
                    child: Material(
                      color: p?.historyMode == mode.$1
                          ? colors.secondaryContainer
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: owner.savingPreference
                            ? null
                            : () =>
                                  owner.setPreference('history_mode', mode.$1),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                          child: Row(
                            children: [
                              IgnorePointer(
                                child: RadioGroup<String>(
                                  groupValue: p?.historyMode,
                                  onChanged: (_) {},
                                  child: Radio<String>(
                                    value: mode.$1,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 20 / 14,
                                        fontWeight: p?.historyMode == mode.$1
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mode.$3,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 16 / 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Divider(
                  height: 9,
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
                const SizedBox(height: 8),
                heading('切换行为'),
                const SizedBox(height: 8),
                toggle(
                  '自动切换角色卡',
                  '切换对话时自动匹配绑定的角色卡',
                  p?.autoCharacter ?? false,
                  'auto_character',
                ),
                const SizedBox(height: 8),
                toggle(
                  '自动切换聊天',
                  '切换角色卡或群组时自动进入对应的最新对话，没有则创建',
                  p?.autoChat ?? false,
                  'auto_chat',
                ),
                if (owner.savingPreference)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (owner.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      owner.error!,
                      style: TextStyle(fontSize: 12, color: colors.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  ),
);
