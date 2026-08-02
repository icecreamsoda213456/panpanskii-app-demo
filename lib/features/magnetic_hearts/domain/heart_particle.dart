import 'dart:math' as math;
import 'dart:ui';

class HeartParticle {
  const HeartParticle({
    required this.scatteredPosition,
    required this.heartPosition,
    required this.velocity,
    required this.size,
    required this.opacity,
    required this.phase,
  });

  final Offset scatteredPosition;
  final Offset heartPosition;
  final Offset velocity;
  final double size;
  final double opacity;
  final double phase;
}

class HeartParticleField {
  const HeartParticleField._();

  static List<HeartParticle> generate({
    int count = 840,
    int seed = 0x50414E,
  }) {
    final random = math.Random(seed);
    return List<HeartParticle>.generate(count, (index) {
      final outline = index < (count * 0.38).round();
      final t = outline
          ? index / (count * 0.38) * math.pi * 2
          : random.nextDouble() * math.pi * 2;
      final radial = outline ? 1.0 : math.sqrt(random.nextDouble()) * 0.94;
      final x = 16 * math.pow(math.sin(t), 3).toDouble();
      final y = 13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t);
      final target = Offset(
        0.5 + (x / 46) * radial,
        0.43 - (y / 46) * radial,
      );
      return HeartParticle(
        scatteredPosition: Offset(
          0.06 + random.nextDouble() * 0.88,
          0.08 + random.nextDouble() * 0.82,
        ),
        heartPosition: target,
        velocity: Offset(
          0.006 + random.nextDouble() * 0.009,
          0.005 + random.nextDouble() * 0.008,
        ),
        size: 0.8 + random.nextDouble() * 2.2,
        opacity: 0.32 + random.nextDouble() * 0.68,
        phase: random.nextDouble() * math.pi * 2,
      );
    }, growable: false);
  }
}
