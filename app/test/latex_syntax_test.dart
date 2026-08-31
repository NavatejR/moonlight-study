import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:study_companion/shared/widgets/latex_extension.dart';

List<String> tagsOf(List<md.Node> children) {
  final result = <String>[];
  for (final child in children) {
    if (child is md.Element) {
      result.add(child.tag);
      result.addAll(tagsOf(child.children ?? const []));
    }
  }
  return result;
}

void main() {
  final doc = md.Document(
    blockSyntaxes: latexBlockSyntaxes,
    inlineSyntaxes: latexInlineSyntaxes,
  );

  test('inline \$\$ math produces latex_inline', () {
    final out = doc.parse(r'Solve $x^2 + \frac{1}{2}$ now.');
    expect(tagsOf(out), contains('latex_inline'));
  });

  test('single-line dollar-dollar block', () {
    final out = doc.parse(r'x $$a+b$$ y');
    expect(tagsOf(out), contains('latex_block'));
  });

  test('multi-line dollar-dollar block', () {
    final out = doc.parse('A\n\n\$\$\nE = mc^2\n\$\$\n\nB');
    expect(tagsOf(out), contains('latex_block'));
  });

  test('backslash paren inline', () {
    final out = doc.parse(r'Then \(a + b\) holds.');
    expect(tagsOf(out), contains('latex_inline'));
  });

  test('backslash bracket block', () {
    final out = doc.parse(r'See \[f(x)=\frac{1}{2}\] below.');
    expect(tagsOf(out), contains('latex_block'));
  });

  test('does not throw on multiple inline math (double-consume regression)', () {
    final out = doc.parse(r'Text $a$ then $b$ and more.');
    expect(tagsOf(out).where((t) => t == 'latex_inline').length, 2);
  });
}
