import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/local_account_store.dart';
import '../../domain/heart_particle.dart';
import '../../domain/magnetic_heart_models.dart';
import '../controllers/magnetic_heart_controller.dart';
import '../painters/magnetic_heart_painter.dart';

class MagneticHeartsScreen extends StatefulWidget {
  const MagneticHeartsScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<MagneticHeartsScreen> createState() => _MagneticHeartsScreenState();
}

class _MagneticHeartsScreenState extends State<MagneticHeartsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _shareChannel = MethodChannel('panpanskii/share');

  late final MagneticHeartController _controller;
  late final Ticker _ticker;
  final _roomCodeController = TextEditingController();
  final _captureKey = GlobalKey();
  final _particles = HeartParticleField.generate();
  bool _isSaving = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MagneticHeartController(account: widget.account);
    _ticker = createTicker(_controller.tick)..start();
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.setAppActive(false));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_controller.setAppActive(true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _roomCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (_isLeaving) return;
    final room = _controller.state.room;
    if (room?.isActive == true) {
      final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Leave Magnetic Hearts?'),
              content: const Text(
                'This will close the active room for both players.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Leave room'),
                ),
              ],
            ),
          ) ??
          false;
      if (!leave || !mounted) return;
    }

    _isLeaving = true;
    await _controller.leaveRoom();
    if (mounted) context.go('/');
  }

  Future<void> _copyRoomCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room code $code copied.')),
    );
  }

  Future<void> _shareRoomCode(String code) async {
    final message =
        'Join my Magnetic Hearts room in Panpanskii. Room code: $code';
    try {
      await _shareChannel.invokeMethod<void>('shareText', {'text': message});
    } catch (_) {
      await _copyRoomCode(code);
    }
  }

  Future<void> _saveMemory() async {
    if (_isSaving || !_controller.state.isCompleted) return;
    setState(() => _isSaving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _captureKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary ||
          !renderObject.hasSize ||
          renderObject.size.isEmpty) {
        throw StateError('The heart memory is not ready yet.');
      }
      final image = await renderObject.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The heart memory could not be prepared.');
      }
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) throw StateError('Gallery permission was not granted.');
      }
      await Gal.putImageBytes(
        bytes,
        album: 'Panpanskii',
        name: 'magnetic-hearts-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magnetic Hearts memory saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090B13),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF090B13),
                Color(0xFF16101D),
                Color(0xFF080A10),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.state;
                return Column(
                  children: [
                    _MagneticHeader(onBack: _handleBack),
                    if (state.errorMessage != null)
                      _ErrorBanner(
                        message: state.errorMessage!,
                        onClose: _controller.clearError,
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _buildStage(state),
                      ),
                    ),
                    if (state.isBusy)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: MagneticHeartPainter.pink,
                        backgroundColor: Colors.transparent,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(MagneticHeartGameState state) {
    final room = state.room;
    if (room == null) {
      return _EntryLobby(
        key: const ValueKey('magnetic-entry'),
        codeController: _roomCodeController,
        state: state,
        particles: _particles,
        onCreate: _controller.createRoom,
        onJoin: () => _controller.joinRoom(_roomCodeController.text),
      );
    }
    if (room.status == MagneticHeartRoomStatus.playing || room.isCompleted) {
      return _GameStage(
        key: ValueKey('magnetic-game-${room.id}'),
        controller: _controller,
        state: state,
        particles: _particles,
        captureKey: _captureKey,
        isSaving: _isSaving,
        onSave: _saveMemory,
        onBack: _handleBack,
      );
    }
    return _RoomLobby(
      key: ValueKey('magnetic-room-${room.id}'),
      controller: _controller,
      state: state,
      particles: _particles,
      onCopyCode: () => _copyRoomCode(room.roomCode),
      onShareCode: () => _shareRoomCode(room.roomCode),
    );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
  }
}

class _MagneticHeader extends StatelessWidget {
  const _MagneticHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Back home',
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.09),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  MagneticHeartPainter.blue,
                  MagneticHeartPainter.pink,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: MagneticHeartPainter.pink.withValues(alpha: 0.24),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Magnetic Hearts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  'Bring your hearts together in real time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryLobby extends StatelessWidget {
  const _EntryLobby({
    super.key,
    required this.codeController,
    required this.state,
    required this.particles,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController codeController;
  final MagneticHeartGameState state;
  final List<HeartParticle> particles;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: MagneticHeartPainter(
                  state: state,
                  particles: particles,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'One heart needs the other.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a private room or enter the code from your person.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: state.isBusy ? null : onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: MagneticHeartPainter.pink,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create room'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .12))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(color: Colors.white38)),
              ),
              Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .12))),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: codeController,
            enabled: !state.isBusy,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
              _UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: 'LOVE82',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: .22),
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .06),
              prefixIcon: const Icon(
                Icons.key_rounded,
                color: MagneticHeartPainter.blue,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: .14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: MagneticHeartPainter.blue,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => onJoin(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : onJoin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .24)),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Join room'),
          ),
        ],
      ),
    );
  }
}

