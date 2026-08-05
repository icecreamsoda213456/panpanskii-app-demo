import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../../widgets/app_update_dialog.dart';
import '../../../dates/data/couple_date_store.dart';
import '../../../auth/data/local_account_store.dart';
import '../../../bible/data/daily_bible_notification_service.dart';
import '../../../send_love/data/send_love_store.dart';
import '../widgets/home_action_button.dart';
import '../widgets/home_dashboard_cards.dart';
import '../widgets/home_ui_kit.dart';
import '../widgets/scene_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.account,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final LocalAccount account;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// The four shortcuts shown under "Quick Actions", in display order.
const _kQuickActionOrder = <_HomeShortcut>[
  _HomeShortcut.chat,
  _HomeShortcut.sendLove,
  _HomeShortcut.photoBooth,
  _HomeShortcut.journal,
];

/// The personal note typed out under the panda portrait. Kept as a top-level
/// constant so a test can assert the exact wording never changes.
@visibleForTesting
const String kHomePandaMessage =
    'You are my cutiepatottie majoyskii, my panda and my favorite person in every tiny universe we make together.';

/// The personal note typed out under the koala portrait.
@visibleForTesting
const String kHomeKoalaMessage =
    'You are my cutie patootie naughty chanchanskii, my clingy koala, my comfort person, and my favorite place to call home';

/// Exposes immutable dashboard route metadata to focused widget tests without
/// booting the whole screen (and with it Supabase).
@visibleForTesting
class HomeDashboardTestAccess {
  const HomeDashboardTestAccess._();

  /// Title to route for every "Today Together" card.
  static Map<String, String> get todayTogetherRoutes => {
        for (final item in _TodayTogetherSection._items) item.title: item.route,
      };

  /// Label to route for every "Quick Actions" tile.
  static Map<String, String> get quickActionRoutes => {
        for (final shortcut in _kQuickActionOrder)
          shortcut.label: shortcut.flaskPath,
      };

  /// Every label Home puts on screen, so a test can prove the "More" tab never
  /// repeats one of them.
  static Set<String> get homeLabels => {
        ...todayTogetherRoutes.keys,
        ...quickActionRoutes.keys,
      };
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const _pandaMessage = kHomePandaMessage;
  static const _koalaMessage = kHomeKoalaMessage;
  final _loveButtonKey = GlobalKey();
  final _sendLoveStore = SendLoveStore();
  final List<_LoveParticle> _particles = [];
  final math.Random _random = math.Random();

