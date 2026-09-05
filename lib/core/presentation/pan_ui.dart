import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';

class PanGlassCard extends StatelessWidget {
  const PanGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor = const Color(0xFFFFD45A),
    this.opacity = 0.9,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (isDark ? scheme.surfaceContainerHighest : scheme.surface)
            .withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: isDark ? 26 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PanFeatureHeader extends StatelessWidget {
  const PanFeatureHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    this.trailing,
    this.accentColor = const Color(0xFFFFD45A),
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final Widget? trailing;
  final Color accentColor;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PanGlassCard(
      accentColor: accentColor,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Back home',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontSize: 20,
                      ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: -0.05, end: 0);
  }
}

class PanLoadingSliver extends StatelessWidget {
  const PanLoadingSliver({
    super.key,
    this.title = 'Loading',
    this.message = 'Preparing something lovely...',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: PanLoadingState(title: title, message: message),
    );
  }
}

class PanLoadingState extends StatelessWidget {
  const PanLoadingState({
    super.key,
    this.title = 'Loading',
    this.message = 'Preparing something lovely...',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Skeletonizer.zone(
          child: PanGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Bone.circle(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone.text(words: 2),
                          const SizedBox(height: 8),
                          Bone.text(width: 150),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Bone.multiText(lines: 3),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PanCachedImage extends StatelessWidget {
  const PanCachedImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.height = 220,
    this.fit = BoxFit.contain,
    this.errorLabel = 'Picture preview unavailable',
  });

  final String imageUrl;
  final String heroTag;
  final double? height;
  final BoxFit fit;
  final String errorLabel;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: double.infinity,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, url) {
          return Skeletonizer.zone(
            child: SizedBox(
              height: height ?? 240,
              child: const Center(child: Bone.circle(size: 36)),
            ),
          );
        },
        errorWidget: (context, url, error) {
          final scheme = Theme.of(context).colorScheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              height: height ?? 120,
              child: Center(
                child: Text(
                  errorLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
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
