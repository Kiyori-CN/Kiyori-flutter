import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showEmojiConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () {},
        style: danger
            ? TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              )
            : null,
        child: Text(action),
      ),
    ],
  ),
);

class CreateEmojiCategoryDialog extends StatefulWidget {
  const CreateEmojiCategoryDialog({super.key});
  @override
  State<CreateEmojiCategoryDialog> createState() =>
      _CreateEmojiCategoryDialogState();
}

class _CreateEmojiCategoryDialogState extends State<CreateEmojiCategoryDialog> {
  final name = TextEditingController();
  static final valid = RegExp(r'^[a-z0-9_]*$');
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: name,
    builder: (context, value, _) {
      final error = !valid.hasMatch(value.text);
      return AlertDialog(
        title: const Text('新建类别'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('只能包含小写字母、数字和下划线'),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (_, value) => value.copyWith(text: value.text.toLowerCase()),
                ),
              ],
              decoration: InputDecoration(
                labelText: '类别名称',
                errorText: error ? '类别名称只能包含小写字母、数字和下划线' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: value.text.trim().isNotEmpty && !error ? () {} : null,
            child: const Text('创建'),
          ),
        ],
      );
    },
  );
}
