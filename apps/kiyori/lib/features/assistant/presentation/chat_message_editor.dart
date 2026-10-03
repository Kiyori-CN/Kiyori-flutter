import 'package:flutter/material.dart';

/// MessageEditor.kt 的无损片段投影；空白与标签属性均属于正文。
class ChatMessagePart {
  ChatMessagePart(this.content, {this.tag, this.attributes = ''});
  String content;
  String? tag;
  String attributes;
  String get source =>
      tag == null ? content : '<$tag$attributes>$content</$tag>';
}

List<ChatMessagePart> parseChatMessage(String source) {
  final parts = <ChatMessagePart>[];
  var offset = 0;
  final pattern = RegExp(r'<([a-zA-Z0-9_-]+)([^>]*)>([\s\S]*?)</\1>');
  for (final match in pattern.allMatches(source)) {
    if (match.start > offset) {
      parts.add(ChatMessagePart(source.substring(offset, match.start)));
    }
    parts.add(ChatMessagePart(match[3]!, tag: match[1], attributes: match[2]!));
    offset = match.end;
  }
  if (offset < source.length) {
    parts.add(ChatMessagePart(source.substring(offset)));
  }
  return parts;
}

class ChatMessageEditor extends StatefulWidget {
  const ChatMessageEditor({
    required this.initial,
    required this.onSave,
    this.onResend,
    super.key,
  });
  final String initial;
  final Future<bool> Function(String) onSave;
  final Future<bool> Function(String)? onResend;
  @override
  State<ChatMessageEditor> createState() => _ChatMessageEditorState();
}

class _ChatMessageEditorState extends State<ChatMessageEditor> {
  late final raw = TextEditingController(text: widget.initial);
  late List<ChatMessagePart> parts = parseChatMessage(widget.initial);
  bool rawMode = false, saving = false, failed = false, closing = false;
  DialogRoute<bool>? discard;
  DialogRoute<ChatMessagePart>? tagRoute;

  void recompose() => raw.text = parts.map((p) => p.source).join();