class _RoomLobby extends StatelessWidget {
  const _RoomLobby({
    super.key,
    required this.controller,
    required this.state,
    required this.particles,
    required this.onCopyCode,
    required this.onShareCode,
  });

  final MagneticHeartController controller;
  final MagneticHeartGameState state;
  final List<HeartParticle> particles;
  final VoidCallback onCopyCode;
  final VoidCallback onShareCode;

  @override
  Widget build(BuildContext context) {
    final room = state.room!;
    final countdown = state.countdownValue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      child: Column(
        children: [
          _RoomCodeBar(
            code: room.roomCode,
            onCopy: onCopyCode,
            onShare: onShareCode,
          ),
          const SizedBox(height: 10),
          _PlayerRow(state: state),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: MagneticHeartPainter(
                      state: state,
                      particles: particles,
                    ),
                  ),
                  if (room.status == MagneticHeartRoomStatus.countdown)
                    _CountdownOverlay(value: countdown ?? 3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _lobbyMessage(state),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (room.status == MagneticHeartRoomStatus.waiting ||
              room.status == MagneticHeartRoomStatus.ready)
            FilledButton.icon(
              onPressed:
                  state.bothPlayersJoined && state.bothOnline && !state.isBusy
                      ? controller.toggleReady
                      : null,
              style: FilledButton.styleFrom(
                backgroundColor: state.localMember?.isReady == true
                    ? const Color(0xFF3E9B76)
                    : MagneticHeartPainter.pink,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                state.localMember?.isReady == true
                    ? Icons.check_circle_rounded
                    : Icons.favorite_rounded,
              ),
              label: Text(
                state.localMember?.isReady == true ? 'Ready' : "I'm ready",
              ),
            ),
        ],
      ),
    );
  }

  String _lobbyMessage(MagneticHeartGameState state) {
    if (state.room?.status == MagneticHeartRoomStatus.countdown) {
      return 'Stay close. Your hearts are about to unlock.';
    }
    if (!state.bothPlayersJoined) return 'Waiting for your person to join...';
    if (!state.bothOnline) return 'Waiting for both phones to come online...';
    if (state.localMember?.isReady == true && !state.bothReady) {
      return 'You are ready. Waiting for your person...';
    }
    return 'Both players press Ready, then drag together.';
  }
}

class _GameStage extends StatelessWidget {
  const _GameStage({
    super.key,
    required this.controller,
    required this.state,
    required this.particles,
    required this.captureKey,
    required this.isSaving,
    required this.onSave,
    required this.onBack,
  });

