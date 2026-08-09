import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders quiz content that mixes Markdown with inline (`$..$`) and
/// block (`$$..$$`) LaTeX math — the "basic latex and markdown support"
/// a Moodle-style question bank needs, without pulling in a full TeX
/// engine or webview.
///
/// Strategy: split the raw string into plain-text/Markdown chunks and
/// math chunks, then lay them out as wrapped inline spans. This keeps the
/// implementation to a regex + two renderer widgets rather than writing a
/// custom Markdown inline-element parser for flutter_markdown_plus.
class RichContent extends StatelessWidget {
  final String data;
  final TextStyle? style;

  const RichContent(this.data, {super.key, this.style});

  static final _mathPattern = RegExp(
    r'\$\$(.+?)\$\$|\$(.+?)\$',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? DefaultTextStyle.of(context).style.copyWith(fontSize: 15);
    final segments = _split(data);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final segment in segments)
          if (segment.isMath)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                segment.text,
                mathStyle: MathStyle.text,
                textStyle: baseStyle,
                onErrorFallback: (err) => Text(
                  '\$${segment.text}\$',
                  style: baseStyle.copyWith(color: Colors.red),
                ),
              ),
            )
          else if (segment.text.trim().isNotEmpty)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              child: MarkdownBody(
                data: segment.text,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(p: baseStyle),
                shrinkWrap: true,
              ),
            ),
      ],
    );
  }

  static List<_Segment> _split(String input) {
    final segments = <_Segment>[];
    var lastEnd = 0;
    for (final match in _mathPattern.allMatches(input)) {
      if (match.start > lastEnd) {
        segments.add(_Segment(input.substring(lastEnd, match.start), false));
      }
      final tex = match.group(1) ?? match.group(2) ?? '';
      segments.add(_Segment(tex.trim(), true));
      lastEnd = match.end;
    }
    if (lastEnd < input.length) {
      segments.add(_Segment(input.substring(lastEnd), false));
    }
    return segments;
  }
}

class _Segment {
  final String text;
  final bool isMath;
  const _Segment(this.text, this.isMath);
}
