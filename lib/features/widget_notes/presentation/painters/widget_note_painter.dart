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
    // Strokes mutate in place: only the POINTS on a shared stroke list are
    // appended during a drag, and the State widget keeps holding the exact
    // same list object from one build to the next. Because old and new
    // delegates therefore read the SAME (already-mutated) object when we
    // compare them here, comparing stroke counts or point lengths can never
    // detect the change — so shouldRepaint would return false and the canvas
    // would not repaint live while the user draws.
    //
    // The canvas is small and repaints are cheap, so we always repaint on
    // rebuild. Length changes (new stroke, undo, clear) and color/width
    // touches all flow through setState too, so they are covered as well.
    return true;
  }
}
