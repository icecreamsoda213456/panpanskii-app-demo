import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

/// A painted midground that gives the garden its shared, lived-in place.
/// It deliberately sits behind the plant and mascots, so gameplay state stays
/// entirely in the existing components.
class GardenTerrainComponent extends PositionComponent {
  GardenTerrainComponent({
    GardenTimeOfDay timeOfDay = GardenTimeOfDay.day,
  })  : _timeOfDay = timeOfDay,
        super(priority: 10);

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
    _paintGroundWash(canvas);
    _paintDistantHedge(canvas);
    _paintFence(canvas);
    _paintPlantingBed(canvas);
    _paintPath(canvas);
    _paintFlowersAndGrass(canvas);
  }

  void _paintGroundWash(Canvas canvas) {
    final color = switch (_timeOfDay) {
      GardenTimeOfDay.morning => const Color(0xFF93C873),
      GardenTimeOfDay.day => const Color(0xFF68A85D),
      GardenTimeOfDay.sunset => const Color(0xFF6E8455),
      GardenTimeOfDay.night => const Color(0xFF203E43),
    };
    canvas.drawRect(
      Rect.fromLTWH(0, size.y * .62, size.x, size.y * .38),
      Paint()..color = color.withValues(alpha: .26),
    );
  }

  void _paintDistantHedge(Canvas canvas) {
    final hedgeColor = switch (_timeOfDay) {
      GardenTimeOfDay.morning => const Color(0xFF79AD6D),
      GardenTimeOfDay.day => const Color(0xFF5C9864),
      GardenTimeOfDay.sunset => const Color(0xFF71805F),
      GardenTimeOfDay.night => const Color(0xFF1D4A4A),
    };
    final hedge = Paint()..color = hedgeColor.withValues(alpha: .72);
    final path = Path()..moveTo(0, size.y * .65);
    for (var index = 0; index <= 12; index += 1) {
      final x = size.x * index / 12;
      final crest = size.y * (.58 + (index.isEven ? .012 : -.018));
      path.quadraticBezierTo(
        x - size.x * .04,
        crest - size.y * .05,
        x,
        crest,
      );
    }
    path
      ..lineTo(size.x, size.y * .69)
      ..lineTo(0, size.y * .69)
      ..close();
    canvas.drawPath(path, hedge);
  }

  void _paintFence(Canvas canvas) {
    final rail = Paint()
      ..color = const Color(0xFF8A5D45).withValues(alpha: .74)
      ..strokeWidth = math.max(2, size.x * .012).toDouble();
    final slat = Paint()
      ..color = const Color(0xFFC98D62).withValues(alpha: .84);
    final shadow = Paint()
      ..color = const Color(0xFF60402F).withValues(alpha: .55);
    final top = size.y * .58;
    final height = size.y * .14;
    final slatWidth = math.max(7, size.x * .026).toDouble();

    canvas.drawLine(
      Offset(0, top + height * .3),
      Offset(size.x, top + height * .3),
      rail,
    );
    canvas.drawLine(
      Offset(0, top + height * .72),
      Offset(size.x, top + height * .72),
      rail,
    );
    for (var index = 0; index <= 14; index += 1) {
      final x = size.x * index / 14 - slatWidth * .5;
      final rect = Rect.fromLTWH(x, top, slatWidth, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        slat,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, top + height * .73, slatWidth, height * .13),
        shadow,
      );
    }
  }

  void _paintPlantingBed(Canvas canvas) {
    final bed = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .81),
        width: size.x * .58,
        height: size.y * .23,
      ),
      Radius.circular(size.x * .14),
    );
    canvas.drawRRect(
      bed,
      Paint()..color = const Color(0xFF59423A).withValues(alpha: .64),
    );
    final innerBed = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .805),
        width: size.x * .5,
        height: size.y * .17,
      ),
      Radius.circular(size.x * .12),
    );
    canvas.drawRRect(
      innerBed,
      Paint()..color = const Color(0xFF9A6A4C).withValues(alpha: .78),
    );
    canvas.drawRRect(
      innerBed,
      Paint()
        ..color = const Color(0xFFD2A06B).withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, size.x * .005).toDouble(),
    );
    final stone = Paint()
      ..color = const Color(0xFFCCC1AC).withValues(alpha: .62);
    for (final offset in const <Offset>[
      Offset(.29, .81),
      Offset(.34, .87),
      Offset(.67, .87),
      Offset(.72, .81),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * offset.dx, size.y * offset.dy),
          width: size.x * .036,
          height: size.y * .022,
        ),
        stone,
      );
    }
    final soilMark = Paint()
      ..color = const Color(0xFF6E4839).withValues(alpha: .72)
      ..strokeWidth = math.max(1.5, size.x * .006).toDouble()
      ..strokeCap = StrokeCap.round;
    for (final offset in const <Offset>[
      Offset(.35, .79),
      Offset(.42, .83),
      Offset(.61, .8),
      Offset(.69, .84),
    ]) {
      canvas.drawLine(
        Offset(size.x * offset.dx, size.y * offset.dy),
        Offset(size.x * (offset.dx + .045), size.y * (offset.dy + .012)),
        soilMark,
      );
    }
  }

  void _paintPath(Canvas canvas) {
    final stone = Paint()
      ..color = const Color(0xFFCFC3A7).withValues(alpha: .62);
    final stoneShade = Paint()
      ..color = const Color(0xFF8E8A7D).withValues(alpha: .38);
    final stones = <Rect>[
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .95),
        width: size.x * .13,
        height: size.y * .045,
      ),
      Rect.fromCenter(
        center: Offset(size.x * .42, size.y * .91),
        width: size.x * .1,
        height: size.y * .04,
      ),
      Rect.fromCenter(
        center: Offset(size.x * .58, size.y * .89),
        width: size.x * .09,
        height: size.y * .035,
      ),
    ];
    for (final rect in stones) {
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rounded, stone);
      canvas.drawLine(
        Offset(rect.left + rect.width * .18, rect.center.dy),
        Offset(rect.right - rect.width * .18, rect.center.dy),
        stoneShade..strokeWidth = 1.2,
      );
    }
  }

  void _paintFlowersAndGrass(Canvas canvas) {
    final grass = Paint()
      ..color = const Color(0xFF367047).withValues(alpha: .72)
      ..strokeWidth = math.max(1.2, size.x * .004).toDouble()
      ..strokeCap = StrokeCap.round;
    final grassPoints = const <Offset>[
      Offset(.07, .84),
      Offset(.14, .75),
      Offset(.25, .88),
      Offset(.76, .86),
      Offset(.88, .77),
      Offset(.95, .89),
    ];
    for (final point in grassPoints) {
      final origin = Offset(size.x * point.dx, size.y * point.dy);
      canvas.drawLine(
          origin, origin.translate(-size.x * .014, -size.y * .035), grass);
      canvas.drawLine(
          origin, origin.translate(size.x * .014, -size.y * .032), grass);
    }

    final stem = Paint()
      ..color = const Color(0xFF4B8D59)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final petals = <Paint>[
      Paint()..color = const Color(0xFFFFD878),
      Paint()..color = const Color(0xFFFFA6B9),
      Paint()..color = const Color(0xFFCBA4EE),
    ];
    final flowers = const <Offset>[
      Offset(.11, .71),
      Offset(.22, .78),
      Offset(.78, .75),
      Offset(.91, .7),
    ];
    for (var index = 0; index < flowers.length; index += 1) {
      final point = flowers[index];
      final center = Offset(size.x * point.dx, size.y * point.dy);
      canvas.drawLine(
        center.translate(0, size.y * .025),
        center,
        stem,
      );
      final petal = petals[index % petals.length];
      canvas.drawCircle(center.translate(-2, 0), 2.1, petal);
      canvas.drawCircle(center.translate(2, 0), 2.1, petal);
      canvas.drawCircle(center.translate(0, -2), 2.1, petal);
      canvas.drawCircle(center, 1.4, Paint()..color = const Color(0xFFFFF3AD));
    }
  }
}
