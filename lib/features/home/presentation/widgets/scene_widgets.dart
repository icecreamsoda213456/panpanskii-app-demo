import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SkyGlow extends StatefulWidget {
  const SkyGlow(
      {super.key,
      required this.size,
      required this.color,
      this.enableGlow = true});

  final double size;
  final Color color;
  final bool enableGlow;

  @override
  State<SkyGlow> createState() => _SkyGlowState();
}

class _SkyGlowState extends State<SkyGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = 15.0 * math.sin(_controller.value * math.pi * 2);
        return Transform.translate(
          offset: Offset(offset, -offset * 0.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: widget.enableGlow ? 1.0 : 0.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color.withValues(
                    alpha:
                        0.35 + (0.05 * math.cos(_controller.value * math.pi))),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: SizedBox.square(dimension: widget.size),
            ),
          ),
        );
      },
    );
  }
}

class PetalLayer extends StatefulWidget {
  const PetalLayer({super.key, this.enableGlow = true});

  final bool enableGlow;

  @override
  State<PetalLayer> createState() => _PetalLayerState();
}

class _PetalLayerState extends State<PetalLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    const offsets = [
      0.04,
      0.11,
      0.18,
      0.28,
      0.37,
      0.48,
      0.59,
      0.68,
      0.76,
      0.84,
      0.91,
      0.96,
    ];
    const delays = [0.0, 2.0, 5.0, 3.0, 7.0, 1.0, 6.0, 4.0, 8.0, 2.8, 5.9, 7.6];

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: List.generate(12, (index) {
                final progress = (_controller.value + delays[index] / 10) % 1;
                final x = width * offsets[index] +
                    30 * math.sin(progress * math.pi * 2 + index);
                final y = height * (1 - progress) - 54;
                final opacity = progress < 0.15
                    ? progress / 0.15
                    : (1 - progress).clamp(0.0, 1.0).toDouble();
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: opacity * 0.8,
                    child: Transform.rotate(
                      angle: progress * math.pi * 2,
                      child: index % 4 == 0
                          ? _PixelButterfly(
                              size: 16,
                              flap: math.sin(progress * math.pi * 10).abs(),
                            )
                          : _PixelSparkle(
                              size: index.isEven ? 12 : 10,
                              color: index.isEven
                                  ? const Color(0xFFFFF1A8)
                                  : const Color(0xFFFF9DB0),
                            ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class CharacterStage extends StatelessWidget {
  const CharacterStage({
    super.key,
    this.height,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.enableBubble = true,
  });

  final double? height;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool enableBubble;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 520;
    final stageHeight = height ?? (compact ? 480.0 : 740.0);
    final petSize = (stageHeight * (compact ? 0.5 : 0.52)).clamp(
      170.0,
      220.0,
    );

    return SizedBox(
      height: stageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _RetroBackdrop(isDarkMode: isDarkMode)),
          Positioned(
            right: compact ? 16 : 20,
            top: compact ? 14 : 18,
            child: _PixelSkyToggle(
              isDarkMode: isDarkMode,
              onPressed: onToggleTheme,
            ),
          ),
          Positioned(
            left: 10,
            bottom: compact ? 86 : 102,
            child: const _PixelTree(size: 86, blossom: true),
          ),
          Positioned(
            right: 6,
            bottom: compact ? 96 : 112,
            child: const _PixelTree(size: 96),
          ),
          Positioned(
            left: compact ? 150 : 250,
            bottom: compact ? 112 : 132,
            child: const _PixelTree(size: 70, blossom: true),
          ),
          Positioned(
            left: 92,
            bottom: compact ? 80 : 94,
            child: const _PixelBush(width: 82),
          ),
          Positioned(
            right: 98,
            bottom: compact ? 76 : 90,
            child: const _PixelBush(width: 74),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: Ground(compact: compact),
          ),
          Positioned(
            left: compact ? 12 : 66,
            bottom: compact ? 38 : 52,
            child: _PetWithBubble(
              name: 'Pippa',
              assetPath: 'assets/pets/pippa/spritesheet.webp',
              size: petSize,
              rows: const [0, 2, 3, 7],
              duration: const Duration(milliseconds: 980),
              greeting: 'Welcome back!',
              enableBubble: enableBubble,
            ),
          ),
          Positioned(
            right: compact ? 12 : 66,
            bottom: compact ? 38 : 52,
            child: _PetWithBubble(
              name: 'Kebo',
              assetPath: 'assets/pets/kebo/spritesheet.webp',
              size: petSize * 1.02,
              rows: const [0, 2, 4, 6],
              duration: const Duration(milliseconds: 1040),
              greeting: 'So cozy here!',
              enableBubble: enableBubble,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetroBackdrop extends StatelessWidget {
  const _RetroBackdrop({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? const [Color(0xFF1C2553), Color(0xFF54406A), Color(0xFF426256)]
              : const [Color(0xFFAEE7FF), Color(0xFFFFF5C9), Color(0xFFBDEB93)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF8972A9) : const Color(0xFFB8906E),
          width: 2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RetroBackdropPainter(isDarkMode: isDarkMode),
            ),
          ),
          Positioned(
            left: 16,
            top: 74,
            child: _PixelCloud(size: 42, isDarkMode: isDarkMode),
          ),
          Positioned(
            left: 36,
            top: 34,
            child: _PixelCloud(size: 66, isDarkMode: isDarkMode),
          ),
          Positioned(
            left: 142,
            top: 24,
            child: _PixelCloud(size: 38, isDarkMode: isDarkMode),
          ),
          Positioned(
            right: 54,
            top: 44,
            child: _PixelCloud(size: 54, isDarkMode: isDarkMode),
          ),
          Positioned(
            right: 16,
            top: 86,
            child: _PixelCloud(size: 36, isDarkMode: isDarkMode),
          ),
          Positioned(
            right: 142,
            top: 72,
            child: _PixelCloud(size: 46, isDarkMode: isDarkMode),
          ),
          Positioned(
            left: 14,
            top: 18,
            child: _PixelStar(size: 8, color: Color(0xFFFFF1A8)),
          ),
          Positioned(
            right: 30,
            top: 32,
            child: _PixelStar(size: 6, color: Color(0xFFFFF1A8)),
          ),
          Positioned(
            left: 92,
            top: 44,
            child: _PixelStar(size: 5, color: Color(0xFFFF9DB0)),
          ),
          Positioned(
            right: 96,
            top: 54,
            child: _PixelStar(size: 5, color: Color(0xFFFFF1A8)),
          ),
        ],
      ),
    );
  }
}

class _RetroBackdropPainter extends CustomPainter {
  const _RetroBackdropPainter({required this.isDarkMode});

  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.62;
    final farHill = Paint()
      ..color = isDarkMode
          ? const Color(0xFF303D6B).withValues(alpha: 0.7)
          : const Color(0xFF8FD2C1).withValues(alpha: 0.62);
    final nearHill = Paint()
      ..color = isDarkMode
          ? const Color(0xFF36566A).withValues(alpha: 0.82)
          : const Color(0xFF72BFA5).withValues(alpha: 0.72);

    final farHillPath = Path()
      ..moveTo(0, horizon + 12)
      ..lineTo(size.width * 0.12, horizon - 18)
      ..lineTo(size.width * 0.22, horizon - 2)
      ..lineTo(size.width * 0.34, horizon - 34)
      ..lineTo(size.width * 0.48, horizon + 2)
      ..lineTo(size.width * 0.62, horizon - 22)
      ..lineTo(size.width * 0.76, horizon - 5)
      ..lineTo(size.width * 0.9, horizon - 28)
      ..lineTo(size.width, horizon - 4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farHillPath, farHill);

    final nearHillPath = Path()
      ..moveTo(0, horizon + 30)
      ..lineTo(size.width * 0.16, horizon + 2)
      ..lineTo(size.width * 0.3, horizon + 24)
      ..lineTo(size.width * 0.46, horizon - 8)
      ..lineTo(size.width * 0.61, horizon + 22)
      ..lineTo(size.width * 0.77, horizon - 2)
      ..lineTo(size.width * 0.9, horizon + 18)
      ..lineTo(size.width, horizon - 2)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearHillPath, nearHill);

    final horizonPaint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF85A58F).withValues(alpha: 0.2)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.34);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon + 30, size.width, 2),
      horizonPaint,
    );

    final fieldPaint = Paint()
      ..color = isDarkMode
          ? const Color(0xFFB2C79A).withValues(alpha: 0.12)
          : const Color(0xFF3F8F68).withValues(alpha: 0.16);
    final rowHeight = size.height * 0.035;
    for (var row = 0; row < 4; row++) {
      final y = horizon + 48 + row * rowHeight;
      final offset = row.isEven ? 0.0 : size.width * 0.08;
      for (var x = -size.width * 0.1; x < size.width; x += 42) {
        canvas.drawRect(
          Rect.fromLTWH(x + offset, y, 22, 2),
          fieldPaint,
        );
      }
    }

    final pixelHighlight = Paint()
      ..color = isDarkMode
          ? const Color(0xFFC9C2FF).withValues(alpha: 0.12)
          : const Color(0xFFFFF7D7).withValues(alpha: 0.44);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.24, 36, 3),
      pixelHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.72, size.height * 0.31, 54, 3),
      pixelHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _RetroBackdropPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode;
}

