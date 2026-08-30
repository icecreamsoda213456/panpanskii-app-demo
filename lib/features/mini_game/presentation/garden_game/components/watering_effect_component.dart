import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class WateringEffectComponent extends PositionComponent {
  WateringEffectComponent({
    required Vector2 sceneSize,
    required this.target,
    required this.onWaterHit,
    required this.onFinished,
    this.reducedMotion = false,
  }) : super(size: sceneSize, priority: 50);

  static const _duration = 1.35;
  static const _reducedDuration = .7;

  final Vector2 target;
  final VoidCallback onWaterHit;
  final VoidCallback onFinished;
  final bool reducedMotion;
  double _elapsed = 0;
  bool _hasHitPlant = false;
  bool _hasFinished = false;

  double get _totalDuration => reducedMotion ? _reducedDuration : _duration;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final progress = (_elapsed / _totalDuration).clamp(0.0, 1.0).toDouble();
    if (!_hasHitPlant && progress >= .7) {
      _hasHitPlant = true;
      onWaterHit();
    }
    if (!_hasFinished && progress >= 1) {
      _hasFinished = true;
      onFinished();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _totalDuration).clamp(0.0, 1.0).toDouble();
    final enter = (progress / .25).clamp(0.0, 1.0).toDouble();
    final easedEnter = 1 - math.pow(1 - enter, 3).toDouble();
    final canCenter = Offset(
      size.x + 34 - (size.x * .29 + 34) * easedEnter,
      size.y * .28,
    );
    final tilt = progress < .22
        ? 0.0
        : ((progress - .22) / .25).clamp(0.0, 1.0).toDouble() * -.46;
    _paintWateringCan(canvas, canCenter, tilt);

    if (progress > .24 && progress < .92) {
      _paintDroplets(canvas, canCenter, progress);
    }
    if (progress > .68) {
      _paintSplash(canvas, progress);
    }
    if (progress > .7) {
      _paintThankYou(canvas, progress);
    }
  }

  void _paintWateringCan(Canvas canvas, Offset center, double tilt) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    final body = Paint()..color = const Color(0xFF70B9D0);
    const shade = Color(0xFF3E7F9C);
    final shadePaint = Paint()..color = shade;
    final highlight = Paint()..color = const Color(0xFFBEEBEE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-17, -11, 27, 20), const Radius.circular(4)),
      body,
    );
    canvas.drawArc(
      const Rect.fromLTWH(-11, -25, 23, 23),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = shade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final spout = Path()
      ..moveTo(8, -4)
      ..lineTo(29, 4)
      ..lineTo(29, 9)
      ..lineTo(7, 5)
      ..close();
    canvas.drawPath(spout, shadePaint);
    canvas.drawCircle(const Offset(29, 6.5), 4, highlight);
    canvas.drawRect(const Rect.fromLTWH(-10, -7, 10, 3), highlight);
    canvas.restore();
  }

  void _paintDroplets(Canvas canvas, Offset canCenter, double progress) {
    final paint = Paint()..color = const Color(0xFF85D7EC);
    final highlight = Paint()..color = const Color(0xFFD8F6FF);
    final waterProgress = ((progress - .24) / .68).clamp(0.0, 1.0).toDouble();
    final source = Offset(canCenter.dx + 24, canCenter.dy + 8);
    for (var index = 0; index < 9; index += 1) {
      final dropletProgress =
          (waterProgress - index * .062).clamp(0.0, 1.0).toDouble();
      if (dropletProgress <= 0) continue;
      final x = source.dx +
          (target.x - source.dx) * dropletProgress +
          math.sin(index * 2.1) * 3;
      final y = source.dy +
          (target.y - source.dy) * dropletProgress +
          dropletProgress * dropletProgress * 14;
      // Droplets stretch as they fall, then shrink as they near the soil.
      final fade = 1 - math.pow(dropletProgress, 3).toDouble() * .55;
      final radius = (2.6 + math.sin(index * 1.3) * .5) * fade;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 2,
          height: radius * 2.7,
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(x - radius * .3, y - radius * .5),
        math.max(.6, radius * .32),
        highlight,
      );
    }
  }

  /// Small burst where the water meets the soil.
  void _paintSplash(Canvas canvas, double progress) {
    final splash = ((progress - .68) / .24).clamp(0.0, 1.0).toDouble();
    if (splash <= 0 || splash >= 1) return;
    final alpha = (1 - splash).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..color = const Color(0xFFBDEEFF).withValues(alpha: alpha * .9);
    final origin = Offset(target.x, target.y + size.y * .04);
    for (var index = 0; index < 6; index += 1) {
      final angle = math.pi + (index / 5) * math.pi;
      final distance = splash * size.x * .07;
      final center = Offset(
        origin.dx + math.cos(angle) * distance,
        origin.dy + math.sin(angle) * distance * .5,
      );
      canvas.drawCircle(center, math.max(.8, 2.4 * alpha), paint);
    }
  }

  void _paintThankYou(Canvas canvas, double progress) {
    final alpha = ((1 - progress) / .3).clamp(0.0, 1.0).toDouble();
    if (alpha <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFFFFD987).withValues(alpha: alpha);
    final center = Offset(target.x, target.y - size.y * .1);
    canvas.drawCircle(center, 4, paint);
    canvas.drawLine(Offset(center.dx - 6, center.dy),
        Offset(center.dx + 6, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 6),
        Offset(center.dx, center.dy + 6), paint);
  }
}
