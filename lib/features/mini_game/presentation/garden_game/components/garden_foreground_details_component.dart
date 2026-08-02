import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

/// A light foreground pass that makes the garden floor feel layered without
/// adding state, assets, or extra game objects.
class GardenForegroundDetailsComponent extends PositionComponent {
  GardenForegroundDetailsComponent({
    GardenTimeOfDay timeOfDay = GardenTimeOfDay.day,
  })  : _timeOfDay = timeOfDay,
        super(priority: 18);

  GardenTimeOfDay _timeOfDay;

  void layoutForScene(Vector2 sceneSize) {
    size.setFrom(sceneSize);
    position.setZero();
  }

  void updateTimeOfDay(GardenTimeOfDay value) {
    _timeOfDay = value;
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    _paintForegroundGrass(canvas);
    _paintRockClusters(canvas);
    _paintFlowerCorners(canvas);
  }

  void _paintForegroundGrass(Canvas canvas) {
    final color = switch (_timeOfDay) {
      GardenTimeOfDay.morning => const Color(0xFF4A9157),
      GardenTimeOfDay.day => const Color(0xFF347B49),
      GardenTimeOfDay.sunset => const Color(0xFF506A4B),
      GardenTimeOfDay.night => const Color(0xFF274D46),
    };
    final grass = Paint()
      ..color = color.withValues(alpha: .84)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const tufts = <Offset>[
      Offset(.04, .94),
      Offset(.12, .9),
      Offset(.21, .96),
      Offset(.76, .96),
      Offset(.88, .91),
      Offset(.96, .95),
    ];
    for (final tuft in tufts) {
      final origin = Offset(size.x * tuft.dx, size.y * tuft.dy);
      canvas.drawLine(
          origin, origin.translate(-size.x * .018, -size.y * .05), grass);
      canvas.drawLine(
          origin, origin.translate(size.x * .014, -size.y * .055), grass);
      canvas.drawLine(
          origin, origin.translate(size.x * .003, -size.y * .067), grass);
    }
  }

  void _paintRockClusters(Canvas canvas) {
    final rock = Paint()..color = const Color(0xFFB7AF9B).withValues(alpha: .7);
    final shade = Paint()
      ..color = const Color(0xFF746E68).withValues(alpha: .42);
    for (final point in const <Offset>[
      Offset(.26, .91),
      Offset(.71, .92),
      Offset(.94, .84),
    ]) {
      final center = Offset(size.x * point.dx, size.y * point.dy);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.x * .035,
          height: size.y * .022,
        ),
        rock,
      );
      canvas.drawLine(
        center.translate(-size.x * .009, 0),
        center.translate(size.x * .009, 0),
        shade..strokeWidth = 1,
      );
    }
  }

  void _paintFlowerCorners(Canvas canvas) {
    final petals = <Paint>[
      Paint()..color = const Color(0xFFFFC3D5),
      Paint()..color = const Color(0xFFFFE28A),
    ];
    final centerPaint = Paint()..color = const Color(0xFFFFF7BE);
    for (var index = 0; index < 2; index += 1) {
      final point =
          index == 0 ? const Offset(.08, .82) : const Offset(.91, .82);
      final center = Offset(size.x * point.dx, size.y * point.dy);
      final petal = petals[index];
      canvas.drawCircle(center.translate(-2.2, 0), 2, petal);
      canvas.drawCircle(center.translate(2.2, 0), 2, petal);
      canvas.drawCircle(center.translate(0, -2.2), 2, petal);
      canvas.drawCircle(center, 1.25, centerPaint);
    }
  }
}
