import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../garden_scene_state.dart';

class MainPlantComponent extends PositionComponent {
  MainPlantComponent({required this.sprites})
      : _stage = GardenGrowthStage.seed,
        super(anchor: Anchor.bottomCenter, priority: 20);

  final Map<GardenGrowthStage, Sprite?> sprites;
  final Paint _pixelPaint = Paint()..filterQuality = FilterQuality.none;
  GardenGrowthStage _stage;
  bool _hasAppliedStage = false;
  double _elapsed = 0;
  double _growthReaction = 0;
  double _waterReaction = 0;
  double _stageTransition = 0;

  void layoutForScene(Vector2 sceneSize) {
    final plantWidth = math.max(78, sceneSize.x * .39).toDouble();
    size.setValues(plantWidth, plantWidth);
    position.setValues(sceneSize.x * .5, sceneSize.y * .84);
  }

  void setStage(GardenGrowthStage stage) {
    if (_hasAppliedStage && stage != _stage) {
      _stageTransition = 1;
      _growthReaction = math.max(_growthReaction, .92).toDouble();
    }
    _stage = stage;
    _hasAppliedStage = true;
  }

  void reactToGrowth() {
    _growthReaction = 1;
  }

  void reactToWater() {
    _waterReaction = 1;
  }

  void celebrate() {
    reactToGrowth();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _growthReaction = math.max(0, _growthReaction - dt * 1.45).toDouble();
    _waterReaction = math.max(0, _waterReaction - dt * 2.1).toDouble();
    _stageTransition = math.max(0, _stageTransition - dt * 1.2).toDouble();
  }

  @override
  void render(Canvas canvas) {
    final base = Offset(size.x * .5, size.y);
    final idleSway = math.sin(_elapsed * 1.25) * .022;
    final growthProgress = 1 - _growthReaction;
    final earlyShrink = _growthReaction > 0 && growthProgress < .18
        ? (.18 - growthProgress) * .28
        : 0.0;
    final growthAmplitude = _stageTransition > 0 ? .2 : .13;
    final growScale = _growthReaction > 0
        ? 1 - earlyShrink + math.sin(growthProgress * math.pi) * growthAmplitude
        : 1.0;
    final waterScale = 1 + math.sin(_waterReaction * math.pi) * .09;
    final stageScale = _stageScale;

    if (_stage == GardenGrowthStage.blooming) {
      _paintBloomHalo(canvas, base);
    }

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(idleSway);
    canvas.scale(stageScale * growScale * waterScale);
    canvas.translate(-base.dx, -base.dy);
    final sprite = sprites[_stage];
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: _pixelPaint);
    } else {
      _paintFallbackPlant(canvas);
    }
    canvas.restore();

    if (_growthReaction > 0) {
      _paintSparkles(canvas, _growthReaction);
    }
  }

  double get _stageScale => switch (_stage) {
        GardenGrowthStage.seed => .56,
        GardenGrowthStage.sprouting => .7,
        GardenGrowthStage.growing => .88,
        GardenGrowthStage.budding => 1.04,
        GardenGrowthStage.blooming => 1.17,
      };

  void _paintBloomHalo(Canvas canvas, Offset base) {
    final pulse = .1 + math.sin(_elapsed * 1.7).abs() * .06;
    final halo = Paint()
      ..color = const Color(0xFFFFE680).withValues(alpha: pulse);
    canvas.drawCircle(
      Offset(base.dx, size.y * .45),
      size.x * .37,
      halo,
    );
  }

  void _paintFallbackPlant(Canvas canvas) {
    final stem = Paint()..color = const Color(0xFF4E9B52);
    final leaf = Paint()..color = const Color(0xFF75BF62);
    final soil = Paint()..color = const Color(0xFF8C5B43);
    final center = Offset(size.x * .5, size.y * .74);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .9),
          width: size.x * .8,
          height: size.y * .18),
      soil,
    );
    if (_stage == GardenGrowthStage.seed) {
      canvas.drawOval(
        Rect.fromCenter(
            center: center, width: size.x * .15, height: size.y * .1),
        Paint()..color = const Color(0xFF5B3A2E),
      );
      return;
    }
    final stemTop = Offset(size.x * .5, size.y * .28);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .56),
          width: size.x * .09,
          height: size.y * .42),
      stem,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.x * .34, size.y * .52),
          width: size.x * .3,
          height: size.y * .17),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.x * .66, size.y * .44),
          width: size.x * .3,
          height: size.y * .17),
      leaf,
    );
    if (_stage == GardenGrowthStage.budding ||
        _stage == GardenGrowthStage.blooming) {
      canvas.drawCircle(
          stemTop, size.x * .13, Paint()..color = const Color(0xFFFFD057));
    }
  }

  void _paintSparkles(Canvas canvas, double strength) {
    final alpha = strength.clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..color = const Color(0xFFFFE57C).withValues(alpha: alpha);
    final points = [
      Offset(size.x * .2, size.y * .26),
      Offset(size.x * .8, size.y * .38),
      Offset(size.x * .38, size.y * .1),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 2.2, paint);
      canvas.drawLine(Offset(point.dx - 3, point.dy),
          Offset(point.dx + 3, point.dy), paint);
      canvas.drawLine(Offset(point.dx, point.dy - 3),
          Offset(point.dx, point.dy + 3), paint);
    }
  }
}
