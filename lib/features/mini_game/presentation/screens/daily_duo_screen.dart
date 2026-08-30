import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../../core/supabase/supabase.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/cozy_garden_store.dart';
import '../../data/daily_duo_store.dart';

class DailyDuoScreen extends StatefulWidget {
  const DailyDuoScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<DailyDuoScreen> createState() => _DailyDuoScreenState();
}

class _DailyDuoScreenState extends State<DailyDuoScreen> {
  final _store = DailyDuoStore();
  final _gardenStore = CozyGardenStore();
  late DailyDuoRound _round = _store.roundForNow();
  late Stream<List<DailyDuoAnswer>> _answersStream =
      _store.watchAnswers(_round.dayKey);
  Timer? _dayRolloverTimer;
  bool _isSubmitting = false;
  int? _pendingOption;
  bool _isClaimingGardenBonus = false;
  bool _gardenBonusClaimQueued = false;
  DailyDuoGardenBonusResult? _gardenBonus;

  @override
  void initState() {
    super.initState();
    // Re-check the current round so a day that flips while this screen stays
    // open (6 AM Manila boundary) rolls over instead of freezing the user on
    // yesterday's question forever.
    _dayRolloverTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _handleDayRollover(),
    );
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    super.dispose();
  }

  void _handleDayRollover() {
    if (!mounted) return;
    final nextRound = _store.roundForNow();
    if (nextRound.dayKey == _round.dayKey) return;
    setState(() {
      _round = nextRound;
      _answersStream = _store.watchAnswers(nextRound.dayKey);
      _pendingOption = null;
      _isSubmitting = false;
      _gardenBonus = null;
      _gardenBonusClaimQueued = false;
      _isClaimingGardenBonus = false;
    });
  }

  Future<void> _submitAnswer(int optionIndex) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _pendingOption = optionIndex;
    });
    // Capture the day this answer belongs to so a 6 AM rollover in the middle
    // of the write can never claim the garden bonus for the wrong day.
    final round = _round;
    try {
      await _store.submitAnswer(
        account: widget.account,
        round: round,
        optionIndex: optionIndex,
      );
      await _claimGardenBonus(dayKey: round.dayKey);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingOption = null);
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _claimGardenBonus({required String dayKey}) async {
    if (_isClaimingGardenBonus) return;
    if (mounted) setState(() => _isClaimingGardenBonus = true);
    try {
      final result = await _gardenStore.claimDailyDuoBonus(dayKey: dayKey);
      // The day may have rolled over while the RPC was in flight; discard a
      // stale reward so yesterday's bonus never flashes on today's round.
      if (!mounted || dayKey != _round.dayKey) return;
      setState(() => _gardenBonus = result);
    } catch (_) {
      // Realtime will retry after both answers and the Phase 2 RPC are ready.
    } finally {
      if (mounted) setState(() => _isClaimingGardenBonus = false);
    }
  }

  void _queueGardenBonusClaim(bool bothAnswered) {
    if (!bothAnswered ||
        _isClaimingGardenBonus ||
        _gardenBonusClaimQueued ||
        _gardenBonus?.isComplete == true) {
      return;
    }
    _gardenBonusClaimQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gardenBonusClaimQueued = false;
      if (!mounted || _isClaimingGardenBonus) return;
      _claimGardenBonus(dayKey: _round.dayKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<DailyDuoAnswer>>(
          stream: _answersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const PanLoadingState(
                title: 'Loading Daily Duo',
                message: 'Setting up today\'s little challenge.',
              );
            }
            final answers = snapshot.data ?? const <DailyDuoAnswer>[];
            final currentUserId = supabase.auth.currentUser?.id;
            final mine = _firstAnswer(
              answers,
              (answer) => answer.userId == currentUserId,
            );
            final partner = _firstAnswer(
              answers,
              (answer) => answer.userId != currentUserId,
            );
            final bothAnswered = mine != null && partner != null;
            _queueGardenBonusClaim(bothAnswered);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  sliver: SliverToBoxAdapter(
                    child: PanFeatureHeader(
                      title: 'Daily Duo',
                      subtitle: 'Answer together, match together',
                      leading: const _DuoHeaderIcon(),
                      trailing: IconButton(
                        tooltip: 'Open Cozy Garden',
                        onPressed: () => context.push('/cozy-garden'),
                        icon: const Icon(Icons.local_florist_rounded),
                      ),
                      accentColor: const Color(0xFFFF7888),
                      onBack: () => context.go('/'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  sliver: SliverToBoxAdapter(
                    child: _DuoPromptCard(
                      round: _round,
                      mine: mine,
                      partner: partner,
                      pendingOption: _pendingOption,
                      isSubmitting: _isSubmitting,
                      onSelect: _submitAnswer,
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DuoMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Daily Duo is offline',
                      message: 'Run supabase_daily_duo.sql in Supabase first.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _DuoStatusCard(
                            round: _round,
                            mine: mine,
                            partner: partner,
                          ),
                          if (_gardenBonus?.isComplete == true &&
                              _gardenBonus!.totalDayBonus > 0) ...[
                            const SizedBox(height: 10),
                            _GardenBonusMessage(result: _gardenBonus!),
                          ],
                          const SizedBox(height: 10),
                          PanGlassCard(
                            accentColor: const Color(0xFF72D6A0),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_florist_rounded,
                                  color: Color(0xFF72D6A0),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Grow a shared Cozy Garden together.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'Open Cozy Garden',
                                  onPressed: () => context.push('/cozy-garden'),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

DailyDuoAnswer? _firstAnswer(
  Iterable<DailyDuoAnswer> answers,
  bool Function(DailyDuoAnswer answer) test,
) {
  for (final answer in answers) {
    if (test(answer)) return answer;
  }
  return null;
}

class _DuoHeaderIcon extends StatelessWidget {
  const _DuoHeaderIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(
        dimension: 46,
        child: Icon(Icons.people_alt_rounded),
      ),
    );
  }
}

class _DuoPromptCard extends StatelessWidget {
  const _DuoPromptCard({
    required this.round,
    required this.mine,
    required this.partner,
    required this.pendingOption,
    required this.isSubmitting,
    required this.onSelect,
  });

  final DailyDuoRound round;
  final DailyDuoAnswer? mine;
  final DailyDuoAnswer? partner;
  final int? pendingOption;
  final bool isSubmitting;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSavingNewAnswer = mine == null && pendingOption != null;
    final bothAnswered = mine != null && partner != null;
    final showLocked = isSavingNewAnswer || bothAnswered;
    final canChangeAnswer = mine != null && partner == null;
    final selectedOption = mine?.optionIndex ?? pendingOption;
    return PanGlassCard(
      accentColor: const Color(0xFFFF7888),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DuoMascotRow(),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC857)),
              const SizedBox(width: 8),
              Text(
                'TODAY\'S DUO PROMPT',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            round.prompt,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 15),
          if (showLocked)
            _LockedAnswer(
              label: round.options[mine?.optionIndex ?? pendingOption ?? 0],
              isPending: pendingOption != null,
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: round.options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) => _DuoOptionButton(
                label: round.options[index],
                index: index,
                isSelected: selectedOption == index,
                disabled: isSubmitting,
                onTap: () => onSelect(index),
              ),
            ),
            if (canChangeAnswer) ...[
              const SizedBox(height: 10),
              Text(
                'You can still change your answer until your person answers.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .04, end: 0);
  }
}

class _DuoMascotRow extends StatelessWidget {
  const _DuoMascotRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DuoMascot(
          name: 'Pippa',
          assetPath: 'assets/pets/pippa/spritesheet.webp',
          accent: const Color(0xFFFFC857),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(
            Icons.favorite_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
        ),
        _DuoMascot(
          name: 'Kebo',
          assetPath: 'assets/pets/kebo/spritesheet.webp',
          accent: const Color(0xFF72D6A0),
        ),
      ],
    );
  }
}

class _DuoMascot extends StatelessWidget {
  const _DuoMascot(
      {required this.name, required this.assetPath, required this.accent});

  final String name;
  final String assetPath;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
          ),
          child: PetdexFace(assetPath: assetPath, size: 48),
        ),
        const SizedBox(height: 3),
        Text(
          name,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

/// Color per answer slot, shared by the option buttons.
const _duoOptionColors = <Color>[
  Color(0xFFFFC857),
  Color(0xFF72D6A0),
  Color(0xFFFF9F68),
  Color(0xFF9C8CFF),
];

class _DuoOptionButton extends StatelessWidget {
  const _DuoOptionButton({
    required this.label,
    required this.index,
    this.isSelected = false,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool isSelected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _duoOptionColors[index % _duoOptionColors.length];
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isSelected ? .32 : .15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? accent : accent.withValues(alpha: .65),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, color: accent, size: 16),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
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

class _LockedAnswer extends StatelessWidget {
  const _LockedAnswer({required this.label, required this.isPending});

  final String label;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: scheme.primary.withValues(alpha: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                isPending ? 'Saving your answer...' : 'You chose: $label',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (isPending)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuoStatusCard extends StatelessWidget {
  const _DuoStatusCard({
    required this.round,
    required this.mine,
    required this.partner,
  });

  final DailyDuoRound round;
  final DailyDuoAnswer? mine;
  final DailyDuoAnswer? partner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bothAnswered = mine != null && partner != null;
    final matched = bothAnswered && mine!.optionIndex == partner!.optionIndex;
    final title = mine == null
        ? 'Waiting for you'
        : partner == null
            ? 'Waiting for your person'
            : matched
                ? 'Perfect match!'
                : 'Different answers, same team';
    final message = mine == null
        ? 'Pick an answer above to join today\'s duo round.'
        : partner == null
            ? 'Your answer is saved and you can still change it. The result appears when the other phone answers.'
            : matched
                ? 'You both picked the same answer today. That deserves a little celebration.'
                : 'You chose different answers. Compare them in private chat and see why.';
    return PanGlassCard(
      accentColor:
          bothAnswered && matched ? const Color(0xFFFFC857) : scheme.secondary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bothAnswered && matched
                ? Icons.celebration_rounded
                : bothAnswered
                    ? Icons.forum_rounded
                    : Icons.hourglass_top_rounded,
            color: bothAnswered && matched
                ? const Color(0xFFFFA84F)
                : scheme.secondary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
                if (bothAnswered) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ChoicePill(
                        label: '${mine!.username}: '
                            '${round.options[mine!.optionIndex]}',
                        accent: matched
                            ? const Color(0xFFFFC857)
                            : scheme.primary,
                      ),
                      _ChoicePill(
                        label: '${partner!.username}: '
                            '${round.options[partner!.optionIndex]}',
                        accent: matched
                            ? const Color(0xFFFFC857)
                            : scheme.tertiary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _GardenBonusMessage extends StatelessWidget {
  const _GardenBonusMessage({required this.result});

  final DailyDuoGardenBonusResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = result.isMatch
        ? 'Perfect Match Garden Bonus'
        : 'Daily Duo Garden Bonus';
    return PanGlassCard(
      accentColor: scheme.secondary,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(Icons.local_florist_rounded, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${result.totalDayBonus} garden growth',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
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

class _DuoMessage extends StatelessWidget {
  const _DuoMessage(
      {required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
