import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'latex_syntax.dart';

/// Shared LaTeX extensions for all [MarkdownBody] widgets in the app.
///
/// Import this file and pass the syntax/builder lists into MarkdownBody:
///
/// ```dart
/// MarkdownBody(
///   data: text,
///   blockSyntaxes: latexBlockSyntaxes,
///   inlineSyntaxes: latexInlineSyntaxes,
///   builders: latexBuilders(textStyle: ...),
/// )
/// ```

/// Block-level LaTeX: multi-line `$$...$$`.
final List<md.BlockSyntax> latexBlockSyntaxes = [LatexBlockSyntax()];

/// Inline-level LaTeX: single-line `$...$`, single-line `$$...$$`,
/// `\(...\)`, and `\[...\]`.
final List<md.InlineSyntax> latexInlineSyntaxes = [
  LatexInlineBlockSyntax(),
  LatexBracketSyntax(),
  LatexInlineSyntax(),
];

/// Creates the builders map. Pass [textStyle] to set the base font for
/// inline math sizing.
Map<String, MarkdownElementBuilder> latexBuilders({TextStyle? textStyle}) => {
      'latex_block': LatexBuilder(textStyle: textStyle),
      'latex_inline': LatexBuilder(textStyle: textStyle),
    };
