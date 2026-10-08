import 'package:flutter/material.dart';

/// One line in a [CategoryProgressChart]: a label, its color, and its
/// chronological (cumulative questions answered, accuracy-percent) points.
/// An empty series (a category with zero sessions so far) draws no line on
/// the chart, but still gets a legend entry pinned to 0% — see the
/// legend's doc comment in [CategoryProgressChart] for why that's not just
/// omitted.
@immutable
class QuestionTrendSeries {
  final String label;
  final Color color;

  /// [total]/[known] are the *cumulative* counts backing [percent] (so
  /// they always divide out to it exactly) — shown in the hover tooltip
  /// alongside the percentage.
  final List<({int questionsAnswered, double percent, int total, int known})> points;

  const QuestionTrendSeries({
    required this.label,
    required this.color,
    required this.points,
  });
}

/// A multi-series accuracy-by-question-count line chart with a color
/// legend. Used for the progress screen's "Entwicklung" card on both the
/// Karteikarten and Quiz tabs — one line per topic plus a "Gesamt" line.
///
/// Each series is positioned by *how many questions of that category have
/// been answered so far* rather than by session order or date — a topic
/// practiced less ends up with a shorter line, stopping short of the right
/// edge. All series share one fixed x-axis domain, `[0, maxX]` (`maxX`
/// being the total questions answered overall in this mode), so the three
/// topic lines' lengths visually sum to the "Gesamt" line's full length.
///
/// Hand-rolled `CustomPainter` — no charting package dependency, see
/// CLAUDE.md's Progress screen section for why.
class CategoryProgressChart extends StatefulWidget {
  final List<QuestionTrendSeries> series;

  /// Fixed right edge of the x-axis (total questions answered overall in
  /// this mode) — not derived from `series` because a topic's own last
  /// point is usually less than this.
  final int maxX;

  final double height;

  const CategoryProgressChart({
    super.key,
    required this.series,
    required this.maxX,
    this.height = 220,
  });

  @override
  State<CategoryProgressChart> createState() => _CategoryProgressChartState();
}

class _CategoryProgressChartState extends State<CategoryProgressChart> {
  int? _selectedX;

