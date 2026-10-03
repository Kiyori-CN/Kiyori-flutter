import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:kiyori_ui/kiyori_ui.dart';

String chatPlainText(String source) {
  String plain(md.Node node) {
    if (node is md.Text) return node.text;
    final element = node as md.Element;
    if (element.tag == 'br') return '\n';
    if (element.tag == 'img') return element.attributes['alt'] ?? '';
    if (element.tag == 'input') {
      return element.attributes.containsKey('checked') ? '☑ ' : '☐ ';
    }
    final children = element.children ?? const <md.Node>[];
    return children.map(plain).join(switch (element.tag) {
      'ul' || 'ol' || 'table' || 'thead' || 'tbody' => '\n',
      'tr' => '\t',
      _ => '',
    });
  }

  return md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(source.split('\n')).map(plain).join('\n\n');
}

Future<void> showChatCopyPreview(
  BuildContext context,
  String text, {
  ValueChanged<ModalRoute<dynamic>>? onRoute,
}) => showKiyoriModalDrawer<void>(
  context,
  onRoute: onRoute,
  builder: (_, _) => _CopyPreview(text),
);

class _CopyPreview extends StatefulWidget {
  const _CopyPreview(this.source);
  final String source;
  @override
  State<_CopyPreview> createState() => _CopyPreviewState();
}

class _CopyPreviewState extends State<_CopyPreview> {
  final editor = TextEditingController();
  String? plain;
  bool failed = false;
  bool showPlain = true;
  @override
  void initState() {
    super.initState();
    compute(chatPlainText, widget.source).then(
      (value) {
        if (!mounted) return;
        setState(() {
          plain = value;
          if (showPlain) editor.text = value;
        });
      },
      onError: (Object _, StackTrace _) {
        if (mounted) setState(() => failed = true);
      },
    );
  }

  void select(bool value) => setState(() {
    showPlain = value;
    editor.text = value ? plain ?? '' : widget.source;
  });

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '复制消息',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              selected: showPlain,
              onSelected: (_) => select(true),
              label: const Text('纯文本'),
            ),
            FilterChip(
              selected: !showPlain,
              onSelected: (_) => select(false),
              label: const Text('Markdown 源码'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: showPlain && plain == null
              ? Center(
                  child: failed
                      ? const Text('纯文本转换失败，可切换到 Markdown 源码')
                      : const CircularProgressIndicator(),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: TextField(
                      key: const Key('chat-copy-text'),
                      controller: editor,
                      readOnly: true,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: showPlain && plain == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: editor.text));
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('消息已复制到剪贴板')),
                      );
                    }
                  },
            child: Text(showPlain ? '复制纯文本' : '复制 Markdown 源码'),
          ),
        ),
      ],
    ),
  );
}