  final MagneticHeartController controller;
  final MagneticHeartGameState state;
  final List<HeartParticle> particles;
  final GlobalKey captureKey;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: Column(
        children: [
          _PlayerRow(state: state),
          const SizedBox(height: 8),
          Expanded(
            child: RepaintBoundary(
              key: captureKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    controller.setCanvasSize(size);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) =>
                          controller.startDrag(details.localPosition),
                      onPanUpdate: (details) =>
                          controller.updateDrag(details.localPosition),
                      onPanEnd: (_) => controller.endDrag(),
                      onPanCancel: controller.endDrag,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: MagneticHeartPainter(
                              state: state,
                              particles: particles,
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            right: 14,
                            child: _GameInstruction(state: state),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 16,
                            child: _ConnectionProgress(state: state),
                          ),
                          if (!state.bothOnline && !state.isCompleted)
                            const _WaitingOverlay(),
                          if (state.revealStarted) _RevealOverlay(state: state),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (state.isCompleted) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.isBusy ? null : controller.playAgain,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(128, 46),
                    backgroundColor: MagneticHeartPainter.pink,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Play again'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onSave,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(128, 46),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .25),
                    ),
                  ),
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Save memory'),
                ),
                TextButton.icon(
                  onPressed: onBack,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Home'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomCodeBar extends StatelessWidget {
  const _RoomCodeBar({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            const Icon(
              Icons.lock_rounded,
              size: 18,
              color: MagneticHeartPainter.blue,
            ),
            const SizedBox(width: 8),
            Text(
              'ROOM',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            Text(
              code,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Copy room code',
              onPressed: onCopy,
              color: Colors.white70,
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Share room code',
              onPressed: onShare,
              color: Colors.white70,
              icon: const Icon(Icons.share_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.state});

  final MagneticHeartGameState state;

  @override
  Widget build(BuildContext context) {
    MagneticHeartMember? host;
    MagneticHeartMember? guest;
    for (final member in state.members) {
      if (member.role == MagneticHeartRole.host) {
        host = member;
      } else {
        guest = member;
      }
    }
    return Row(
      children: [
        Expanded(
          child: _PlayerChip(
            member: host,
            online: host != null && state.onlineUserIds.contains(host.userId),
            isLocal: host?.userId == state.localUserId,
            color: MagneticHeartPainter.blue,
            waitingLabel: 'Blue player',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(Icons.favorite_rounded, color: Colors.white30, size: 16),
        ),
        Expanded(
          child: _PlayerChip(
            member: guest,
            online: guest != null && state.onlineUserIds.contains(guest.userId),
            isLocal: guest?.userId == state.localUserId,
            color: MagneticHeartPainter.pink,
            waitingLabel: 'Pink player',
          ),
        ),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.member,
    required this.online,
    required this.isLocal,
    required this.color,
    required this.waitingLabel,
  });

  final MagneticHeartMember? member;
  final bool online;
  final bool isLocal;
  final Color color;
  final String waitingLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    member?.mascot == 'koala'
                        ? Icons.nightlife_rounded
                        : Icons.pets_rounded,
                    color: color,
                    size: 17,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: online ? const Color(0xFF65D69C) : Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF11131A)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member == null
                        ? waitingLabel
                        : isLocal
                            ? 'You'
                            : member!.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    member == null
                        ? 'Waiting'
                        : member!.isReady
                            ? 'Ready'
                            : online
                                ? 'Online'
                                : 'Offline',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: member?.isReady == true
                              ? const Color(0xFF72DDA7)
                              : Colors.white54,
                          fontWeight: FontWeight.w800,
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

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: .4),
      child: Center(
        child: Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF17131F).withValues(alpha: .9),
            border: Border.all(color: MagneticHeartPainter.pink, width: 2),
            boxShadow: [
              BoxShadow(
                color: MagneticHeartPainter.pink.withValues(alpha: .3),
                blurRadius: 28,
              ),
            ],
          ),
          child: Text(
            value == 0 ? 'GO' : '$value',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: value == 0 ? 28 : 50,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ),
    );
  }
}

class _GameInstruction extends StatelessWidget {
  const _GameInstruction({required this.state});

  final MagneticHeartGameState state;

  @override
  Widget build(BuildContext context) {
    final text = state.isCompleted
        ? 'HEARTS CONNECTED'
        : state.connectionProgress > 0
            ? 'HOLD TOGETHER'
            : 'DRAG YOUR ${state.localMember?.nodeColor.name.toUpperCase() ?? ''} HEART';
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .32),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionProgress extends StatelessWidget {
  const _ConnectionProgress({required this.state});

  final MagneticHeartGameState state;

  @override
  Widget build(BuildContext context) {
    final percent = (state.connectionProgress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: MagneticHeartPainter.pink,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: state.connectionProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: .1),
                  valueColor: const AlwaysStoppedAnimation(
                    MagneticHeartPainter.pink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
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

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: .56),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: MagneticHeartPainter.blue,
              ),
              const SizedBox(height: 16),
              Text(
                'Waiting for your person...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The heart will continue when both phones reconnect.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealOverlay extends StatelessWidget {
  const _RevealOverlay({required this.state});

  final MagneticHeartGameState state;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF080910).withValues(alpha: .36),
              const Color(0xFF080910).withValues(alpha: .78),
            ],
          ),
        ),
        child: Align(
          alignment: const Alignment(0, .62),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CONNECTED',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MagneticHeartPainter.gold,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.room?.revealMessage ??
                      'Two hearts, one little universe.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _coupleNames(state),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _coupleNames(MagneticHeartGameState state) {
    if (state.members.length != 2) return 'PANPANSKII';
    return '${state.members[0].username} + ${state.members[1].username}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF5B2634),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: MagneticHeartPainter.pink.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onClose,
            color: Colors.white70,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
