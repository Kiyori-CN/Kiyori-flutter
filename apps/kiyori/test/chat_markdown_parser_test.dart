import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:kiyori/features/assistant/presentation/chat_markdown_parser.dart';

void main() {
  test(
    'incremental projection equals complete parser for every stream prefix',
    () {
      for (final source in [
        '第一段 **加粗**。\n\n第二段\n续行\n\n尾部',
        'Intro\n\nTitle\n---\n\n- one\n\n  continuation\n- two\n',
        'Intro\n\n```dart\nfinal x = "a";\n\n// code\n```\n\nEnd',
        'Intro\n\nA | B\n---|---\nx|y\n',
        'Intro\n\n[link][later]\n\n[later]: https://example.com\n',
        'Intro\n\n<div>\n\ninside\n</div>\n',
        '段落含 `code` 和 ~~删除~~。\n\n文字\n\n',
      ]) {
        var prefix = '';
        final committed = <md.Node>[];
        for (var i = 1; i <= source.length; i++) {
          final current = source.substring(0, i);
          final result = parseChatMarkdown((source: current, prefix: prefix));
          if (result.reset) committed.clear();
          committed.addAll(result.committed);
          prefix = result.prefix;
          final expected = md.Document(
            extensionSet: md.ExtensionSet.gitHubFlavored,
            encodeHtml: false,
          ).parseLines(current.split('\n'));
          expect(
            md.renderToHtml([...committed, ...result.tail]),
            md.renderToHtml(expected),
            reason: current,
          );
        }
      }
    },
  );
  test(
    'closed paragraphs are not reparsed and edits invalidate the prefix',
    () {
      final first = parseChatMarkdown((source: '完整段落\n\n尾', prefix: ''));
      expect(first.committed, hasLength(1));
      final second = parseChatMarkdown((
        source: '完整段落\n\n尾部',
        prefix: first.prefix,
      ));
      expect(second.reset, isFalse);
      expect(second.committed, isEmpty);
      final edit = parseChatMarkdown((
        source: '编辑段落\n\n尾部',
        prefix: first.prefix,
      ));
      expect(edit.reset, isTrue);
      expect(edit.committed.single.textContent, '编辑段落');
    },
  );
}
