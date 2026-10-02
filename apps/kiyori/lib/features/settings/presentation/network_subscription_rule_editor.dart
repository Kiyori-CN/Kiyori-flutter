import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class NetworkSubscriptionRuleEditor extends StatefulWidget {
  const NetworkSubscriptionRuleEditor({
    required this.name,
    required this.index,
    required this.rule,
    this.busy = false,
    super.key,
  });
  final String name, rule;
  final int index;
  final bool busy;
  @override
  State<NetworkSubscriptionRuleEditor> createState() => _EditorState();
}

class _EditorState extends State<NetworkSubscriptionRuleEditor> {
  late final controller = TextEditingController(text: widget.rule);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        controller.text.trim().isNotEmpty &&
        !RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(controller.text);
    return AlertDialog(
      scrollable: true,
      title: const Text('编辑当前订阅规则'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.name} · 第 ${widget.index + 1} 条',
            style: TextStyle(
              fontSize: 12,
              color: PrimaryColors.of(context).secondary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Mihomo 规则',
              border: const OutlineInputBorder(),
              errorText: valid ? null : '',
              helperText: '保存时重新校验规则类型、匹配内容、目标和依赖；更新订阅会覆盖此编辑。',
              helperMaxLines: 4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: valid && !widget.busy ? emptyAction : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