  late final AnimationController _cursorController;
  late final AnimationController _particleController;
  Timer? _typingTimer;
  String _typedMessage = '';
  int _particleSeed = 0;
  String get _message => widget.account.mascot == AccountMascot.koala
      ? _koalaMessage
      : _pandaMessage;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _particles.clear();
        }
      });
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.mascot == widget.account.mascot) return;
    _typingTimer?.cancel();
    _typedMessage = '';
    _startTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _startTyping() {
    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 42), (timer) {
      if (!mounted || index >= _message.length) {
        timer.cancel();
        return;
      }
      setState(() => _typedMessage = _message.substring(0, index + 1));
      index += 1;
    });
  }

  Future<void> _sendLove() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SendLoveSheet(
        account: widget.account,
        store: _sendLoveStore,
        onSent: (sentLove) {
          _burstLoveParticles();
          DailyBibleNotificationService.showSendLoveNotification(
            username: widget.account.username,
            hasAttachment: sentLove.attachmentPath != null,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Love sent. The garden felt it.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1400),
            ),
          );
        },
      ),
    );
  }

  void _burstLoveParticles() {
    final renderBox =
        _loveButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);
    final origin = renderBox == null
        ? Offset(screenSize.width / 2, screenSize.height / 2)
        : renderBox.localToGlobal(renderBox.size.center(Offset.zero));

    final generated = <_LoveParticle>[];
    for (var index = 0; index < 18; index += 1) {
      final angle = (math.pi * 2 * index) / 18;
      final distance = 48 + _random.nextDouble() * 72;
      generated.add(
        _LoveParticle(
          origin: origin,
          drift: Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance - 36,
          ),
          color: index % 3 == 0
              ? const Color(0xFFFFD45A)
              : const Color(0xFFFF7A9A),
          size: 11 + _random.nextDouble() * 5,
          sparkle: false,
        ),
      );
    }
    for (var index = 0; index < 10; index += 1) {
      final angle = _random.nextDouble() * math.pi * 2;
      final distance = 28 + _random.nextDouble() * 80;
      generated.add(
        _LoveParticle(
          origin: origin,
          drift: Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance - 24,
          ),
          color: const Color(0xFFFFF7A8),
          size: 7 + _random.nextDouble() * 5,
          sparkle: true,
        ),
      );
    }

    setState(() {
      _particleSeed += 1;
      _particles
        ..clear()
        ..addAll(generated);
    });
    _particleController.forward(from: 0);
  }

  void _selectNextScreen(_HomeShortcut shortcut) {
    context.go(shortcut.flaskPath);
  }

  @override
  Widget build(BuildContext context) {
    AppUpdateCoordinator.scheduleAutomaticCheck(context);
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final isMobile = size.width <= 520;
    final pagePadding = isMobile ? 12.0 : 24.0;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.54, 1],
                colors: widget.isDarkMode
                    ? [
                        scheme.surface,
                        scheme.surfaceContainerHighest,
                        scheme.primaryContainer.withValues(alpha: 0.7),
                      ]
                    : [
                        scheme.surface,
                        scheme.surfaceContainerHighest,
                        scheme.secondaryContainer.withValues(alpha: 0.72),
                      ],
              ),
            ),
          ),
          Positioned(
            left: -112,
            top: -96,
            child: SkyGlow(
              size: 352,
              color: widget.isDarkMode ? scheme.tertiary : scheme.primary,
            ),
          ),
          Positioned(
            right: -64,
            bottom: size.height * 0.1,
            child: SkyGlow(
              size: 288,
              color: widget.isDarkMode ? scheme.primary : scheme.tertiary,
            ),
          ),
          Positioned(
            right: isMobile ? -14 : 24,
            top: isMobile ? 72 : 90,
            child: IgnorePointer(
              child: Opacity(
                opacity: widget.isDarkMode ? 0.34 : 0.52,
                child: Lottie.asset(
                  'assets/animations/soft_sparkles.json',
                  width: isMobile ? 128 : 176,
                  repeat: true,
                ),
              ),
            ),
          ),
          const PetalLayer(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pagePadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.paddingOf(context).vertical -
                      pagePadding * 2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildHeroPanel(context),
                  ),
                ),
              ),
            ),
          ),
          ..._buildLoveParticles(),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 520;
    const actions = _kQuickActionOrder;

    final sectionGap = compact ? 20.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeTopBar(
          compact: compact,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
        SizedBox(height: compact ? 10 : 14),
        _PixelHeroTitle(compact: compact, isDarkMode: widget.isDarkMode),
        SizedBox(height: compact ? 12 : 14),
        _HomeConnectionCard(
          compact: compact,
          typedMessage: _typedMessage,
          cursorController: _cursorController,
          isDarkMode: widget.isDarkMode,
        ),
        SizedBox(height: sectionGap),
        _HomeSection(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeSectionHeader(
                title: 'Today Together',
                icon: Icons.wb_twilight_outlined,
              ),
              SizedBox(height: compact ? 10 : 12),
              const _TodayTogetherSection(),
            ],
          ),
        ),
        SizedBox(height: sectionGap),
        _HomeSection(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeSectionHeader(
                title: 'Quick Actions',
                icon: Icons.bolt_rounded,
              ),
              SizedBox(height: compact ? 10 : 12),
              _buildActionTray(actions, compact),
            ],
          ),
        ),
        SizedBox(height: sectionGap),
        _HomeSection(index: 2, child: const _NextSharedActivitySection()),
        SizedBox(height: sectionGap),
        // Everything else lives in the "More" tab, so Home never repeats it.
        _HomeSection(index: 3, child: _ExploreMoreHint(compact: compact)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActionTray(List<_HomeShortcut> shortcuts, bool compact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeGridColumns(
          context: context,
          width: constraints.maxWidth,
          minTileWidth: 150,
          maxColumns: compact ? 2 : 4,
        );

        return HomeCardGrid(
          columns: columns,
          spacing: compact ? 10 : 12,
          tileHeight: QuickActionCard.heightFor(context),
          children: [
            for (var index = 0; index < shortcuts.length; index += 1)
              KeyedSubtree(
                key: shortcuts[index] == _HomeShortcut.sendLove
                    ? _loveButtonKey
                    : null,
                child: QuickActionCard(
                  label: shortcuts[index].label,
                  glyph: shortcuts[index].glyph,
                  gradient: shortcuts[index].gradient,
                  textColor: shortcuts[index].textColor,
                  shadowColor: shortcuts[index].shadowColor,
                  onPressed: shortcuts[index] == _HomeShortcut.sendLove
                      ? _sendLove
                      : () => _selectNextScreen(shortcuts[index]),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildLoveParticles() {
    if (_particles.isEmpty) {
      return const [];
    }
    // Keep the animation frame stable while the completion callback clears
    // the live particle list.
    final particles = List<_LoveParticle>.of(_particles);
    return [
      for (var index = 0; index < particles.length; index += 1)
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            final progress = Curves.easeOut.transform(
              _particleController.value,
            );
            return Positioned(
              key: ValueKey('$_particleSeed-$index'),
              left: particles[index].origin.dx +
                  (particles[index].drift.dx * progress),
              top: particles[index].origin.dy +
                  (particles[index].drift.dy * progress),
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: particles[index].sparkle
                        ? 0.15 + (1.75 * progress)
                        : 0.25 + (0.85 * math.sin(progress * math.pi)),
                    child: particles[index].sparkle
                        ? _Sparkle(
                            size: particles[index].size,
                            color: particles[index].color,
                          )
                        : _Heart(
                            size: particles[index].size,
                            color: particles[index].color,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _SendLoveSheet extends StatefulWidget {
  const _SendLoveSheet({
    required this.account,
    required this.store,
    required this.onSent,
  });

  final LocalAccount account;
  final SendLoveStore store;
  final ValueChanged<SentLove> onSent;

  @override
  State<_SendLoveSheet> createState() => _SendLoveSheetState();
}

class _SendLoveSheetState extends State<_SendLoveSheet> {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _isSending = false;
  bool _isClosing = false;
  String? _error;
  SentLove? _sentLove;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _messageController.text.trim().isNotEmpty || _pickedImageBytes != null;

  Future<void> _handleClose() async {
    if (_isClosing || _isSending) {
      return;
    }
    if (!_hasDraft || _sentLove != null) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this love note?'),
        content: const Text(
          'You have an unfinished message. Your note will be cleared if you leave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep writing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _isClosing = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Write a little message first.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final sentLove = await widget.store.sendLove(
        account: widget.account,
        message: message,
        attachmentBytes: _pickedImageBytes,
        attachmentName: _pickedImage?.name,
        attachmentContentType: _pickedImage?.mimeType,
      );
      if (!mounted) {
        return;
      }
      setState(() => _sentLove = sentLove);
      widget.onSent(sentLove);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlySendLoveError(error));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Hindi ma-open ang gallery. Try again.');
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
    });
  }

  String _friendlySendLoveError(Object error) {
    final text = error.toString();
    if (text.contains('send_love_letters')) {
      return 'Supabase table is missing. Run the SQL first.';
    }
    if (text.contains('send-love-attachments') ||
        text.contains('storage') ||
        text.contains('bucket')) {
      return 'Supabase Storage is missing. Run the updated SQL first.';
    }
    if (text.contains('row-level security') || text.contains('policy')) {
      return 'Supabase policy blocked this. Check the SQL policies.';
    }
    return 'Hindi na-send. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom + 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      scheme.surface,
                      scheme.surfaceContainerHighest,
                      scheme.primaryContainer.withValues(alpha: 0.72),
                    ]
                  : [
                      scheme.surface,
                      scheme.surfaceContainerHighest,
                      scheme.primaryContainer.withValues(alpha: 0.5),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.34),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.25),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MascotMark(mascot: widget.account.mascot),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Love',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    fontSize: 22,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.account.username} as ${widget.account.mascot.label}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _handleClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LoveAudienceBanner(mascot: widget.account.mascot),
                  const SizedBox(height: 14),
                  if (_sentLove == null) ...[
                    TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      minLines: 5,
                      maxLines: 8,
                      maxLength: 600,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write something from the heart...',
                        hintStyle: TextStyle(
                          color:
                              scheme.onSurfaceVariant.withValues(alpha: 0.72),
                        ),
                        filled: true,
                        fillColor: scheme.surface.withValues(alpha: 0.82),
                        counterStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AttachmentPicker(
                      bytes: _pickedImageBytes,
                      fileName: _pickedImage?.name,
                      onPickImage: _isSending ? null : _pickImage,
                      onRemoveImage: _isSending ? null : _removeImage,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _SendLoveError(
                        message: _error!,
                        onRetry: _isSending ? null : _submit,
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed:
                          _isSending || _messageController.text.trim().isEmpty
                              ? null
                              : _submit,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isSending
                            ? const SizedBox.square(
                                key: ValueKey('sending'),
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.favorite_rounded,
                                key: ValueKey('send'),
                              ),
                      ),
                      label: Text(_isSending ? 'Sending...' : 'Send love'),
                    ),
                  ] else ...[
                    _SentLoveCard(sentLove: _sentLove!),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _handleClose,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done'),
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

class _LoveAudienceBanner extends StatelessWidget {
  const _LoveAudienceBanner({required this.mascot});

  final AccountMascot mascot;

  @override
  Widget build(BuildContext context) {
    final accent = mascot == AccountMascot.panda
        ? const Color(0xFFFFD166)
        : const Color(0xFF9AD9B8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _MascotMark(mascot: mascot),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Shared with both Panpanskii users',
                style: TextStyle(
                  color: Color(0xFFF7F4EE),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.public_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SentLoveCard extends StatelessWidget {
  const _SentLoveCard({required this.sentLove});

  final SentLove sentLove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD45A).withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MascotMark(mascot: sentLove.mascot),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sentLove.username,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFFFFF4EA),
                              fontSize: 18,
                            ),
                      ),
                      Text(
                        '${sentLove.mascot.label} - ${_formatSentLoveDate(sentLove.createdAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFCFC3E8),
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
              sentLove.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFFFF4EA),
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (sentLove.attachmentUrl != null) ...[
              const SizedBox(height: 14),
              _TappableNetworkImage(
                imageUrl: sentLove.attachmentUrl!,
                heroTag: 'sent-love-${sentLove.id}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentPicker extends StatelessWidget {
  const _AttachmentPicker({
    required this.bytes,
    required this.fileName,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final Uint8List? bytes;
  final String? fileName;
  final VoidCallback? onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final imageBytes = bytes;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6E628F).withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: imageBytes == null
            ? OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.image_rounded),
                label: const Text('Attach picture'),
              )
            : Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF050714).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${fileName ?? 'Attached picture'} - ${_formatAttachmentSize(imageBytes.length)}',
                      style: const TextStyle(
                        color: Color(0xFFB7BBC5),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickImage,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Change'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Remove picture',
                        onPressed: onRemoveImage,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _TappableNetworkImage extends StatelessWidget {
  const _TappableNetworkImage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              _ImageViewerScreen(imageUrl: imageUrl, heroTag: heroTag),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050714).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF6E628F).withValues(alpha: 0.42),
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

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050714),
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

class _MascotMark extends StatelessWidget {
  const _MascotMark({required this.mascot});

  final AccountMascot mascot;

  @override
  Widget build(BuildContext context) {
    final isPanda = mascot == AccountMascot.panda;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPanda ? const Color(0xFFFFF4EA) : const Color(0xFFD8D2C8),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFFD45A).withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 52,
        child: PetdexFace(
          assetPath: isPanda
              ? 'assets/pets/pippa/spritesheet.webp'
              : 'assets/pets/kebo/spritesheet.webp',
          size: 52,
        ),
      ),
    );
  }
}

class _SendLoveError extends StatelessWidget {
  const _SendLoveError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB4AB).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB4AB)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFFFDAD6),
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatAttachmentSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(0)} KB';
  }
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}

