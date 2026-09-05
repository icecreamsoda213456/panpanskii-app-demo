import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'cozy_garden_game.dart';

class CozyGardenGameView extends StatefulWidget {
  const CozyGardenGameView({super.key, required this.game});

  final CozyGardenGame game;

  @override
  State<CozyGardenGameView> createState() => _CozyGardenGameViewState();
}

class _CozyGardenGameViewState extends State<CozyGardenGameView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mirror the platform "reduce motion" accessibility setting into the
    // scene. The game instance itself is owned by CozyGardenScreen, so this
    // widget never creates or disposes one.
    widget.game.setReducedMotion(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(CozyGardenGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.game, widget.game)) {
      widget.game.setReducedMotion(MediaQuery.disableAnimationsOf(context));
    }
  }

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
                game: widget.game,
                loadingBuilder: _fallbackScene,
                errorBuilder: (context, error) {
                  debugPrint('Cozy Garden scene failed to load: $error');
                  return _fallbackScene(context);
                },
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
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Cozy Garden fallback asset failed to load: $error');
        return const ColoredBox(color: Color(0xFFBDE3A5));
      },
    );
  }
}