class _PixelCloud extends StatelessWidget {
  const _PixelCloud({required this.size, this.isDarkMode = false});

  final double size;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CloudPainter(isDarkMode: isDarkMode),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter({required this.isDarkMode});

  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final paint = Paint()
      ..color = isDarkMode
          ? const Color(0xFFCED6FF).withValues(alpha: 0.78)
          : Colors.white.withValues(alpha: 0.98);
    const cells = [
      Offset(1, 3),
      Offset(2, 2),
      Offset(3, 1),
      Offset(4, 1),
      Offset(5, 2),
      Offset(6, 3),
      Offset(1, 4),
      Offset(2, 3),
      Offset(3, 2),
      Offset(4, 2),
      Offset(5, 3),
      Offset(6, 4),
      Offset(2, 4),
      Offset(3, 3),
      Offset(4, 3),
      Offset(5, 4),
    ];
    for (final o in cells) {
      canvas.drawRect(
        Rect.fromLTWH(o.dx * cell, o.dy * cell, cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode;
}

class _PixelSkyToggle extends StatelessWidget {
  const _PixelSkyToggle({required this.isDarkMode, required this.onPressed});

  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              (isDarkMode ? const Color(0xFF30294D) : const Color(0xFFFFF4B8))
                  .withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isDarkMode ? const Color(0xFFC8B9FF) : const Color(0xFFE6A94D),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4E342E).withValues(alpha: 0.24),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: (isDarkMode
                      ? const Color(0xFFA499FF)
                      : const Color(0xFFFFD45A))
                  .withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween<double>(
                      begin: -0.08,
                      end: 0,
                    ).animate(animation),
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: CustomPaint(
                  key: ValueKey(isDarkMode),
                  size: const Size.square(34),
                  painter: _SkyOrbPainter(isDarkMode: isDarkMode),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyOrbPainter extends CustomPainter {
  const _SkyOrbPainter({required this.isDarkMode});

  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 11, height: 11, size: size);
    if (isDarkMode) {
      const moon = Color(0xFFFFF2B8);
      const moonShade = Color(0xFFD7C87A);
      const crater = Color(0xFFBDAE72);
      const star = Color(0xFFE8E0FF);
      grid.rect(8, 1, 1, 1, star);
      grid.rect(2, 2, 1, 1, star);
      grid.rect(9, 7, 1, 1, star);
      grid.ellipse(5, 5, 4, 4, moon);
      grid.ellipse(7, 4, 3, 4, const Color(0xFF30294D));
      grid.rect(4, 4, 1, 1, crater);
      grid.rect(5, 7, 1, 1, moonShade);
      grid.rect(3, 6, 1, 1, moonShade);
      return;
    }

    const sun = Color(0xFFFFD45A);
    const sunShade = Color(0xFFFFA84F);
    const sunLight = Color(0xFFFFF4A8);
    grid.rect(5, 0, 1, 2, sun);
    grid.rect(5, 9, 1, 2, sun);
    grid.rect(0, 5, 2, 1, sun);
    grid.rect(9, 5, 2, 1, sun);
    grid.rect(2, 2, 1, 1, sunShade);
    grid.rect(8, 2, 1, 1, sunShade);
    grid.rect(2, 8, 1, 1, sunShade);
    grid.rect(8, 8, 1, 1, sunShade);
    grid.ellipse(5, 5, 4, 4, sunShade);
    grid.ellipse(5, 5, 3, 3, sun);
    grid.rect(4, 3, 2, 1, sunLight);
    grid.rect(3, 5, 1, 1, sunLight);
  }

  @override
  bool shouldRepaint(covariant _SkyOrbPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode;
}

class _PixelTree extends StatelessWidget {
  const _PixelTree({required this.size, this.blossom = false});

  final double size;
  final bool blossom;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.25),
      painter: _TreePainter(blossom: blossom),
    );
  }
}

