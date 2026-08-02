import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'cozy_garden_game.dart';

class CozyGardenGameView extends StatelessWidget {
  const CozyGardenGameView({super.key, required this.game});

  final CozyGardenGame game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Animated shared garden',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF263739),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.secondary.withValues(alpha: .7),
            width: 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: AspectRatio(
              aspectRatio: 1.2,
              child: GameWidget<CozyGardenGame>(
                game: game,
                loadingBuilder: _fallbackScene,
                errorBuilder: (context, _) => _fallbackScene(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackScene(BuildContext context) {
    return Image.asset(
      'assets/garden/garden_scene.png',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Color(0xFFBDE3A5),
      ),
    );
  }
}
