import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeActionButton extends StatelessWidget {
  const HomeActionButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.gradient,
    required this.textColor,
    this.shadowColor,
    this.onPressed,
    this.notificationCount,
  });

  final String label;
  final HomeActionGlyph glyph;
  final Gradient gradient;
  final Color textColor;
  final Color? shadowColor;
  final VoidCallback? onPressed;
  final int? notificationCount;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(14));
    final hasNotification = (notificationCount ?? 0) > 0;

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C3A35).withValues(alpha: 0.24),
              blurRadius: 0,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: (shadowColor ?? const Color(0xFF000000)).withValues(
                alpha: 0.22,
              ),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            child: Ink(
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.84),
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: const Color(
                              0xFF6F5142,
                            ).withValues(alpha: 0.32),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 7,
                    child: Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      _PixelButtonGlyph(
                        glyph: glyph,
                        foreground: textColor,
                        shadow: shadowColor ?? const Color(0xFF6F5142),
                      )
                          .animate(
                            target: onPressed == null ? 0 : 1,
                            onPlay: (controller) => controller.repeat(
                              reverse: true,
                              period: const Duration(milliseconds: 1800),
                            ),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.05, 1.05),
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1.08,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF4D332D).withValues(
                                alpha: textColor == Colors.white ? 0.32 : 0.12,
                              ),
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const Positioned(
                    right: 4,
                    top: 3,
                    child: Opacity(opacity: 0.38, child: _ButtonSparkles()),
                  ),
                  if (hasNotification)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: _NotificationBadge(count: notificationCount!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFF4F4F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFC42828),
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0xFFFF4F4F),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
          duration: 900.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.1, 1.1),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          duration: 900.ms,
          begin: const Offset(1.1, 1.1),
          end: const Offset(1, 1),
          curve: Curves.easeInOut,
        );
  }
}

enum HomeActionGlyph {
  heart,
  game,
  wisdom,
  pencil,
  reminder,
  question,
  journal,
  letter,
  chat,
  mood,
  bell,
  bible,
  camera,
  calendar,
}

class _PixelButtonGlyph extends StatelessWidget {
  const _PixelButtonGlyph({
    required this.glyph,
    required this.foreground,
    required this.shadow,
  });

  final HomeActionGlyph glyph;
  final Color foreground;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: 0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(
          _assetFor(glyph),
          width: 27,
          height: 27,
          colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
          semanticsLabel: glyph.name,
        ),
      ),
    );
  }

  String _assetFor(HomeActionGlyph glyph) {
    return switch (glyph) {
      HomeActionGlyph.heart => 'assets/icons/heart.svg',
      HomeActionGlyph.game => 'assets/icons/game.svg',
      HomeActionGlyph.wisdom ||
      HomeActionGlyph.bible =>
        'assets/icons/book.svg',
      HomeActionGlyph.pencil => 'assets/icons/pencil.svg',
      HomeActionGlyph.reminder ||
      HomeActionGlyph.bell =>
        'assets/icons/bell.svg',
      HomeActionGlyph.question => 'assets/icons/question.svg',
      HomeActionGlyph.journal => 'assets/icons/journal.svg',
      HomeActionGlyph.letter => 'assets/icons/letter.svg',
      HomeActionGlyph.chat => 'assets/icons/chat.svg',
      HomeActionGlyph.mood => 'assets/icons/mood.svg',
      HomeActionGlyph.camera => 'assets/icons/camera.svg',
      HomeActionGlyph.calendar => 'assets/icons/calendar.svg',
    };
  }
}

class _ButtonSparkles extends StatelessWidget {
  const _ButtonSparkles();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 34,
        height: 24,
        child: Stack(
          children: [
            _Dot(left: 18, top: 1, color: Color(0xFFFFF7A8)),
            _Dot(left: 0, top: 7, color: Color(0xFFFFF7A8)),
            _Dot(left: 10, top: 16, color: Colors.white),
            _Dot(left: 28, top: 18, color: Color(0xFFFFD45A)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.left, required this.top, required this.color});

  final double left;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 7),
      ),
    );
  }
}