class _TreePainter extends CustomPainter {
  const _TreePainter({required this.blossom});

  final bool blossom;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 14, height: 18, size: size);
    const trunk = Color(0xFF9A6846);
    const trunkDark = Color(0xFF6D4938);
    final leaf = blossom ? const Color(0xFFFFA8BD) : const Color(0xFF6EC16D);
    final leafDark =
        blossom ? const Color(0xFFE9789A) : const Color(0xFF3F914F);
    final leafLight =
        blossom ? const Color(0xFFFFD2DD) : const Color(0xFF9BE07B);

    grid.rect(6, 9, 2, 8, trunkDark);
    grid.rect(7, 9, 2, 8, trunk);
    grid.rect(5, 14, 1, 2, trunkDark);
    grid.rect(9, 13, 1, 2, trunk);
    grid.ellipse(7, 6, 5, 5, leafDark);
    grid.ellipse(6, 5, 4, 4, leaf);
    grid.ellipse(9, 7, 3, 4, leaf);
    grid.rect(4, 3, 2, 1, leafLight);
    grid.rect(9, 5, 2, 1, leafLight);
    grid.rect(3, 8, 1, 1, leafLight);
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) =>
      oldDelegate.blossom != blossom;
}

class _PixelBush extends StatelessWidget {
  const _PixelBush({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.34),
      painter: _BushPainter(),
    );
  }
}

class _BushPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 18, height: 7, size: size);
    const dark = Color(0xFF3C8A4B);
    const mid = Color(0xFF6DBF67);
    const light = Color(0xFFA4E07F);
    grid.ellipse(4, 4, 4, 3, dark);
    grid.ellipse(9, 3, 5, 3, mid);
    grid.ellipse(14, 4, 4, 3, dark);
    grid.rect(5, 2, 2, 1, light);
    grid.rect(10, 1, 2, 1, light);
    grid.rect(14, 3, 1, 1, light);
  }

  @override
  bool shouldRepaint(covariant _BushPainter oldDelegate) => false;
}

class _PixelButterfly extends StatelessWidget {
  const _PixelButterfly({required this.size, required this.flap});

  final double size;
  final double flap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ButterflyPainter(flap),
    );
  }
}

class _ButterflyPainter extends CustomPainter {
  const _ButterflyPainter(this.flap);

  final double flap;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 7, height: 7, size: size);
    final wing =
        flap > 0.45 ? const Color(0xFFFFA1B8) : const Color(0xFFFFD45A);
    const body = Color(0xFF6D4938);
    grid.rect(3, 2, 1, 3, body);
    grid.rect(1, 1, 2, 2, wing);
    grid.rect(4, 1, 2, 2, wing);
    grid.rect(1, 4, 2, 1, wing.withValues(alpha: 0.85));
    grid.rect(4, 4, 2, 1, wing.withValues(alpha: 0.85));
    grid.rect(2, 2, 1, 1, Colors.white.withValues(alpha: 0.65));
    grid.rect(4, 2, 1, 1, Colors.white.withValues(alpha: 0.65));
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter oldDelegate) =>
      oldDelegate.flap != flap;
}

class _PixelStar extends StatelessWidget {
  const _PixelStar({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(color: color),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 5;
    final paint = Paint()..color = color;
    const cells = [
      Offset(2, 0),
      Offset(2, 1),
      Offset(0, 2),
      Offset(1, 2),
      Offset(2, 2),
      Offset(3, 2),
      Offset(4, 2),
      Offset(2, 3),
      Offset(2, 4),
    ];
    for (final o in cells) {
      canvas.drawRect(
        Rect.fromLTWH(o.dx * cell, o.dy * cell, cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class Pippa extends StatelessWidget {
  const Pippa({
    super.key,
    this.size = 210,
    this.row = 3,
    this.frameCount = 4,
    this.duration = const Duration(milliseconds: 980),
  });

  final double size;
  final int row;
  final int frameCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return _PetdexPet(
      name: 'Pippa',
      assetPath: 'assets/pets/pippa/spritesheet.webp',
      size: size,
      frameWidth: 192,
      frameHeight: 208,
      row: row,
      frameCount: frameCount,
      duration: duration,
    );
  }
}

class Kebo extends StatelessWidget {
  const Kebo({
    super.key,
    this.size = 214,
    this.row = 3,
    this.frameCount = 4,
    this.duration = const Duration(milliseconds: 1040),
  });

  final double size;
  final int row;
  final int frameCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return _PetdexPet(
      name: 'Kebo',
      assetPath: 'assets/pets/kebo/spritesheet.webp',
      size: size,
      frameWidth: 192,
      frameHeight: 208,
      row: row,
      frameCount: frameCount,
      duration: duration,
    );
  }
}

class _PetWithBubble extends StatefulWidget {
  const _PetWithBubble({
    required this.name,
    required this.assetPath,
    required this.size,
    required this.rows,
    required this.duration,
    required this.greeting,
    this.enableBubble = true,
  });

  final String name;
  final String assetPath;
  final double size;
  final List<int> rows;
  final Duration duration;
  final String greeting;
  final bool enableBubble;

  @override
  State<_PetWithBubble> createState() => _PetWithBubbleState();
}

class _PetWithBubbleState extends State<_PetWithBubble> {
  bool _showBubble = false;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleBubble();
  }

  @override
  void didUpdateWidget(covariant _PetWithBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableBubble != oldWidget.enableBubble) {
      if (widget.enableBubble) {
        _scheduleBubble();
      } else {
        _showTimer?.cancel();
        _hideTimer?.cancel();
        if (_showBubble) {
          setState(() => _showBubble = false);
        }
      }
    }
  }

  void _scheduleBubble() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (!widget.enableBubble) {
      return;
    }
    _showTimer = Timer(Duration(seconds: 3 + math.Random().nextInt(10)), () {
      if (mounted) {
        setState(() => _showBubble = true);
        _hideTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _showBubble = false);
            _scheduleBubble();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        _RandomHomePet(
          name: widget.name,
          assetPath: widget.assetPath,
          size: widget.size,
          rows: widget.rows,
          duration: widget.duration,
        ),
        Positioned(
          top: -30,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showBubble ? 1.0 : 0.0,
            child: _PixelSpeechBubble(text: widget.greeting),
          ),
        ),
      ],
    );
  }
}

