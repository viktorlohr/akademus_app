import 'package:flutter/material.dart';
import '../../services/progress_stats_service.dart';

/// A compact single-series line chart for a run of [TrendPoint]s. Drag or
/// tap anywhere on the chart to move a crosshair to the nearest point —
/// there's no need to land precisely on a dot.
///
/// Single series only: no legend box (the card title above it already says
/// what's plotted), one hue, endpoint value labeled directly.
class TrendLineChart extends StatefulWidget {
  final List<TrendPoint> points;
  final double Function(TrendPoint) valueOf;
  final String Function(double) formatValue;
  final Color lineColor;
  final Color dotColor;
  final double height;

  const TrendLineChart({
    super.key,
    required this.points,
    required this.valueOf,
    required this.formatValue,
    required this.lineColor,
    required this.dotColor,
    this.height = 180,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _selectedIndex;

  void _selectFromLocalX(double dx, double width) {
    final n = widget.points.length;
    if (n == 0) return;
    if (n == 1) {
      setState(() => _selectedIndex = 0);
      return;
    }
    final plotWidth = (width - _TrendLinePainter.leftPad - _TrendLinePainter.rightPad)
        .clamp(1.0, double.infinity);
    final t = ((dx - _TrendLinePainter.leftPad) / plotWidth).clamp(0.0, 1.0);
    final index = (t * (n - 1)).round().clamp(0, n - 1);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return SizedBox(height: widget.height);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _selectFromLocalX(d.localPosition.dx, width),
          onPanUpdate: (d) => _selectFromLocalX(d.localPosition.dx, width),
          onPanEnd: (_) => setState(() => _selectedIndex = null),
          onPanCancel: () => setState(() => _selectedIndex = null),
          child: CustomPaint(
            size: Size(width, widget.height),
            painter: _TrendLinePainter(
              points: widget.points,
              valueOf: widget.valueOf,
              formatValue: widget.formatValue,
              lineColor: widget.lineColor,
              dotColor: widget.dotColor,
              selectedIndex: _selectedIndex,
            ),
          ),
        );
      },
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  static const leftPad = 38.0;
  static const rightPad = 8.0;
  static const topPad = 18.0;
  static const bottomPad = 22.0;

  final List<TrendPoint> points;
  final double Function(TrendPoint) valueOf;
  final String Function(double) formatValue;
  final Color lineColor;
  final Color dotColor;
  final int? selectedIndex;

  _TrendLinePainter({
    required this.points,
    required this.valueOf,
    required this.formatValue,
    required this.lineColor,
    required this.dotColor,
    required this.selectedIndex,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      (size.width - leftPad - rightPad).clamp(1.0, double.infinity),
      (size.height - topPad - bottomPad).clamp(1.0, double.infinity),
    );

    final values = points.map(valueOf).toList();
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 1e-9) {
      minV -= 1;
      maxV += 1;
    } else {
      final pad = (maxV - minV) * 0.15;
      minV -= pad;
      maxV += pad;
    }

    double xFor(int i) => points.length == 1
        ? plotRect.center.dx
        : plotRect.left + plotRect.width * i / (points.length - 1);
    double yFor(double v) =>
        plotRect.bottom - (v - minV) / (maxV - minV) * plotRect.height;

    // Recessive gridlines + axis ticks.
    final gridPaint = Paint()
      ..color = const Color(0xFFE6E6E6)
      ..strokeWidth = 1;
    final axisStyle = TextStyle(color: Colors.grey[500], fontSize: 10);
    for (final f in [0.0, 0.5, 1.0]) {
      final y = plotRect.bottom - plotRect.height * f;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
      final tickTp = TextPainter(
        text: TextSpan(
          text: formatValue(minV + (maxV - minV) * f),
          style: axisStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tickTp.paint(canvas, Offset(0, (y - tickTp.height / 2).clamp(0.0, size.height)));
    }

    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(xFor(i), yFor(valueOf(points[i]))),
    ];

    if (offsets.length > 1) {
      final areaPath = Path()..moveTo(offsets.first.dx, plotRect.bottom);
      for (final o in offsets) {
        areaPath.lineTo(o.dx, o.dy);
      }
      areaPath.lineTo(offsets.last.dx, plotRect.bottom);
      areaPath.close();
      canvas.drawPath(areaPath, Paint()..color = lineColor.withValues(alpha: 0.08));

      final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        linePath.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Crosshair for the selected point, drawn under the dots.
    if (selectedIndex != null && selectedIndex! < offsets.length) {
      final x = offsets[selectedIndex!].dx;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        Paint()
          ..color = lineColor.withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
    }

    // Dots: only the endpoint (labeled per "label selectively") and the
    // touched point get drawn — a dot per session would be chart noise at
    // the trend's usual 10-20 point length.
    for (var i = 0; i < offsets.length; i++) {
      final isLast = i == offsets.length - 1;
      final isSelected = i == selectedIndex;
      if (offsets.length > 1 && !isLast && !isSelected) continue;
      final o = offsets[i];
      canvas.drawCircle(o, 7, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5, Paint()..color = dotColor);
    }

    // Endpoint value label.
    final lastOffset = offsets.last;
    final endLabelTp = TextPainter(
      text: TextSpan(
        text: formatValue(valueOf(points.last)),
        style: TextStyle(
          color: lineColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final endLabelAbove = lastOffset.dy - endLabelTp.height - 12 >= topPad - 6;
    endLabelTp.paint(
      canvas,
      Offset(
        (lastOffset.dx - endLabelTp.width / 2).clamp(0.0, size.width - endLabelTp.width),
        endLabelAbove ? lastOffset.dy - endLabelTp.height - 10 : lastOffset.dy + 10,
      ),
    );

    // First/last date labels along the x-axis.
    if (points.length > 1) {
      final dateStyle = TextStyle(color: Colors.grey[500], fontSize: 10);
      final firstTp = TextPainter(
        text: TextSpan(text: _formatDate(points.first.date), style: dateStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      firstTp.paint(canvas, Offset(plotRect.left, size.height - bottomPad + 6));
      final lastTp = TextPainter(
        text: TextSpan(text: _formatDate(points.last.date), style: dateStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      lastTp.paint(
        canvas,
        Offset(plotRect.right - lastTp.width, size.height - bottomPad + 6),
      );
    }

    // Tooltip bubble for the touched point.
    if (selectedIndex != null && selectedIndex! < points.length) {
      final i = selectedIndex!;
      final o = offsets[i];
      final p = points[i];
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${_formatDate(p.date)}\n',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            TextSpan(
              text: formatValue(valueOf(p)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      const hPad = 8.0, vPad = 6.0;
      final bubbleWidth = tp.width + hPad * 2;
      final bubbleHeight = tp.height + vPad * 2;
      final bubbleLeft =
          (o.dx - bubbleWidth / 2).clamp(0.0, size.width - bubbleWidth);
      var bubbleTop = o.dy - bubbleHeight - 14;
      if (bubbleTop < 0) bubbleTop = (o.dy + 14).clamp(0.0, size.height - bubbleHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xFF264358));
      tp.paint(canvas, Offset(bubbleLeft + hPad, bubbleTop + vPad));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor;
}
