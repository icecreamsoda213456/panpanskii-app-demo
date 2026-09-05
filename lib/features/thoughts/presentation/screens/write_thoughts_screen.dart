import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/thoughts_store.dart';

class WriteThoughtsScreen extends StatefulWidget {
  const WriteThoughtsScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<WriteThoughtsScreen> createState() => _WriteThoughtsScreenState();
}

class _WriteThoughtsScreenState extends State<WriteThoughtsScreen> {
  final _store = ThoughtsStore();
  final _thoughtController = TextEditingController();
  final _thoughtFocusNode = FocusNode();
  late Future<List<ThoughtPost>> _thoughtsFuture = _store.loadThoughts();
  bool _isPosting = false;
  bool _isFocused = false;
  static const _maxThoughtLength = 600;
  String get _draftKey => 'thought_draft_${widget.account.username}';

  @override
  void initState() {
    super.initState();
    _thoughtFocusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _thoughtFocusNode.hasFocus);
    });
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final draft = preferences.getString(_draftKey);
    if (mounted && _thoughtController.text.isEmpty && draft != null) {
      _thoughtController.text = draft;
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
    if (_thoughtController.text.trim().isEmpty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep your thought?'),
        content: const Text('Your unfinished thought is saved as a draft.'),
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
    return discard ?? false;
  }

  @override
  void dispose() {
    _thoughtController.dispose();
    _thoughtFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _thoughtsFuture = _store.loadThoughts();
    });
  }

  Future<void> _postThought() async {
    final body = _thoughtController.text;
    if (body.trim().isEmpty || _isPosting) {
      return;
    }

    setState(() => _isPosting = true);
    try {
      await _store.createThought(account: widget.account, body: body);
      if (!mounted) {
        return;
      }
      _thoughtController.clear();
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_draftKey);
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
      _refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hindi na-save. Check thoughts SQL.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
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
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  sliver: SliverToBoxAdapter(
                    child: _ThoughtsHeader(account: widget.account),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  sliver: SliverToBoxAdapter(
                    child: _ThoughtComposer(
                      controller: _thoughtController,
                      focusNode: _thoughtFocusNode,
                      isFocused: _isFocused,
                      isPosting: _isPosting,
                      maxLength: _maxThoughtLength,
                      onChanged: _saveDraft,
                      onPost: _postThought,
                    ),
                  ),
                ),
                FutureBuilder<List<ThoughtPost>>(
                  future: _thoughtsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const PanLoadingSliver(
                        title: 'Loading thoughts',
                        message: 'Bringing in the shared notes.',
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: _ThoughtStateMessage(
                          icon: Icons.cloud_off_rounded,
                          title: 'Hindi ma-load ang thoughts',
                          message: 'Run the thoughts SQL sa Supabase editor.',
                          onRetry: _refresh,
                        ),
                      );
                    }

                    final thoughts = snapshot.data ?? const [];
                    if (thoughts.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ThoughtStateMessage(
                          icon: Icons.edit_note_rounded,
                          title: 'No thoughts yet',
                          message: 'Write the first shared thought.',
                          onRetry: _refresh,
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                      sliver: SliverList.separated(
                        itemCount: thoughts.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 12);
                        },
                        itemBuilder: (context, index) {
                          return RepaintBoundary(
                            child: _ThoughtCard(
                              thought: thoughts[index],
                              account: widget.account,
                              store: _store,
                            )
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
      ),
    );
  }
}

class _ThoughtsHeader extends StatelessWidget {
  const _ThoughtsHeader({required this.account});

  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    return PanFeatureHeader(
      title: 'Write Your Thoughts',
      subtitle: 'Shared notes with reacts and comments',
      leading: _MascotBadge(mascot: account.mascot, size: 46),
      trailing: const _FeedBadge(),
      accentColor: const Color(0xFF7CC2FF),
      onBack: () => context.go('/'),
    );
  }
}