class _PixelSpeechBubble extends StatelessWidget {
  const _PixelSpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B2D33), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2B2D33),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RandomHomePet extends StatefulWidget {
  const _RandomHomePet({
    required this.name,
    required this.assetPath,
    required this.size,
    required this.rows,
    required this.duration,
  });

  final String name;
  final String assetPath;
  final double size;
  final List<int> rows;
  final Duration duration;

  @override
  State<_RandomHomePet> createState() => _RandomHomePetState();
}

class _RandomHomePetState extends State<_RandomHomePet> {
  late final math.Random _random;
  Timer? _timer;
  late int _row;

  @override
  void initState() {
    super.initState();
    _random = math.Random(widget.name.hashCode);
    _row = widget.rows.first;
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || widget.rows.length < 2) return;
      var nextRow = _row;
      while (nextRow == _row) {
        nextRow = widget.rows[_random.nextInt(widget.rows.length)];
      }
      setState(() => _row = nextRow);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild
          ],
        );
      },
      child: _PetdexPet(
        key: ValueKey('${widget.name}-$_row'),
        name: widget.name,
        assetPath: widget.assetPath,
        size: widget.size,
        frameWidth: 192,
        frameHeight: 208,
        row: _row,
        frameCount: 4,
        duration: widget.duration,
      ),
    );
  }
}

class PetdexFace extends StatelessWidget {
  const PetdexFace({
    super.key,
    required this.assetPath,
    this.size = 52,
  });

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 192,
            height: 208,
            child: _PetdexSprite(
              assetPath: assetPath,
              frameWidth: 192,
              frameHeight: 208,
              columns: 8,
              row: 0,
              frameCount: 1,
              duration: const Duration(milliseconds: 1000),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedPetdexFace extends StatelessWidget {
  const AnimatedPetdexFace({
    super.key,
    required this.assetPath,
    this.size = 52,
    this.row = 0,
    this.frameCount = 4,
    this.duration = const Duration(milliseconds: 1000),
  });

  final String assetPath;
  final double size;
  final int row;
  final int frameCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 192,
            height: 208,
            child: _PetdexSprite(
              assetPath: assetPath,
              frameWidth: 192,
              frameHeight: 208,
              columns: 8,
              row: row,
              frameCount: frameCount,
              duration: duration,
            ),
          ),
        ),
      ),
    );
  }
}

class PetdexMood extends StatelessWidget {
  const PetdexMood({
    super.key,
    required this.name,
    required this.assetPath,
    required this.mood,
    this.size = 82,
  });

  final String name;
  final String assetPath;
  final String mood;
  final double size;

  int get _row => switch (mood) {
        'happy' => 2,
        'loved' => 3,
        'calm' => 0,
        'excited' => 7,
        'tired' => 4,
        'sad' => 6,
        'anxious' => 6,
        'scared' => 4,
        'grateful' => 2,
        'hopeful' => 7,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    return _PetdexPet(
      name: name,
      assetPath: assetPath,
      size: size,
      frameWidth: 192,
      frameHeight: 208,
      row: _row,
      frameCount: 4,
      duration: name == 'Pippa'
          ? const Duration(milliseconds: 980)
          : const Duration(milliseconds: 1040),
    );
  }
}

class _PetdexPet extends StatelessWidget {
  const _PetdexPet({
    super.key,
    required this.name,
    required this.assetPath,
    required this.size,
    required this.frameWidth,
    required this.frameHeight,
    required this.row,
    required this.frameCount,
    required this.duration,
  });

  final String name;
  final String assetPath;
  final double size;
  final int frameWidth;
  final int frameHeight;
  final int row;
  final int frameCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final height = size * frameHeight / frameWidth;

    return Semantics(
      image: true,
      label: name,
      child: SizedBox(
        width: size,
        height: height + 24,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2D33).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SizedBox(width: size * 0.68, height: 18),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _PetdexSprite(
                assetPath: assetPath,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                columns: 8,
                row: row,
                frameCount: frameCount,
                duration: duration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetdexSprite extends StatefulWidget {
  const _PetdexSprite({
    required this.assetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.columns,
    required this.row,
    required this.frameCount,
    required this.duration,
  });

  final String assetPath;
  final int frameWidth;
  final int frameHeight;
  final int columns;
  final int row;
  final int frameCount;
  final Duration duration;

  @override
  State<_PetdexSprite> createState() => _PetdexSpriteState();
}

class _PetdexSpriteState extends State<_PetdexSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 0;
    if (widget.frameCount > 1) {
      _controller.repeat();
    }
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _PetdexSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _image?.dispose();
      _image = null;
      _loadImage();
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (widget.frameCount > 1) {
        _controller.repeat();
      } else {
        _controller.value = 0;
      }
    }
    if (oldWidget.frameCount != widget.frameCount) {
      if (widget.frameCount > 1) {
        _controller.repeat();
      } else {
        _controller
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.frameWidth / widget.frameHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final image = _image;
          if (image == null) {
            return const SizedBox.expand();
          }

          final frame = (_controller.value * widget.frameCount).floor() %
              widget.frameCount;
          return CustomPaint(
            painter: _PetdexSpritePainter(
              image: image,
              frame: frame,
              row: widget.row,
              columns: widget.columns,
              frameWidth: widget.frameWidth,
              frameHeight: widget.frameHeight,
            ),
          );
        },
      ),
    );
  }
}

