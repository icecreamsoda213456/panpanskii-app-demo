import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

/// Small Canvas fallbacks for Phase 2 decor. Dedicated art can replace these
/// without changing CozyGardenGame's state flow.
class GardenDecorationComponent extends PositionComponent {
  GardenDecorationComponent({
    required this.decorationId,
    GardenTimeOfDay timeOfDay = GardenTimeOfDay.day,
  })  : _timeOfDay = timeOfDay,
        super(anchor: Anchor.bottomCenter, priority: 16);

  static const supportedIds = <String>{
    'mushroom',
    'lantern',
    'wooden_sign',
    'couple_bench',
  };

  final String decorationId;
  GardenTimeOfDay _timeOfDay;
  double _elapsed = 0;
  bool _reducedMotion = false;

  void updateTimeOfDay(GardenTimeOfDay value) {
    _timeOfDay = value;
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  void layoutForScene(Vector2 sceneSize) {
    switch (decorationId) {
      case 'mushroom':
        // Foreground-left cluster, clear of the plant's wider footprint.
        size.setValues(sceneSize.x * .1, sceneSize.x * .1);
        position.setValues(sceneSize.x * .25, sceneSize.y * .9);
        break;
      case 'lantern':
        // Right edge, slightly higher so its glow reads as a back layer.
        size.setValues(sceneSize.x * .11, sceneSize.x * .18);
        position.setValues(sceneSize.x * .91, sceneSize.y * .825);
        break;
      case 'wooden_sign':
        size.setValues(sceneSize.x * .17, sceneSize.x * .16);
        position.setValues(sceneSize.x * .1, sceneSize.y * .845);
        break;
      case 'couple_bench':
        // Mid-ground bench: narrower and pushed right so it tucks behind the
        // plant instead of competing with it.
        size.setValues(sceneSize.x * .24, sceneSize.x * .12);
        position.setValues(sceneSize.x * .73, sceneSize.y * .875);
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_reducedMotion) _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    switch (decorationId) {
      case 'mushroom':
        _paintMushroom(canvas);
        break;
      case 'lantern':
        _paintLantern(canvas);
        break;
      case 'wooden_sign':
        _paintWoodenSign(canvas);
        break;
      case 'couple_bench':
        _paintCoupleBench(canvas);
        break;
    }
  }

  void _paintMushroom(Canvas canvas) {
    final shadow = Paint()..color = Colors.black.withValues(alpha: .16);
    final stem = Paint()..color = const Color(0xFFFFF5DE);
    final cap = Paint()..color = const Color(0xFFF07869);
    final dot = Paint()..color = const Color(0xFFFFEFD5);
    canvas.drawOval(
      Rect.fromLTWH(size.x * .18, size.y * .77, size.x * .66, size.y * .13),
      shadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .39, size.y * .48, size.x * .23, size.y * .4),
        const Radius.circular(3),
      ),
      stem,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.x * .14, size.y * .17, size.x * .72, size.y * .45),
      cap,
    );
    canvas.drawCircle(Offset(size.x * .38, size.y * .35), size.x * .06, dot);
    canvas.drawCircle(Offset(size.x * .62, size.y * .29), size.x * .045, dot);
    canvas.drawCircle(Offset(size.x * .52, size.y * .43), size.x * .035, dot);
  }

  void _paintLantern(Canvas canvas) {
    final pole = Paint()
      ..color = const Color(0xFF5E4A3B)
      ..strokeWidth = math.max(2, size.x * .09).toDouble()
      ..strokeCap = StrokeCap.round;
    final frame = Paint()
      ..color = const Color(0xFF7B5D3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.x * .07).toDouble();
    final flicker = _reducedMotion ? 0.0 : math.sin(_elapsed * 2.1);
    final glowStrength = switch (_timeOfDay) {
      GardenTimeOfDay.night => .48 + flicker * .15,
      GardenTimeOfDay.sunset => .13 + flicker * .04,
      GardenTimeOfDay.morning => 0.0,
      GardenTimeOfDay.day => 0.0,
    };
    final glow = Paint()
      ..color = const Color(0xFFFFD86B).withValues(alpha: glowStrength);
    final light = Paint()
      ..color = _timeOfDay == GardenTimeOfDay.night
          ? const Color(0xFFFFF0A5)
          : const Color(0xFFE2B96B);
    canvas.drawLine(
      Offset(size.x * .5, size.y),
      Offset(size.x * .5, size.y * .24),
      pole,
    );
    if (glowStrength > 0) {
      canvas.drawCircle(Offset(size.x * .5, size.y * .3), size.x * .34, glow);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .22, size.y * .12, size.x * .56, size.y * .37),
        Radius.circular(size.x * .08),
      ),
      frame,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * .39, size.y * .2, size.x * .22, size.y * .2),
      light,
    );
  }

  void _paintWoodenSign(Canvas canvas) {
    final post = Paint()..color = const Color(0xFF79543B);
    final board = Paint()..color = const Color(0xFFC98D55);
    final mark = Paint()
      ..color = const Color(0xFF765038)
      ..strokeWidth = math.max(1, size.x * .05).toDouble();
    canvas.drawRect(
      Rect.fromLTWH(size.x * .45, size.y * .46, size.x * .12, size.y * .54),
      post,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .04, size.y * .08, size.x * .92, size.y * .5),
        Radius.circular(size.x * .07),
      ),
      board,
    );
    canvas.drawLine(
      Offset(size.x * .25, size.y * .29),
      Offset(size.x * .75, size.y * .29),
      mark,
    );
    canvas.drawLine(
      Offset(size.x * .5, size.y * .2),
      Offset(size.x * .5, size.y * .4),
      mark,
    );
  }

  void _paintCoupleBench(Canvas canvas) {
    final wood = Paint()..color = const Color(0xFF9A6C46);
    final darkWood = Paint()..color = const Color(0xFF68442F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .08, size.y * .2, size.x * .84, size.y * .24),
        const Radius.circular(3),
      ),
      wood,
    );
    final highlight = Paint()..color = const Color(0xFFC99262);
    canvas.drawRect(
      Rect.fromLTWH(size.x * .1, size.y * .24, size.x * .8, size.y * .04),
      highlight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * .03, size.y * .53, size.x * .94, size.y * .2),
        const Radius.circular(3),
      ),
      wood,
    );
    final legWidth = size.x * .08;
    canvas.drawRect(
      Rect.fromLTWH(size.x * .18, size.y * .67, legWidth, size.y * .33),
      darkWood,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * .74, size.y * .67, legWidth, size.y * .33),
      darkWood,
    );
  }
}
