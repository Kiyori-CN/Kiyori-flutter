import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'wakeup_presentation.dart';

class WakeEnrollmentDialog extends StatelessWidget {
  const WakeEnrollmentDialog({required this.snapshot, super.key});
  final WakeEnrollmentPresentation snapshot;
  @override
  Widget build(BuildContext context) {
    final busy = snapshot.recordingStep != 0;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('个人化唤醒配置'),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '请对唤醒词说三遍，系统会记录你的发音特征用于唤醒识别。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (snapshot.error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              for (var i = 1; i <= 3; i++) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('第$i遍')),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FilledButton(
                        onPressed: busy ? null : emptyAction,
                        child: Text(
                          snapshot.recordingStep == i
                              ? '录音中…'
                              : snapshot.completedSteps.contains(i)
                              ? '已录入'
                              : '开始录音',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed:
                !busy &&
                    const {1, 2, 3}.difference(snapshot.completedSteps).isEmpty
                ? emptyAction
                : null,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class WakeAttachmentDialog extends StatefulWidget {
  const WakeAttachmentDialog({required this.item, super.key});
  final WakeAttachmentPresentation item;
  @override
  State<WakeAttachmentDialog> createState() => _WakeAttachmentDialogState();
}

class _WakeAttachmentDialogState extends State<WakeAttachmentDialog> {
  late bool enabled = widget.item.enabled;
  late final keywords = TextEditingController(text: widget.item.keywords);
  @override
  void dispose() {
    keywords.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item.type.title),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('自动附加')),
              Switch(
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: keywords,
            decoration: InputDecoration(
              labelText: widget.item.type.keywordLabel,
              helperText: '多个用 | 或 , 分隔',
              helperMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除自动附加项'),
            content: Text('确定删除“${widget.item.type.title}”自动附加项吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: emptyAction,
                child: Text(
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
        child: const Text('删除'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(onPressed: emptyAction, child: const Text('保存')),
    ],
  );
}

class WakeAttachmentCreateDialog extends StatefulWidget {
  const WakeAttachmentCreateDialog({required this.types, super.key});
  final List<WakeAttachmentType> types;
  @override
  State<WakeAttachmentCreateDialog> createState() =>
      _WakeAttachmentCreateDialogState();
}

class _WakeAttachmentCreateDialogState
    extends State<WakeAttachmentCreateDialog> {
  late WakeAttachmentType? selected = widget.types.firstOrNull;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('添加附件项'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: DropdownButtonFormField<WakeAttachmentType>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '类型',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: [
          for (final type in widget.types)
            DropdownMenuItem(value: type, child: Text(type.title)),
        ],
        onChanged: (v) => setState(() => selected = v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: selected == null ? null : emptyAction,
        child: const Text('确定'),
      ),
    ],
  );
}
