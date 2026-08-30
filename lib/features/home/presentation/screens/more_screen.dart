import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';

/// Exposes the "More" tab entries so a test can prove they never repeat a card
/// Home already shows.
@visibleForTesting
class MoreScreenTestAccess {
  const MoreScreenTestAccess._();

  /// Label to route for every tile in the "More" tab.
  static Map<String, String> get routes => {
        for (final group in _exploreGroups)
          for (final item in group.items) item.label: item.route,
      };
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverToBoxAdapter(
                child: PanFeatureHeader(
                  title: 'Explore Our Space',
                  subtitle: 'Every little corner, neatly together',
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(
                      dimension: 46,
                      child: Icon(Icons.grid_view_rounded),
                    ),
                  ),
                  trailing: const Icon(Icons.auto_awesome_rounded),
                  accentColor: scheme.tertiary,
                  onBack: () => context.go('/'),
                ),
              ),
            ),
            for (final group in _exploreGroups) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    group.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverList.separated(
                  itemCount: group.items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 62,
                    color: scheme.outlineVariant.withValues(alpha: .45),
                  ),
                  itemBuilder: (context, index) {
                    final item = group.items[index];
                    return _ExploreTile(item: item);
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.item});

  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(item.route),
        // Hidden diagnostics: long-press the Widget Note tile to open the
        // widget-note chain check (account -> RLS -> URL -> widget data).
        onLongPress: item.route == '/widget-notes'
            ? () => context.push('/widget-notes-diagnostics')
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreGroup {
  const _ExploreGroup(this.label, this.items);

  final String label;
  final List<_ExploreItem> items;
}

class _ExploreItem {
  const _ExploreItem({
    required this.label,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;
}

/// The "More" tab is the home for everything Home does *not* already show.
///
/// Home owns the daily rhythm ("Today Together" plus "Quick Actions"), so
/// Magnetic Hearts, Daily Duo, Cozy Garden, Daily Question, Mood Status,
/// Private Chat, Send Love, Photo Booth and Shared Journal deliberately do not
/// repeat here. `HomeDashboardTestAccess.homeLabels` guards that split.
const _exploreGroups = <_ExploreGroup>[
  _ExploreGroup('CONNECT', [
    _ExploreItem(
      label: 'Love Letters',
      subtitle: 'Reopen the little notes you sent each other',
      route: '/love-letters',
      icon: Icons.mark_email_read_rounded,
      color: Color(0xFFFF6F91),
    ),
    _ExploreItem(
      label: 'Widget Note',
      subtitle: 'Draw a note for their home screen',
      route: '/widget-notes',
      icon: Icons.draw_rounded,
      color: Color(0xFF43A878),
    ),
  ]),
  _ExploreGroup('MEMORIES', [
    _ExploreItem(
      label: 'Our Dates',
      subtitle: 'Shared and personal plans in one calendar',
      route: '/dates',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFFE49A35),
    ),
    _ExploreItem(
      label: 'Write Your Thoughts',
      subtitle: 'Leave something honest for your shared space',
      route: '/write-thoughts',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF8C82D4),
    ),
    _ExploreItem(
      label: 'Photo Gallery',
      subtitle: 'Every strip you have taken together',
      route: '/photobooth-gallery',
      icon: Icons.photo_library_rounded,
      color: Color(0xFFB891B8),
    ),
  ]),
  _ExploreGroup('REFLECT', [
    _ExploreItem(
      label: 'Communal Wisdom',
      subtitle: 'Keep a little encouragement close',
      route: '/wisdom',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF8C82D4),
    ),
    _ExploreItem(
      label: 'Reminders',
      subtitle: 'Gentle check-ins across the day',
      route: '/reminders',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFFF6F91),
    ),
    _ExploreItem(
      label: 'Bible Verses',
      subtitle: 'Return to today\'s verse',
      route: '/bible-verses',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF43A878),
    ),
  ]),
];
