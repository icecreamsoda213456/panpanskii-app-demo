import 'package:flutter/material.dart';

/// One continuous finger stroke on the note canvas.
class WidgetNoteStroke {
  const WidgetNoteStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;
}

/// Renders the hand-drawn strokes on a soft paper background, mirroring the
/// candle-app look: warm cream canvas, rounded pastel strokes.
class WidgetNotePainter extends CustomPainter {
  const WidgetNotePainter({
    required this.strokes,
    this.background = const Color(0xFFFFF6E9),
  });

  final List<WidgetNoteStroke> strokes;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);

    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.isEmpty) {
        continue;
      }

      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          stroke.width / 2,
          Paint()..color = stroke.color,
        );
        continue;
      }

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length; index += 1) {
        path.lineTo(points[index].dx, points[index].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WidgetNotePainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.background != background;
  }
}
