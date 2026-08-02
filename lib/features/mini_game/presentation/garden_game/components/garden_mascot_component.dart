import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GardenMascotComponent extends PositionComponent {
  GardenMascotComponent({
    required this.name,
    required this.sprite,
    required this.fallbackColor,
    required this.isLeft,
  }) : super(anchor: Anchor.bottomCenter, priority: 25);

  final String name;
  final Sprite? sprite;
  final Color fallbackColor;
  final bool isLeft;
  final Paint _pixelPaint = Paint()..filterQuality = FilterQuality.none;

  bool _watered = false;
  double _elapsed = 0;
  double _reaction = 0;

  void layoutForScene(Vector2 sceneSize) {
    final mascotWidth = math.max(50, sceneSize.x * .19).toDouble();
    size.setValues(mascotWidth, mascotWidth * 208 / 192);
    position.setValues(
      sceneSize.x * (isLeft ? .17 : .83),
      sceneSize.y * .93,
    );
  }

  void setWatered(bool value) {
    if (value && !_watered) _reaction = 1;
    _watered = value;
  }

  void celebrate() {
    _reaction = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _reaction = math.max(0, _reaction - dt * 1.7).toDouble();
  }

  @override
  void render(Canvas canvas) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: .16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .93),
        width: size.x * .68,
        height: size.y * .09,
      ),
      shadow,
    );

    final phase = isLeft ? .2 : .8;
    final base = Offset(size.x * .5, size.y * .88);
    final idleScale = 1 + math.sin(_elapsed * 1.35 + phase) * .014;
    final reactionScale = 1 + math.sin(_reaction * math.pi) * .075;
    final bob = math.sin(_elapsed * 1.05 + phase) * size.y * .009;
    final wander = math.sin(_elapsed * .48 + phase) * size.x * .016;
    final centerLean =
        math.sin(_elapsed * .72 + phase) * .01 * (isLeft ? 1 : -1);
    final celebrationLean =
        math.sin(_reaction * math.pi) * .045 * (isLeft ? 1 : -1);
    canvas.save();
    canvas.translate(base.dx + wander, base.dy + bob);
    canvas.rotate(centerLean + celebrationLean);
    canvas.scale(idleScale * reactionScale);
    canvas.translate(-base.dx, -base.dy);
    final mascotSprite = sprite;
    if (mascotSprite != null) {
      mascotSprite.render(canvas, size: size, overridePaint: _pixelPaint);
    } else {
      _paintFallbackMascot(canvas);
    }
    canvas.restore();

    if (_watered) {
      _paintHeart(canvas, Offset(size.x * .72, size.y * .18));
    }
  }

  void _paintFallbackMascot(Canvas canvas) {
    final face = Paint()..color = fallbackColor;
    final ear = Paint()..color = fallbackColor.withValues(alpha: .78);
    final center = Offset(size.x * .5, size.y * .52);
    canvas.drawCircle(Offset(size.x * .31, size.y * .3), size.x * .16, ear);
    canvas.drawCircle(Offset(size.x * .69, size.y * .3), size.x * .16, ear);
    canvas.drawCircle(center, size.x * .32, face);
    canvas.drawCircle(
      Offset(size.x * .4, size.y * .49),
      size.x * .04,
      Paint()..color = const Color(0xFF24242B),
    );
    canvas.drawCircle(
      Offset(size.x * .6, size.y * .49),
      size.x * .04,
      Paint()..color = const Color(0xFF24242B),
    );
  }

  void _paintHeart(Canvas canvas, Offset center) {
    final paint = Paint()..color = const Color(0xFFFF8FAA);
    final path = Path()
      ..moveTo(center.dx, center.dy + 6)
      ..cubicTo(center.dx - 12, center.dy - 1, center.dx - 8, center.dy - 10,
          center.dx, center.dy - 3)
      ..cubicTo(center.dx + 8, center.dy - 10, center.dx + 12, center.dy - 1,
          center.dx, center.dy + 6);
    canvas.drawPath(path, paint);
  }
}
