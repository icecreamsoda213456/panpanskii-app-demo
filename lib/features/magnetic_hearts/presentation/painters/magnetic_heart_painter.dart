import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/heart_particle.dart';
import '../../domain/magnetic_heart_models.dart';
import '../../domain/magnetic_heart_rules.dart';

class MagneticHeartPainter extends CustomPainter {
  const MagneticHeartPainter({
    required this.state,
    required this.particles,
  });

  static const blue = Color(0xFF67C8FF);
  static const pink = Color(0xFFFF6FAD);
  static const gold = Color(0xFFFFD66B);

  final MagneticHeartGameState state;
  final List<HeartParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintAmbientLights(canvas, size);
    _paintConnectionZone(canvas, size);
    _paintParticles(canvas, size);
    _paintNodeConnection(canvas, size);
    _paintNode(
      canvas,
      size,
      state.bluePosition,
      blue,
      state.blueDragging,
      _nodeLabel(MagneticNodeColor.blue),
    );
    _paintNode(
      canvas,
      size,
      state.pinkPosition,
      pink,
      state.pinkDragging,
      _nodeLabel(MagneticNodeColor.pink),
    );
    if (state.revealStarted) _paintFloatingHearts(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090B13),
            Color(0xFF12101C),
            Color(0xFF090A10),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.72,
          colors: [
            Color.lerp(blue, pink, 0.5)!.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _paintAmbientLights(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < 32; index += 1) {
      final seed = index * 1.713;
      final x = (math.sin(seed * 2.1) * 0.5 + 0.5) * size.width;
      final y = (math.cos(seed * 1.37) * 0.5 + 0.5) * size.height;
      final twinkle =
          0.35 + (math.sin(state.animationSeconds * 1.7 + seed) + 1) * 0.2;
      paint.color = (index.isEven ? blue : pink).withValues(
        alpha: twinkle * 0.35,
      );
      canvas.drawCircle(Offset(x, y), 0.8 + index % 3 * 0.45, paint);
    }
  }

  void _paintConnectionZone(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final radius = math.min(size.width, size.height) * 0.14;
    final pulse = 1 + math.sin(state.animationSeconds * 2.2) * 0.04;
    canvas.drawCircle(
      center,
      radius * pulse,
      Paint()
        ..color = Color.lerp(blue, pink, 0.5)!.withValues(alpha: 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.1),
    );
  }

  void _paintParticles(Canvas canvas, Size size) {
    final progress = Curves.easeInOutCubic.transform(
      state.connectionProgress.clamp(0.0, 1.0).toDouble(),
    );
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (final particle in particles) {
      final drift = Offset(
        math.sin(state.animationSeconds * 0.7 + particle.phase) *
            particle.velocity.dx,
        math.cos(state.animationSeconds * 0.55 + particle.phase) *
            particle.velocity.dy,
      );
      final scattered = particle.scatteredPosition + drift;
      var position = Offset.lerp(scattered, particle.heartPosition, progress) ??
          particle.heartPosition;
      if (state.revealStarted) {
        final pulse = 1 + math.sin(state.animationSeconds * 2.5) * 0.018;
        position = Offset(
          0.5 + (position.dx - 0.5) * pulse,
          0.43 + (position.dy - 0.43) * pulse,
        );
      }
      final point = Offset(position.dx * size.width, position.dy * size.height);
      final colorMix = particle.heartPosition.dx.clamp(0.1, 0.9).toDouble();
      particlePaint.color = Color.lerp(blue, pink, colorMix)!.withValues(
        alpha: particle.opacity * (0.55 + progress * 0.45),
      );
      final radius = particle.size * (0.72 + progress * 0.34);
      canvas.drawCircle(point, radius, particlePaint);
    }

    if (progress > 0.72) {
      final opacity = ((progress - 0.72) / 0.28).clamp(0.0, 1.0).toDouble();
      final heart = _heartPath(
        Offset(size.width / 2, size.height * 0.43),
        math.min(size.width, size.height) * 0.235,
      );
      canvas.drawPath(
        heart,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: opacity * 0.46)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _paintNodeConnection(Canvas canvas, Size size) {
    if (!state.isPlaying && !state.isCompleted) return;
    final blueCenter = MagneticHeartRules.denormalizePosition(
      state.bluePosition,
      size,
    );
    final pinkCenter = MagneticHeartRules.denormalizePosition(
      state.pinkPosition,
      size,
    );
    final progress = state.connectionProgress;
    final linePaint = Paint()
      ..shader = const LinearGradient(colors: [blue, pink]).createShader(
        Rect.fromPoints(blueCenter, pinkCenter),
      )
      ..strokeWidth = 1.5 + progress * 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.25 + progress * 0.55);
    canvas.drawLine(blueCenter, pinkCenter, linePaint);
  }

  void _paintNode(
    Canvas canvas,
    Size size,
    Offset normalized,
    Color color,
    bool dragging,
    String label,
  ) {
    final center = MagneticHeartRules.denormalizePosition(normalized, size);
    final pulse = 1 +
        math.sin(state.animationSeconds * (dragging ? 5 : 2.2) + center.dx) *
            (dragging ? 0.07 : 0.035);
    final radius = MagneticHeartRules.nodeRadius * pulse;
    canvas.drawCircle(
      center,
      radius * 1.75,
      Paint()
        ..color = color.withValues(alpha: dragging ? 0.27 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      radius + 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.48),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          colors: [Colors.white, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.26, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.72),
    );

    final icon = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, center - Offset(icon.width / 2, icon.height / 2));

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    labelPainter.paint(
      canvas,
      Offset(
        (center.dx - labelPainter.width / 2)
            .clamp(4, size.width - 104)
            .toDouble(),
        (center.dy + radius + 13).clamp(0, size.height - 18).toDouble(),
      ),
    );
  }

  void _paintFloatingHearts(Canvas canvas, Size size) {
    for (var index = 0; index < 13; index += 1) {
      final speed = 0.055 + index % 4 * 0.012;
      final progress = (state.animationSeconds * speed + index / 13) % 1.0;
      final x = size.width *
          (0.12 +
              index / 12 * 0.76 +
              math.sin(state.animationSeconds + index) * 0.025);
      final y = size.height * (1.05 - progress * 1.18);
      final heart = _heartPath(
        Offset(x, y),
        6 + (index % 4) * 2.5,
      );
      canvas.drawPath(
        heart,
        Paint()
          ..color = (index.isEven ? pink : blue).withValues(
            alpha:
                math.sin(progress * math.pi).clamp(0.0, 1.0).toDouble() * 0.72,
          ),
      );
    }
  }

  Path _heartPath(Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.72);
    path.cubicTo(
      center.dx - size * 1.25,
      center.dy,
      center.dx - size * 0.72,
      center.dy - size,
      center.dx,
      center.dy - size * 0.34,
    );
    path.cubicTo(
      center.dx + size * 0.72,
      center.dy - size,
      center.dx + size * 1.25,
      center.dy,
      center.dx,
      center.dy + size * 0.72,
    );
    path.close();
    return path;
  }

  String _nodeLabel(MagneticNodeColor color) {
    final local = state.localMember;
    if (local?.nodeColor == color) return 'You';
    final remote = state.remoteMember;
    if (remote?.nodeColor == color) return remote!.username;
    return color == MagneticNodeColor.blue ? 'Blue' : 'Pink';
  }

  @override
  bool shouldRepaint(covariant MagneticHeartPainter oldDelegate) => true;
}
