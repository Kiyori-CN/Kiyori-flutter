import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MarkdownSyntaxKind {
  heading,
  emphasis,
  code,
  link,
  quote,
  marker,
  comment,
  html,
}

typedef MarkdownSyntaxRange = ({MarkdownSyntaxKind kind, int start, int end});

/// 按旧 MarkdownSyntaxHighlighting 扫描颜色区间，不插入/删除字符。
/// 未闭合行内标记最多前看512字符，避免输入半段 Markdown 时反复扫描整行。
List<MarkdownSyntaxRange> scanMarkdownSyntax(String source) =>
    _SyntaxScanner(source).scan();

class _SyntaxScanner {
  _SyntaxScanner(this.source);
  final String source;
  final ranges = <MarkdownSyntaxRange>[];
  static final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _autolinkWhitespace = RegExp(r'[\s<]');
  void emit(MarkdownSyntaxKind kind, int start, int end) {
    if (start < end) ranges.add((kind: kind, start: start, end: end));
  }

  bool whitespace(int i) => source[i].trim().isEmpty;
  bool letterOrDigit(int i) => _letterOrDigit.hasMatch(source[i]);
  int run(int start, int end, String marker) {
    var i = start;
    while (i < end && source[i] == marker) {
      i++;
    }
    return i - start;
  }

  int skip(int start, int end) {
    var i = start;
    while (i < end && whitespace(i)) {
      i++;
    }
    return i;
  }

  bool prefix(String value, int start, int end) =>
      start >= 0 &&
      start + value.length <= end &&
      source.startsWith(value, start);
  int find(String value, int start, int end) {
    for (var i = start; i + value.length <= end; i++) {
      if (source.startsWith(value, i)) return i;
    }
    return -1;
  }

  int unescaped(String value, int start, int end) {
    var i = start;
    while (i < end) {
      if (source[i] == r'\') {
        i += 2;
      } else if (source[i] == value) {
        return i;
      } else {
        i++;
      }
    }
    return -1;
  }

  int matchingRun(String marker, int length, int start, int end) {
    var i = start;
    while (i < end) {
      if (source[i] == r'\') {
        i += 2;
      } else if (source[i] == marker) {
        final count = run(i, end, marker);
        if (count == length) return i;
        i += count;
      } else {
        i++;
      }
    }
    return -1;
  }

  List<MarkdownSyntaxRange> scan() {
    var start = 0, fenceLength = 0;
    String? fence;
    var comment = false;
    while (start < source.length) {
      final newline = source.indexOf('\n', start);
      final rawEnd = newline < 0 ? source.length : newline;
      final end = rawEnd > start && source[rawEnd - 1] == '\r'
          ? rawEnd - 1
          : rawEnd;
      if (comment) {
        final closing = find('-->', start, end);
        emit(
          MarkdownSyntaxKind.comment,
          start,
          closing < 0 ? end : closing + 3,
        );
        if (closing >= 0) comment = inline(closing + 3, end);
      } else {
        var block = start;
        while (block < end && source[block] == ' ' && block - start < 4) {
          block++;
        }
        if (block - start > 3) block = -1;
        if (fence != null) {
          emit(MarkdownSyntaxKind.code, start, end);
          if (block >= 0 && block < end && source[block] == fence) {
            final count = run(block, end, fence);
            if (count >= fenceLength && skip(block + count, end) == end) {
              fence = null;
            }
          }
        } else {
          final marker = block >= 0 && block < end ? source[block] : '';
          final count = ['`', '~'].contains(marker)
              ? run(block, end, marker)
              : 0;
          if (count >= 3 &&
              (marker != '`' || find('`', block + count, end) < 0)) {
            fence = marker;
            fenceLength = count;
            emit(MarkdownSyntaxKind.code, start, end);
          } else {
            comment = line(start, end, block);
          }
        }
      }
      start = newline < 0 ? source.length : newline + 1;
    }
    return ranges;
  }

  bool line(int start, int end, int block) {
    if (block < 0 || block >= end) return inline(start, end);
    var content = block;
    if (source[content] == '>') {
      final quote = content;
      do {
        content++;
        if (content < end && source[content] == ' ') content++;
      } while (content < end && source[content] == '>');
      emit(MarkdownSyntaxKind.quote, quote, content);
      content = skip(content, end);
    }
    var heading = content;
    while (heading < end && source[heading] == '#' && heading - content < 6) {
      heading++;
    }
    if (heading > content && (heading == end || whitespace(heading))) {
      emit(MarkdownSyntaxKind.marker, content, heading);
      emit(MarkdownSyntaxKind.heading, skip(heading, end), end);
      return false;
    }
    if (content < end && ['*', '-', '_'].contains(source[content])) {
      final marker = source[content];
      var count = 0, valid = true;
      for (var i = content; i < end; i++) {
        if (source[i] == marker) {
          count++;
        } else if (source[i] != ' ' && source[i] != '\t') {
          valid = false;
          break;
        }
      }
      if (valid && count >= 3) {
        emit(MarkdownSyntaxKind.marker, content, end);
        return false;
      }
    }
    var markerEnd = -1;
    if (content + 1 < end &&
        ['-', '+', '*'].contains(source[content]) &&
        whitespace(content + 1)) {
      markerEnd = content + 1;
    } else {
      var i = content;
      while (i < end && '0123456789'.contains(source[i]) && i - content < 9) {
        i++;
      }
      if (i > content &&
          i + 1 < end &&
          ['.', ')'].contains(source[i]) &&
          whitespace(i + 1)) {
        markerEnd = i + 1;
      }
    }
    if (markerEnd > content) {
      emit(MarkdownSyntaxKind.marker, content, markerEnd);
      content = skip(markerEnd, end);
      if (content + 2 < end &&
          source[content] == '[' &&
          [' ', 'x', 'X'].contains(source[content + 1]) &&
          source[content + 2] == ']' &&
          (content + 3 == end || whitespace(content + 3))) {
        emit(MarkdownSyntaxKind.marker, content, content + 3);
        content = skip(content + 3, end);
      }
    }
    return inline(content, end);
  }

