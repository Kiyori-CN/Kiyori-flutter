import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 旧ChatHeader的历史入口：数量是运行中的会话数，不是历史条目数。
class ChatHistoryButton extends StatelessWidget {
  const ChatHistoryButton({
    required this.runningCount,
    required this.expanded,
    required this.onTap,
    super.key,
  });
  final int runningCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = IconTone.browser.iconFor(context);
    final background = IconTone.browser.containerFor(context);
    final label = expanded ? '隐藏历史' : '显示历史';
    final radius = BorderRadius.circular(12);
    return Material(
      key: const Key('chat-history-button-surface'),
      color: expanded || runningCount >= 2 ? background : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: runningCount < 2
          ? ShellAction(
              Icons.history,
              label,
              size: 32,
              color: icon,
              onTap: onTap,
            )
          : Semantics(
              button: true,
              label: label,
              value: '$runningCount 个运行任务',
              onTap: onTap,
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: SizedBox(
                  height: 32,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 20, color: icon),
                        const SizedBox(width: 6),
                        Text(
                          '$runningCount',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            height: 16 / 11,
                            fontWeight: FontWeight.w600,
                            color: icon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