class _PetdexSpritePainter extends CustomPainter {
  const _PetdexSpritePainter({
    required this.image,
    required this.frame,
    required this.row,
    required this.columns,
    required this.frameWidth,
    required this.frameHeight,
  });

  final ui.Image image;
  final int frame;
  final int row;
  final int columns;
  final int frameWidth;
  final int frameHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final column = frame % columns;
    final sourceLeft = column * frameWidth;
    final sourceTop = row * frameHeight;
    if (sourceLeft < 0 ||
        sourceTop < 0 ||
        sourceLeft + frameWidth > image.width ||
        sourceTop + frameHeight > image.height) {
      return;
    }
    final source = Rect.fromLTWH(
      sourceLeft.toDouble(),
      sourceTop.toDouble(),
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
    final destination = Offset.zero & size;
    canvas.drawImageRect(image, source, destination, Paint());
  }

  @override
  bool shouldRepaint(covariant _PetdexSpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.frame != frame ||
        oldDelegate.row != row ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight;
  }
}

class Panda extends StatelessWidget {
  const Panda({super.key, this.size = 236});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _PixelMascot(
      kind: _MascotKind.panda,
      size: size,
      drift: -0.05,
      duration: const Duration(milliseconds: 5200),
    );
  }
}

class Koala extends StatelessWidget {
  const Koala({super.key, this.size = 228});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _PixelMascot(
      kind: _MascotKind.koala,
      size: size,
      drift: 0.1,
      duration: const Duration(milliseconds: 5900),
    );
  }
}

enum _MascotKind { panda, koala }

class _PixelMascot extends StatefulWidget {
  const _PixelMascot({
    required this.kind,
    required this.size,
    required this.drift,
    required this.duration,
  });

  final _MascotKind kind;
  final double size;
  final double drift;
  final Duration duration;

  @override
  State<_PixelMascot> createState() => _PixelMascotState();
}

