import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../data/couple_date_notification_service.dart';
import '../../data/couple_date_store.dart';

class CoupleDatesScreen extends StatefulWidget {
  const CoupleDatesScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<CoupleDatesScreen> createState() => _CoupleDatesScreenState();
}

class _CoupleDatesScreenState extends State<CoupleDatesScreen> {
  final _store = CoupleDateStore();
  StreamSubscription<List<CoupleDatePlan>>? _plansSubscription;

  List<CoupleDatePlan> _plans = const [];
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _watchPlans();
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    super.dispose();
  }

  void _watchPlans() {
    _plansSubscription = _store.watchPlans().listen(
      (plans) {
        unawaited(CoupleDateNotificationService.syncPlans(plans));
        if (!mounted) {
          return;
        }
        setState(() {
          _plans = plans;
          _isLoading = false;
          _loadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _loadError = _friendlyError(error);
        });
      },
    );
  }

  List<CoupleDatePlan> get _selectedPlans =>
      _plans.where((plan) => _sameDay(plan.startsAt, _selectedDay)).toList();

  void _changeMonth(int offset) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    setState(() {
      _visibleMonth = next;
      _selectedDay = DateTime(next.year, next.month, 1);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      if (day.year != _visibleMonth.year || day.month != _visibleMonth.month) {
        _visibleMonth = DateTime(day.year, day.month);
      }
    });
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _openEditor({CoupleDatePlan? plan}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _DatePlanEditor(
        account: widget.account,
        store: _store,
        initialDay: plan?.startsAt ?? _selectedDay,
        plan: plan,
      ),
    );
  }

  Future<void> _setupAndTestReminders() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable prominent reminders?'),
        content: const Text(
          'Android may open Notifications, Alarms & reminders, and Full-screen notifications. These allow date alerts to arrive on time, ring, vibrate, and appear over the lock screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Continue'),
          ),
        ],
      ),
    );
    if (shouldContinue != true || !mounted) {
      return;
    }

    try {
      final access =
          await CoupleDateNotificationService.requestProminentReminderAccess();
      if (!mounted) {
        return;
      }

      if (!access.notificationsAllowed) {
        await _showReminderMessage(
          title: 'Notifications are off',
          message:
              'Allow Panpanskii notifications in Android settings, then tap the bell again.',
        );
        return;
      }

      await CoupleDateNotificationService.syncUpcomingPlans();
      if (!mounted) {
        return;
      }

      if (!access.exactTimingAllowed) {
        final runBasicTest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exact alarm access is off'),
            content: const Text(
              'Enable Alarms & reminders for an on-time alarm. You can still run a basic sound and vibration test now.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text('Basic test'),
              ),
            ],
          ),
        );
        if (runBasicTest == true) {
          await CoupleDateNotificationService.showTestReminder();
        }
        return;
      }

      final startTest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Ready to test the alarm?'),
          content: Text(
            access.fullScreenAllowed
                ? 'Tap Start test, then immediately lock the phone or put the app in the background. The alarm should ring, vibrate, and open as a full-screen alert after 8 seconds.'
                : 'Tap Start test, then immediately put the app in the background. The alarm should ring and vibrate as a large heads-up alert after 8 seconds. Full-screen access is currently off.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.alarm_rounded),
              label: const Text('Start test'),
            ),
          ],
        ),
      );
      if (startTest != true || !mounted) {
        return;
      }

      await CoupleDateNotificationService.scheduleTestReminder();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alarm scheduled. Lock the phone or leave the app now.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      await _showReminderMessage(
        title: 'Reminder setup failed',
        message: _friendlyError(error),
      );
    }
  }

  Future<void> _showReminderMessage({
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(CoupleDatePlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: Text('"${plan.title}" will be removed from the calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _store.deletePlan(plan);
      await CoupleDateNotificationService.cancelPlan(plan.id);
      await CoupleDateNotificationService.syncUpcomingPlans();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan a date'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverToBoxAdapter(
                child: PanFeatureHeader(
                  title: 'Our Dates',
                  subtitle: 'Shared moments and personal plans',
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(
                      dimension: 46,
                      child: Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                  trailing: IconButton.filledTonal(
                    tooltip: 'Set up and test reminders',
                    onPressed: _setupAndTestReminders,
                    icon: const Icon(Icons.notification_important_rounded),
                  ),
                  accentColor: const Color(0xFFFF7888),
                  onBack: () => context.go('/'),
                ),
              ),
            ),
            if (_isLoading)
              const PanLoadingSliver(
                title: 'Opening your calendar',
                message: 'Gathering your plans...',
              )
            else if (_loadError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CalendarError(
                  message: _loadError!,
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _plansSubscription?.cancel();
                    _watchPlans();
                  },
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                sliver: SliverToBoxAdapter(
                  child: _MonthCalendar(
                    visibleMonth: _visibleMonth,
                    selectedDay: _selectedDay,
                    plans: _plans,
                    onPreviousMonth: () => _changeMonth(-1),
                    onNextMonth: () => _changeMonth(1),
                    onToday: _selectToday,
                    onSelectDay: _selectDay,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayHeading(_selectedDay),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${_selectedPlans.length} ${_selectedPlans.length == 1 ? 'plan' : 'plans'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Add plan on this day',
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedPlans.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
                  sliver: SliverToBoxAdapter(
                    child: _EmptyDate(
                      onAdd: () => _openEditor(),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
                  sliver: SliverList.separated(
                    itemCount: _selectedPlans.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final plan = _selectedPlans[index];
                      return _DatePlanCard(
                        plan: plan,
                        onEdit:
                            plan.isMine ? () => _openEditor(plan: plan) : null,
                        onDelete: plan.isMine ? () => _deletePlan(plan) : null,
                      )
                          .animate(delay: (45 * index).ms)
                          .fadeIn(duration: 220.ms)
                          .slideY(begin: .025, end: 0);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.selectedDay,
    required this.plans,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onSelectDay,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<CoupleDatePlan> plans;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday % 7));
    const weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return PanGlassCard(
      accentColor: const Color(0xFFFF7888),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthYear(visibleMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Today',
                onPressed: onToday,
                icon: const Icon(Icons.today_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: .92,
            ),
            itemBuilder: (context, index) {
              final day = gridStart.add(Duration(days: index));
              final dayPlans =
                  plans.where((plan) => _sameDay(plan.startsAt, day)).toList();
              return _CalendarDay(
                day: day,
                isInMonth: day.month == visibleMonth.month,
                isSelected: _sameDay(day, selectedDay),
                isToday: _sameDay(day, DateTime.now()),
                plans: dayPlans,
                onTap: () => onSelectDay(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.isInMonth,
    required this.isSelected,
    required this.isToday,
    required this.plans,
    required this.onTap,
  });

  final DateTime day;
  final bool isInMonth;
  final bool isSelected;
  final bool isToday;
  final List<CoupleDatePlan> plans;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isSelected
        ? scheme.onPrimary
        : isInMonth
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: .48);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${_monthNames[day.month - 1]} ${day.day}',
      child: Material(
        color: isSelected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              child: Column(
                children: [
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final plan in plans.take(3)) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.onPrimary
                                  : _categoryColor(plan.category),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 5),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ],
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

class _DatePlanCard extends StatelessWidget {
  const _DatePlanCard({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  final CoupleDatePlan plan;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _categoryColor(plan.category);
    final isPast = plan.startsAt.isBefore(DateTime.now());
    return Opacity(
      opacity: isPast ? .72 : 1,
      child: PanGlassCard(
        accentColor: accent,
        radius: 17,
        padding: const EdgeInsets.fromLTRB(13, 13, 9, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(plan.category), color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatTime(plan.startsAt)}  |  ${plan.category.label}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (plan.notes.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      plan.notes,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _PlanBadge(
                        icon: plan.isShared
                            ? Icons.people_alt_rounded
                            : Icons.person_rounded,
                        label: plan.visibility.label,
                        color: plan.isShared ? scheme.primary : scheme.tertiary,
                      ),
                      _PlanBadge(
                        icon: plan.mascot == AccountMascot.panda
                            ? Icons.circle_rounded
                            : Icons.circle_outlined,
                        label: plan.isMine ? 'You' : plan.mascot.label,
                        color: scheme.secondary,
                      ),
                      if (plan.reminderMinutes != null)
                        _PlanBadge(
                          icon: Icons.notifications_active_rounded,
                          label: CoupleDateReminder.fromMinutes(
                            plan.reminderMinutes,
                          ).label,
                          color: accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<_PlanAction>(
                tooltip: 'Plan actions',
                onSelected: (action) {
                  switch (action) {
                    case _PlanAction.edit:
                      onEdit?.call();
                      break;
                    case _PlanAction.delete:
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: _PlanAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_rounded),
                        title: Text('Edit'),
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: _PlanAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _PlanAction { edit, delete }

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDate extends StatelessWidget {
  const _EmptyDate({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 48,
            color: scheme.primary.withValues(alpha: .72),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing planned yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a plan'),
          ),
        ],
      ),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 12),
            Text(
              'Calendar unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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

class _DatePlanEditor extends StatefulWidget {
  const _DatePlanEditor({
    required this.account,
    required this.store,
    required this.initialDay,
    required this.plan,
  });

  final LocalAccount account;
  final CoupleDateStore store;
  final DateTime initialDay;
  final CoupleDatePlan? plan;

  @override
  State<_DatePlanEditor> createState() => _DatePlanEditorState();
}

class _DatePlanEditorState extends State<_DatePlanEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late TimeOfDay _time;
  late CoupleDateCategory _category;
  late CoupleDateVisibility _visibility;
  late CoupleDateReminder _reminder;
  String? _savedPlanId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    final suggested = plan?.startsAt ?? _suggestedStart(widget.initialDay);
    _titleController = TextEditingController(text: plan?.title ?? '');
    _notesController = TextEditingController(text: plan?.notes ?? '');
    _date = DateTime(suggested.year, suggested.month, suggested.day);
    _time = TimeOfDay.fromDateTime(suggested);
    _category = plan?.category ?? CoupleDateCategory.date;
    _visibility = plan?.visibility ?? CoupleDateVisibility.shared;
    _savedPlanId = plan?.id;
    _reminder = plan == null
        ? CoupleDateReminder.oneHour
        : CoupleDateReminder.fromMinutes(plan.reminderMinutes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _startsAt => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'Choose a time',
      cancelText: 'Cancel',
      confirmText: 'Set time',
      switchToInputEntryModeIcon: const Icon(Icons.keyboard_rounded),
      switchToTimerEntryModeIcon: const Icon(Icons.schedule_rounded),
      builder: _buildTimePicker,
    );
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Widget _buildTimePicker(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hourMinuteStyle =
        (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w900,
      color: colors.onSurface,
      letterSpacing: 0,
    );
    final pickerTextTheme = theme.textTheme.copyWith(
      displayLarge: hourMinuteStyle,
      displayMedium: hourMinuteStyle,
      headlineSmall: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
    final selectorColor = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
    );
    final selectorTextColor = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colors.onPrimaryContainer
          : colors.onSurfaceVariant,
    );
    final dialTextColor = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colors.onPrimary
          : colors.onSurface,
    );

    return Theme(
      data: theme.copyWith(
        textTheme: pickerTextTheme,
        timePickerTheme: TimePickerThemeData(
          backgroundColor: colors.surfaceContainerHigh,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          helpTextStyle: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          hourMinuteColor: selectorColor,
          hourMinuteTextColor: selectorTextColor,
          hourMinuteTextStyle: hourMinuteStyle,
          hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          timeSelectorSeparatorColor: WidgetStatePropertyAll(
            colors.onSurfaceVariant,
          ),
          timeSelectorSeparatorTextStyle: WidgetStatePropertyAll(
            hourMinuteStyle,
          ),
          dayPeriodColor: selectorColor,
          dayPeriodTextColor: selectorTextColor,
          dayPeriodTextStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          dayPeriodShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          dayPeriodBorderSide: BorderSide(color: colors.outlineVariant),
          dialBackgroundColor: colors.surfaceContainerHighest.withValues(
            alpha: 0.85,
          ),
          dialHandColor: colors.primary,
          dialTextColor: dialTextColor,
          dialTextStyle: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          entryModeIconColor: colors.primary,
          cancelButtonStyle: TextButton.styleFrom(
            foregroundColor: colors.onSurfaceVariant,
            minimumSize: const Size(76, 44),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          confirmButtonStyle: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            minimumSize: const Size(92, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Give this plan a name first.');
      return;
    }
    if (widget.plan == null &&
        _startsAt
            .isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      setState(() => _error = 'Choose a time that has not passed yet.');
      return;
    }
    final reminderMinutes = _reminder.minutes;
    if (reminderMinutes != null) {
      final reminderAt = _startsAt.subtract(Duration(minutes: reminderMinutes));
      if (!reminderAt.isAfter(DateTime.now())) {
        setState(() {
          _error =
              'That reminder time has already passed. Choose At start time, a shorter reminder, or a later plan.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (_reminder != CoupleDateReminder.none) {
        final access = await CoupleDateNotificationService
            .requestProminentReminderAccess();
        if (!mounted) {
          return;
        }
        if (!access.notificationsAllowed) {
          setState(() {
            _isSaving = false;
            _error =
                'Notifications are off. Allow them on this phone, or choose No reminder.';
          });
          return;
        }
        if (!access.exactTimingAllowed) {
          setState(() {
            _isSaving = false;
            _error =
                'Alarms & reminders access is off. Enable it for an on-time alarm, or choose No reminder.';
          });
          return;
        }
      }

      final savedPlan = await widget.store.savePlan(
        id: _savedPlanId,
        account: widget.account,
        title: _titleController.text,
        notes: _notesController.text,
        category: _category,
        visibility: _visibility,
        previousVisibility: widget.plan?.visibility,
        startsAt: _startsAt,
        reminderMinutes: _reminder.minutes,
      );
      _savedPlanId = savedPlan.id;
      if (savedPlan.reminderAt == null) {
        await CoupleDateNotificationService.cancelPlan(savedPlan.id);
      } else {
        await CoupleDateNotificationService.schedulePlan(savedPlan);
      }
      await CoupleDateNotificationService.syncUpcomingPlans();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.plan == null ? 'Plan something' : 'Edit plan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            autofocus: widget.plan == null,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Plan name',
              hintText: 'Movie night, game time, dinner...',
              prefixIcon: Icon(Icons.edit_calendar_rounded),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CoupleDateCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Activity',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: [
              for (final category in CoupleDateCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(_categoryIcon(category), size: 20),
                      const SizedBox(width: 9),
                      Text(category.label),
                    ],
                  ),
                ),
            ],
            onChanged: _isSaving
                ? null
                : (category) {
                    if (category != null) {
                      setState(() => _category = category);
                    }
                  },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(_shortDate(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<CoupleDateVisibility>(
            segments: const [
              ButtonSegment(
                value: CoupleDateVisibility.shared,
                icon: Icon(Icons.people_alt_rounded),
                label: Text('Shared'),
              ),
              ButtonSegment(
                value: CoupleDateVisibility.personal,
                icon: Icon(Icons.person_rounded),
                label: Text('Personal'),
              ),
            ],
            selected: {_visibility},
            showSelectedIcon: false,
            onSelectionChanged: _isSaving
                ? null
                : (selection) {
                    setState(() => _visibility = selection.first);
                  },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<CoupleDateReminder>(
            initialValue: _reminder,
            decoration: const InputDecoration(
              labelText: 'Notification',
              prefixIcon: Icon(Icons.notifications_active_rounded),
            ),
            items: [
              for (final reminder in CoupleDateReminder.values)
                DropdownMenuItem(
                  value: reminder,
                  child: Text(reminder.label),
                ),
            ],
            onChanged: _isSaving
                ? null
                : (reminder) {
                    if (reminder != null) {
                      setState(() => _reminder = reminder);
                    }
                  },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            enabled: !_isSaving,
            maxLength: 1000,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 2),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save plan'),
          ),
        ],
      ),
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _monthYear(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.year}';
}

String _dayHeading(DateTime date) {
  final now = DateTime.now();
  if (_sameDay(date, now)) {
    return 'Today';
  }
  if (_sameDay(date, now.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  return '${_weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
}

String _shortDate(DateTime date) {
  return '${_monthNames[date.month - 1].substring(0, 3)} ${date.day}, ${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

DateTime _suggestedStart(DateTime initialDay) {
  final now = DateTime.now();
  if (!_sameDay(initialDay, now)) {
    return DateTime(initialDay.year, initialDay.month, initialDay.day, 19);
  }

  final next = now.add(const Duration(hours: 1));
  final roundedMinute = ((next.minute + 4) ~/ 5) * 5;
  return DateTime(
    next.year,
    next.month,
    next.day,
    next.hour + (roundedMinute ~/ 60),
    roundedMinute % 60,
  );
}

IconData _categoryIcon(CoupleDateCategory category) {
  return switch (category) {
    CoupleDateCategory.date => Icons.favorite_rounded,
    CoupleDateCategory.movie => Icons.movie_rounded,
    CoupleDateCategory.game => Icons.sports_esports_rounded,
    CoupleDateCategory.food => Icons.restaurant_rounded,
    CoupleDateCategory.other => Icons.event_note_rounded,
  };
}

Color _categoryColor(CoupleDateCategory category) {
  return switch (category) {
    CoupleDateCategory.date => const Color(0xFFFF6F91),
    CoupleDateCategory.movie => const Color(0xFF8C82D4),
    CoupleDateCategory.game => const Color(0xFF43A878),
    CoupleDateCategory.food => const Color(0xFFE49A35),
    CoupleDateCategory.other => const Color(0xFF4F8CC9),
  };
}

String _friendlyError(Object error) {
  final message = error.toString().trim();
  return message
      .replaceFirst('PostgrestException(message: ', '')
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Bad state: ', '');
}
