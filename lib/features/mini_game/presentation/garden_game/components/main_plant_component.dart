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
  bool _reducedMotion = false;
  String _plantType = 'sunflower';

  /// The glow colour behind an open bloom, one per plant.
  static const _haloColors = <String, Color>{
    'sunflower': Color(0xFFFFE680),
    'tulip': Color(0xFFFFC7D0),
    'sakura': Color(0xFFFFD6E0),
    'rose': Color(0xFFFFC2D4),
    'lavender': Color(0xFFE0D0FF),
    'tree': Color(0xFFBCE8A8),
  };

  void layoutForScene(Vector2 sceneSize) {
    // The plant is the focal point: it stays centred between the mascots
    // (which sit at 17% / 83% of the width) so it can grow without covering
    // them. Height is capped so tall scenes do not push it off the bed.
    final widthBudget = sceneSize.x * .46;
    final heightBudget = sceneSize.y * .58;
    final plantWidth =
        math.max(96, math.min(widthBudget, heightBudget)).toDouble();
    size.setValues(plantWidth, plantWidth);
    position.setValues(sceneSize.x * .5, sceneSize.y * .845);
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

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  /// Tells the plant which seed is growing so every growth stage past the
  /// generic sprout draws the right flower (tulip in, tulip out).
  void setPlantType(String plantType) {
    _plantType = plantType.trim().toLowerCase();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_reducedMotion) _elapsed += dt;
    _growthReaction = math.max(0, _growthReaction - dt * 1.45).toDouble();
    _waterReaction = math.max(0, _waterReaction - dt * 2.1).toDouble();
    _stageTransition = math.max(0, _stageTransition - dt * 1.2).toDouble();
  }

  @override
  void render(Canvas canvas) {
    final base = Offset(size.x * .5, size.y);
    final idleSway = _reducedMotion ? 0.0 : math.sin(_elapsed * 1.25) * .022;
    final growthProgress = 1 - _growthReaction;
    final earlyShrink = _growthReaction > 0 && growthProgress < .18
        ? (.18 - growthProgress) * .28
        : 0.0;
    final growthAmplitude = _reducedMotion
        ? (_stageTransition > 0 ? .08 : .05)
        : (_stageTransition > 0 ? .2 : .13);
    final growScale = _growthReaction > 0
        ? 1 - earlyShrink + math.sin(growthProgress * math.pi) * growthAmplitude
        : 1.0;
    final waterScale =
        1 + math.sin(_waterReaction * math.pi) * (_reducedMotion ? .04 : .09);
    final stageScale = _stageScale;

    _paintContactShadow(canvas, growScale * waterScale);

    if (_stage == GardenGrowthStage.blooming) {
      _paintBloomHalo(canvas, base);
    }

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(idleSway);
    canvas.scale(stageScale * growScale * waterScale);
    canvas.translate(-base.dx, -base.dy);
    if (_usesPixelTileStages && sprites[_stage] != null) {
      sprites[_stage]!.render(canvas, size: size, overridePaint: _pixelPaint);
    } else {
      _paintProceduralPlant(canvas);
    }
    canvas.restore();

    if (_waterReaction > 0) {
      _paintSoilSparkle(canvas, _waterReaction);
    }
    if (_growthReaction > 0) {
      _paintSparkles(canvas, _growthReaction);
    }
  }

  /// Grounds the plant against the garden bed so it reads as a separate
  /// layer from the terrain behind it.
  void _paintContactShadow(Canvas canvas, double liftScale) {
    final lift = (liftScale - 1).clamp(0.0, .3).toDouble();
    final width = size.x * _stageScale * (.52 - lift * .5);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .18 - lift * .3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * .5, size.y * .965),
        width: math.max(1.0, width),
        height: math.max(1.0, size.y * .07),
      ),
      shadow,
    );
  }

  void _paintSoilSparkle(Canvas canvas, double strength) {
    final alpha = strength.clamp(0.0, 1.0).toDouble();
    final rise = (1 - alpha) * size.y * .06;
    final paint = Paint()
      ..color = const Color(0xFFB6E9FF).withValues(alpha: alpha * .85);
    for (var index = 0; index < 5; index += 1) {
      final spread = (index - 2) / 2;
      final center = Offset(
        size.x * .5 + spread * size.x * .18,
        size.y * .93 - rise - (index.isEven ? size.y * .015 : 0),
      );
      canvas.drawCircle(center, 1.8 + alpha * 1.1, paint);
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
    final pulse =
        _reducedMotion ? .13 : .1 + math.sin(_elapsed * 1.7).abs() * .06;
    final halo = Paint()
      ..color = (_haloColors[_plantType] ?? const Color(0xFFFFE680))
          .withValues(alpha: pulse);
    canvas.drawCircle(
      Offset(base.dx, _bloomHaloCenterY),
      size.x * .37,
      halo,
    );
  }

  /// Centres the glow behind the open head, which sits at a different height
  /// for each plant so the halo hugs the flower instead of floating below it.
  double get _bloomHaloCenterY => switch (_plantType) {
        'tree' => size.y * .34,
        'lavender' => size.y * .44,
        'rose' => size.y * .32,
        'tulip' => size.y * .3,
        'sakura' => size.y * .3,
        _ => size.y * .28,
      };

  bool get _usesPixelTileStages =>
      _stage == GardenGrowthStage.seed ||
      _stage == GardenGrowthStage.sprouting;

  /// Together: the soil mound, stem/leaves, and the per-type flower head.
  /// Also the defensive fallback when a pixel tile failed to load: growing,
  /// budding and blooming always render the real flower; seed and sprouting
  /// draw a simple seed / sprout instead of accidentally showing a full bloom.
  void _paintProceduralPlant(Canvas canvas) {
    final soil = Paint()..color = const Color(0xFF8C5B43);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .9),
          width: size.x * .8,
          height: size.y * .18),
      soil,
    );

    final painter = switch ((_stage, _plantType)) {
      (GardenGrowthStage.seed, _) => _paintSeed,
      (GardenGrowthStage.sprouting, _) => _paintSprout,
      (_, 'tree') => _paintTree,
      (_, 'lavender') => _paintLavender,
      (_, 'tulip') => _paintTulip,
      (_, 'sakura') => _paintSakura,
      (_, 'rose') => _paintRose,
      _ => _paintSunflower,
    };
    painter(canvas);
  }

  void _paintSeed(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .74),
          width: size.x * .15,
          height: size.y * .1),
      Paint()..color = const Color(0xFF5B3A2E),
    );
  }

  void _paintSprout(Canvas canvas) {
    final stem = Paint()..color = const Color(0xFF6BAF5E);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .62),
          width: size.x * .06,
          height: size.y * .26),
      stem,
    );
    final leaf = Paint()..color = const Color(0xFF75BF62);
    canvas
      ..save()
      ..translate(size.x * .46, size.y * .62)
      ..rotate(-.6);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: size.x * .26, height: size.y * .13),
        leaf);
    canvas.restore();
    canvas
      ..save()
      ..translate(size.x * .56, size.y * .55)
      ..rotate(.55);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: size.x * .26, height: size.y * .13),
        leaf);
    canvas.restore();
  }

  void _paintStemAndLeaves(Canvas canvas) {
    final stem = Paint()..color = const Color(0xFF4E9B52);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .56),
          width: size.x * .09,
          height: size.y * .42),
      stem,
    );
    final leaf = Paint()..color = const Color(0xFF75BF62);
    // Swept leaves alternate sides for a little life.
    canvas
      ..save()
      ..translate(size.x * .36, size.y * .6)
      ..rotate(-.55);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: size.x * .3, height: size.y * .14),
        leaf);
    canvas.restore();
    canvas
      ..save()
      ..translate(size.x * .64, size.y * .5)
      ..rotate(.5);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: size.x * .3, height: size.y * .14),
        leaf);
    canvas.restore();
  }

  /// A small closed bud wrapped by green calyx leaves.
  void _paintBud(Canvas canvas, Offset top, Color color) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(top.dx, top.dy + size.y * .04),
          width: size.x * .22,
          height: size.y * .16),
      Paint()..color = const Color(0xFF4E9B52),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(top.dx, top.dy - size.y * .02),
          width: size.x * .15,
          height: size.y * .2),
      Paint()..color = color,
    );
  }

  void _paintTulip(Canvas canvas) {
    _paintStemAndLeaves(canvas);
    final headTop = Offset(size.x * .5, size.y * .3);
    if (_stage == GardenGrowthStage.budding) {
      _paintBud(canvas, headTop, const Color(0xFFFF7A9A));
      return;
    }
    if (_stage != GardenGrowthStage.blooming) return;
    final radius = size.x * .2;
    // A tulip reads as a flared cup: three petals hugging a deep throat.
    final cupDeep = Paint()..color = const Color(0xFFE84A6E);
    final cupLight = Paint()..color = const Color(0xFFFF7A9A);
    final centerPetal = Path()
      ..moveTo(headTop.dx - radius * .4, headTop.dy)
      ..quadraticBezierTo(headTop.dx - radius * .5, headTop.dy + radius * 1.15,
          headTop.dx, headTop.dy + radius * 1.5)
      ..quadraticBezierTo(headTop.dx + radius * .5, headTop.dy + radius * 1.15,
          headTop.dx + radius * .4, headTop.dy)
      ..quadraticBezierTo(headTop.dx, headTop.dy - radius * .15,
          headTop.dx - radius * .4, headTop.dy)
      ..close();
    canvas.drawPath(centerPetal, cupDeep);
    final leftPetal = Path()
      ..moveTo(headTop.dx - radius * .45, headTop.dy)
      ..quadraticBezierTo(headTop.dx - radius, headTop.dy + radius * .4,
          headTop.dx - radius * .55, headTop.dy + radius * 1.15)
      ..quadraticBezierTo(headTop.dx - radius * .2, headTop.dy + radius * 1.3,
          headTop.dx, headTop.dy + radius * 1.1)
      ..quadraticBezierTo(headTop.dx - radius * .1, headTop.dy + radius * .55,
          headTop.dx - radius * .45, headTop.dy)
      ..close();
    canvas.drawPath(leftPetal, cupLight);
    final rightPetal = Path()
      ..moveTo(headTop.dx + radius * .45, headTop.dy)
      ..quadraticBezierTo(headTop.dx + radius, headTop.dy + radius * .4,
          headTop.dx + radius * .55, headTop.dy + radius * 1.15)
      ..quadraticBezierTo(headTop.dx + radius * .2, headTop.dy + radius * 1.3,
          headTop.dx, headTop.dy + radius * 1.1)
      ..quadraticBezierTo(headTop.dx + radius * .1, headTop.dy + radius * .55,
          headTop.dx + radius * .45, headTop.dy)
      ..close();
    canvas.drawPath(rightPetal, cupLight);
  }

  void _paintSakura(Canvas canvas) {
    _paintStemAndLeaves(canvas);
    final headTop = Offset(size.x * .5, size.y * .3);
    if (_stage == GardenGrowthStage.budding) {
      _paintBud(canvas, headTop, const Color(0xFFFFB7C5));
      return;
    }
    if (_stage != GardenGrowthStage.blooming) return;
    final radius = size.x * .2;
    final petal = Paint()..color = const Color(0xFFFFB7C5);
    // Five rounded, notched petals like a cherry blossom.
    for (var index = 0; index < 5; index++) {
      canvas
        ..save()
        ..translate(headTop.dx, headTop.dy)
        ..rotate(index * 2 * math.pi / 5);
      canvas
        ..drawCircle(Offset(-radius * .22, -radius * 1.05), radius * .38, petal)
        ..drawCircle(Offset(radius * .22, -radius * 1.05), radius * .38, petal)
        ..drawOval(
            Rect.fromCenter(
                center: Offset(0, -radius * 1.25),
                width: radius * .6,
                height: radius * .55),
            petal);
      canvas.restore();
    }
    canvas.drawCircle(
        headTop, radius * .18, Paint()..color = const Color(0xFFFF8FAB));
    final stamen =
        Paint()..color = const Color(0xFFFFE680)..strokeWidth = 1.4;
    for (var index = 0; index < 5; index++) {
      final angle = index * 2 * math.pi / 5;
      canvas.drawLine(
        headTop,
        Offset(
          headTop.dx + math.cos(angle) * radius * .4,
          headTop.dy + math.sin(angle) * radius * .4,
        ),
        stamen,
      );
    }
  }

  void _paintRose(Canvas canvas) {
    _paintStemAndLeaves(canvas);
    final headTop = Offset(size.x * .5, size.y * .32);
    if (_stage == GardenGrowthStage.budding) {
      _paintBud(canvas, headTop, const Color(0xFFE84A7A));
      return;
    }
    if (_stage != GardenGrowthStage.blooming) return;
    final radius = size.x * .26;
    // Layered open petals radiating outward, then a tight spiral core.
    final outer = Paint()..color = const Color(0xFFE84A7A);
    for (var index = 0; index < 6; index++) {
      canvas.drawCircle(
        Offset(
          headTop.dx + math.cos(index * math.pi / 3) * radius * .72,
          headTop.dy + math.sin(index * math.pi / 3) * radius * .72,
        ),
        radius * .52,
        outer,
      );
    }
    canvas.drawCircle(
        headTop, radius * .6, Paint()..color = const Color(0xFFC93660));
    canvas.drawCircle(
        headTop, radius * .34, Paint()..color = const Color(0xFFE84A7A));
    canvas.drawCircle(
        headTop, radius * .16, Paint()..color = const Color(0xFF9E2748));
  }

  void _paintLavender(Canvas canvas) {
    // A slender stem crowned by stacked purple florets.
    final stem = Paint()..color = const Color(0xFF5A8F4E);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.x * .5, size.y * .54),
          width: size.x * .05,
          height: size.y * .38),
      stem,
    );
    if (_stage == GardenGrowthStage.growing) return;
    if (_stage == GardenGrowthStage.budding) {
      _paintBud(canvas, Offset(size.x * .5, size.y * .3),
          const Color(0xFF9C7BD8));
      return;
    }
    if (_stage != GardenGrowthStage.blooming) return;
    final light = Paint()..color = const Color(0xFF9C7BD8);
    final deep = Paint()..color = const Color(0xFF7E5BBF);
    for (var index = 0; index < 6; index++) {
      final t = index / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * .5, size.y * (.56 - t * .34)),
          width: size.x * (.24 - t * .085),
          height: size.y * .1,
        ),
        index < 3 ? light : deep,
      );
    }
  }

  void _paintTree(Canvas canvas) {
    // A sturdy trunk with a round leafy canopy (and fruit once in bloom).
    final trunk = Path()
      ..moveTo(size.x * .44, size.y * .86)
      ..lineTo(size.x * .56, size.y * .86)
      ..lineTo(size.x * .52, size.y * .48)
      ..lineTo(size.x * .48, size.y * .48)
      ..close();
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF8C5B43));
    if (_stage == GardenGrowthStage.growing) return;
    final canopy = Paint()..color = const Color(0xFF4E9B52);
    canvas.drawCircle(Offset(size.x * .5, size.y * .34), size.x * .3, canopy);
    canvas.drawCircle(Offset(size.x * .38, size.y * .42), size.x * .18,
        Paint()..color = const Color(0xFF75BF62));
    canvas.drawCircle(Offset(size.x * .62, size.y * .42), size.x * .18,
        Paint()..color = const Color(0xFF75BF62));
    if (_stage == GardenGrowthStage.blooming) {
      final fruit = Paint()..color = const Color(0xFFFF9AAE);
      canvas
        ..drawCircle(Offset(size.x * .38, size.y * .26), size.x * .035, fruit)
        ..drawCircle(Offset(size.x * .58, size.y * .3), size.x * .035, fruit)
        ..drawCircle(Offset(size.x * .48, size.y * .4), size.x * .035, fruit);
    }
  }

  void _paintSunflower(Canvas canvas) {
    _paintStemAndLeaves(canvas);
    final headTop = Offset(size.x * .5, size.y * .28);
    if (_stage == GardenGrowthStage.budding) {
      _paintBud(canvas, headTop, const Color(0xFF75BF62));
      return;
    }
    if (_stage != GardenGrowthStage.blooming) return;
    final radius = size.x * .24;
    final petal = Paint()..color = const Color(0xFFFFC857);
    for (var index = 0; index < 12; index++) {
      canvas
        ..save()
        ..translate(headTop.dx, headTop.dy)
        ..rotate(index * math.pi / 6);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -radius * 1.35),
            width: radius * .55,
            height: radius * 1.0),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(headTop, radius, Paint()..color = const Color(0xFF8A5A2B));
    final seed = Paint()..color = const Color(0xFF6B4423);
    for (var index = 0; index < 6; index++) {
      canvas.drawCircle(
        Offset(
          headTop.dx + math.cos(index * math.pi / 3) * radius * .5,
          headTop.dy + math.sin(index * math.pi / 3) * radius * .5,
        ),
        radius * .1,
        seed,
      );
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