class _PixelMascotState extends State<_PixelMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _tap;
  final math.Random _random = math.Random();
  late double _blinkAt;
  late double _blinkWidth;

  @override
  void initState() {
    super.initState();
    _resetBlink();
    _idle = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _resetBlink();
        }
      })
      ..repeat();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _idle.dispose();
    _tap.dispose();
    super.dispose();
  }

  void _pop() {
    _tap.forward(from: 0);
  }

  void _resetBlink() {
    _blinkAt = 0.16 + _random.nextDouble() * 0.68;
    _blinkWidth = 0.018 + _random.nextDouble() * 0.018;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _pop,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _tap]),
        builder: (context, child) {
          final phase = _idle.value * math.pi * 2;
          final easedIdle = Curves.easeInOut.transform(
            (math.sin(phase * 0.9 + widget.drift) + 1) / 2,
          );
          final together = Curves.easeInOut.transform(
            (math.sin(phase * 0.34 + widget.drift) + 1) / 2,
          );
          final bob = (easedIdle - 0.5) * 9.0;
          final lean = widget.kind == _MascotKind.panda
              ? together * 0.035
              : -together * 0.035;
          final sway = math.sin(phase * 0.55 + widget.drift) * 0.026 + lean;
          final scale = 1 + (easedIdle - 0.5) * 0.026;
          final tapPulse = math.sin(_tap.value * math.pi).clamp(0.0, 1.0);
          final blinkDistance =
              ((_idle.value - _blinkAt).abs() / _blinkWidth).clamp(0.0, 1.0);
          final blink = Curves.easeInOut.transform(1 - blinkDistance);
          final earMoment = math
              .pow(math.sin(phase * 0.72 + widget.drift).abs(), 9)
              .toDouble();
          final earWiggle =
              Curves.easeInOut.transform(earMoment.clamp(0.0, 1.0)) *
                      (widget.kind == _MascotKind.panda ? 1.0 : 1.25) +
                  tapPulse * 1.6;
          final armWave = math.sin(phase * 0.95 + widget.drift * 2) * 0.7 +
              together * 0.4 +
              tapPulse * 2.2;
          final legBounce = (easedIdle - 0.5) * 1.2;

          return Transform.translate(
            offset: Offset(0, bob),
            child: Transform.rotate(
              angle: sway,
              child: Transform.scale(
                scale: scale + tapPulse * 0.07,
                child: CustomPaint(
                  size: Size(widget.size, widget.size * 1.2),
                  painter: _PixelMascotPainter(
                    kind: widget.kind,
                    breathing: math.sin(phase * 0.9 + widget.drift) * 0.6,
                    blink: blink,
                    earWiggle: earWiggle,
                    armWave: armWave,
                    legBounce: legBounce,
                    tapPulse: tapPulse,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PixelMascotPainter extends CustomPainter {
  const _PixelMascotPainter({
    required this.kind,
    required this.breathing,
    required this.blink,
    required this.earWiggle,
    required this.armWave,
    required this.legBounce,
    required this.tapPulse,
  });

  final _MascotKind kind;
  final double breathing;
  final double blink;
  final double earWiggle;
  final double armWave;
  final double legBounce;
  final double tapPulse;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 32, height: 36, size: size);
    final bodyLift = breathing.round();
    final headLift = bodyLift + math.sin(earWiggle * 0.7).round();
    final earShift = math.sin(earWiggle).round();
    final wave = armWave.round();
    final legShift = legBounce.round();

    _pixelShadow(grid, cx: 16, cy: 33, rx: 11, ry: 2);
    if (tapPulse > 0.04) {
      _drawTapAura(grid, tapPulse);
    }
    if (kind == _MascotKind.panda) {
      _drawPandaSprite(
        grid,
        bodyLift: bodyLift,
        headLift: headLift,
        earShift: earShift,
        wave: wave,
        legShift: legShift,
      );
    } else {
      _drawKoalaSprite(
        grid,
        bodyLift: bodyLift,
        headLift: headLift,
        earShift: earShift,
        wave: wave,
        legShift: legShift,
      );
    }
  }

  void _drawPandaSprite(
    _PixelGrid grid, {
    required int bodyLift,
    required int headLift,
    required int earShift,
    required int wave,
    required int legShift,
  }) {
    const black = Color(0xFF131313);
    const blackSoft = Color(0xFF25252B);
    const white = Color(0xFFFFFCF4);
    const cream = Color(0xFFF3E7D5);
    const blush = Color(0xFFFF9FAB);
    const smile = Color(0xFF6C4745);

    grid.ellipse(8, 29 + legShift, 5, 3, black);
    grid.ellipse(24, 29 - legShift, 5, 3, black);
    grid.ellipse(9, 28 + legShift, 2, 1, blackSoft);
    grid.ellipse(23, 28 - legShift, 2, 1, blackSoft);

    grid.ellipse(16, 25 + bodyLift, 10, 8, black);
    grid.ellipse(16, 25 + bodyLift, 6, 6, cream);
    grid.rect(12, 25 + bodyLift, 8, 3, white);
    grid.rect(14, 27 + bodyLift, 1, 1, const Color(0xFFFFE4EF));
    grid.rect(17, 28 + bodyLift, 1, 1, const Color(0xFFFFE4EF));

    grid.ellipse(6, 23 + wave, 4, 4, black);
    grid.ellipse(26, 23 - wave, 4, 4, black);
    grid.rect(6, 23 + wave, 2, 2, cream.withValues(alpha: 0.65));
    grid.rect(24, 23 - wave, 2, 2, cream.withValues(alpha: 0.65));

    grid.ellipse(8 + earShift, 7 + headLift, 5, 5, black);
    grid.ellipse(24 - earShift, 7 + headLift, 5, 5, black);
    grid.rect(7 + earShift, 4 + headLift, 3, 1, blackSoft);
    grid.rect(22 - earShift, 4 + headLift, 3, 1, blackSoft);

    grid.ellipse(16, 14 + headLift, 13, 11, black);
    grid.ellipse(16, 14 + headLift, 12, 10, white);
    grid.rect(10, 5 + headLift, 2, 1, const Color(0xFFE8D4BD));
    grid.rect(13, 4 + headLift, 1, 1, const Color(0xFFE8D4BD));
    grid.rect(16, 4 + headLift, 1, 1, const Color(0xFFE8D4BD));
    _drawPixelBow(
      grid,
      x: 20 - earShift,
      y: 5 + headLift,
      main: const Color(0xFFFF7FA0),
      shade: const Color(0xFFD94E78),
      light: const Color(0xFFFFC3D0),
    );

    grid.ellipse(10, 14 + headLift, 4, 5, black);
    grid.ellipse(22, 14 + headLift, 4, 5, black);
    if (blink > 0.45) {
      grid.rect(8, 14 + headLift, 5, 1, white);
      grid.rect(20, 14 + headLift, 5, 1, white);
    } else {
      grid.rect(10, 13 + headLift, 2, 2, const Color(0xFF080808));
      grid.rect(21, 13 + headLift, 2, 2, const Color(0xFF080808));
      grid.rect(11, 12 + headLift, 1, 1, Colors.white);
      grid.rect(22, 12 + headLift, 1, 1, Colors.white);
    }

    grid.ellipse(16, 18 + headLift, 5, 3, white);
    grid.rect(15, 17 + headLift, 2, 1, black);
    grid.rect(14, 19 + headLift, 1, 1, smile);
    grid.rect(17, 19 + headLift, 1, 1, smile);
    if (tapPulse > 0.35) {
      grid.rect(15, 20 + headLift, 2, 1, const Color(0xFFFF7FA0));
    }
    grid.rect(7, 18 + headLift, 3, 2, blush);
    grid.rect(22, 18 + headLift, 3, 2, blush);
    grid.rect(8, 17 + headLift, 1, 1, const Color(0xFFFFC4CB));
    grid.rect(23, 17 + headLift, 1, 1, const Color(0xFFFFC4CB));
    grid.rect(12, 24 + bodyLift, 2, 1, const Color(0xFFFFC3D0));
    grid.rect(18, 24 + bodyLift, 2, 1, const Color(0xFFFFC3D0));
    grid.rect(15, 23 + bodyLift, 2, 2, const Color(0xFFFF7FA0));
    grid.rect(16, 24 + bodyLift, 1, 1, const Color(0xFFFFEEF3));
    _drawPixelScarf(
      grid,
      x: 10,
      y: 21 + bodyLift,
      main: const Color(0xFFFFD45A),
      shade: const Color(0xFFE4933F),
    );
  }

  void _drawKoalaSprite(
    _PixelGrid grid, {
    required int bodyLift,
    required int headLift,
    required int earShift,
    required int wave,
    required int legShift,
  }) {
    const outline = Color(0xFF5B625F);
    const fur = Color(0xFFC9CFCA);
    const furLight = Color(0xFFE9EDEA);
    const shade = Color(0xFFAAB2AE);
    const inner = Color(0xFFFFEFEA);
    const nose = Color(0xFF4B5250);
    const blush = Color(0xFFF39EA1);

    grid.ellipse(9, 29 + legShift, 4, 3, outline);
    grid.ellipse(23, 29 - legShift, 4, 3, outline);
    grid.ellipse(10, 28 + legShift, 2, 1, shade);
    grid.ellipse(22, 28 - legShift, 2, 1, shade);

    grid.ellipse(16, 25 + bodyLift, 9, 8, outline);
    grid.ellipse(16, 24 + bodyLift, 8, 7, fur);
    grid.ellipse(16, 27 + bodyLift, 5, 4, inner);
    grid.rect(13, 25 + bodyLift, 6, 1, furLight);
    grid.rect(14, 27 + bodyLift, 1, 1, const Color(0xFFFFD7DE));
    grid.rect(18, 27 + bodyLift, 1, 1, const Color(0xFFFFD7DE));

    grid.ellipse(7, 23 + wave, 3, 4, outline);
    grid.ellipse(25, 23 - wave, 3, 4, outline);
    grid.rect(7, 24 + wave, 2, 1, furLight.withValues(alpha: 0.65));
    grid.rect(23, 24 - wave, 2, 1, furLight.withValues(alpha: 0.65));

    grid.ellipse(7 + earShift, 10 + headLift, 7, 7, outline);
    grid.ellipse(25 - earShift, 10 + headLift, 7, 7, outline);
    grid.ellipse(7 + earShift, 10 + headLift, 5, 5, furLight);
    grid.ellipse(25 - earShift, 10 + headLift, 5, 5, furLight);
    grid.ellipse(7 + earShift, 11 + headLift, 3, 4, inner);
    grid.ellipse(25 - earShift, 11 + headLift, 3, 4, inner);
    _drawPixelLeafPin(
      grid,
      x: 23 - earShift,
      y: 7 + headLift,
      green: const Color(0xFF78C96D),
      shade: const Color(0xFF3E9A55),
      flower: const Color(0xFFFFB2C0),
    );

    grid.ellipse(16, 15 + headLift, 12, 10, outline);
    grid.ellipse(16, 15 + headLift, 11, 9, fur);
    grid.rect(12, 6 + headLift, 2, 1, furLight);
    grid.rect(15, 5 + headLift, 2, 1, furLight);
    grid.rect(19, 6 + headLift, 1, 1, shade);

    if (blink > 0.45) {
      grid.rect(9, 15 + headLift, 4, 1, outline);
      grid.rect(20, 15 + headLift, 4, 1, outline);
    } else {
      grid.rect(10, 14 + headLift, 2, 2, const Color(0xFF222625));
      grid.rect(21, 14 + headLift, 2, 2, const Color(0xFF222625));
      grid.rect(11, 14 + headLift, 1, 1, Colors.white);
      grid.rect(22, 14 + headLift, 1, 1, Colors.white);
    }

    grid.ellipse(16, 16 + headLift, 4, 5, nose);
    grid.rect(15, 13 + headLift, 2, 1, const Color(0xFF737B78));
    grid.rect(14, 21 + headLift, 1, 1, outline.withValues(alpha: 0.7));
    grid.rect(18, 21 + headLift, 1, 1, outline.withValues(alpha: 0.7));
    if (tapPulse > 0.35) {
      grid.rect(15, 21 + headLift, 3, 1, const Color(0xFF5B625F));
    }
    grid.rect(7, 18 + headLift, 3, 2, blush.withValues(alpha: 0.82));
    grid.rect(22, 18 + headLift, 3, 2, blush.withValues(alpha: 0.82));
    grid.rect(8, 17 + headLift, 1, 1, const Color(0xFFFFC3C4));
    grid.rect(23, 17 + headLift, 1, 1, const Color(0xFFFFC3C4));
    grid.rect(12, 24 + bodyLift, 2, 1, furLight);
    grid.rect(18, 24 + bodyLift, 2, 1, furLight);
    grid.rect(15, 25 + bodyLift, 2, 1, const Color(0xFFFFB2C0));
    grid.rect(16, 26 + bodyLift, 1, 1, const Color(0xFFFFE2E7));
    _drawPixelScarf(
      grid,
      x: 11,
      y: 22 + bodyLift,
      main: const Color(0xFF7CC2FF),
      shade: const Color(0xFF4D7FD6),
    );
  }

  void _drawTapAura(_PixelGrid grid, double pulse) {
    final glow = Color.lerp(
      const Color(0xFFFFF1A8),
      const Color(0xFFFF7FA0),
      pulse,
    )!;
    final lift = (pulse * 4).round();
    grid.rect(5, 7 - lift, 1, 1, glow);
    grid.rect(27, 8 - lift, 1, 1, glow);
    grid.rect(3, 16 - lift, 1, 1, const Color(0xFFFF9FAB));
    grid.rect(29, 17 - lift, 1, 1, const Color(0xFFFF9FAB));
    grid.rect(14, 2 - lift, 1, 1, const Color(0xFFFFFFFF));
    grid.rect(17, 2 - lift, 1, 1, glow);
  }

  void _drawPixelScarf(
    _PixelGrid grid, {
    required int x,
    required int y,
    required Color main,
    required Color shade,
  }) {
    grid.rect(x, y, 12, 1, shade);
    grid.rect(x + 1, y, 10, 2, main);
    grid.rect(x + 7, y + 2, 2, 3, shade);
    grid.rect(x + 8, y + 2, 2, 3, main);
    grid.rect(x + 2, y, 1, 1, Colors.white.withValues(alpha: 0.55));
  }

  void _drawPixelBow(
    _PixelGrid grid, {
    required int x,
    required int y,
    required Color main,
    required Color shade,
    required Color light,
  }) {
    grid.rect(x, y + 1, 2, 2, shade);
    grid.rect(x + 4, y + 1, 2, 2, shade);
    grid.rect(x + 1, y, 2, 3, main);
    grid.rect(x + 3, y, 2, 3, main);
    grid.rect(x + 2, y + 1, 2, 2, shade);
    grid.rect(x + 2, y + 1, 1, 1, light);
    grid.rect(x + 4, y, 1, 1, light);
  }

  void _drawPixelLeafPin(
    _PixelGrid grid, {
    required int x,
    required int y,
    required Color green,
    required Color shade,
    required Color flower,
  }) {
    grid.rect(x + 1, y, 2, 1, green);
    grid.rect(x, y + 1, 4, 2, green);
    grid.rect(x + 2, y + 3, 2, 1, shade);
    grid.rect(x + 4, y + 1, 1, 1, shade);
    grid.rect(x + 1, y + 1, 1, 1, const Color(0xFFD9F4A3));
    grid.rect(x - 1, y + 3, 1, 1, flower);
    grid.rect(x, y + 2, 1, 1, flower);
    grid.rect(x, y + 4, 1, 1, flower);
    grid.rect(x + 1, y + 3, 1, 1, const Color(0xFFFFF1A8));
  }

  void _pixelShadow(
    _PixelGrid grid, {
    required int cx,
    required int cy,
    required int rx,
    required int ry,
  }) {
    grid.ellipse(
      cx,
      cy,
      rx + 1,
      ry + 1,
      const Color(0xFF2B2D33).withValues(alpha: 0.18),
    );
    grid.ellipse(
      cx,
      cy,
      rx,
      ry,
      const Color(0xFF2B2D33).withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _PixelMascotPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.breathing != breathing ||
        oldDelegate.blink != blink ||
        oldDelegate.earWiggle != earWiggle ||
        oldDelegate.armWave != armWave ||
        oldDelegate.legBounce != legBounce ||
        oldDelegate.tapPulse != tapPulse;
  }
}

class _PixelGrid {
  _PixelGrid({
    required this.canvas,
    required this.width,
    required this.height,
    required this.size,
  })  : cell = math.min(size.width / width, size.height / height),
        offsetX = (size.width -
                math.min(size.width / width, size.height / height) * width) /
            2,
        offsetY = (size.height -
                math.min(size.width / width, size.height / height) * height) /
            2;

  final Canvas canvas;
  final int width;
  final int height;
  final Size size;
  final double cell;
  final double offsetX;
  final double offsetY;

  void rect(int x, int y, int w, int h, Color color) {
    if (w <= 0 || h <= 0) {
      return;
    }
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(offsetX + x * cell, offsetY + y * cell, w * cell, h * cell),
      paint,
    );
  }

  void ellipse(int cx, int cy, int rx, int ry, Color color) {
    final paint = Paint()..color = color;
    for (var y = cy - ry; y <= cy + ry; y += 1) {
      for (var x = cx - rx; x <= cx + rx; x += 1) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1) {
          canvas.drawRect(
            Rect.fromLTWH(offsetX + x * cell, offsetY + y * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }
}

class _PixelSparkle extends StatelessWidget {
  const _PixelSparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PixelSparklePainter(color),
    );
  }
}

class _PixelSparklePainter extends CustomPainter {
  _PixelSparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 5, height: 5, size: size);
    grid.rect(2, 0, 1, 1, color);
    grid.rect(2, 1, 1, 1, color);
    grid.rect(0, 2, 5, 1, color);
    grid.rect(2, 2, 1, 1, Colors.white);
    grid.rect(2, 3, 1, 1, color);
    grid.rect(2, 4, 1, 1, color);
  }

  @override
  bool shouldRepaint(covariant _PixelSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SharedPixelHeart extends StatefulWidget {
  const _SharedPixelHeart();

  @override
  State<_SharedPixelHeart> createState() => _SharedPixelHeartState();
}

class _SharedPixelHeartState extends State<_SharedPixelHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final floatY = math.sin(phase) * 6;
        final floatX = math.sin(phase * 0.55) * 3;
        final scale = 1 + math.sin(phase * 1.5) * 0.05;
        return Transform.translate(
          offset: Offset(floatX, floatY),
          child: Transform.scale(
            scale: scale,
            child: const CustomPaint(
              size: Size.square(48),
              painter: _PixelHeartPainter(),
            ),
          ),
        );
      },
    );
  }
}

class _PixelHeartPainter extends CustomPainter {
  const _PixelHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 9, height: 9, size: size);
    const outline = Color(0xFFB8425D);
    const fill = Color(0xFFFF6F91);
    const light = Color(0xFFFFBBC8);
    const shine = Color(0xFFFFFFFF);
    grid.rect(2, 1, 2, 1, outline);
    grid.rect(5, 1, 2, 1, outline);
    grid.rect(1, 2, 7, 1, outline);
    grid.rect(1, 3, 7, 2, outline);
    grid.rect(2, 5, 5, 1, outline);
    grid.rect(3, 6, 3, 1, outline);
    grid.rect(4, 7, 1, 1, outline);
    grid.rect(2, 2, 2, 2, fill);
    grid.rect(5, 2, 2, 2, fill);
    grid.rect(2, 4, 5, 1, fill);
    grid.rect(3, 5, 3, 1, fill);
    grid.rect(4, 6, 1, 1, fill);
    grid.rect(2, 2, 1, 1, light);
    grid.rect(5, 2, 1, 1, light);
    grid.rect(3, 3, 1, 1, shine.withValues(alpha: 0.65));
  }

  @override
  bool shouldRepaint(covariant _PixelHeartPainter oldDelegate) => false;
}

