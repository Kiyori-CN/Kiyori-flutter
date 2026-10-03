import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;

/// 静态资料预览；AST只随文本变化重建，不加载远程图片或打开链接。
class ProfileMarkdownPreview extends StatefulWidget {
  const ProfileMarkdownPreview({
    required this.text,
    this.embedded = false,
    this.selectable = true,
    this.parsedNodes,
    super.key,
  });
  final String text;
  final bool embedded;
  final bool selectable;
  final List<md.Node>? parsedNodes;
  @override
  State<ProfileMarkdownPreview> createState() => _ProfileMarkdownPreviewState();
}

class _ProfileMarkdownPreviewState extends State<ProfileMarkdownPreview> {
  late List<md.Node> nodes = parse();
  List<md.Node> parse() =>
      widget.parsedNodes ??
      md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parseLines(widget.text.split('\n'));
  @override
  void didUpdateWidget(ProfileMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.parsedNodes != widget.parsedNodes) {
      nodes = parse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.embedded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final node in nodes) block(context, node)],
          )
        : ListView.builder(
            key: const PageStorageKey('profile-preview'),
            padding: const EdgeInsets.all(16),
            itemCount: nodes.length,
            itemBuilder: (context, index) => block(context, nodes[index]),
          );
    return widget.selectable ? SelectionArea(child: content) : content;
  }

  Widget block(BuildContext context, md.Node node) {
    final colors = Theme.of(context).colorScheme;
    if (node is md.Text) return text(context, [node]);
    final element = node as md.Element,
        children = node.children ?? const <md.Node>[];
    switch (element.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(element.tag.substring(1));
        return Padding(
          padding: EdgeInsets.only(
            top: [12, 10, 8, 6, 6, 6][level - 1].toDouble(),
            bottom: level <= 2 ? 4 : 2,
          ),
          child: text(
            context,
            children,
            style: TextStyle(
              fontSize: [28, 24, 22, 16, 14, 14][level - 1].toDouble(),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'p':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: text(context, children),
        );
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final child in children) block(context, child)],
          ),
        );
      case 'ul':
      case 'ol':
        final start = int.tryParse(element.attributes['start'] ?? '') ?? 1;
        final items = children
            .whereType<md.Element>()
            .where((child) => child.tag == 'li')
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      element.tag == 'ol' ? '${i + start}.' : '•',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: listItem(context, items[i])),
                  ],
                ),
              ),
          ],
        );
      case 'pre':
        final code = children.whereType<md.Element>().firstOrNull;
        final language =
            code?.attributes['class']?.replaceFirst('language-', '') ?? '';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        language,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: '复制',
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: element.textContent),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Text(
                  element.textContent,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.3,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'hr':
        return Divider(color: colors.outlineVariant, height: 16);
      case 'table':
        return table(context, element);
      default:
        return text(context, children);
    }
  }

  Widget listItem(BuildContext context, md.Element item) {
    final chunks = <Widget>[], inlines = <md.Node>[];
    void flush() {
      if (inlines.isNotEmpty) {
        chunks.add(text(context, List.of(inlines)));
        inlines.clear();
      }
    }

    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element &&
          ['p', 'ul', 'ol', 'blockquote', 'pre'].contains(child.tag)) {
        flush();
        chunks.add(block(context, child));
      } else {
        inlines.add(child);
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: chunks,
    );
  }

  Widget text(BuildContext context, List<md.Node> nodes, {TextStyle? style}) =>
      Text.rich(
        TextSpan(children: [for (final node in nodes) inline(context, node)]),
        style: TextStyle(
          fontSize: 14,
          height: 1.3,
          color: Theme.of(context).colorScheme.onSurface,
        ).merge(style),
      );
  InlineSpan inline(BuildContext context, md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    final element = node as md.Element, colors = Theme.of(context).colorScheme;
    if (element.tag == 'br') return const TextSpan(text: '\n');
    if (element.tag == 'input') {
      return TextSpan(
        text: element.attributes.containsKey('checked') ? '☑ ' : '☐ ',
      );
    }
    if (element.tag == 'img') {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Semantics(
          label: element.attributes['alt'] ?? '图片',
          child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
        ),
      );
    }
    final style = switch (element.tag) {
      'strong' => const TextStyle(fontWeight: FontWeight.bold),
      'em' => const TextStyle(fontStyle: FontStyle.italic),
      'del' => const TextStyle(decoration: TextDecoration.lineThrough),
      'code' => TextStyle(
        fontFamily: 'monospace',
        color: colors.primary,
        backgroundColor: colors.surfaceContainerHigh,
      ),
      'a' => TextStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
      _ => null,
    };
    return TextSpan(
      style: style,
      children: [
        for (final child in element.children ?? const <md.Node>[])
          inline(context, child),
      ],
    );
  }

  Widget table(BuildContext context, md.Element element) {
    final rows = <md.Element>[];
    void collect(md.Element parent) {
      for (final child in parent.children ?? const <md.Node>[]) {
        if (child is md.Element) {
          if (child.tag == 'tr') {
            rows.add(child);
          } else {
            collect(child);
          }
        }
      }
    }

    collect(element);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(160),
        border: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        children: [
          for (final row in rows)
            TableRow(
              children: [
                for (final cell
                    in (row.children ?? const <md.Node>[])
                        .whereType<md.Element>())
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: text(
                      context,
                      cell.children ?? const [],
                      style: TextStyle(
                        fontWeight: cell.tag == 'th'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
