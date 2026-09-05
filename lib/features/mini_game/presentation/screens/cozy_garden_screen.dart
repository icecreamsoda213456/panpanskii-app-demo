import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../../core/supabase/supabase.dart';
import '../../../auth/data/local_account_store.dart';
import '../../data/cozy_garden_store.dart';
import '../../data/garden_progression.dart';
import '../garden_game/cozy_garden_game.dart';
import '../garden_game/cozy_garden_game_view.dart';
import '../garden_game/garden_scene_state.dart';

class CozyGardenScreen extends StatefulWidget {
  const CozyGardenScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<CozyGardenScreen> createState() => _CozyGardenScreenState();
}

class _CozyGardenScreenState extends State<CozyGardenScreen>
    with WidgetsBindingObserver {
  final _store = CozyGardenStore();
  late final CozyGardenGame _gardenGame;
  late String _dayKey;
  late final Stream<CozyGardenState> _gardenStream = _store.watchGarden();
  late Stream<List<CozyGardenAction>> _actionsStream;
  late final Stream<List<CozyGardenUnlock>> _unlocksStream =
      _store.watchUnlocks();
  late Stream<List<CozyGardenBonusEvent>> _bonusEventsStream;
  Timer? _dayRolloverTimer;
  bool _isWatering = false;
  bool _awaitingWaterConfirmation = false;
  bool _confirmationClearQueued = false;
  bool _isHarvesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gardenGame = CozyGardenGame();
    _dayKey = _store.todayKey();
    _actionsStream = _store.watchActions(_dayKey);
    _bonusEventsStream = _store.watchBonusEvents(_dayKey);
    _dayRolloverTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshGardenDayIfNeeded(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _refreshGardenDayIfNeeded();
        _gardenGame.refreshTimeOfDay();
        _gardenGame.resumeEngine();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _gardenGame.pauseEngine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRolloverTimer?.cancel();
    _gardenGame.pauseEngine();
    _gardenGame.cancelWatering();
    super.dispose();
  }

  Future<void> _waterGarden() async {
    if (_isWatering || _awaitingWaterConfirmation) return;
    _refreshGardenDayIfNeeded();
    final requestDayKey = _dayKey;
    setState(() => _isWatering = true);
    _gardenGame.playWatering(widget.account.mascot);
    try {
      await _store.waterGarden(
        account: widget.account,
        dayKey: requestDayKey,
      );
      if (!mounted || requestDayKey != _dayKey) return;
      setState(() {
        _isWatering = false;
        _awaitingWaterConfirmation = true;
      });
    } catch (error) {
      if (!mounted || requestDayKey != _dayKey) return;
      _gardenGame.cancelWatering();
      setState(() {
        _isWatering = false;
        _awaitingWaterConfirmation = false;
      });
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _refreshGardenDayIfNeeded() {
    if (!mounted) return;
    final nextDayKey = _store.todayKey();
    if (nextDayKey == _dayKey) return;

    _gardenGame.cancelWatering();
    setState(() {
      _dayKey = nextDayKey;
      _actionsStream = _store.watchActions(nextDayKey);
      _bonusEventsStream = _store.watchBonusEvents(nextDayKey);
      _isWatering = false;
      _awaitingWaterConfirmation = false;
      _confirmationClearQueued = false;
    });
  }

  Future<void> _openHarvestSeedPicker(
    CozyGardenState garden,
    Set<String> unlockedKeys,
  ) async {
    final selectedPlant = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SeedPickerSheet(
        unlockedKeys: unlockedKeys,
        completedHarvests: garden.totalHarvests,
        longestStreak: garden.longestStreak,
      ),
    );
    if (!mounted || selectedPlant == null) return;
    await _harvestGarden(selectedPlant);
  }

  Future<void> _harvestGarden(String nextPlant) async {
    if (_isHarvesting) return;
    setState(() => _isHarvesting = true);
    try {
      final result = await _store.harvestGarden(nextPlant: nextPlant);
      if (!mounted) return;
      _gardenGame.playHarvestCelebration();
      final plant = GardenPlantDefinition.forId(result.garden.plantType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plant.displayName} is planted. New cycle!')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isHarvesting = false);
    }
  }

  void _openGardenBook(Set<String> unlockedKeys) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GardenBookSheet(
        store: _store,
        unlockedKeys: unlockedKeys,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<CozyGardenState>(
          stream: _gardenStream,
          builder: (context, gardenSnapshot) {
            if (gardenSnapshot.connectionState == ConnectionState.waiting &&
                !gardenSnapshot.hasData) {
              return const PanLoadingState(
                title: 'Growing your garden',
                message: 'Preparing a little shared space for both of you.',
              );
            }
            return StreamBuilder<List<CozyGardenAction>>(
              key: ValueKey('cozy-garden-actions-$_dayKey'),
              stream: _actionsStream,
              builder: (context, actionSnapshot) {
                return StreamBuilder<List<CozyGardenUnlock>>(
                  stream: _unlocksStream,
                  builder: (context, unlockSnapshot) {
                    return StreamBuilder<List<CozyGardenBonusEvent>>(
                      key: ValueKey('cozy-garden-bonuses-$_dayKey'),
                      stream: _bonusEventsStream,
                      builder: (context, bonusSnapshot) {
                        final garden =
                            gardenSnapshot.data ?? CozyGardenState.initial;
                        final actions =
                            actionSnapshot.data ?? const <CozyGardenAction>[];
                        final unlocks =
                            unlockSnapshot.data ?? const <CozyGardenUnlock>[];
                        final bonusEvents = bonusSnapshot.data ??
                            const <CozyGardenBonusEvent>[];
                        final currentUserId = supabase.auth.currentUser?.id;
                        final hasWatered = currentUserId != null &&
                            actions.any(
                              (action) => action.userId == currentUserId,
                            );
                        final partnerWatered = currentUserId != null &&
                            actions.any(
                              (action) => action.userId != currentUserId,
                            );
                        _confirmPendingWatering(hasWatered);
                        final partnerMascot = _partnerMascotFromActions(
                          actions: actions,
                          currentUserId: currentUserId,
                          currentMascot: widget.account.mascot,
                        );
                        return _buildContent(
                          context,
                          garden: garden,
                          hasWatered: hasWatered,
                          partnerWatered: partnerWatered,
                          partnerMascot: partnerMascot,
                          unlocks: unlocks,
                          bonusEvents: bonusEvents,
                          hasError: gardenSnapshot.hasError ||
                              actionSnapshot.hasError ||
                              unlockSnapshot.hasError ||
                              bonusSnapshot.hasError,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required CozyGardenState garden,
    required bool hasWatered,
    required bool partnerWatered,
    required AccountMascot partnerMascot,
    required List<CozyGardenUnlock> unlocks,
    required List<CozyGardenBonusEvent> bonusEvents,
    required bool hasError,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final growth = garden.growth.clamp(0, 100).toInt();
    final stage = GardenGrowthStage.fromGrowth(growth);
    final currentMascot = widget.account.mascot;
    final unlockedKeys = unlocks.map((unlock) => unlock.unlockKey).toSet();
    final unlockedDecorations = unlocks
        .where((unlock) => unlock.unlockType == 'decoration')
        .map((unlock) => unlock.unlockKey.replaceFirst('decoration:', ''))
        .toSet();
    final togetherBonus = _bonusFor(bonusEvents, 'both_watered');
    final nextMilestone = _nextMilestone(
      garden: garden,
      unlockedKeys: unlockedKeys,
    );
    final isReadyToHarvest = growth >= 100;
    final waterButtonLocked =
        hasWatered || _isWatering || _awaitingWaterConfirmation;

    _gardenGame.updateGardenState(
      growth: garden.growth,
      plantType: garden.plantType,
      currentMascot: currentMascot,
      partnerMascot: partnerMascot,
      hasWatered: hasWatered,
      partnerWatered: partnerWatered,
      unlockedDecorations: unlockedDecorations,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          sliver: SliverToBoxAdapter(
            child: PanFeatureHeader(
              title: 'Cozy Garden',
              subtitle: 'Grow something together every day',
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 46,
                  child: Icon(Icons.local_florist_rounded),
                ),
              ),
              trailing: IconButton.filledTonal(
                tooltip: 'Open garden book',
                onPressed: () => _openGardenBook(unlockedKeys),
                icon: const Icon(Icons.menu_book_rounded),
              ),
              accentColor: scheme.secondary,
              onBack: () => context.go('/panpans-home'),
            ),
          ),
        ),
        if (hasError)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
            sliver: SliverToBoxAdapter(child: _GardenErrorBanner()),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: CozyGardenGameView(game: _gardenGame),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GardenSectionHeading(
                  icon: Icons.park_rounded,
                  label: 'Garden progress',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isReadyToHarvest
                            ? 'FULLY BLOOMED'
                            : stage.label.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    Text(
                      '$growth / 100',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isReadyToHarvest
                      ? 'Your garden is ready for a new seed.'
                      : 'A little shared care goes a long way.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: growth / 100,
                    minHeight: 12,
                    color: scheme.secondary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 18),
                _StreakSummary(
                  currentStreak: _displayCurrentStreak(garden),
                  longestStreak: garden.longestStreak,
                ),
                if (togetherBonus != null) ...[
                  const SizedBox(height: 10),
                  _TogetherBonusRow(bonus: togetherBonus),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1),
                ),
                _GardenSectionHeading(
                  icon: Icons.water_drop_outlined,
                  label: 'Today\'s care',
                ),
                const SizedBox(height: 13),
                _CareStatusRow(
                  mascot: currentMascot,
                  role: 'YOU',
                  watered: hasWatered,
                ),
                const SizedBox(height: 12),
                _CareStatusRow(
                  mascot: partnerMascot,
                  role: 'YOUR PERSON',
                  watered: partnerWatered,
                ),
                const SizedBox(height: 22),
                if (isReadyToHarvest) ...[
                  Text(
                    'You grew this together. Pick the next seed when you are ready.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isHarvesting
                          ? null
                          : () => _openHarvestSeedPicker(garden, unlockedKeys),
                      icon: _isHarvesting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isHarvesting ? 'Harvesting...' : 'Harvest Garden',
                      ),
                    ),
                  ),
                ] else
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: waterButtonLocked ? null : _waterGarden,
                      icon: Icon(
                        hasWatered
                            ? Icons.check_circle_rounded
                            : Icons.water_drop_rounded,
                      ),
                      label: Text(
                        _isWatering
                            ? 'Watering...'
                            : _awaitingWaterConfirmation && !hasWatered
                                ? 'Syncing watering...'
                                : hasWatered
                                    ? 'Watered for Today'
                                    : 'Water the Garden',
                      ),
                    ),
                  ),
                if (nextMilestone != null) ...[
                  const SizedBox(height: 14),
                  _NextMilestoneFooter(milestone: nextMilestone),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGardenBook(unlockedKeys),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('View Garden Book'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(color: scheme.surface),
        ),
      ],
    );
  }

  CozyGardenBonusEvent? _bonusFor(
    List<CozyGardenBonusEvent> events,
    String eventType,
  ) {
    for (final event in events) {
      if (event.eventType == eventType) return event;
    }
    return null;
  }

  _GardenMilestone? _nextMilestone({
    required CozyGardenState garden,
    required Set<String> unlockedKeys,
  }) {
    final milestones = <_GardenMilestone>[];
    final harvests = garden.totalHarvests;
    final longestStreak = garden.longestStreak;

    void addHarvestMilestone({
      required String unlockKey,
      required IconData icon,
      required String title,
      required String detail,
      required int target,
      required int priority,
    }) {
      if (unlockedKeys.contains(unlockKey)) return;
      milestones.add(
        _GardenMilestone(
          icon: icon,
          title: title,
          detail: detail,
          current: harvests > target ? target : harvests,
          target: target,
          priority: priority,
        ),
      );
    }

    void addStreakMilestone({
      required String unlockKey,
      required IconData icon,
      required String title,
      required String detail,
      required int target,
      required int priority,
    }) {
      if (unlockedKeys.contains(unlockKey)) return;
      milestones.add(
        _GardenMilestone(
          icon: icon,
          title: title,
          detail: detail,
          current: longestStreak > target ? target : longestStreak,
          target: target,
          priority: priority,
        ),
      );
    }

    addHarvestMilestone(
      unlockKey: plantUnlockKey(GardenPlantDefinition.sakura.id),
      icon: GardenPlantDefinition.sakura.icon,
      title: 'Next plant: Sakura',
      detail: GardenPlantDefinition.sakura.unlockHint,
      target: 1,
      priority: 0,
    );
    addHarvestMilestone(
      unlockKey: decorationUnlockKey(GardenDecorationDefinition.woodenSign.id),
      icon: GardenDecorationDefinition.woodenSign.icon,
      title: 'Next reward: Wooden Garden Sign',
      detail: GardenDecorationDefinition.woodenSign.unlockHint,
      target: 1,
      priority: 1,
    );
    addHarvestMilestone(
      unlockKey: plantUnlockKey(GardenPlantDefinition.rose.id),
      icon: GardenPlantDefinition.rose.icon,
      title: 'Next plant: Rose',
      detail: GardenPlantDefinition.rose.unlockHint,
      target: 3,
      priority: 2,
    );
    addHarvestMilestone(
      unlockKey: decorationUnlockKey(GardenDecorationDefinition.coupleBench.id),
      icon: GardenDecorationDefinition.coupleBench.icon,
      title: 'Next reward: Couple Bench',
      detail: GardenDecorationDefinition.coupleBench.unlockHint,
      target: 3,
      priority: 3,
    );
    addStreakMilestone(
      unlockKey: plantUnlockKey(GardenPlantDefinition.tulip.id),
      icon: GardenPlantDefinition.tulip.icon,
      title: 'Next plant: Tulip',
      detail: GardenPlantDefinition.tulip.unlockHint,
      target: 7,
      priority: 4,
    );
    addStreakMilestone(
      unlockKey: decorationUnlockKey(GardenDecorationDefinition.mushroom.id),
      icon: GardenDecorationDefinition.mushroom.icon,
      title: 'Next reward: Mushroom',
      detail: GardenDecorationDefinition.mushroom.unlockHint,
      target: 3,
      priority: 5,
    );
    addStreakMilestone(
      unlockKey: decorationUnlockKey(GardenDecorationDefinition.lantern.id),
      icon: GardenDecorationDefinition.lantern.icon,
      title: 'Next reward: Garden Lantern',
      detail: GardenDecorationDefinition.lantern.unlockHint,
      target: 7,
      priority: 6,
    );

    if (milestones.isEmpty) return null;
    milestones.sort((first, second) {
      final progress = second.progress.compareTo(first.progress);
      return progress != 0
          ? progress
          : first.priority.compareTo(second.priority);
    });
    return milestones.first;
  }

  int _displayCurrentStreak(CozyGardenState garden) {
    final lastCompletedDay = garden.lastCompletedDay;
    if (lastCompletedDay == null) return 0;

    // The backend uses the same Asia/Manila 6:00 AM garden-day boundary.
    final nowInManila = DateTime.now().toUtc().add(const Duration(hours: 8));
    final shifted = nowInManila.subtract(const Duration(hours: 6));
    final effectiveDay = DateTime.utc(shifted.year, shifted.month, shifted.day);
    final completedDay = DateTime.utc(
      lastCompletedDay.year,
      lastCompletedDay.month,
      lastCompletedDay.day,
    );
    final oldestActiveDay = effectiveDay.subtract(const Duration(days: 1));
    if (completedDay.isBefore(oldestActiveDay) ||
        completedDay.isAfter(effectiveDay)) {
      return 0;
    }
    return garden.currentStreak;
  }

  void _confirmPendingWatering(bool actionConfirmed) {
    if (!actionConfirmed ||
        !_awaitingWaterConfirmation ||
        _confirmationClearQueued) {
      return;
    }
    _confirmationClearQueued = true;
    final confirmationDayKey = _dayKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || confirmationDayKey != _dayKey) return;
      _confirmationClearQueued = false;
      if (!_awaitingWaterConfirmation) return;
      setState(() => _awaitingWaterConfirmation = false);
    });
  }

  AccountMascot _partnerMascotFromActions({
    required List<CozyGardenAction> actions,
    required String? currentUserId,
    required AccountMascot currentMascot,
  }) {
    if (currentUserId != null) {
      for (final action in actions) {
        if (action.userId != currentUserId) return action.mascot;
      }
    }
    return currentMascot == AccountMascot.panda
        ? AccountMascot.koala
        : AccountMascot.panda;
  }
}