class Ground extends StatelessWidget {
  const Ground({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 118 : 138,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.elliptical(420, 90),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFA4E879),
                    Color(0xFF58AF65),
                    Color(0xFF3F8F55),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 14),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 54,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3B8E4F),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 36,
            bottom: 64,
            child: _PixelFlower(color: Color(0xFFFF8FAA)),
          ),
          const Positioned(
            left: 82,
            bottom: 70,
            child: _PixelFlower(color: Color(0xFFFFD45A)),
          ),
          const Positioned(
            right: 50,
            bottom: 66,
            child: _PixelFlower(color: Color(0xFFFFF1A8)),
          ),
          const Positioned(
            right: 104,
            bottom: 72,
            child: _PixelFlower(color: Color(0xFFFF8FAA)),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PixelTile(size: 14, color: const Color(0xFF5EAD6F)),
                _PixelTile(size: 14, color: const Color(0xFF4E9E63)),
                _PixelTile(size: 14, color: const Color(0xFF5EAD6F)),
                _PixelTile(size: 14, color: const Color(0xFF4E9E63)),
                _PixelTile(size: 14, color: const Color(0xFF5EAD6F)),
                _PixelTile(size: 14, color: const Color(0xFF4E9E63)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x33000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelFlower extends StatelessWidget {
  const _PixelFlower({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 28),
      painter: _FlowerPainter(color),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _PixelGrid(canvas: canvas, width: 7, height: 9, size: size);
    const stem = Color(0xFF2F7C48);
    grid.rect(3, 4, 1, 5, stem);
    grid.rect(2, 6, 1, 1, stem);
    grid.rect(4, 5, 1, 1, stem);
    grid.rect(3, 1, 1, 1, color);
    grid.rect(2, 2, 3, 1, color);
    grid.rect(1, 3, 5, 1, color);
    grid.rect(2, 4, 3, 1, color);
    grid.rect(3, 3, 1, 1, const Color(0xFFFFF7A8));
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PixelTile extends StatelessWidget {
  const _PixelTile({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xFF2D693C), width: 1),
      ),
    );
  }
}