String _formatSentLoveDate(DateTime date) {
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

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD45A).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFD45A).withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          'skii space',
          style: TextStyle(
            color: Color(0xFFFFE6A6),
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.compact,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool compact;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Badge(),
        const Spacer(),
        Tooltip(
          message: isDarkMode ? 'Light mode' : 'Dark mode',
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFFFFE6A6),
            ),
            onPressed: onToggleTheme,
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeConnectionCard extends StatelessWidget {
  const _HomeConnectionCard({
    required this.compact,
    required this.typedMessage,
    required this.cursorController,
    required this.isDarkMode,
  });

  final bool compact;
  final String typedMessage;
  final AnimationController cursorController;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connector =
        isDarkMode ? const Color(0xFFFFD166) : const Color(0xFFC98724);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1B1F26).withValues(alpha: 0.96)
            : scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connector.withValues(alpha: isDarkMode ? 0.24 : 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: compact ? 68 : 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: compact ? 44 : 52,
                  right: compact ? 44 : 52,
                  top: compact ? 33 : 38,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF7888).withValues(alpha: 0.46),
                          connector.withValues(alpha: 0.68),
                          const Color(0xFFB8AEFF).withValues(alpha: 0.46),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: connector.withValues(alpha: 0.16),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _MascotPortrait(
                      label: 'Pippa the panda',
                      assetPath: 'assets/pets/pippa/spritesheet.webp',
                      accent: const Color(0xFFFF7888),
                      size: compact ? 56 : 64,
                      animationRow: 2,
                      animationDuration: const Duration(milliseconds: 980),
                      floatDuration: const Duration(milliseconds: 1900),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 9 : 12,
                            vertical: compact ? 7 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF111318)
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: connector.withValues(alpha: 0.48),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: compact ? 14 : 16,
                                color: const Color(0xFFFF7888),
                              )
                                  .animate(
                                    onPlay: (controller) =>
                                        controller.repeat(reverse: true),
                                  )
                                  .scale(
                                    begin: const Offset(0.92, 0.92),
                                    end: const Offset(1.08, 1.08),
                                    duration: 1100.ms,
                                    curve: Curves.easeInOut,
                                  ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'PANDA + KOALA',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: connector,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                ),
                              ),
                              Text(
                                'our little universe',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: compact ? 9 : 10,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _MascotPortrait(
                      label: 'Kebo the koala',
                      assetPath: 'assets/pets/kebo/spritesheet.webp',
                      accent: const Color(0xFFB8AEFF),
                      size: compact ? 56 : 64,
                      animationRow: 2,
                      animationDuration: const Duration(milliseconds: 1040),
                      floatDuration: const Duration(milliseconds: 2150),
                      floatDelay: const Duration(milliseconds: 240),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.42),
          ),
          SizedBox(height: compact ? 9 : 11),
          _RetroTerminalMessage(
            compact: compact,
            bodySize: compact ? 13.5 : 15,
            typedMessage: typedMessage,
            cursorController: cursorController,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}

