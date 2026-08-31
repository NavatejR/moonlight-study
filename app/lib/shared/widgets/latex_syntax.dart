import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as fm;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Block math that spans multiple lines, delimited by `$$` on its own line:
///
/// ```text
/// $$
/// E = mc^2
/// $$
/// ```
class LatexBlockSyntax extends md.BlockSyntax {
  const LatexBlockSyntax();

  @override
  RegExp get pattern => RegExp(r'^\$\$\s*$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final lines = <String>[];
    parser.advance(); // skip opening $$

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trimRight() == r'$$') {
        parser.advance(); // skip closing $$
        break;
      }
      lines.add(line);
      parser.advance();
    }

    final tex = lines.join('\n').trim();
    if (tex.isEmpty) return null;

    return md.Element('latex_block', [md.Text(tex)]);
  }
}

/// Inline math `$...$` on a single line (does not match `$$`).
///
/// NOTE: `onMatch` must NOT call `parser.consume(...)` — [InlineSyntax.tryMatch]
/// advances the parser by the match length automatically when `onMatch` returns
/// `true`. Consuming here too double-advances and throws [RangeError].
class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(?<!\$)\$(?!\$)([^$\n]+?)(?<!\$)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1)?.trim() ?? '';
    if (tex.isEmpty) return false;
    parser.addNode(md.Element('latex_inline', [md.Text(tex)]));
    return true;
  }
}

/// Single-line display math `$$...$$` (both delimiters on one line).
class LatexInlineBlockSyntax extends md.InlineSyntax {
  LatexInlineBlockSyntax() : super(r'\$\$([^$\n]+?)\$\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1)?.trim() ?? '';
    if (tex.isEmpty) return false;
    parser.addNode(md.Element('latex_block', [md.Text(tex)]));
    return true;
  }
}

/// `\(...\)` inline math and `\[...\]` display math (backslash brackets).
class LatexBracketSyntax extends md.InlineSyntax {
  LatexBracketSyntax() : super(r'\\[\(\[](.+?)\\[\)\]]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1)?.trim() ?? '';
    if (tex.isEmpty) return false;
    final isBlock = match[0]!.startsWith(r'\[');
    parser.addNode(md.Element(
      isBlock ? 'latex_block' : 'latex_inline',
      [md.Text(tex)],
    ));
    return true;
  }
}

/// Renders `latex_block` / `latex_inline` elements as typeset equations via
/// `flutter_math_fork`. The element tag selects display vs text mode.
class LatexBuilder extends MarkdownElementBuilder {
  LatexBuilder({this.textStyle});

  /// Optional base text style for inline math sizing context.
  final TextStyle? textStyle;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return const SizedBox.shrink();

    final isBlock = element.tag == 'latex_block';

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isBlock ? 8 : 0,
        horizontal: isBlock ? 4 : 0,
      ),
      child: fm.Math.tex(
        tex,
        mathStyle: isBlock ? fm.MathStyle.display : fm.MathStyle.text,
        textStyle: (textStyle ?? const TextStyle(fontSize: 16)).copyWith(
          color: preferredStyle?.color,
        ),
        onErrorFallback: (error) => _errorFallback(tex, isBlock, error),
      ),
    );
  }

  Widget _errorFallback(String tex, bool isBlock, fm.FlutterMathException e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Text(
        tex,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: isBlock ? 14 : 13,
          color: Colors.red.shade700,
        ),
      ),
    );
  }
}
