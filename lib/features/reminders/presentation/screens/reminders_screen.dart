import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../bible/data/daily_bible_notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  DateTime _now = DateTime.now();
  Timer? _hourTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHourRefresh();
  }

  @override
  void dispose() {
    _hourTimer?.cancel();
    super.dispose();
  }

  void _scheduleHourRefresh() {
    _hourTimer?.cancel();
    final nextHour = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour + 1,
    );
    _hourTimer = Timer(nextHour.difference(DateTime.now()), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleHourRefresh();
    });
  }

  int get _visibleHour => _now.hour.clamp(6, 21).toInt();

  DailyReminder get _visibleReminder => hourlyReminders.firstWhere(
        (reminder) => reminder.hour == _visibleHour,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reminder = _visibleReminder;
    final isCurrentHour = _now.hour >= 6 && _now.hour <= 21;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverToBoxAdapter(
                child: PanFeatureHeader(
                  title: 'Daily Reminders',
                  subtitle: 'Gentle check-ins from morning to evening',
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(
                      dimension: 46,
                      child: Icon(Icons.notifications_active_rounded),
                    ),
                  ),
                  trailing: const Icon(Icons.schedule_rounded),
                  accentColor: scheme.secondary,
                  onBack: () => context.go('/'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              sliver: SliverToBoxAdapter(
                child: _ReminderSummary(reminder: reminder),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverToBoxAdapter(
                child: _ReminderTile(
                  reminder: reminder,
                  isCurrent: isCurrentHour,
                  badgeLabel:
                      isCurrentHour ? 'NOW' : (_now.hour < 6 ? 'NEXT' : 'LAST'),
                )
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideX(begin: .025, end: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({required this.reminder});

  final DailyReminder reminder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PanGlassCard(
      accentColor: const Color(0xFFFFC857),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: .2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: Color(0xFFFFA84F),
              size: 30,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current hourly reminder',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatHour(reminder.hour)}: ${reminder.title}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: scheme.secondary),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.isCurrent,
    required this.badgeLabel,
  });

  final DailyReminder reminder;
  final bool isCurrent;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isCurrent ? scheme.primary : scheme.secondary;
    return PanGlassCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      radius: 17,
      opacity: isCurrent ? .98 : .88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatHour(reminder.hour),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'DAILY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: accent.withValues(alpha: .32),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (badgeLabel.isNotEmpty)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          child: Text(
                            badgeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.notifications_none_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

String _formatHour(int hour) {
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:00 ${hour >= 12 ? 'PM' : 'AM'}';
}
