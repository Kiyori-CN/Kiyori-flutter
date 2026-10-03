import 'package:flutter/material.dart';

/// FullscreenInputDialog：关闭与系统返回均保留草稿，确认只结束编辑，不发送。
class ChatFullscreenInput extends StatefulWidget {
  const ChatFullscreenInput({
    required this.initial,
    required this.onChanged,
    super.key,
  });
  final TextEditingValue initial;
  final ValueChanged<TextEditingValue> onChanged;

  @override
  State<ChatFullscreenInput> createState() => _ChatFullscreenInputState();
}

class _ChatFullscreenInputState extends State<ChatFullscreenInput> {
  late final editor = TextEditingController.fromValue(widget.initial);

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '全屏输入',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '保存',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TextField(
                key: const Key('chat-fullscreen-draft'),
                controller: editor,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16, height: 1.5),
                onChanged: (_) => widget.onChanged(editor.value),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
