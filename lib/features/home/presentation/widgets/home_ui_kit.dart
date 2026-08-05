import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared visual language for the Home dashboard so every card lines up with
/// the same radius, spacing and press feedback.
const double kHomeCardRadius = 16;
const BorderRadius kHomeCardBorderRadius =
    BorderRadius.all(Radius.circular(kHomeCardRadius));

/// Padding shared by every tappable Home card.
const EdgeInsets kHomeCardPadding = EdgeInsets.all(12);

/// Minimum tap target for any Home card.
const double kHomeMinTapTarget = 48;

/// Clamped text scale used for the deterministic card heights. Keeping the
/// clamp in one place means every grid grows at exactly the same rate.
double homeTextScale(BuildContext context, {double max = 1.5}) {
  return MediaQuery.textScalerOf(context).scale(1).clamp(1.0, max).toDouble();
}

/// Returns how many columns keep a tile of [minTileWidth] readable inside
/// [width]. Larger text scales ask for wider tiles, so a narrow phone or a big
/// text scale drops to fewer columns instead of squeezing labels.
///
/// The text scale only counts for 25% of the extra width it asks for: labels
/// wrap to a second line long before a tile needs to be 1.5x wider, and the
/// card heights already grow with the scale to hold that extra line.
///
/// That keeps a 360px phone (336px of content) on two 150px columns through
/// Android's "Large" setting of 1.3x, where a stronger weighting would collapse
/// the whole dashboard into one long column. Anything past roughly 1.4x does
/// drop to a single column, which is the point where two labels genuinely stop
/// fitting side by side.
int homeGridColumns({
  required BuildContext context,
  required double width,
  double minTileWidth = 152,
  double spacing = 10,
  int maxColumns = 3,
}) {
  final textScale = homeTextScale(context, max: 1.6);
  final tileWidth = minTileWidth * (1 + (textScale - 1) * 0.25);
  final columns = ((width + spacing) / (tileWidth + spacing)).floor();
  return columns.clamp(1, maxColumns);
}

/// Wraps a Home card with a gentle press scale plus the usual ink response.
class HomePressable extends StatefulWidget {
  const HomePressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = kHomeCardBorderRadius,
    this.pressedScale = 0.972,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double pressedScale;

  @override
  State<HomePressable> createState() => _HomePressableState();
}

class _HomePressableState extends State<HomePressable> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed || widget.onTap == null) {
      return;
    }
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: _isPressed && !reduceMotion ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Quiet label used above each Home section. Intentionally lighter than the
/// hero so the connection card stays the strongest element on the screen.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 15,
            color: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.9 : 1),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7),
                  scheme.outlineVariant.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pixel-dash label used for the groups inside "Explore Our Space".
class HomeGroupLabel extends StatelessWidget {
  const HomeGroupLabel({
    super.key,
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

/// A responsive grid with a deterministic [tileHeight], so every card in a row
/// matches without needing an `IntrinsicHeight` pass.
///
/// When [stretchLastRow] is true, a trailing row that cannot be filled lets its
/// cards span the remaining width instead of leaving an empty slot. That is how
/// the fifth "Today Together" card gets a full-width row of its own.
class HomeCardGrid extends StatelessWidget {
  const HomeCardGrid({
    super.key,
    required this.children,
    required this.columns,
    required this.tileHeight,
    this.spacing = 10,
    this.stretchLastRow = false,
  });

  final List<Widget> children;
  final int columns;
  final double tileHeight;
  final double spacing;
  final bool stretchLastRow;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final columnCount = columns < 1 ? 1 : columns;
    final height = math.max(tileHeight, kHomeMinTapTarget);
    final rows = <Widget>[];

    for (var start = 0; start < children.length; start += columnCount) {
      final remaining = children.length - start;
      final isLastRow = remaining <= columnCount;
      final filledSlots = remaining < columnCount ? remaining : columnCount;
      final slotCount = isLastRow && stretchLastRow ? filledSlots : columnCount;

      final slots = <Widget>[];
      for (var column = 0; column < slotCount; column += 1) {
        if (column > 0) {
          slots.add(SizedBox(width: spacing));
        }
        final index = start + column;
        slots.add(
          Expanded(
            child: index < children.length
                ? children[index]
                : const SizedBox.shrink(),
          ),
        );
      }

      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: spacing));
      }
      rows.add(
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: slots,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
