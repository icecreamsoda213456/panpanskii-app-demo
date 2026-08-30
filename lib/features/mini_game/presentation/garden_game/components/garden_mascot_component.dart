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
  bool _reducedMotion = false;
  double _elapsed = 0;
  double _reaction = 0;
  double _attention = 0;
  double _attentionTarget = 0;
  double _hop = 0;

  /// Each mascot animates on its own frequency so the pair never looks like a
  /// single sprite mirrored twice.
  double get _idlePhase => isLeft ? .2 : 2.35;
  double get _breathRate => isLeft ? 1.35 : 1.12;
  double get _bobRate => isLeft ? 1.05 : .87;
  double get _wanderRate => isLeft ? .48 : .61;

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

  /// Short happy hop for a shared milestone (both watered / Daily Duo done).
  void cheer() {
    _reaction = 1;
    _hop = 1;
  }

  /// Turns the mascot's gaze toward the plant while watering is playing.
  void setWatchingPlant(bool value) {
    _attentionTarget = value ? 1 : 0;
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _reaction = math.max(0, _reaction - dt * 1.7).toDouble();
    _hop = math.max(0, _hop - dt * 1.9).toDouble();
    final attentionDelta = dt * 2.6;
    if (_attention < _attentionTarget) {
      _attention = math.min(_attentionTarget, _attention + attentionDelta);
    } else if (_attention > _attentionTarget) {
      _attention = math.max(_attentionTarget, _attention - attentionDelta);
    }
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

    final phase = _idlePhase;
    final base = Offset(size.x * .5, size.y * .88);
    final motion = _reducedMotion ? 0.0 : 1.0;
    final idleScale =
        1 + math.sin(_elapsed * _breathRate + phase) * .014 * motion;
    final reactionScale = 1 + math.sin(_reaction * math.pi) * .075;
    final bob = math.sin(_elapsed * _bobRate + phase) * size.y * .009 * motion;
    final hopLift = math.sin(_hop * math.pi) * size.y * .06;
    final wander =
        math.sin(_elapsed * _wanderRate + phase) * size.x * .016 * motion;
    final centerLean =
        math.sin(_elapsed * .72 + phase) * .01 * (isLeft ? 1 : -1) * motion;
    final celebrationLean =
        math.sin(_reaction * math.pi) * .045 * (isLeft ? 1 : -1);
    // Lean in toward the plant (scene centre) when watching it grow.
    final watchLean = _attention * .12 * (isLeft ? 1 : -1);
    final watchShift = _attention * size.x * .05 * (isLeft ? 1 : -1);
    canvas.save();
    canvas.translate(base.dx + wander + watchShift, base.dy + bob - hopLift);
    canvas.rotate(centerLean + celebrationLean + watchLean);
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
