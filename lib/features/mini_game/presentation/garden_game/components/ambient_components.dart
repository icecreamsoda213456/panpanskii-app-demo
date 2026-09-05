import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

class GardenCloudComponent extends PositionComponent {
  GardenCloudComponent({
    required this.relativeX,
    required this.relativeY,
    required this.speedFactor,
  }) : super(priority: 4);

  final double relativeX;
  final double relativeY;
  final double speedFactor;
  Vector2 _sceneSize = Vector2.zero();
  GardenTimeOfDay _timeOfDay = GardenTimeOfDay.day;
  bool _hasLaidOut = false;
  bool _reducedMotion = false;

  void layoutForScene(Vector2 sceneSize) {
    _sceneSize = sceneSize.clone();
    final width = sceneSize.x * .24;
    size.setValues(width, width * .26);
    if (!_hasLaidOut) {
      position.setValues(sceneSize.x * relativeX, sceneSize.y * relativeY);
      _hasLaidOut = true;
    } else {
      position.y = sceneSize.y * relativeY;
    }
  }

  void updateTimeOfDay(GardenTimeOfDay value) {
    _timeOfDay = value;
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reducedMotion || _sceneSize.x <= 0) return;
    final timeMultiplier = switch (_timeOfDay) {
      GardenTimeOfDay.morning => .68,
      GardenTimeOfDay.day => 1.0,
      GardenTimeOfDay.sunset => .78,
      GardenTimeOfDay.night => .42,
    };
    position.x += _sceneSize.x * speedFactor * timeMultiplier * dt;
    if (position.x - size.x > _sceneSize.x) position.x = -size.x;
  }

  @override
  void render(Canvas canvas) {
    final alpha = switch (_timeOfDay) {
      GardenTimeOfDay.morning => .4,
      GardenTimeOfDay.day => .52,
      GardenTimeOfDay.sunset => .3,
      GardenTimeOfDay.night => .18,
    };
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
    canvas.drawOval(
      Rect.fromLTWH(size.x * .05, size.y * .32, size.x * .48, size.y * .46),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .27, size.y * .1, size.x * .42, size.y * .64),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .53, size.y * .3, size.x * .4, size.y * .48),
      paint,
    );
  }
}

class GardenButterflyComponent extends PositionComponent {
  GardenButterflyComponent() : super(priority: 32);

  Vector2 _sceneSize = Vector2.zero();
  double _elapsed = 0;
  bool _reducedMotion = false;

  void layoutForScene(Vector2 sceneSize) {
    _sceneSize = sceneSize.clone();
    final wingSpan = math.max(13, sceneSize.x * .05).toDouble();
    size.setValues(wingSpan, wingSpan * .58);
    if (_reducedMotion) _setRestingPosition();
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
    if (value) _setRestingPosition();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reducedMotion) {
      _setRestingPosition();
      return;
    }
    _elapsed += dt;
    if (_sceneSize.x <= 0) return;
    position.setValues(
      _sceneSize.x * (.58 + math.sin(_elapsed * .55) * .16),
      _sceneSize.y * (.28 + math.cos(_elapsed * 1.1) * .08),
    );
  }

  @override
  void render(Canvas canvas) {
    final flap = _reducedMotion ? .7 : math.sin(_elapsed * 9).abs();
    final wing = Paint()
      ..color = flap > .45 ? const Color(0xFFFFB1C7) : const Color(0xFFFFD46D);
    final body = Paint()..color = const Color(0xFF5D4843);
    canvas.drawOval(
      Rect.fromLTWH(0, size.y * .2, size.x * .46, size.y * .62),
      wing,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .54, size.y * .2, size.x * .46, size.y * .62),
      wing,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * .45, size.y * .2, size.x * .1, size.y * .72),
      body,
    );
  }

  void _setRestingPosition() {
    if (_sceneSize.x <= 0) return;
    position.setValues(_sceneSize.x * .67, _sceneSize.y * .3);
  }
}

class GardenBeeComponent extends PositionComponent {
  GardenBeeComponent() : super(priority: 31);

  Vector2 _sceneSize = Vector2.zero();
  bool _active = false;
  double _elapsed = 0;
  bool _reducedMotion = false;

  void layoutForScene(Vector2 sceneSize) {
    _sceneSize = sceneSize.clone();
    final width = math.max(11, sceneSize.x * .04).toDouble();
    size.setValues(width, width * .75);
    if (_reducedMotion) _setRestingPosition();
  }

  void setActive(bool value) {
    _active = value;
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
    if (value) _setRestingPosition();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reducedMotion) {
      _setRestingPosition();
      return;
    }
    _elapsed += dt;
    if (!_active || _sceneSize.x <= 0) return;
    position.setValues(
      _sceneSize.x * .5 + math.cos(_elapsed * 1.4) * _sceneSize.x * .13,
      _sceneSize.y * .55 + math.sin(_elapsed * 1.8) * _sceneSize.y * .09,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    final wing = Paint()..color = const Color(0xFFCDE9FF).withValues(alpha: .8);
    final body = Paint()..color = const Color(0xFFFFD44F);
    final stripe = Paint()..color = const Color(0xFF4A3B32);
    canvas.drawOval(
      Rect.fromLTWH(size.x * .08, 0, size.x * .45, size.y * .42),
      wing,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .48, 0, size.x * .45, size.y * .42),
      wing,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .15, size.y * .35, size.x * .7, size.y * .5),
      body,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * .4, size.y * .35, size.x * .12, size.y * .5),
      stripe,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * .62, size.y * .35, size.x * .12, size.y * .5),
      stripe,
    );
  }

  void _setRestingPosition() {
    if (_sceneSize.x <= 0) return;
    position.setValues(_sceneSize.x * .63, _sceneSize.y * .52);
  }
}

