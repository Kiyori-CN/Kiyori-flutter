import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'profile/profile_markdown_preview.dart';
import 'chat_markdown_parser.dart';

/// 流与历史使用同一渲染器。解析离开UI线程，并合并积压，最多一个解析在途。
/// 保留完整原文，解析期间保留上一版排版；新实体不得收到旧实体结果。
class ChatMarkdown extends StatefulWidget {
  const ChatMarkdown({required this.text, this.streaming = false, super.key});
  final String text;
  final bool streaming;
  @override
  State<ChatMarkdown> createState() => _ChatMarkdownState();
}

class _ChatMarkdownState extends State<ChatMarkdown> {
  List<md.Node>? nodes;
  String prefix = '';
  final committed = <md.Node>[];
  final blocks = <md.Node, Widget>{};
  String? rendered;
  Timer? timer;
  bool parsing = false, failed = false;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(ChatMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.streaming != widget.streaming) {
      schedule();
    }
  }

  void schedule() {
    if (parsing || rendered == widget.text) return;
    // 节流而不是去抖：连续delta不能无限重置计时器直到流结束才排版。
    if (widget.streaming && (timer?.isActive ?? false)) return;
    timer?.cancel();
    // 流式只刷新当前消息，历史AST不会因token事件重算。
    timer = Timer(
      widget.streaming ? const Duration(milliseconds: 80) : Duration.zero,
      parse,
    );
  }

  Future<void> parse() async {
    timer = null;
    if (!mounted || parsing) return;
    parsing = true;
    final source = widget.text;
    try {
      final next = await compute(parseChatMarkdown, (
        source: source,
        prefix: prefix,
      ));
      if (!mounted) return;
      setState(() {
        if (next.reset) committed.clear();
        committed.addAll(next.committed);
        prefix = next.prefix;
        nodes = [...committed, ...next.tail];
        final retained = nodes!.toSet();
        blocks.removeWhere((node, _) => !retained.contains(node));
        rendered = source;
        failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          rendered = source;
        });
      }
    } finally {
      parsing = false;
      if (mounted) schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      // 排版失败保留原文可读，而不是隐藏或丢弃回复。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '排版失败，显示原文',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          Text(widget.text, style: const TextStyle(fontSize: 14, height: 1.3)),
        ],
      );
    }
    if (nodes == null) return const SizedBox(height: 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in nodes!)
          blocks.putIfAbsent(
            node,
            () => ProfileMarkdownPreview(
              key: ObjectKey(node),
              text: '',
              parsedNodes: [node],
              embedded: true,
              selectable: false,
            ),
          ),
      ],
    );
  }
}
