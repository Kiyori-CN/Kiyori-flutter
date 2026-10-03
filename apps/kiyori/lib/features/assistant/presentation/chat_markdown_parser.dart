import 'package:markdown/markdown.dart' as md;

typedef ChatMarkdownInput = ({String source, String prefix});
typedef ChatMarkdownResult = ({
  bool reset,
  String prefix,
  List<md.Node> committed,
  List<md.Node> tail,
});

List<md.Node> _parse(String text) => md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(text.split('\n'));

/// 只提交语法上已经闭合的普通段落。列表、表格、围栏和HTML保留在可变尾部，
/// 交给正式解析器；后置引用可能影响前文，遇到引用语法时整篇重新求值。
/// 此保守边界不猜测复杂块的结束，也不截断未闭合内容。
ChatMarkdownResult parseChatMarkdown(ChatMarkdownInput input) {
  final source = input.source;
  final references = source.contains('[') || source.contains('<');
  final reset = references || !source.startsWith(input.prefix);
  final start = reset ? 0 : input.prefix.length;
  var end = start;
  final committed = <md.Node>[];
  if (!references) {
    for (final boundary in RegExp(r'\n[ \t]*\n').allMatches(source, start)) {
      final candidate = source.substring(end, boundary.end);
      final lines = candidate
          .split('\n')
          .where((line) => line.trim().isNotEmpty);
      if (lines.any(
        (line) =>
            !RegExp(r'^[A-Za-z\u0080-\uFFFF]').hasMatch(line) ||
            line.contains('<') ||
            line.contains('\r'),
      )) {
        break;
      }
      committed.addAll(_parse(candidate));
      end = boundary.end;
    }
  }
  return (
    reset: reset,
    prefix: source.substring(0, end),
    committed: committed,
    tail: _parse(source.substring(end)),
  );
}
