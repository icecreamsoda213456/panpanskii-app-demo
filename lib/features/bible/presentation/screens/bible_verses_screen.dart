import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../data/daily_bible_notification_service.dart';
import '../../data/daily_bible_verse_store.dart';

class BibleVersesScreen extends StatefulWidget {
  const BibleVersesScreen({super.key});

  @override
  State<BibleVersesScreen> createState() => _BibleVersesScreenState();
}

class _BibleVersesScreenState extends State<BibleVersesScreen> {
  final _store = DailyBibleVerseStore();
  late Future<DailyBibleVerse> _verseFuture = _loadVerse();

  Future<DailyBibleVerse> _loadVerse({bool forceRefresh = false}) async {
    await DailyBibleNotificationService.initializeAndSchedule();
    return _store.loadTodayVerse(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DailyBibleVerse>(
          future: _verseFuture,
          builder: (context, snapshot) {
            final verse = snapshot.data;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _BibleHeader(),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    verse == null)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError && verse == null)
                  SliverFillRemaining(
                    child: _BibleStateMessage(onRetry: () {
                      setState(() {
                        _verseFuture = _loadVerse();
                      });
                    }),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: _VerseCard(verse: verse!)
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: .04, end: 0),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BibleHeader extends StatelessWidget {
  const _BibleHeader();

  @override
  Widget build(BuildContext context) {
    return PanFeatureHeader(
      title: 'Bible Verses',
      subtitle: 'Daily 6:00 AM reflection',
      leading: const _VerseSeal(size: 46),
      trailing: const Icon(Icons.today_rounded),
      accentColor: const Color(0xFFFFC857),
      onBack: () => context.go('/'),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});

  final DailyBibleVerse verse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: .55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _VerseSeal(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verse.reference,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        verse.translation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  verse.text,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ReflectionPanel(reflection: verse.reflection),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SoftBadge(
                  icon: Icons.notifications_active_rounded,
                  label: '6:00 AM',
                ),
                _SoftBadge(
                  icon: verse.isFromFallback
                      ? Icons.cloud_off_rounded
                      : Icons.public_rounded,
                  label:
                      verse.isFromFallback ? 'Offline backup' : 'bible-api.com',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReflectionPanel extends StatelessWidget {
  const _ReflectionPanel({required this.reflection});

  final String reflection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.secondary.withValues(alpha: .5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFC857),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reflection,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseSeal extends StatelessWidget {
  const _VerseSeal({this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD45A), Color(0xFFFF7A9A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A9A).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.menu_book_rounded,
          color: Color(0xFF27152D),
          size: 30,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD45A), size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BibleStateMessage extends StatelessWidget {
  const _BibleStateMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFFFFC857),
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              'Hindi ma-load ang verse',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
