import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../data/daily_wisdom_store.dart';

class CommunalWisdomScreen extends StatelessWidget {
  const CommunalWisdomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wisdom = DailyWisdomStore().quoteForDate(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverToBoxAdapter(
                child: PanFeatureHeader(
                  title: 'Communal Wisdom',
                  subtitle: 'A little encouragement for today',
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(
                      dimension: 46,
                      child: Icon(Icons.lightbulb_rounded),
                    ),
                  ),
                  trailing: const Icon(Icons.wb_sunny_rounded),
                  accentColor: const Color(0xFFFFC857),
                  onBack: () => context.go('/'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _WisdomCard(wisdom: wisdom),
                    const SizedBox(height: 12),
                    PanGlassCard(
                      accentColor: scheme.secondary,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: scheme.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A new wisdom reminder arrives daily at 6:05 AM.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WisdomCard extends StatelessWidget {
  const _WisdomCard({required this.wisdom});

  final DailyWisdomQuote wisdom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: .55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .1),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFC857),
                ),
                const SizedBox(width: 8),
                Text(
                  'TODAY\'S WISDOM',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '"${wisdom.quote}"',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              wisdom.author,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note_rounded, color: scheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Short reflection',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            wisdom.reflection,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: .04, end: 0);
  }
}