class GardenAmbientParticles extends PositionComponent {
  GardenAmbientParticles() : super(priority: 34);

  GardenTimeOfDay _timeOfDay = GardenTimeOfDay.day;
  int _growth = 0;
  bool _reducedMotion = false;
  double _elapsed = 0;
  double _celebration = 0;

  void layoutForScene(Vector2 sceneSize) {
    size.setFrom(sceneSize);
    position.setZero();
  }

  void setConditions({
    required GardenTimeOfDay timeOfDay,
    required int growth,
  }) {
    _timeOfDay = timeOfDay;
    _growth = growth;
  }

  /// When reduced motion is requested we keep the ambient layer visible but
  /// stop the continuous drifting animation.
  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  void triggerCelebration() {
    _celebration = 1.25;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Celebrations still resolve under reduced motion, but the idle drift
    // clock is frozen so nothing loops forever on screen.
    if (!_reducedMotion) _elapsed += dt;
    _celebration = math.max(0, _celebration - dt).toDouble();
  }

  @override
  void render(Canvas canvas) {
    if (_timeOfDay == GardenTimeOfDay.night) {
      _paintFireflies(canvas);
    } else {
      _paintDriftingLeaves(canvas);
      if (_growth >= 65) _paintPollen(canvas);
    }
    if (_growth >= 100) _paintBloomSparkles(canvas);
    if (_celebration > 0) _paintCelebration(canvas);
  }

  void _paintFireflies(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFF48C);
    for (var index = 0; index < 7; index += 1) {
      final phase = _elapsed * 1.8 + index;
      final point = Offset(
        size.x * (.12 + (index * .13 % .76)),
        size.y * (.35 + math.sin(phase) * .08),
      );
      canvas.drawCircle(point, 1.2 + math.sin(phase).abs(), paint);
    }
  }

  void _paintPollen(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFFFE78B).withValues(alpha: .72);
    final count = _growth >= 100 ? 9 : 6;
    for (var index = 0; index < count; index += 1) {
      final point = Offset(
        size.x * (.2 + index * .075),
        size.y * (.37 + math.sin(_elapsed + index) * .075),
      );
      canvas.drawCircle(point, 1.4, paint);
    }
  }

  void _paintDriftingLeaves(Canvas canvas) {
    final petalColor = _timeOfDay == GardenTimeOfDay.sunset
        ? const Color(0xFFFFC69C)
        : const Color(0xFFF8F0BA);
    final paint = Paint()..color = petalColor.withValues(alpha: .52);
    for (var index = 0; index < 4; index += 1) {
      final phase = _elapsed * (.35 + index * .04) + index * 1.8;
      final center = Offset(
        size.x * (.18 + index * .2 + math.sin(phase) * .035),
        size.y * (.26 + (index % 2) * .12 + math.cos(phase * 1.4) * .035),
      );
      final leaf = Path()
        ..moveTo(center.dx, center.dy - 2.8)
        ..lineTo(center.dx + 2.6, center.dy)
        ..lineTo(center.dx, center.dy + 2.8)
        ..lineTo(center.dx - 2.6, center.dy)
        ..close();
      canvas.drawPath(leaf, paint);
    }
  }

  void _paintBloomSparkles(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFFFF4B8).withValues(alpha: .78)
      ..strokeWidth = 1.2;
    for (final point in <Offset>[
      Offset(size.x * .35, size.y * .36),
      Offset(size.x * .66, size.y * .42),
      Offset(size.x * .52, size.y * .28),
    ]) {
      final pulse = 1.5 + math.sin(_elapsed * 2.4 + point.dx).abs();
      canvas.drawLine(
        point.translate(-pulse, 0),
        point.translate(pulse, 0),
        paint,
      );
      canvas.drawLine(
        point.translate(0, -pulse),
        point.translate(0, pulse),
        paint,
      );
    }
  }

  void _paintCelebration(Canvas canvas) {
    final alpha = _celebration.clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..color = const Color(0xFFFF8FAA).withValues(alpha: alpha);
    final center = Offset(size.x * .5, size.y * .58 - (1 - alpha) * 18);
    final heart = Path()
      ..moveTo(center.dx, center.dy + 8)
      ..cubicTo(center.dx - 15, center.dy - 2, center.dx - 9, center.dy - 12,
          center.dx, center.dy - 4)
      ..cubicTo(center.dx + 9, center.dy - 12, center.dx + 15, center.dy - 2,
          center.dx, center.dy + 8);
    canvas.drawPath(heart, paint);
    final sparkle = Paint()
      ..color = const Color(0xFFFFEA9B).withValues(alpha: alpha);
    for (final point in [
      Offset(center.dx - 24, center.dy - 2),
      Offset(center.dx + 24, center.dy + 4),
    ]) {
      canvas.drawCircle(point, 2, sparkle);
      canvas.drawLine(Offset(point.dx - 3, point.dy),
          Offset(point.dx + 3, point.dy), sparkle);
      canvas.drawLine(Offset(point.dx, point.dy - 3),
          Offset(point.dx, point.dy + 3), sparkle);
    }
  }
}