  void _selectFromLocalX(double dx, double width) {
    final nonEmpty = widget.series.where((s) => s.points.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return;

    final plotLeft = _CategoryProgressPainter.leftPad;
    final plotWidth =
        (width - _CategoryProgressPainter.leftPad - _CategoryProgressPainter.rightPad)
            .clamp(1.0, double.infinity);
    final maxX = widget.maxX <= 0 ? 1 : widget.maxX;
    double xFor(int q) => plotLeft + plotWidth * q / maxX;

    int? nearest;
    var bestDist = double.infinity;
    for (final s in nonEmpty) {
      for (final p in s.points) {
        final dist = (xFor(p.questionsAnswered) - dx).abs();
        if (dist < bestDist) {
          bestDist = dist;
          nearest = p.questionsAnswered;
        }
      }
    }
    if (nearest != null) setState(() => _selectedX = nearest);
  }

  @override
  Widget build(BuildContext context) {
    final nonEmpty = widget.series.where((s) => s.points.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return SizedBox(height: widget.height);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // TapRegion makes the tooltip a tap-to-show/tap-elsewhere-to-
            // hide affair on touch devices (there's no hover on a phone):
            // a tap on a point selects it and it stays up — onPanEnd no
            // longer clears it — until a tap anywhere outside this region
            // (the legend below, another card, ...) calls onTapOutside.
            return TapRegion(
              onTapOutside: (_) => setState(() => _selectedX = null),
              child: MouseRegion(
                // Desktop/web pointer hover, distinct from the pan
                // handlers below (which cover touch drag/tap) — a mouse
                // doesn't need to be pressed down to reveal the tooltip.
                onHover: (e) => _selectFromLocalX(e.localPosition.dx, width),
                onExit: (_) => setState(() => _selectedX = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) => _selectFromLocalX(d.localPosition.dx, width),
                  onPanUpdate: (d) => _selectFromLocalX(d.localPosition.dx, width),
                  child: CustomPaint(
                    size: Size(width, widget.height),
                    painter: _CategoryProgressPainter(
                      series: nonEmpty,
                      maxX: widget.maxX,
                      selectedX: _selectedX,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          // Every series is listed here, unlike the chart itself — a
          // category with no sessions yet still gets a legend entry
          // pinned to 0%, rather than being omitted (which read as if it
          // had silently inherited "Gesamt"'s value instead of having no
          // data of its own).
          children: [
            for (final s in widget.series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.label} · ${s.points.isEmpty ? 0 : s.points.last.percent.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s.color,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryProgressPainter extends CustomPainter {
  static const leftPad = 34.0;
  static const rightPad = 8.0;
  static const topPad = 10.0;
  static const bottomPad = 34.0;
  static const minY = 0.0;
  static const maxY = 100.0;

  /// Evenly-spaced x-axis ticks (7, including 0 and maxX), regardless of
  /// how many points exist.
  static const _tickFractions = [0.0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1.0];

  final List<QuestionTrendSeries> series;
  final int maxX;
  final int? selectedX;

  _CategoryProgressPainter({
    required this.series,
    required this.maxX,
    required this.selectedX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      (size.width - leftPad - rightPad).clamp(1.0, double.infinity),
      (size.height - topPad - bottomPad).clamp(1.0, double.infinity),
    );

    final domainMax = maxX <= 0 ? 1 : maxX;

    double xFor(int q) => plotRect.left + plotRect.width * q / domainMax;
    double yFor(double v) => plotRect.bottom - (v - minY) / (maxY - minY) * plotRect.height;

    // Gridlines + y-axis percent ticks.
    final gridPaint = Paint()
      ..color = const Color(0xFFE6E6E6)
      ..strokeWidth = 1;
    final axisStyle = TextStyle(color: Colors.grey[500], fontSize: 10);
    for (final f in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = plotRect.bottom - plotRect.height * f;
      canvas.drawLine(Offset(plotRect.left, y), Offset(plotRect.right, y), gridPaint);
      final tickTp = TextPainter(
        text: TextSpan(text: '${(minY + (maxY - minY) * f).round()}%', style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tickTp.paint(canvas, Offset(0, (y - tickTp.height / 2).clamp(0.0, size.height)));
    }

    // x-axis ticks: a fixed handful of evenly-spaced question counts along
    // the shared domain, not one per data point.
    final tickStyle = TextStyle(color: Colors.grey[500], fontSize: 10);
    for (final f in _tickFractions) {
      final q = (domainMax * f).round();
      final x = plotRect.left + plotRect.width * f;
      final tp = TextPainter(
        text: TextSpan(text: '$q', style: tickStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final tickLeft = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(tickLeft, size.height - bottomPad + 6));
    }
    final captionTp = TextPainter(
      text: TextSpan(text: 'Anzahl beantworteter Fragen', style: tickStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    captionTp.paint(
      canvas,
      Offset(
        (plotRect.center.dx - captionTp.width / 2).clamp(0.0, size.width - captionTp.width),
        size.height - captionTp.height,
      ),
    );

    for (final s in series) {
      final offsets = [
        for (final p in s.points) Offset(xFor(p.questionsAnswered), yFor(p.percent)),
      ];

      if (offsets.isNotEmpty) {
        // Every line visually starts at x=0 (0 questions answered), flat at
        // its first real value, so a line's rightward reach always shows
        // the true count of questions answered in that category — not just
        // the gap between its first and last session.
        final linePath = Path()..moveTo(xFor(0), offsets.first.dy);
        for (final o in offsets) {
          linePath.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
          linePath,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      // A dot per actual data point — series don't share x-positions, so
      // dots (not just the line) show where real sessions landed. The
      // touched question-count's dot (if this series has one there) is
      // drawn larger.
      for (var i = 0; i < offsets.length; i++) {
        final isSelected = selectedX != null && s.points[i].questionsAnswered == selectedX;
        final r = isSelected ? 5.0 : 3.0;
        canvas.drawCircle(offsets[i], r + 1, Paint()..color = Colors.white);
        canvas.drawCircle(offsets[i], r, Paint()..color = s.color);
      }
    }

    // Crosshair + combined tooltip for the touched question-count — lists
    // the nearest point per series that actually has data there (a
    // shorter-practiced topic simply won't be listed once the crosshair
    // moves past its last point).
    if (selectedX != null) {
      final x = xFor(selectedX!);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );

      final matching = [
        for (final s in series)
          if (s.points.any((p) => p.questionsAnswered == selectedX))
            (s, s.points.firstWhere((p) => p.questionsAnswered == selectedX)),
      ];
      if (matching.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$selectedX Fragen\n',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              for (final (s, p) in matching)
                TextSpan(
                  children: [
                    TextSpan(text: '● ', style: TextStyle(color: s.color, fontSize: 11)),
                    TextSpan(
                      text: '${s.label}: ${p.known}/${p.total} richtig (${p.percent.round()}%)\n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        const hPad = 8.0, vPad = 6.0;
        final bubbleWidth = tp.width + hPad * 2;
        final bubbleHeight = tp.height + vPad * 2;
        final bubbleLeft = (x - bubbleWidth / 2).clamp(0.0, size.width - bubbleWidth);
        var bubbleTop = plotRect.top - bubbleHeight - 8;
        if (bubbleTop < 0) bubbleTop = plotRect.top + 8;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, Paint()..color = const Color(0xFF264358));
        tp.paint(canvas, Offset(bubbleLeft + hPad, bubbleTop + vPad));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryProgressPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.maxX != maxX ||
      oldDelegate.selectedX != selectedX;
}