class _FeedBadge extends StatelessWidget {
  const _FeedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF9BE0BC).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF9BE0BC).withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_rounded, color: Color(0xFF9BE0BC), size: 18),
            const SizedBox(width: 6),
            Text(
              'Feed',
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

class _ThoughtComposer extends StatelessWidget {
  const _ThoughtComposer({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.maxLength,
    required this.onChanged,
    required this.isPosting,
    required this.onPost,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final bool isPosting;
  final VoidCallback onPost;

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
          color: isFocused ? scheme.primary : scheme.outlineVariant,
          width: isFocused ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isFocused ? .18 : .08),
            blurRadius: isFocused ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share what is on your heart',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'A small note can brighten someoneâ€™s day.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 5,
              maxLines: 9,
              maxLength: maxLength,
              onChanged: onChanged,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
              decoration: InputDecoration(
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_rounded),
                hintText: 'Whatâ€™s on your heart today?',
                counterStyle: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      isPosting || value.text.trim().isEmpty ? null : onPost,
                  icon: isPosting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(isPosting ? 'Posting...' : 'Post thought'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThoughtCard extends StatelessWidget {
  const _ThoughtCard({
    required this.thought,
    required this.account,
    required this.store,
  });

  final ThoughtPost thought;
  final LocalAccount account;
  final ThoughtsStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = thought.mascot == AccountMascot.panda
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
                _MascotBadge(mascot: thought.mascot, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thought.username,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${thought.mascot.label} - ${_formatThoughtDate(thought.createdAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              thought.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            _ThoughtInteractions(
              thought: thought,
              account: account,
              store: store,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThoughtInteractions extends StatefulWidget {
  const _ThoughtInteractions({
    required this.thought,
    required this.account,
    required this.store,
  });

  final ThoughtPost thought;
  final LocalAccount account;
  final ThoughtsStore store;

  @override
  State<_ThoughtInteractions> createState() => _ThoughtInteractionsState();
}

class _ThoughtInteractionsState extends State<_ThoughtInteractions> {
  final _commentController = TextEditingController();
  late Future<_ThoughtInteractionData> _interactionFuture = _loadInteractions();
  bool _isCommenting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<_ThoughtInteractionData> _loadInteractions() async {
    final summary = await widget.store.loadReactionSummary(widget.thought.id);
    final comments = await widget.store.loadComments(widget.thought.id);
    return _ThoughtInteractionData(summary: summary, comments: comments);
  }

  void _refreshInteractions() {
    setState(() {
      _interactionFuture = _loadInteractions();
    });
  }

  Future<void> _toggleReaction(
    String reaction,
    ThoughtReactionSummary summary,
  ) async {
    await widget.store.toggleReaction(
      account: widget.account,
      thoughtId: widget.thought.id,
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
        thoughtId: widget.thought.id,
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
    return FutureBuilder<_ThoughtInteractionData>(
      future: _interactionFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final summary = data?.summary ??
            const ThoughtReactionSummary(counts: {}, myReaction: null);
        final comments = data?.comments ?? const <ThoughtComment>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.totalCount == 0
                  ? 'Be first to react'
                  : '${summary.totalCount} reaction${summary.totalCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCFC3E8),
                    fontWeight: FontWeight.w900,
                  ),
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
            OutlinedButton.icon(
              onPressed: () => _openComments(comments.length),
              icon: const Icon(Icons.mode_comment_outlined, size: 18),
              label: Text(comments.isEmpty
                  ? 'Be the first to comment'
                  : '${comments.length} comments'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openComments(int count) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text('Comments',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                Expanded(
                  child: FutureBuilder<List<ThoughtComment>>(
                    future: widget.store.loadComments(widget.thought.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data ?? const <ThoughtComment>[];
                      if (items.isEmpty) {
                        return const Center(
                            child: Text(
                                'No comments yet. Start the conversation.'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _ThoughtCommentTile(comment: items[index]),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: _CommentComposer(
                    controller: _commentController,
                    isSending: _isCommenting,
                    onSend: () async {
                      await _addComment();
                      if (mounted && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      _refreshInteractions();
    }
  }
}

class _ThoughtInteractionData {
  const _ThoughtInteractionData({
    required this.summary,
    required this.comments,
  });

  final ThoughtReactionSummary summary;
  final List<ThoughtComment> comments;
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
    id: 'agree',
    label: 'Agree',
    icon: Icons.thumb_up_alt_rounded,
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
        label:
            '${option.label} reaction${widget.count == 0 ? '' : ', ${widget.count}'}',
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
              curve: Curves.easeOutCubic,
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

class _ThoughtCommentTile extends StatelessWidget {
  const _ThoughtCommentTile({required this.comment});

  final ThoughtComment comment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151B30).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MascotBadge(mascot: comment.mascot, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${comment.username} - ${_formatThoughtDate(comment.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFCFC3E8),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFFF4EA),
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
                  color: const Color(0xFFFFF4EA),
                  fontWeight: FontWeight.w900,
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

class _ThoughtStateMessage extends StatelessWidget {
  const _ThoughtStateMessage({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD45A), size: 44),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCFC3E8),
                    fontWeight: FontWeight.w900,
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

String _formatThoughtDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $period';
}
