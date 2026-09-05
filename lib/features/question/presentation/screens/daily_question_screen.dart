import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/daily_question_store.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  final _store = DailyQuestionStore();
  final _commentController = TextEditingController();
  late DailyQuestion _question;
  late Stream<List<DailyQuestionComment>> _comments;
  Timer? _refreshTimer;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _question = _store.questionForNow();
    _comments = _store.watchComments(_question.dayKey);
    _scheduleMorningRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _scheduleMorningRefresh() {
    _refreshTimer?.cancel();
    final delay = _store.nextRefreshAt().difference(DateTime.now());
    _refreshTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _question = _store.questionForNow();
        _comments = _store.watchComments(_question.dayKey);
      });
      _scheduleMorningRefresh();
    });
  }

  Future<void> _sendComment() async {
    if (_isSending || _commentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _store.addComment(
        account: widget.account,
        dayKey: _question.dayKey,
        message: _commentController.text,
      );
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_readableError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _confirmDelete(DailyQuestionComment comment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete answer?'),
        content: const Text(
          'This removes your answer from today\'s conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _store.deleteComment(comment.id);
    } catch (error) {
      if (mounted) {
        _showMessage(_readableError(error));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _readableError(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Could not update today\'s conversation. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panda = widget.account.mascot == AccountMascot.panda;
    final assetPath = panda
        ? 'assets/pets/pippa/spritesheet.webp'
        : 'assets/pets/kebo/spritesheet.webp';
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              sliver: SliverToBoxAdapter(
                child: PanFeatureHeader(
                  title: 'Daily Question',
                  subtitle: 'One thoughtful question each morning',
                  leading: _QuestionAvatar(
                    assetPath: assetPath,
                    accentColor: const Color(0xFFFFC857),
                  ),
                  trailing: const Icon(Icons.wb_sunny_rounded),
                  accentColor: const Color(0xFFFFC857),
                  onBack: () => context.go('/'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _QuestionHero(
                      question: _question.question,
                      dayKey: _question.dayKey,
                      name: panda ? 'Pippa' : 'Kebo',
                      assetPath: assetPath,
                    ),
                    const SizedBox(height: 12),
                    _DailyQuestionConversation(
                      comments: _comments,
                      currentUserId: _store.currentUserId,
                      controller: _commentController,
                      isSending: _isSending,
                      onSend: _sendComment,
                      onDelete: _confirmDelete,
                    ),
                    const SizedBox(height: 12),
                    PanGlassCard(
                      accentColor: scheme.secondary,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.schedule_rounded, color: scheme.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A new question appears every morning at 6:00 AM. Your shared answers stay together with today\'s question.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionHero extends StatelessWidget {
  const _QuestionHero({
    required this.question,
    required this.dayKey,
    required this.name,
    required this.assetPath,
  });

  final String question;
  final String dayKey;
  final String name;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2A3E) : const Color(0xFFFFF0A8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: .72),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? .24 : .1),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFFFA84F)),
                const SizedBox(width: 8),
                Text(
                  'TODAY\'S QUESTION',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                ),
                const Spacer(),
                Text(
                  dayKey,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 104,
                  height: 128,
                  child: PetdexMood(
                    name: name,
                    assetPath: assetPath,
                    mood: 'calm',
                    size: 82,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A small question for a meaningful conversation.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: .04, end: 0);
  }
}

class _DailyQuestionConversation extends StatelessWidget {
  const _DailyQuestionConversation({
    required this.comments,
    required this.currentUserId,
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onDelete,
  });

  final Stream<List<DailyQuestionComment>> comments;
  final String? currentUserId;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<DailyQuestionComment> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PanGlassCard(
      accentColor: const Color(0xFFFFC857),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, color: scheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Our answers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                'Shared today',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<DailyQuestionComment>>(
            stream: comments,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ConversationNotice(
                  icon: Icons.cloud_off_rounded,
                  message: 'Answers could not load right now.',
                  color: scheme.error,
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return _ConversationNotice(
                  icon: Icons.chat_bubble_outline_rounded,
                  message: 'Be the first to answer today\'s question.',
                  color: scheme.secondary,
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _DailyQuestionCommentTile(
                      comment: items[index],
                      canDelete: items[index].userId == currentUserId,
                      onDelete: () => onDelete(items[index]),
                    ),
                    if (index != items.length - 1)
                      Divider(
                        height: 22,
                        color: scheme.outlineVariant.withValues(alpha: .7),
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Divider(color: scheme.outlineVariant.withValues(alpha: .7)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 600,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write your answer...',
                    prefixIcon: Icon(Icons.edit_rounded),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final canSend = value.text.trim().isNotEmpty && !isSending;
                  return IconButton.filled(
                    tooltip: 'Send answer',
                    onPressed: canSend ? onSend : null,
                    icon: isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyQuestionCommentTile extends StatelessWidget {
  const _DailyQuestionCommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final DailyQuestionComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPanda = comment.mascot == AccountMascot.panda;
    final assetPath = isPanda
        ? 'assets/pets/pippa/spritesheet.webp'
        : 'assets/pets/kebo/spritesheet.webp';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Center(child: PetdexFace(assetPath: assetPath, size: 34)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCommentTime(comment.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Delete answer',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    ),
                  ],
                ],
              ),
              Text(
                comment.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationNotice extends StatelessWidget {
  const _ConversationNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCommentTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

class _QuestionAvatar extends StatelessWidget {
  const _QuestionAvatar({required this.assetPath, required this.accentColor});

  final String assetPath;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: PetdexFace(assetPath: assetPath, size: 42),
    );
  }
}
