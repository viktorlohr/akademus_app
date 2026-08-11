import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Renders quiz content that mixes Markdown with inline (`$..$`) and
/// block (`$$..$$`) LaTeX math — the "basic latex and markdown support"
/// a Moodle-style question bank needs, without pulling in a full TeX
/// engine or webview.
///
/// Strategy: register `$..$`/`$$..$$` as a custom inline Markdown syntax
/// that produces a `math` element, and a matching [MarkdownElementBuilder]
/// that renders it as a [Math.tex] widget. flutter_markdown_plus then
/// merges that widget into the surrounding paragraph's `RichText` as a
/// `WidgetSpan` (the same mechanism it uses for inline images), so math
/// wraps inline with the surrounding text instead of forcing a line break.
class RichContent extends StatelessWidget {
  final String data;
  final TextStyle? style;

  const RichContent(this.data, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? DefaultTextStyle.of(context).style.copyWith(fontSize: 15);

    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
      ),
      shrinkWrap: true,
      inlineSyntaxes: [_MathSyntax()],
      builders: {'math': _MathBuilder(baseStyle)},
    );
  }
}

class _MathSyntax extends md.InlineSyntax {
  // `[^$]` (rather than `.`) so the match spans newlines without needing
  // a `dotAll` option, which markdown's InlineSyntax doesn't expose.
  _MathSyntax() : super(r'\$\$([^$]+?)\$\$|\$([^$]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = (match[1] ?? match[2] ?? '').trim();
    parser.addNode(md.Element.text('math', tex));
    return true;
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  final TextStyle baseStyle;
  _MathBuilder(this.baseStyle);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    final textStyle = parentStyle ?? preferredStyle ?? baseStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Math.tex(
        tex,
        mathStyle: MathStyle.text,
        textStyle: textStyle,
        onErrorFallback: (err) => Text(
          '\$$tex\$',
          style: textStyle.copyWith(color: Colors.red),
        ),
      ),
    );
  }
}
