import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/send_love_store.dart';

class LoveLettersScreen extends StatefulWidget {
  const LoveLettersScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<LoveLettersScreen> createState() => _LoveLettersScreenState();
}

class _LoveLettersScreenState extends State<LoveLettersScreen> {
  final _store = SendLoveStore();
  late Future<List<SentLove>> _lettersFuture = _store.loadSentLoveLetters();

  void _refresh() {
    setState(() {
      _lettersFuture = _store.loadSentLoveLetters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _LoveLettersHeader(
                    account: widget.account,
                    onRefresh: _refresh,
                  ),
                ),
              ),
              FutureBuilder<List<SentLove>>(
                future: _lettersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const PanLoadingSliver(
                      title: 'Loading letters',
                      message: 'Collecting the newest love notes.',
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: _LoveLettersStateMessage(
                        icon: Icons.error_rounded,
                        title: 'Hindi ma-load',
                        message: 'Check Supabase table and storage policies.',
                        onRetry: _refresh,
                      ),
                    );
                  }

                  final letters = snapshot.data ?? const [];
                  if (letters.isEmpty) {
                    return SliverFillRemaining(
                      child: _LoveLettersStateMessage(
                        icon: Icons.mail_rounded,
                        title: 'No letters yet',
                        message: 'Send Love muna, then babasahin natin dito.',
                        onRetry: _refresh,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    sliver: SliverList.separated(
                      itemBuilder: (context, index) {
                        return RepaintBoundary(
                          child: _LoveLetterCard(
                            letter: letters[index],
                            account: widget.account,
                            store: _store,
                          )
                              .animate(delay: (index * 45).ms)
                              .fadeIn(duration: 280.ms)
                              .slideY(begin: .04, end: 0),
                        );
                      },
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 12);
                      },
                      itemCount: letters.length,
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

class _LoveLettersHeader extends StatelessWidget {
  const _LoveLettersHeader({required this.account, required this.onRefresh});

  final LocalAccount account;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PanFeatureHeader(
      title: 'Love Letters',
      subtitle: 'Shared feed with reacts and comments',
      leading: _SmallMascotBadge(mascot: account.mascot),
      accentColor: const Color(0xFFFFD45A),
      onBack: () => context.go('/'),
      trailing: IconButton.filledTonal(
        tooltip: 'Refresh',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}

class _LoveLetterCard extends StatelessWidget {
  const _LoveLetterCard({
    required this.letter,
    required this.account,
    required this.store,
  });

  final SentLove letter;
  final LocalAccount account;
  final SendLoveStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = letter.mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: .42),
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
                _MascotBadge(mascot: letter.mascot),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letter.username,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${letter.mascot.label} - ${formatSentLoveDate(letter.createdAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              letter.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (letter.attachmentUrl != null) ...[
              const SizedBox(height: 14),
              _TappableLetterImage(
                imageUrl: letter.attachmentUrl!,
                heroTag: 'love-letter-${letter.id}',
              ),
            ],
            const SizedBox(height: 14),
            _LoveLetterInteractions(
              letter: letter,
              account: account,
              store: store,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveLetterInteractions extends StatefulWidget {
  const _LoveLetterInteractions({
    required this.letter,
    required this.account,
    required this.store,
  });

  final SentLove letter;
  final LocalAccount account;
  final SendLoveStore store;

  @override
  State<_LoveLetterInteractions> createState() =>
      _LoveLetterInteractionsState();
}

class _LoveLetterInteractionsState extends State<_LoveLetterInteractions> {
  final _commentController = TextEditingController();
  late Future<_LoveLetterInteractionData> _interactionFuture =
      _loadInteractions();
  bool _isCommenting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<_LoveLetterInteractionData> _loadInteractions() async {
    final summary = await widget.store.loadReactionSummary(widget.letter.id);
    final comments = await widget.store.loadComments(widget.letter.id);
    return _LoveLetterInteractionData(summary: summary, comments: comments);
  }

  void _refreshInteractions() {
    setState(() {
      _interactionFuture = _loadInteractions();
    });
  }

  Future<void> _toggleReaction(
    String reaction,
    SentLoveReactionSummary summary,
  ) async {
    await widget.store.toggleReaction(
      account: widget.account,
      letterId: widget.letter.id,
      reaction: reaction,
      currentReaction: summary.myReaction,
    );
    _refreshInteractions();
  }

  Future<void> _addComment() async {
    final message = _commentController.text;
    if (message.trim().isEmpty || _isCommenting) {
      return;
    }

    setState(() => _isCommenting = true);
    try {
      await widget.store.addComment(
        account: widget.account,
        letterId: widget.letter.id,
        message: message,
      );
      _commentController.clear();
      _refreshInteractions();
    } finally {
      if (mounted) {
        setState(() => _isCommenting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoveLetterInteractionData>(
      future: _interactionFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final summary = data?.summary ??
            const SentLoveReactionSummary(counts: {}, myReaction: null);
        final comments = data?.comments ?? const <SentLoveComment>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReactionSummary(
              summary: summary,
              onTap: summary.reactors.isEmpty
                  ? null
                  : () => _showReactors(summary.reactors),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reaction in _reactionOptions)
                  _ReactionChip(
                    option: reaction,
                    count: summary.counts[reaction.id] ?? 0,
                    isSelected: summary.myReaction == reaction.id,
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : () => _toggleReaction(reaction.id, summary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (comments.isNotEmpty) ...[
              for (final comment in comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LoveComment(comment: comment),
                ),
            ],
            _CommentComposer(
              controller: _commentController,
              isSending: _isCommenting,
              onSend: _addComment,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReactors(List<SentLoveReactor> reactors) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Text(
                  'People who reacted',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: reactors.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _ReactionDetailsTile(
                    reactor: reactors[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoveLetterInteractionData {
  const _LoveLetterInteractionData({
    required this.summary,
    required this.comments,
  });

  final SentLoveReactionSummary summary;
  final List<SentLoveComment> comments;
}

class _ReactionOption {
  const _ReactionOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const _reactionOptions = <_ReactionOption>[
  _ReactionOption(
    id: 'love',
    label: 'Love',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFF7A9A),
  ),
  _ReactionOption(
    id: 'care',
    label: 'Care',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFFFFD45A),
  ),
  _ReactionOption(
    id: 'laugh',
    label: 'Haha',
    icon: Icons.sentiment_very_satisfied_rounded,
    color: Color(0xFF9BE0BC),
  ),
  _ReactionOption(
    id: 'wow',
    label: 'Wow',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF7CC2FF),
  ),
  _ReactionOption(
    id: 'sad',
    label: 'Sad',
    icon: Icons.sentiment_dissatisfied_rounded,
    color: Color(0xFFCFC3E8),
  ),
];

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.summary, this.onTap});

  final SentLoveReactionSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = summary.totalCount == 0
        ? 'Be first to react'
        : '${summary.totalCount} reaction${summary.totalCount == 1 ? '' : 's'}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              summary.totalCount == 0
                  ? Icons.favorite_border_rounded
                  : Icons.favorite_rounded,
              size: 17,
              color: summary.totalCount == 0
                  ? scheme.onSurfaceVariant
                  : const Color(0xFFFF7A9A),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (summary.firstReactorUsername != null &&
                summary.firstReactorMascot != null) ...[
              const SizedBox(width: 8),
              _FirstReactorBadge(
                username: summary.firstReactorUsername!,
                mascot: summary.firstReactorMascot!,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionDetailsTile extends StatelessWidget {
  const _ReactionDetailsTile({required this.reactor});

  final SentLoveReactor reactor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final option = _reactionOptions.firstWhere(
      (item) => item.id == reactor.reaction,
      orElse: () => _reactionOptions.first,
    );
    final accent = reactor.mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: scheme.surfaceContainerHighest,
      leading: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.5),
        ),
        child: PetdexFace(
          assetPath: reactor.mascot == AccountMascot.panda
              ? 'assets/pets/pippa/spritesheet.webp'
              : 'assets/pets/kebo/spritesheet.webp',
          size: 42,
        ),
      ),
      title: Text(reactor.username,
          style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
          '${reactor.mascot.label} Â· ${formatSentLoveDate(reactor.createdAt)}'),
      trailing: Icon(option.icon, color: option.color),
    );
  }
}

class _FirstReactorBadge extends StatelessWidget {
  const _FirstReactorBadge({required this.username, required this.mascot});

  final String username;
  final AccountMascot mascot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);
    return Tooltip(
      message: 'First reacted by $username',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.4),
            ),
            child: PetdexFace(
              assetPath: mascot == AccountMascot.panda
                  ? 'assets/pets/pippa/spritesheet.webp'
                  : 'assets/pets/kebo/spritesheet.webp',
              size: 25,
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    required this.option,
    required this.count,
    required this.isSelected,
    required this.onPressed,
  });

  final _ReactionOption option;
  final int count;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final option = widget.option;
    final selected = widget.isSelected;
    return Tooltip(
      message: '${option.label} reaction',
      child: Semantics(
        button: true,
        selected: selected,
        label: '${option.label} reaction',
        child: GestureDetector(
          onTapDown: widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapCancel: widget.onPressed == null
              ? null
              : () => setState(() => _pressed = false),
          onTap: widget.onPressed == null
              ? null
              : () {
                  setState(() => _pressed = false);
                  widget.onPressed!();
                },
          child: AnimatedScale(
            scale: _pressed ? .94 : 1,
            duration: const Duration(milliseconds: 110),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? option.color.withValues(alpha: .2)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? option.color : scheme.outlineVariant,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(option.icon,
                      size: 17,
                      color: selected ? option.color : scheme.onSurfaceVariant),
                  if (widget.count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${widget.count}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected
                                ? option.color
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoveComment extends StatelessWidget {
  const _LoveComment({required this.comment});

  final SentLoveComment comment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SmallMascotBadge(mascot: comment.mascot),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${comment.username} - ${formatSentLoveDate(comment.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              prefixIcon: Icon(Icons.mode_comment_rounded),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Comment',
          onPressed: isSending ? null : onSend,
          icon: isSending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

class _SmallMascotBadge extends StatelessWidget {
  const _SmallMascotBadge({required this.mascot});

  final AccountMascot mascot;

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
        ),
      ),
      child: SizedBox.square(
        dimension: 34,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: PetdexFace(
            assetPath: isPanda
                ? 'assets/pets/pippa/spritesheet.webp'
                : 'assets/pets/kebo/spritesheet.webp',
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _MascotBadge extends StatelessWidget {
  const _MascotBadge({required this.mascot});

  final AccountMascot mascot;

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
        dimension: 52,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: PetdexFace(
            assetPath: isPanda
                ? 'assets/pets/pippa/spritesheet.webp'
                : 'assets/pets/kebo/spritesheet.webp',
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _TappableLetterImage extends StatelessWidget {
  const _TappableLetterImage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              _LetterImageViewer(imageUrl: imageUrl, heroTag: heroTag),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: PanCachedImage(
            imageUrl: imageUrl,
            heroTag: heroTag,
            height: 220,
            fit: BoxFit.contain,
            errorLabel: 'Picture preview unavailable',
          ),
        ),
      ),
    );
  }
}

class _LetterImageViewer extends StatelessWidget {
  const _LetterImageViewer({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 4,
                child: PanCachedImage(
                  imageUrl: imageUrl,
                  heroTag: heroTag,
                  height: null,
                  fit: BoxFit.contain,
                  errorLabel: 'Picture preview unavailable',
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveLettersStateMessage extends StatelessWidget {
  const _LoveLettersStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
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
            Icon(icon, color: scheme.primary, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String formatSentLoveDate(DateTime date) {
  if (date.month < 1 || date.month > 12) {
    return date.toLocal().toString();
  }

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
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
          ? date.hour - 12
          : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final safeMonth = date.month < 1
      ? 1
      : date.month > 12
          ? 12
          : date.month;
  final month = months[safeMonth - 1];
  return '$month ${date.day}, ${date.year} - $hour:$minute $period';
}