  Future<void> close() async {
    if (saving || closing) return;
    if (raw.text != widget.initial) {
      closing = true;
      final route = DialogRoute<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃更改？'),
          content: const Text('消息有未保存的修改，确定放弃吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃'),
            ),
          ],
        ),
      );
      discard = route;
      final confirmed = await Navigator.of(context).push(route);
      discard = null;
      closing = false;
      if (!mounted || confirmed != true) return;
    }
    if (mounted) {
      final route = ModalRoute.of(context)!;
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> save({bool resend = false}) async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      final saved = await (resend ? widget.onResend! : widget.onSave)(raw.text);
      if (!mounted) return;
      if (saved) {
        final route = ModalRoute.of(context)!;
        route.navigator?.removeRoute(route);
      } else {
        setState(() => failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editTag([ChatMessagePart? part]) async {
    if (saving || tagRoute != null) return;
    final route = DialogRoute<ChatMessagePart>(
      context: context,
      builder: (_) => _TagEditor(part: part),
    );
    tagRoute = route;
    final value = await Navigator.of(context).push(route);
    tagRoute = null;
    if (!mounted || value == null) return;
    setState(() {
      final index = part == null ? -1 : parts.indexOf(part);
      if (index < 0) {
        parts.add(value);
      } else {
        parts[index] = value;
      }
      recompose();
    });
  }

  @override
  void dispose() {
    for (final route in <Route<dynamic>?>[discard, tagRoute]) {
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route.isActive) route.navigator?.removeRoute(route);
        });
      }
    }
    raw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width * .05,
          vertical: 24,
        ),
        constraints: const BoxConstraints(maxWidth: 520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.surfaceContainerHighest.withValues(alpha: .3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '编辑消息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            if (rawMode) parts = parseChatMessage(raw.text);
                            rawMode = !rawMode;
                          }),
                    child: Text(rawMode ? '可视化' : '纯文本'),
                  ),
                  IconButton(
                    onPressed: saving ? null : close,
                    tooltip: '关闭编辑',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: rawMode
                      ? TextField(
                          key: const Key('message-editor-raw'),
                          controller: raw,
                          enabled: !saving,
                          minLines: 6,
                          maxLines: 16,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            labelText: '纯文本内容',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
                              child: Text(
                                '内容片段',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            for (final part in parts)
                              Padding(
                                key: ObjectKey(part),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: part.tag == null
                                    ? Stack(
                                        children: [
                                          TextFormField(
                                            initialValue: part.content,
                                            enabled: !saving,
                                            minLines: 1,
                                            maxLines: 12,
                                            onChanged: (value) {
                                              part.content = value;
                                              recompose();
                                            },
                                            decoration: InputDecoration(
                                              labelText: '文本',
                                              hintText: '输入文本内容',
                                              contentPadding:
                                                  const EdgeInsets.fromLTRB(
                                                    12,
                                                    20,
                                                    48,
                                                    12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.topRight,
                                            child: IconButton(
                                              iconSize: 16,
                                              tooltip: '删除片段',
                                              onPressed: saving
                                                  ? null
                                                  : () => setState(() {
                                                      parts.remove(part);
                                                      recompose();
                                                    }),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Card(
                                        color: colors.primary.withValues(
                                          alpha: .08,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ExpansionTile(
                                          leading: const Icon(
                                            Icons.code,
                                            size: 18,
                                          ),
                                          title: Text(
                                            part.tag!,
                                            style: TextStyle(
                                              color: colors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: part.attributes.isEmpty
                                              ? null
                                              : Text(
                                                  part.attributes,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: '编辑标签',
                                                iconSize: 16,
                                                onPressed: saving
                                                    ? null
                                                    : () => editTag(part),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: '删除标签',
                                                iconSize: 16,
                                                onPressed: saving
                                                    ? null
                                                    : () => setState(() {
                                                        parts.remove(part);
                                                        recompose();
                                                      }),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: SelectableText(
                                                part.content,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: saving
                                      ? null
                                      : () => setState(() {
                                          parts.add(ChatMessagePart(''));
                                          recompose();
                                        }),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('添加文本'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: saving ? null : editTag,
                                  icon: const Icon(Icons.code, size: 16),
                                  label: const Text('添加标签'),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '保存失败，修改仍保留，请重试',
                  style: TextStyle(color: colors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                children: [
                  TextButton(
                    onPressed: saving ? null : close,
                    child: const Text('取消'),
                  ),
                  if (widget.onResend != null)
                    OutlinedButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? '保存中…' : '保存'),
                    )
                  else
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? '保存中…' : '保存'),
                    ),
                  if (widget.onResend != null)
                    FilledButton.icon(
                      onPressed: saving ? null : () => save(resend: true),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('保存并重发'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagEditor extends StatefulWidget {
  const _TagEditor({this.part});
  final ChatMessagePart? part;
  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  late final tag = TextEditingController(text: widget.part?.tag ?? '');
  late final attributes = TextEditingController(
    text: widget.part?.attributes ?? '',
  );
  late final content = TextEditingController(text: widget.part?.content ?? '');
  bool invalid = false;
  @override
  void dispose() {
    tag.dispose();
    attributes.dispose();
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.part == null ? '新建标签' : '编辑标签',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: tag,
            decoration: InputDecoration(
              labelText: '标签名称',
              errorText: invalid ? '请输入有效标签名称' : null,
              suffixIcon: PopupMenuButton<String>(
                tooltip: '常用 XML 标签',
                onSelected: (value) => setState(() => tag.text = value),
                itemBuilder: (_) => [
                  for (final name in [
                    'think',
                    'thinking',
                    'search',
                    'tool',
                    'tool_result',
                    'status',
                    'html',
                    'mood',
                    'font',
                    'details',
                    'detail',
                    'meta',
                  ])
                    PopupMenuItem(value: name, child: Text(name)),
                ],
              ),
            ),
          ),
          TextField(
            controller: attributes,
            decoration: const InputDecoration(labelText: '属性（可选）'),
          ),
          TextField(
            controller: content,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(labelText: '标签内容'),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tag.text)) {
                    setState(() => invalid = true);
                    return;
                  }
                  final attrs = attributes.text;
                  Navigator.pop(
                    context,
                    ChatMessagePart(
                      content.text,
                      tag: tag.text,
                      attributes:
                          attrs.isEmpty || RegExp(r'^\s').hasMatch(attrs)
                          ? attrs
                          : ' $attrs',
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