  bool inline(int start, int end) {
    var i = start;
    while (i < end) {
      final marker = source[i], limit = math.min(end, i + 512);
      if (marker == r'\') {
        i += 2;
        continue;
      }
      if (prefix('<!--', i, end)) {
        final close = find('-->', i + 4, end);
        emit(MarkdownSyntaxKind.comment, i, close < 0 ? end : close + 3);
        if (close < 0) return true;
        i = close + 3;
        continue;
      }
      if (marker == '`') {
        final count = run(i, end, marker),
            close = matchingRun(
              marker,
              run(i, end, marker),
              i + run(i, end, marker),
              limit,
            );
        if (close >= 0) {
          emit(MarkdownSyntaxKind.code, i, close + count);
          i = close + count;
        } else {
          i += count;
        }
        continue;
      }
      if (marker == '[' || prefix('![', i, end)) {
        final bracket = marker == '!' ? i + 1 : i;
        final labelEnd = unescaped(']', bracket + 1, limit);
        var closing = -1;
        if (labelEnd >= 0 && labelEnd + 1 < limit) {
          if (source[labelEnd + 1] == '(') {
            closing = balanced(labelEnd + 1, limit);
          } else if (source[labelEnd + 1] == '[') {
            final ref = unescaped(']', labelEnd + 2, limit);
            if (ref >= 0) closing = ref + 1;
          }
        }
        if (closing > i) {
          emit(MarkdownSyntaxKind.link, i, closing);
          i = closing;
          continue;
        }
      }
      if (marker == '<') {
        final close = unescaped('>', i + 1, limit);
        if (close >= 0) {
          final content = source.substring(i + 1, close);
          if (!content.contains(_autolinkWhitespace) &&
              (content.contains(':') || content.contains('@'))) {
            emit(MarkdownSyntaxKind.link, i, close + 1);
            i = close + 1;
            continue;
          }
        }
        if (i + 1 < limit &&
            (_letter.hasMatch(source[i + 1]) ||
                '/!?'.contains(source[i + 1]))) {
          String? quote;
          var j = i + 2;
          while (j < limit) {
            final c = source[j];
            if (c == r'\') {
              j += 2;
              continue;
            }
            if (quote != null) {
              if (c == quote) quote = null;
            } else if (c == '"' || c == "'") {
              quote = c;
            } else if (c == '>') {
              emit(MarkdownSyntaxKind.html, i, j + 1);
              i = j + 1;
              break;
            }
            j++;
          }
          if (j < limit) continue;
        }
      }
      if (['*', '_', '~'].contains(marker)) {
        final count = run(i, end, marker);
        final length = marker == '~'
            ? count >= 2
                  ? 2
                  : -1
            : math.min(count, 3);
        final content = i + length;
        if (length > 0 &&
            content < end &&
            !whitespace(content) &&
            !(marker == '_' && i > 0 && letterOrDigit(i - 1))) {
          var close = matchingRun(marker, length, content, limit);
          while (close >= 0) {
            final after = close + length;
            if (close > content &&
                !whitespace(close - 1) &&
                (marker != '_' || after == end || !letterOrDigit(after))) {
              emit(MarkdownSyntaxKind.emphasis, i, after);
              i = after;
              break;
            }
            close = matchingRun(marker, length, after, limit);
          }
          if (close >= 0) continue;
        }
        i += count;
        continue;
      }
      if (marker == '|') emit(MarkdownSyntaxKind.marker, i, i + 1);
      i++;
    }
    return false;
  }

  int balanced(int start, int end) {
    var depth = 0, i = start;
    String? quote;
    while (i < end) {
      final c = source[i];
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) return i + 1;
      }
      i++;
    }
    return -1;
  }
}

class MarkdownDraftController extends TextEditingController {
  MarkdownDraftController({super.text});
  String? _cachedText;
  List<MarkdownSyntaxRange> _ranges = [];
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_cachedText != text) {
      _cachedText = text;
      _ranges = scanMarkdownSyntax(text);
    }
    final colors = Theme.of(context).colorScheme;
    final boundaries = <int>{
      0,
      text.length,
      for (final range in _ranges) ...[range.start, range.end],
    };
    final composing =
        withComposing &&
            value.isComposingRangeValid &&
            !value.composing.isCollapsed
        ? value.composing
        : TextRange.empty;
    if (composing.isValid) boundaries.addAll([composing.start, composing.end]);
    final sorted = boundaries.toList()..sort();
    var cursor = 0;
    final spans = <InlineSpan>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final start = sorted[i], end = sorted[i + 1];
      while (cursor < _ranges.length && _ranges[cursor].end <= start) {
        cursor++;
      }
      final kind = cursor < _ranges.length && _ranges[cursor].start <= start
          ? _ranges[cursor].kind
          : null;
      final color = switch (kind) {
        MarkdownSyntaxKind.heading ||
        MarkdownSyntaxKind.emphasis => colors.tertiary,
        MarkdownSyntaxKind.code || MarkdownSyntaxKind.link => colors.primary,
        MarkdownSyntaxKind.quote ||
        MarkdownSyntaxKind.marker ||
        MarkdownSyntaxKind.html => colors.secondary,
        MarkdownSyntaxKind.comment => colors.onSurfaceVariant,
        null => null,
      };
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: color,
            decoration:
                composing.isValid &&
                    start >= composing.start &&
                    end <= composing.end
                ? TextDecoration.underline
                : null,
          ),
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}
