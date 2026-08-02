import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

class GardenBackgroundComponent extends PositionComponent {
  GardenBackgroundComponent({
    required this.sceneSprite,
    GardenTimeOfDay timeOfDay = GardenTimeOfDay.day,
  })  : _timeOfDay = timeOfDay,
        super(priority: 0);

  final Sprite? sceneSprite;
  final Paint _pixelPaint = Paint()..filterQuality = FilterQuality.none;
  GardenTimeOfDay _timeOfDay;

  void updateTimeOfDay(GardenTimeOfDay value) {
    _timeOfDay = value;
  }

  @override
  void render(Canvas canvas) {
    final sceneRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(sceneRect, Paint()..color = _skyColor);
    final sprite = sceneSprite;
    if (sprite != null) {
      final sourceSize = sprite.originalSize;
      final scale = math.max(size.x / sourceSize.x, size.y / sourceSize.y);
      final renderSize = Vector2(sourceSize.x * scale, sourceSize.y * scale);
      sprite.render(
        canvas,
        position: Vector2(
          (size.x - renderSize.x) * .5,
          (size.y - renderSize.y) * .5,
        ),
        size: renderSize,
        overridePaint: _pixelPaint,
      );
    } else {
      _paintFallbackLandscape(canvas, sceneRect);
    }

    _paintDistantLayers(canvas);

    final overlay = _overlayColor;
    if (overlay.a > 0) {
      canvas.drawRect(sceneRect, Paint()..color = overlay);
    }
    _paintSkyDetails(canvas);
  }

  Color get _skyColor => switch (_timeOfDay) {
        GardenTimeOfDay.morning => const Color(0xFFCBE8B7),
        GardenTimeOfDay.day => const Color(0xFFBDE3A5),
        GardenTimeOfDay.sunset => const Color(0xFFF2B188),
        GardenTimeOfDay.night => const Color(0xFF15284D),
      };

  Color get _overlayColor => switch (_timeOfDay) {
        GardenTimeOfDay.morning => const Color(0x14FFE6B0),
        GardenTimeOfDay.day => Colors.transparent,
        GardenTimeOfDay.sunset => const Color(0x4DDE766D),
        GardenTimeOfDay.night => const Color(0x8F102147),
      };

  void _paintFallbackLandscape(Canvas canvas, Rect sceneRect) {
    final groundTop = sceneRect.height * .66;
    canvas.drawRect(
      Rect.fromLTWH(
          0, groundTop, sceneRect.width, sceneRect.height - groundTop),
      Paint()..color = const Color(0xFF86B968),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(sceneRect.width * .5, sceneRect.height * .82),
          width: sceneRect.width * .56,
          height: sceneRect.height * .2,
        ),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF8C5B43),
    );
  }

  void _paintSkyDetails(Canvas canvas) {
    switch (_timeOfDay) {
      case GardenTimeOfDay.morning:
      case GardenTimeOfDay.day:
        canvas.drawCircle(
          Offset(size.x * .84, size.y * .16),
          size.x * .055,
          Paint()..color = const Color(0xFFFFE6A0),
        );
      case GardenTimeOfDay.sunset:
        canvas.drawCircle(
          Offset(size.x * .17, size.y * .23),
          size.x * .06,
          Paint()..color = const Color(0xFFFFD18A),
        );
      case GardenTimeOfDay.night:
        _paintMoonAndStars(canvas);
    }
  }

  void _paintDistantLayers(Canvas canvas) {
    final horizon = size.y * .58;
    final farHill = Path()
      ..moveTo(0, horizon)
      ..quadraticBezierTo(size.x * .18, size.y * .4, size.x * .38, horizon)
      ..quadraticBezierTo(size.x * .6, size.y * .35, size.x, horizon)
      ..lineTo(size.x, size.y * .7)
      ..lineTo(0, size.y * .7)
      ..close();
    final hillColor = switch (_timeOfDay) {
      GardenTimeOfDay.morning => const Color(0xFF83B67C),
      GardenTimeOfDay.day => const Color(0xFF6FA873),
      GardenTimeOfDay.sunset => const Color(0xFF8A765E),
      GardenTimeOfDay.night => const Color(0xFF1A4050),
    };
    canvas.drawPath(farHill, Paint()..color = hillColor.withValues(alpha: .32));
    _paintDistantGreenhouse(canvas);

    if (_timeOfDay == GardenTimeOfDay.morning) {
      final mist = Paint()
        ..color = const Color(0xFFEAF4D8).withValues(alpha: .16);
      canvas.drawRect(
        Rect.fromLTWH(0, size.y * .48, size.x, size.y * .035),
        mist,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, size.y * .54, size.x, size.y * .02),
        mist..color = const Color(0xFFEAF4D8).withValues(alpha: .1),
      );
    }
    if (_timeOfDay == GardenTimeOfDay.sunset) {
      final warmBand = Paint()
        ..color = const Color(0xFFFFC17E).withValues(alpha: .12);
      canvas.drawRect(
        Rect.fromLTWH(0, size.y * .35, size.x, size.y * .065),
        warmBand,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, size.y * .42, size.x, size.y * .04),
        warmBand..color = const Color(0xFFE77C6C).withValues(alpha: .1),
      );
    }
  }

  void _paintDistantGreenhouse(Canvas canvas) {
    final width = size.x * .23;
    final height = size.y * .16;
    final left = size.x * .67;
    final top = size.y * .43;
    final tint = switch (_timeOfDay) {
      GardenTimeOfDay.morning => const Color(0xFFC6E9D4),
      GardenTimeOfDay.day => const Color(0xFFB2DCCE),
      GardenTimeOfDay.sunset => const Color(0xFFE7B58D),
      GardenTimeOfDay.night => const Color(0xFF355369),
    };
    final frame = Paint()
      ..color = const Color(0xFF5B6E5E).withValues(alpha: .46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.x * .005).toDouble();
    final glass = Paint()..color = tint.withValues(alpha: .26);
    final body = Rect.fromLTWH(left, top + height * .3, width, height * .7);
    final roof = Path()
      ..moveTo(left - width * .06, top + height * .32)
      ..lineTo(left + width * .5, top)
      ..lineTo(left + width * 1.06, top + height * .32)
      ..close();
    canvas.drawRect(body, glass);
    canvas.drawPath(roof, glass);
    canvas.drawRect(body, frame);
    canvas.drawPath(roof, frame);
    canvas.drawLine(
      Offset(left + width * .5, top + height * .05),
      Offset(left + width * .5, top + height),
      frame,
    );
    canvas.drawLine(
      Offset(left, top + height * .62),
      Offset(left + width, top + height * .62),
      frame,
    );
  }

  void _paintMoonAndStars(Canvas canvas) {
    final moon = Offset(size.x * .83, size.y * .17);
    canvas.drawCircle(
        moon, size.x * .052, Paint()..color = const Color(0xFFFFF2C4));
    canvas.drawCircle(
      Offset(moon.dx + size.x * .018, moon.dy - size.x * .01),
      size.x * .052,
      Paint()..color = const Color(0xFF15284D),
    );
    final starPaint = Paint()
      ..color = const Color(0xFFFFF4BE).withValues(alpha: .8);
    final stars = [
      Offset(size.x * .1, size.y * .11),
      Offset(size.x * .26, size.y * .2),
      Offset(size.x * .45, size.y * .1),
      Offset(size.x * .62, size.y * .27),
      Offset(size.x * .72, size.y * .08),
    ];
    for (final star in stars) {
      canvas.drawCircle(star, 1.3, starPaint);
    }
  }
}