class _StreakSummary extends StatelessWidget {
  const _StreakSummary({
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentLabel = currentStreak == 1 ? 'day' : 'days';
    final bestLabel = longestStreak == 1 ? 'day' : 'days';
    return Row(
      children: [
        Icon(Icons.local_fire_department_rounded, color: scheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$currentStreak $currentLabel shared streak',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Text(
          'Best: $longestStreak $bestLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _GardenSectionHeading extends StatelessWidget {
  const _GardenSectionHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.secondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _GardenMilestone {
  const _GardenMilestone({
    required this.icon,
    required this.title,
    required this.detail,
    required this.current,
    required this.target,
    required this.priority,
  });

  final IconData icon;
  final String title;
  final String detail;
  final int current;
  final int target;
  final int priority;

  double get progress => (current / target).clamp(0.0, 1.0).toDouble();
}

class _NextMilestoneFooter extends StatelessWidget {
  const _NextMilestoneFooter({required this.milestone});

  final _GardenMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.symmetric(
          horizontal: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Row(
          children: [
            Icon(milestone.icon, color: scheme.secondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT MILESTONE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    milestone.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    milestone.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: milestone.progress,
                      minHeight: 5,
                      color: scheme.secondary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${milestone.current}/${milestone.target}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogetherBonusRow extends StatelessWidget {
  const _TogetherBonusRow({required this.bonus});

  final CozyGardenBonusEvent bonus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.favorite_rounded, color: scheme.primary, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Together bonus +${bonus.growthBonus} growth',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _CareStatusRow extends StatelessWidget {
  const _CareStatusRow({
    required this.mascot,
    required this.role,
    required this.watered,
  });

  final AccountMascot mascot;
  final String role;
  final bool watered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPanda = mascot == AccountMascot.panda;
    final accent = isPanda ? const Color(0xFFFFC857) : const Color(0xFF72D6A0);
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: accent.withValues(alpha: .34)),
          ),
          child: SizedBox.square(
            dimension: 34,
            child: Icon(Icons.pets_rounded, color: accent, size: 19),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$role - ${mascot.label.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                watered ? 'Watered today' : 'Waiting for today',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        Icon(
          watered
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: watered ? scheme.secondary : scheme.outline,
        ),
      ],
    );
  }
}

class _SeedPickerSheet extends StatefulWidget {
  const _SeedPickerSheet({
    required this.unlockedKeys,
    required this.completedHarvests,
    required this.longestStreak,
  });

  final Set<String> unlockedKeys;
  final int completedHarvests;
  final int longestStreak;

  @override
  State<_SeedPickerSheet> createState() => _SeedPickerSheetState();
}

class _SeedPickerSheetState extends State<_SeedPickerSheet> {
  String _selectedPlant = GardenPlantDefinition.sunflower.id;

  bool _isUnlocked(GardenPlantDefinition plant) {
    if (plant.id == GardenPlantDefinition.sunflower.id ||
        widget.unlockedKeys.contains(plantUnlockKey(plant.id))) {
      return true;
    }
    if (plant.id == GardenPlantDefinition.sakura.id) {
      return widget.completedHarvests + 1 >= 1;
    }
    if (plant.id == GardenPlantDefinition.rose.id) {
      return widget.completedHarvests + 1 >= 3;
    }
    return plant.id == GardenPlantDefinition.tulip.id &&
        widget.longestStreak >= 7;
  }

  bool _unlocksWithThisHarvest(GardenPlantDefinition plant) {
    return (plant.id == GardenPlantDefinition.sakura.id &&
            widget.completedHarvests + 1 >= 1) ||
        (plant.id == GardenPlantDefinition.rose.id &&
            widget.completedHarvests + 1 >= 3);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plants = GardenPlantDefinition.all
        .where((plant) => plant.id != GardenPlantDefinition.legacyTree.id)
        .toList();
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Choose your next seed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your bloom is safe until the server confirms this harvest.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: plants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    final unlocked = _isUnlocked(plant);
                    final selected = plant.id == _selectedPlant;
                    final unlocksWithThisHarvest =
                        _unlocksWithThisHarvest(plant) &&
                            !widget.unlockedKeys.contains(
                              plantUnlockKey(plant.id),
                            );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      enabled: unlocked,
                      onTap: unlocked
                          ? () => setState(() => _selectedPlant = plant.id)
                          : null,
                      leading: Icon(
                        plant.icon,
                        color: unlocked ? scheme.secondary : scheme.outline,
                      ),
                      title: Text(
                        plant.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: unlocked ? scheme.onSurface : scheme.outline,
                        ),
                      ),
                      subtitle: Text(
                        unlocked
                            ? unlocksWithThisHarvest
                                ? 'Unlocks with this harvest'
                                : 'Unlocked'
                            : plant.unlockHint,
                      ),
                      trailing: unlocked
                          ? Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color:
                                  selected ? scheme.secondary : scheme.outline,
                            )
                          : const Icon(Icons.lock_outline_rounded),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selectedPlant),
                  icon: const Icon(Icons.local_florist_rounded),
                  label: const Text('Plant This Seed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GardenBookSheet extends StatefulWidget {
  const _GardenBookSheet({
    required this.store,
    required this.unlockedKeys,
  });

  final CozyGardenStore store;
  final Set<String> unlockedKeys;

  @override
  State<_GardenBookSheet> createState() => _GardenBookSheetState();
}

class _GardenBookSheetState extends State<_GardenBookSheet> {
  late final Future<List<CozyGardenHarvest>> _harvestFuture;

  @override
  void initState() {
    super.initState();
    _harvestFuture = widget.store.loadHarvests();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.sizeOf(context).height * .82,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: FutureBuilder<List<CozyGardenHarvest>>(
            future: _harvestFuture,
            builder: (context, snapshot) {
              final harvests = snapshot.data ?? const <CozyGardenHarvest>[];
              final counts = <String, int>{};
              for (final harvest in harvests) {
                counts.update(
                  harvest.plantType,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: scheme.secondary),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Our Garden',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'A shared collection of every bloom',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: scheme.onSecondaryContainer,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        labelStyle:
                            const TextStyle(fontWeight: FontWeight.w900),
                        tabs: const [
                          Tab(text: 'Plants'),
                          Tab(text: 'Harvests'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _GardenPlantsTab(
                            unlockedKeys: widget.unlockedKeys,
                            harvestCounts: counts,
                          ),
                          _GardenHarvestsTab(
                            harvests: harvests,
                            isLoading: snapshot.connectionState ==
                                ConnectionState.waiting,
                            hasError: snapshot.hasError,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GardenPlantsTab extends StatelessWidget {
  const _GardenPlantsTab({
    required this.unlockedKeys,
    required this.harvestCounts,
  });

  final Set<String> unlockedKeys;
  final Map<String, int> harvestCounts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _GardenBookSectionLabel(
          title: 'OUR PLANTS',
          subtitle: 'Seeds, flowers, and everything your garden has grown.',
        ),
        const SizedBox(height: 8),
        ...GardenPlantDefinition.all
            .where((plant) => plant.id != GardenPlantDefinition.legacyTree.id)
            .map(
              (plant) => _PlantBookRow(
                plant: plant,
                isUnlocked: plant.id == GardenPlantDefinition.sunflower.id ||
                    unlockedKeys.contains(plantUnlockKey(plant.id)),
                harvestCount: harvestCounts[plant.id] ?? 0,
              ),
            ),
      ],
    );
  }
}

class _GardenHarvestsTab extends StatelessWidget {
  const _GardenHarvestsTab({
    required this.harvests,
    required this.isLoading,
    required this.hasError,
  });

  final List<CozyGardenHarvest> harvests;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const _GardenBookSectionLabel(
          title: 'OUR HARVESTS',
          subtitle: 'Recent blooms from your shared garden.',
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Harvest history will return when the connection is back.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else if (harvests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Your first bloom will appear here.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          ...harvests.map(
            (harvest) => _HarvestHistoryRow(harvest: harvest),
          ),
      ],
    );
  }
}

class _GardenBookSectionLabel extends StatelessWidget {
  const _GardenBookSectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _PlantBookRow extends StatelessWidget {
  const _PlantBookRow({
    required this.plant,
    required this.isUnlocked,
    required this.harvestCount,
  });

  final GardenPlantDefinition plant;
  final bool isUnlocked;
  final int harvestCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countLabel = harvestCount == 1 ? 'time' : 'times';
    final subtitle = isUnlocked
        ? harvestCount > 0
            ? 'Unlocked - Harvested $harvestCount $countLabel'
            : 'Unlocked - 0 harvests'
        : plant.unlockHint;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: Icon(
        plant.icon,
        color: isUnlocked ? scheme.secondary : scheme.outline,
      ),
      title: Text(
        plant.displayName,
        style: TextStyle(
          color: isUnlocked ? scheme.onSurface : scheme.outline,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
        color: isUnlocked ? scheme.secondary : scheme.outline,
      ),
    );
  }
}

class _HarvestHistoryRow extends StatelessWidget {
  const _HarvestHistoryRow({required this.harvest});

  final CozyGardenHarvest harvest;

  @override
  Widget build(BuildContext context) {
    final plant = GardenPlantDefinition.forId(harvest.plantType);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: Icon(plant.icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(
        plant.displayName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text('Bloomed ${_formatGardenDate(harvest.harvestedAt)}'),
      trailing: Text(
        '${harvest.finalGrowth}/100',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _GardenErrorBanner extends StatelessWidget {
  const _GardenErrorBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PanGlassCard(
      accentColor: scheme.error,
      radius: 8,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The garden will refresh when the connection returns.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatGardenDate(DateTime date) {
  const monthNames = <String>[
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
  final local = date.toLocal();
  return '${monthNames[local.month - 1]} ${local.day}, ${local.year}';
}
