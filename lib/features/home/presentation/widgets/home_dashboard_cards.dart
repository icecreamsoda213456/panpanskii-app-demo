import 'package:flutter/material.dart';

import 'home_action_button.dart';
import 'home_ui_kit.dart';

/// Quick action tile. Keeps the existing pixel button identity while the grid
/// owns the height, so a row of actions always lines up.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.label,
    required this.glyph,
    required this.gradient,
    required this.textColor,
    required this.shadowColor,
    required this.onPressed,
  });

  final String label;
  final HomeActionGlyph glyph;
  final Gradient gradient;
  final Color textColor;
  final Color? shadowColor;
  final VoidCallback? onPressed;

  /// Slightly more compact than the old tile, but still far above the 48dp
  /// minimum tap target and still growing with the text scale.
  static double heightFor(BuildContext context) {
    final scale = homeTextScale(context);
    return 100 + (scale - 1) * 46;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: HomeActionButton(
          label: label,
          glyph: glyph,
          gradient: gradient,
          textColor: textColor,
          shadowColor: shadowColor,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Tile used by "Today Together" and, in its emphasized form, by
/// "Next Together".
///
/// [stacked] puts the icon above the label so two of these still read clearly
/// side by side on a 360dp phone. The wide row form is used whenever the tile
/// owns the full width.
class TodayTogetherCard extends StatelessWidget {
  const TodayTogetherCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.stacked = false,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool stacked;

  /// Used by "Next Together" so the live calendar information reads as the
  /// most important row on the lower half of the screen.
  final bool emphasized;

  static double heightFor(BuildContext context, {bool stacked = false}) {
    final scale = homeTextScale(context);
    return stacked ? 112 + (scale - 1) * 56 : 80 + (scale - 1) * 44;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Past ~1.2 the subtitle drops to a single line so the fixed tile height
    // stays comfortable instead of clipping mid-sentence.
    final subtitleMaxLines = homeTextScale(context) > 1.2 ? 1 : 2;

    final titleText = Text(
      title,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );
    final subtitleText = Text(
      subtitle,
      maxLines: stacked ? 1 : subtitleMaxLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 11.5,
        height: 1.2,
      ),
    );

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: HomePressable(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: emphasized
                  ? accent.withValues(alpha: isDark ? 0.14 : 0.12)
                  : isDark
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
                      : scheme.surface.withValues(alpha: 0.88),
              borderRadius: kHomeCardBorderRadius,
              border: Border.all(
                color: accent.withValues(
                  alpha: emphasized ? (isDark ? 0.58 : 0.5) : 0.28,
                ),
                width: emphasized ? 1.5 : 1,
              ),
              boxShadow: emphasized
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: kHomeCardPadding,
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AccentIconBox(icon: icon, accent: accent),
                        const Spacer(),
                        titleText,
                        const SizedBox(height: 2),
                        subtitleText,
                      ],
                    )
                  : Row(
                      children: [
                        _AccentIconBox(icon: icon, accent: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleText,
                              const SizedBox(height: 3),
                              subtitleText,
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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

/// Card used inside "Explore Our Space". Same radius, padding and icon size as
/// every other Home card so the grid reads as one calm family of tiles.
class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  static double heightFor(BuildContext context) {
    final scale = homeTextScale(context);
    return 112 + (scale - 1) * 62;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: HomePressable(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.48)
                  : scheme.surface.withValues(alpha: 0.86),
              borderRadius: kHomeCardBorderRadius,
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.24 : 0.28),
              ),
            ),
            child: Padding(
              padding: kHomeCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccentIconBox(icon: icon, accent: accent),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
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

/// Consistent 40x40 icon container shared by every Home card.
class _AccentIconBox extends StatelessWidget {
  const _AccentIconBox({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }
}
