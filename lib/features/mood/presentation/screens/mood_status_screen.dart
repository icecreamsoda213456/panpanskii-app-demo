import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/mood_status_store.dart';

class MoodStatusScreen extends StatefulWidget {
  const MoodStatusScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<MoodStatusScreen> createState() => _MoodStatusScreenState();
}

class _MoodStatusScreenState extends State<MoodStatusScreen> {
  final _store = MoodStatusStore();
  late final Stream<List<MoodStatus>> _statusesStream = _store.watchStatuses();
  bool _isSaving = false;
  String? _selectedMood;

  void _selectMood(_MoodOption option) {
    if (_isSaving) return;
    setState(() => _selectedMood = option.id);
  }

  Future<void> _shareMood() async {
    final selectedMood = _selectedMood;
    if (_isSaving || selectedMood == null) return;
    final option = _moodOptions.firstWhere(
      (item) => item.id == selectedMood,
      orElse: () => _moodOptions.first,
    );
    setState(() => _isSaving = true);
    try {
      await _store.setMood(account: widget.account, mood: option.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${option.label} mood shared.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<MoodStatus>>(
          stream: _statusesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const PanLoadingState(
                title: 'Loading moods',
                message: 'Checking in with your favorite person.',
              );
            }
            final statuses = snapshot.data ?? const <MoodStatus>[];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  sliver: SliverToBoxAdapter(
                    child: PanFeatureHeader(
                      title: 'Mood Status',
                      subtitle: 'A gentle check-in for both of you',
                      leading: _MoodAvatar(
                        mascot: widget.account.mascot,
                        size: 46,
                      ),
                      trailing: const Icon(Icons.favorite_rounded),
                      accentColor: const Color(0xFFFF7888),
                      onBack: () => context.go('/'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  sliver: SliverToBoxAdapter(
                    child: _MoodPicker(
                      selectedMood: _selectedMood,
                      isSaving: _isSaving,
                      mascot: widget.account.mascot,
                      onSelect: _selectMood,
                      onShare: _shareMood,
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MoodStateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Mood status is offline',
                      message: 'Run the mood status SQL in Supabase first.',
                    ),
                  )
                else if (statuses.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MoodStateMessage(
                      icon: Icons.favorite_border_rounded,
                      title: 'No mood shared yet',
                      message:
                          'Choose a mood above to let the other phone know.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    sliver: SliverList.separated(
                      itemCount: statuses.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) => _MoodCard(
                        status: statuses[index],
                        isMine:
                            statuses[index].username == widget.account.username,
                      )
                          .animate(delay: (index * 45).ms)
                          .fadeIn(duration: 260.ms)
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

class _MoodOption {
  const _MoodOption(
      {required this.id,
      required this.label,
      required this.icon,
      required this.color});

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const _moodOptions = <_MoodOption>[
  _MoodOption(
      id: 'happy',
      label: 'Happy',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFFFFC857)),
  _MoodOption(
      id: 'loved',
      label: 'Loved',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF7888)),
  _MoodOption(
      id: 'calm',
      label: 'Calm',
      icon: Icons.spa_rounded,
      color: Color(0xFF72D6A0)),
  _MoodOption(
      id: 'excited',
      label: 'Excited',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFB8AEFF)),
  _MoodOption(
      id: 'tired',
      label: 'Tired',
      icon: Icons.bedtime_rounded,
      color: Color(0xFF7CC2FF)),
  _MoodOption(
      id: 'sad',
      label: 'Sad',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF8D91A8)),
  _MoodOption(
      id: 'anxious',
      label: 'Anxious',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFFF9F68)),
  _MoodOption(
      id: 'scared',
      label: 'Scared',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF9C8CFF)),
  _MoodOption(
      id: 'grateful',
      label: 'Grateful',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF65C9A0)),
  _MoodOption(
      id: 'hopeful',
      label: 'Hopeful',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFFFC857)),
];

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({
    required this.selectedMood,
    required this.isSaving,
    required this.mascot,
    required this.onSelect,
    required this.onShare,
  });

  final String? selectedMood;
  final bool isSaving;
  final AccountMascot mascot;
  final ValueChanged<_MoodOption> onSelect;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedOption = selectedMood == null
        ? null
        : _moodOptions.firstWhere(
            (item) => item.id == selectedMood,
            orElse: () => _moodOptions.first,
          );
    return PanGlassCard(
      accentColor: selectedOption?.color ?? scheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: [
          Text(
            'How are you feeling today?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose one feeling to share with your person.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          _MoodHero(option: selectedOption, mascot: mascot),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pick a mood',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _moodOptions)
                _MoodChoice(
                  option: option,
                  selected: selectedMood == option.id,
                  disabled: isSaving,
                  onTap: () => onSelect(option),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: selectedOption == null || isSaving ? null : onShare,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(isSaving ? 'Sharing...' : 'Share mood'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mood updates are limited to once every 10 minutes.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodHero extends StatelessWidget {
  const _MoodHero({required this.option, required this.mascot});

  final _MoodOption? option;
  final AccountMascot mascot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = option?.color ?? scheme.primary;
    final panda = mascot == AccountMascot.panda;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: accent.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .16 : .2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 94,
            height: 122,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: .74),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: PetdexMood(
                key: ValueKey('${mascot.name}-${option?.id ?? 'calm'}'),
                name: panda ? 'Pippa' : 'Kebo',
                assetPath: panda
                    ? 'assets/pets/pippa/spritesheet.webp'
                    : 'assets/pets/kebo/spritesheet.webp',
                mood: option?.id ?? 'calm',
                size: 80,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey(option?.id ?? 'empty'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    option?.icon ?? Icons.mood_rounded,
                    size: 34,
                    color: accent,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    option?.label ?? 'Ready when you are',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option == null
                        ? 'Tap a feeling below.'
                        : 'This is how I feel right now.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChoice extends StatelessWidget {
  const _MoodChoice(
      {required this.option,
      required this.selected,
      required this.disabled,
      required this.onTap});

  final _MoodOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? option.color.withValues(alpha: .2) : scheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: selected ? option.color : scheme.outlineVariant,
              width: selected ? 1.8 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(option.icon, size: 19, color: option.color),
          const SizedBox(width: 6),
          Text(option.label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.status, required this.isMine});

  final MoodStatus status;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final option = _moodOptions.firstWhere((item) => item.id == status.mood,
        orElse: () => _moodOptions[2]);
    final accent = status.mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);
    return PanGlassCard(
      accentColor: accent,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        _MoodAvatar(mascot: status.mascot, size: 52),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMine ? 'You' : status.username,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(option.icon, size: 18, color: option.color),
            const SizedBox(width: 6),
            Text('feeling ${option.label.toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800))
          ]),
        ])),
        Text(_formatMoodTime(status.updatedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _MoodAvatar extends StatelessWidget {
  const _MoodAvatar({required this.mascot, required this.size});

  final AccountMascot mascot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final panda = mascot == AccountMascot.panda;
    final accent = panda ? const Color(0xFFFFC857) : const Color(0xFF72D6A0);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: accent, width: 2)),
      child: PetdexFace(
          assetPath: panda
              ? 'assets/pets/pippa/spritesheet.webp'
              : 'assets/pets/kebo/spritesheet.webp',
          size: size - 4),
    );
  }
}

class _MoodStateMessage extends StatelessWidget {
  const _MoodStateMessage(
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 48, color: scheme.primary),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ])));
  }
}

String _formatMoodTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}
