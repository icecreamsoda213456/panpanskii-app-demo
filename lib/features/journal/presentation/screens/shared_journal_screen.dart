import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/shared_journal_store.dart';

class SharedJournalScreen extends StatefulWidget {
  const SharedJournalScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<SharedJournalScreen> createState() => _SharedJournalScreenState();
}

class _SharedJournalScreenState extends State<SharedJournalScreen> {
  final _store = SharedJournalStore();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();
  bool _isSaving = false;
  bool _isBodyFocused = false;
  static const _maxBodyLength = 1200;
  String get _draftKey => 'journal_draft_${widget.account.username}';

  @override
  void initState() {
    super.initState();
    _bodyFocusNode.addListener(() {
      if (mounted) setState(() => _isBodyFocused = _bodyFocusNode.hasFocus);
    });
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final draft = preferences.getString(_draftKey);
    if (mounted && _bodyController.text.isEmpty && draft != null) {
      _bodyController.text = draft;
      setState(() {});
    }
  }

  Future<void> _saveDraft(String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value.trim().isEmpty) {
      await preferences.remove(_draftKey);
    } else {
      await preferences.setString(_draftKey, value);
    }
  }

  Future<bool> _confirmLeave() async {
    if (_bodyController.text.trim().isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep tonight\'s draft?'),
        content: const Text('Your unfinished journal entry is saved locally.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep writing')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_bodyController.text.trim().isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _store.saveTonightEntry(
        account: widget.account,
        title: _titleController.text,
        body: _bodyController.text,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _bodyController.clear();
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_draftKey);
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal saved for tonight.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hindi na-save. Check Supabase SQL.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || !await _confirmLeave()) {
            return;
          }
          if (!mounted) {
            return;
          }
          this.context.go('/');
        },
        child: SafeArea(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                sliver: SliverToBoxAdapter(
                  child: _JournalHeader(account: widget.account),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                sliver: SliverToBoxAdapter(
                  child: _TonightComposer(
                    titleController: _titleController,
                    bodyController: _bodyController,
                    bodyFocusNode: _bodyFocusNode,
                    isBodyFocused: _isBodyFocused,
                    maxBodyLength: _maxBodyLength,
                    onBodyChanged: _saveDraft,
                    isSaving: _isSaving,
                    onSave: _saveEntry,
                  ),
                ),
              ),
              StreamBuilder<List<SharedJournalEntry>>(
                stream: _store.watchEntries(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const PanLoadingSliver(
                      title: 'Loading journal',
                      message: 'Opening tonight\'s shared diary.',
                    );
                  }

                  if (snapshot.hasError) {
                    return const SliverFillRemaining(
                      child: _JournalStateMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Hindi ma-load ang journal',
                        message:
                            'Run the shared journal SQL sa Supabase editor.',
                      ),
                    );
                  }

                  final entries = snapshot.data ?? const [];
                  if (entries.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _JournalStateMessage(
                        icon: Icons.edit_note_rounded,
                        title: 'No journal entries yet',
                        message: 'Write tonight\'s first shared diary entry.',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (context, index) {
                        return RepaintBoundary(
                          child: _JournalEntryCard(entry: entries[index])
                              .animate(delay: (index * 45).ms)
                              .fadeIn(duration: 280.ms)
                              .slideY(begin: .04, end: 0),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.account});

  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    return PanFeatureHeader(
      title: 'Shared Journal',
      subtitle: 'Nightly diary for both of you',
      leading: _MascotBadge(mascot: account.mascot, size: 46),
      trailing: const _NightBadge(),
      accentColor: const Color(0xFFFFD45A),
      onBack: () => context.go('/'),
    );
  }
}

class _TonightComposer extends StatelessWidget {
  const _TonightComposer({
    required this.titleController,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.isBodyFocused,
    required this.maxBodyLength,
    required this.onBodyChanged,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final bool isBodyFocused;
  final int maxBodyLength;
  final ValueChanged<String> onBodyChanged;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBodyFocused ? scheme.primary : scheme.outlineVariant,
          width: isBodyFocused ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isBodyFocused ? .18 : .08),
            blurRadius: isBodyFocused ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tonight\'s shared diary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Write one honest moment for both of you to keep.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.title_rounded),
                hintText: 'Title, optional',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              focusNode: bodyFocusNode,
              minLines: 5,
              maxLines: 9,
              maxLength: maxBodyLength,
              onChanged: onBodyChanged,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_note_rounded),
                hintText: 'What do you want to remember tonight?',
              ),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: bodyController,
              builder: (context, value, child) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      isSaving || value.text.trim().isEmpty ? null : onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_add_rounded),
                  label: Text(isSaving ? 'Saving...' : 'Save tonight'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  final SharedJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final isMine = entry.isMine;
    final scheme = Theme.of(context).colorScheme;
    final accent = entry.mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: isMine ? .62 : .34),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MascotBadge(mascot: entry.mascot, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.username,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${entry.mascot.label} - ${_formatJournalDate(entry.entryDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  Icon(
                    Icons.edit_rounded,
                    color: accent,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entry.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Updated ${_formatJournalTime(entry.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightBadge extends StatelessWidget {
  const _NightBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD45A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFD45A).withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.nights_stay_rounded,
              color: Color(0xFFFFD45A),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Night',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFFF4EA),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalStateMessage extends StatelessWidget {
  const _JournalStateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD45A), size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: const Color(0xFFFFF4EA)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFCFC3E8),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MascotBadge extends StatelessWidget {
  const _MascotBadge({required this.mascot, required this.size});

  final AccountMascot mascot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isPanda = mascot == AccountMascot.panda;
    final accent = isPanda ? const Color(0xFFFFC857) : const Color(0xFF72D6A0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: .8),
          width: 2,
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: PetdexFace(
            assetPath: isPanda
                ? 'assets/pets/pippa/spritesheet.webp'
                : 'assets/pets/kebo/spritesheet.webp',
            size: size - 4,
          ),
        ),
      ),
    );
  }
}

String _formatJournalDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatJournalTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
