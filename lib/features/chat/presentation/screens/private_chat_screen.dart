import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/private_chat_store.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _store = PrivateChatStore();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<List<PrivateChatMessage>> _messagesStream =
      _store.watchMessages();
  late final Stream<List<PrivateChatReaction>> _reactionsStream =
      _store.watchReactions();
  bool _isSending = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text;
    if (message.trim().isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _store.sendMessage(account: widget.account, message: message);
      _messageController.clear();
      _scrollToBottomSoon();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hindi na-send. Check Supabase SQL.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(account: widget.account),
            Expanded(
              child: StreamBuilder<List<PrivateChatMessage>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const PanLoadingState(
                      title: 'Loading chat',
                      message: 'Connecting your private conversation.',
                    );
                  }

                  if (snapshot.hasError) {
                    return const _ChatStateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Hindi ma-load ang chat',
                      message: 'Run the private chat SQL sa Supabase editor.',
                    );
                  }

                  final messages = snapshot.data ?? const [];
                  if (messages.isEmpty) {
                    return const _ChatStateMessage(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Start the chat',
                      message: 'Send your first message from this device.',
                    );
                  }

                  if (messages.length != _lastMessageCount) {
                    _lastMessageCount = messages.length;
                    _scrollToBottomSoon();
                  }
                  return StreamBuilder<List<PrivateChatReaction>>(
                    stream: _reactionsStream,
                    builder: (context, reactionSnapshot) {
                      final reactions = reactionSnapshot.data ??
                          const <PrivateChatReaction>[];
                      return ListView.separated(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                        itemCount: messages.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return RepaintBoundary(
                            child: _MessageBubble(
                              message: message,
                              reactions: reactions
                                  .where((item) => item.messageId == message.id)
                                  .toList(),
                              account: widget.account,
                              store: _store,
                            )
                                .animate(delay: (index.clamp(0, 6) * 28).ms)
                                .fadeIn(duration: 220.ms)
                                .slideY(begin: .035, end: 0),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.account});

  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: PanFeatureHeader(
        title: 'Private Chat',
        subtitle: '${account.username} - ${account.mascot.label}',
        leading: _MascotBadge(mascot: account.mascot, size: 46),
        trailing: const _LiveBadge(),
        accentColor: const Color(0xFF7CC2FF),
        onBack: () => context.go('/'),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF9BE0BC).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF9BE0BC).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 8, color: Color(0xFF9BE0BC)),
            const SizedBox(width: 6),
            Text(
              'Live',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.reactions,
    required this.account,
    required this.store,
  });

  final PrivateChatMessage message;
  final List<PrivateChatReaction> reactions;
  final LocalAccount account;
  final PrivateChatStore store;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final scheme = Theme.of(context).colorScheme;
    final accent = message.mascot == AccountMascot.panda
        ? const Color(0xFFFFC857)
        : const Color(0xFF72D6A0);
    final bubbleColor =
        isMine ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;

    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          _MascotBadge(mascot: message.mascot, size: 38),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    message.username,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              GestureDetector(
                onLongPress: () => _showReactionPicker(context),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 5),
                      bottomRight: Radius.circular(isMine ? 5 : 18),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: accent.withValues(alpha: .42)),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: .1),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.message,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w900,
                                    height: 1.28,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatChatTime(message.createdAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textColor.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (reactions.isNotEmpty) _ReactionSummary(reactions: reactions),
            ],
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 8),
          _MascotBadge(mascot: message.mascot, size: 38),
        ],
      ],
    );
  }

  Future<void> _showReactionPicker(BuildContext context) async {
    final selected = _myReaction?.reaction;
    final reaction = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A9A).withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.favorite_rounded,
                          color: Color(0xFFFF6F91)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send a little reaction',
                      style:
                          Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final option in _chatReactionOptions)
                    _CuteReactionOption(
                      option: option,
                      selected: selected == option.id,
                      onTap: () => Navigator.pop(sheetContext, option.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (reaction == null || !context.mounted) return;
    final current = _myReaction?.reaction;
    try {
      await store.toggleReaction(
        account: account,
        messageId: message.id,
        reaction: reaction,
        currentReaction: current,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hindi na-save ang reaction.')),
        );
      }
    }
  }

  PrivateChatReaction? get _myReaction {
    for (final reaction in reactions) {
      if (reaction.isMine) return reaction;
    }
    return null;
  }
}

class _ChatReactionOption {
  const _ChatReactionOption(
      {required this.id,
      required this.label,
      required this.icon,
      required this.color});

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const _chatReactionOptions = <_ChatReactionOption>[
  _ChatReactionOption(
      id: 'love',
      label: 'Love',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6F91)),
  _ChatReactionOption(
      id: 'like',
      label: 'Like',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF5C9DFF)),
  _ChatReactionOption(
      id: 'laugh',
      label: 'Laugh',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFFFFC857)),
  _ChatReactionOption(
      id: 'wow',
      label: 'Wow',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFB8AEFF)),
  _ChatReactionOption(
      id: 'sad',
      label: 'Sad',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF72D6A0)),
];

class _CuteReactionOption extends StatelessWidget {
  const _CuteReactionOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ChatReactionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? option.color.withValues(alpha: .2)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? option.color : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 26, color: option.color),
              const SizedBox(height: 6),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.reactions});

  final List<PrivateChatReaction> reactions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.reaction] = (counts[reaction.reaction] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final option in _chatReactionOptions)
            if ((counts[option.id] ?? 0) > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: option.color.withValues(alpha: .5)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(option.icon, size: 13, color: option.color),
                      const SizedBox(width: 3),
                      Text('${counts[option.id]}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .1),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                  fillColor: scheme.surfaceContainerHighest,
                  prefixIcon: const Icon(Icons.chat_bubble_rounded),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatStateMessage extends StatelessWidget {
  const _ChatStateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

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
            Icon(icon, color: scheme.primary, size: 46),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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

String _formatChatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