class _MascotPortrait extends StatefulWidget {
  const _MascotPortrait({
    required this.label,
    required this.assetPath,
    required this.accent,
    required this.size,
    required this.animationRow,
    required this.animationDuration,
    required this.floatDuration,
    this.floatDelay = Duration.zero,
  });

  final String label;
  final String assetPath;
  final Color accent;
  final double size;
  final int animationRow;
  final Duration animationDuration;
  final Duration floatDuration;
  final Duration floatDelay;

  @override
  State<_MascotPortrait> createState() => _MascotPortraitState();
}

class _MascotPortraitState extends State<_MascotPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;
  late final Animation<double> _heartOpacity;
  late final Animation<Offset> _heartOffset;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.92), weight: 24),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.08), weight: 34),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 42),
    ]).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 42),
    ]).animate(_tapController);
    _heartOffset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: const Offset(0, -0.42),
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}, tap for a little hello',
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapController.forward(from: 0),
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: _tapScale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF23272F),
                      border: Border.all(color: widget.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedPetdexFace(
                      assetPath: widget.assetPath,
                      size: widget.size - 6,
                      row: widget.animationRow,
                      duration: widget.animationDuration,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _heartOpacity,
                      child: SlideTransition(
                        position: _heartOffset,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: widget.size * 0.24,
                          color: widget.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(
          delay: widget.floatDelay,
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .moveY(
          begin: 1.5,
          end: -1.5,
          duration: widget.floatDuration,
          curve: Curves.easeInOut,
        );
  }
}

class _PixelHeroTitle extends StatelessWidget {
  const _PixelHeroTitle({
    required this.compact,
    required this.isDarkMode,
  });

  final bool compact;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFF7888),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF06F93).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.favorite_rounded,
            size: compact ? 21 : 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panpanskii Home',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDarkMode
                          ? const Color(0xFFFFF4EA)
                          : scheme.onSurface,
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                'Hi my panpanskii, this Mobile app is for you only.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: compact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RetroTerminalMessage extends StatelessWidget {
  const _RetroTerminalMessage({
    required this.compact,
    required this.bodySize,
    required this.typedMessage,
    required this.cursorController,
    required this.isDarkMode,
  });

  final bool compact;
  final double bodySize;
  final String typedMessage;
  final AnimationController cursorController;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (isDarkMode ? const Color(0xFF8972A9) : const Color(0xFF6E628F))
                  .withValues(alpha: 0.62),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 66 : 72),
          child: AnimatedBuilder(
            animation: cursorController,
            builder: (context, child) {
              return RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: bodySize,
                        height: 1.45,
                        color: const Color(0xFFE7D7FF),
                      ),
                  children: [
                    TextSpan(text: '> $typedMessage'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Opacity(
                        opacity: cursorController.value < 0.5 ? 1 : 0,
                        child: Container(
                          width: 7,
                          height: 16,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF06F93),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
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

/// Fades each dashboard section in with a small stagger so the screen settles
/// instead of appearing all at once.
///
/// It owns its controller and only ever plays once, so a live rebuild (the
/// typing message, or a `StreamBuilder` delivering new plans) never restarts
/// the entrance.
class _HomeSection extends StatefulWidget {
  const _HomeSection({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<_HomeSection>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 300);

  late final AnimationController _controller;
  late final Animation<double> _curve;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _startTimer = Timer(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _startTimer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// A single pointer to the "More" tab.
///
/// Home used to mirror the whole "More" list here, which meant Love Letters,
/// Mood Status, Daily Question and friends each rendered twice in the app. Home
/// now owns "Today Together", "Quick Actions" and "Next Together"; everything
/// else is reached through this one card.
class _ExploreMoreHint extends StatelessWidget {
  const _ExploreMoreHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFB8AEFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Explore Our Space',
          icon: Icons.grid_view_rounded,
        ),
        SizedBox(height: compact ? 10 : 12),
        Semantics(
          button: true,
          label: 'Explore our space. Open the More tab',
          onTap: () => context.go('/more'),
          child: ExcludeSemantics(
            child: HomePressable(
              onTap: () => context.go('/more'),
              child: Ink(
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.48)
                      : scheme.surface.withValues(alpha: 0.86),
                  borderRadius: kHomeCardBorderRadius,
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.28 : 0.32),
                  ),
                ),
                child: Padding(
                  padding: kHomeCardPadding,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.16 : 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Everything else',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Letters, dates, thoughts and more live in the More tab',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.65),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFFD45A).withValues(alpha: 0.85),
            blurRadius: 16,
          ),
        ],
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _LoveParticle {
  const _LoveParticle({
    required this.origin,
    required this.drift,
    required this.color,
    required this.size,
    required this.sparkle,
  });

  final Offset origin;
  final Offset drift;
  final Color color;
  final double size;
  final bool sparkle;
}

class _TodayTogetherSection extends StatelessWidget {
  const _TodayTogetherSection();

  static const _items = <_TodayTogetherItem>[
    _TodayTogetherItem(
      title: 'Magnetic Hearts',
      subtitle: 'Bring your hearts together',
      route: '/magnetic-hearts',
      icon: Icons.join_inner_rounded,
      accent: Color(0xFFFF79AE),
    ),
    _TodayTogetherItem(
      title: 'Daily Duo',
      subtitle: "Open today's round",
      route: '/panpans-home',
      icon: Icons.favorite_outline_rounded,
      accent: Color(0xFFF39AB4),
    ),
    _TodayTogetherItem(
      title: 'Cozy Garden',
      subtitle: 'Visit the shared garden',
      route: '/cozy-garden',
      icon: Icons.local_florist_outlined,
      accent: Color(0xFF8FC9A3),
    ),
    _TodayTogetherItem(
      title: 'Daily Question',
      subtitle: "Open today's prompt",
      route: '/daily-question',
      icon: Icons.chat_bubble_outline_rounded,
      accent: Color(0xFFF0BF69),
    ),
    _TodayTogetherItem(
      title: 'Mood Status',
      subtitle: "See today's check-in",
      route: '/mood-status',
      icon: Icons.sentiment_satisfied_alt_rounded,
      accent: Color(0xFF91B8E8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeGridColumns(
          context: context,
          width: constraints.maxWidth,
          minTileWidth: 150,
          maxColumns: 2,
        );
        // Side by side the tiles are too narrow for the wide row form, so they
        // stack the icon above the label instead. The odd fifth tile then keeps
        // the same stacked shape while spanning the final row.
        final stacked = columns > 1;

        return HomeCardGrid(
          columns: columns,
          tileHeight: TodayTogetherCard.heightFor(context, stacked: stacked),
          stretchLastRow: true,
          children: [
            for (final item in _items)
              TodayTogetherCard(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                accent: item.accent,
                stacked: stacked,
                onTap: () => context.push(item.route),
              ),
          ],
        );
      },
    );
  }
}

class _TodayTogetherItem {
  const _TodayTogetherItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color accent;
}

class _NextSharedActivitySection extends StatefulWidget {
  const _NextSharedActivitySection();

  @override
  State<_NextSharedActivitySection> createState() =>
      _NextSharedActivitySectionState();
}

class _NextSharedActivitySectionState
    extends State<_NextSharedActivitySection> {
  late final Stream<List<CoupleDatePlan>> _plansStream;

  @override
  void initState() {
    super.initState();
    _plansStream = CoupleDateStore().watchPlans();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoupleDatePlan>>(
      stream: _plansStream,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final upcoming = (snapshot.data ?? const <CoupleDatePlan>[])
            .where((plan) => plan.isShared && plan.startsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final nextPlan = upcoming.isEmpty ? null : upcoming.first;

        return _NextSharedActivityTile(plan: nextPlan);
      },
    );
  }
}

class _NextSharedActivityTile extends StatelessWidget {
  const _NextSharedActivityTile({required this.plan});

  final CoupleDatePlan? plan;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    final accent = currentPlan == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : const Color(0xFFF0BF69);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Next Together',
          icon: Icons.event_available_outlined,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: TodayTogetherCard.heightFor(context),
          child: TodayTogetherCard(
            title: currentPlan?.title ?? 'No upcoming shared plan',
            subtitle: currentPlan == null
                ? 'Open Our Dates'
                : '${currentPlan.category.label}  |  ${_formatNextActivityDate(currentPlan.startsAt)}',
            icon: currentPlan == null
                ? Icons.calendar_month_outlined
                : Icons.event_available_outlined,
            accent: accent,
            // Live calendar information, so it gets the tinted, outlined form.
            emphasized: true,
            onTap: () => context.push('/dates'),
          ),
        ),
      ],
    );
  }
}

