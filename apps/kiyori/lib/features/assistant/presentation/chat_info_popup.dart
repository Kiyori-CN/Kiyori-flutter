import 'package:flutter/material.dart';

/// AgentInfoPopup：说明在输入栏上方右对齐，不使用居中确认对话框。
Future<void> showChatInfoPopup(
  BuildContext context,
  String title,
  String text, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭说明',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, _, _) {
    onRoute?.call(ModalRoute.of(context)!);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 52 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            key: const Key('chat-info-popup'),
            elevation: 3,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 220,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);