String _formatNextActivityDate(DateTime value) {
  const months = <String>[
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
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, $hour:$minute $period';
}

/// The Quick Actions tray. Every other feature is reached from the "More" tab,
/// so this enum deliberately holds only the four shortcuts Home shows.
enum _HomeShortcut {
  chat(
    'Private Chat',
    '/private-chat',
    LinearGradient(colors: [Color(0xFFB8AEFF), Color(0xFFE5E1FF)]),
    Color(0xFF322A68),
    Color(0xFF8C82D4),
    HomeActionGlyph.chat,
    'private_chat_messages',
  ),
  sendLove(
    'Send Love',
    '/',
    LinearGradient(colors: [Color(0xFFFF7888), Color(0xFFFFA0A9)]),
    Colors.white,
    Color(0xFFF06F93),
    HomeActionGlyph.heart,
    'send_love_letters',
  ),
  photoBooth(
    'Photo Booth',
    '/photobooth',
    LinearGradient(colors: [Color(0xFF2C2734), Color(0xFF735B76)]),
    Colors.white,
    Color(0xFFB891B8),
    HomeActionGlyph.camera,
    null,
  ),
  journal(
    'Shared Journal',
    '/shared-journal',
    LinearGradient(colors: [Color(0xFFD7F1E1), Color(0xFF9AD9B8)]),
    Color(0xFF123427),
    Color(0xFF5B9C77),
    HomeActionGlyph.journal,
    'shared_journal_entries',
  );

  const _HomeShortcut(
    this.label,
    this.flaskPath,
    this.gradient,
    this.textColor,
    this.shadowColor,
    this.glyph,
    this.notificationKey,
  );

  final String label;
  final String flaskPath;
  final LinearGradient gradient;
  final Color textColor;
  final Color shadowColor;
  final HomeActionGlyph glyph;
  final String? notificationKey;
}
