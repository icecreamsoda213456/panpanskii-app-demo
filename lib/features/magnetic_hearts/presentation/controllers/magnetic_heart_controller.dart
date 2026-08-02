import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase.dart';
import '../../../auth/data/local_account_store.dart';
import '../../data/magnetic_heart_realtime_service.dart';
import '../../data/magnetic_heart_repository.dart';
import '../../domain/magnetic_heart_models.dart';
import '../../domain/magnetic_heart_rules.dart';

class MagneticHeartController extends ChangeNotifier {
  MagneticHeartController({
    required this.account,
    MagneticHeartRepository? repository,
  })  : repository = repository ?? MagneticHeartRepository(),
        _state = MagneticHeartGameState(
          localUserId: supabase.auth.currentUser?.id ?? '',
        );

  final LocalAccount account;
  final MagneticHeartRepository repository;

  MagneticHeartGameState _state;
  MagneticHeartGameState get state => _state;

  StreamSubscription<MagneticHeartRoom?>? _roomSubscription;
  StreamSubscription<List<MagneticHeartMember>>? _memberSubscription;
  MagneticHeartRealtimeService? _realtime;
  Timer? _reconnectTimer;
  Size _canvasSize = Size.zero;
  Duration? _lastTick;
  DateTime _lastMovementSent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNodePersisted = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBeginAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;
  bool _membersHydrated = false;
  bool _readyInFlight = false;
  bool _beginInFlight = false;
  bool _completionInFlight = false;
  bool _refreshInFlight = false;
  bool _hapticPlayed = false;
  bool _progressHapticPlayed = false;

  Future<void> initialize() async {
    if (_state.localUserId.isEmpty) {
      _setError('Your session expired. Please sign in again.');
      return;
    }
    _update(_state.copyWith(isBusy: true, clearError: true));
    try {
      final room = await repository.loadCurrentRoom();
      if (room == null) {
        _update(_state.copyWith(isBusy: false));
        return;
      }
      await _bindRoom(room);
    } catch (error) {
      _update(
        _state.copyWith(
          isBusy: false,
          errorMessage: _cleanError(error),
        ),
      );
    }
  }

  Future<void> createRoom() async {
    if (_state.isBusy) return;
    _update(_state.copyWith(isBusy: true, clearError: true));
    try {
      final room = await repository.createRoom(account);
      await _bindRoom(room);
    } catch (error) {
      _update(
        _state.copyWith(
          isBusy: false,
          errorMessage: _cleanError(error),
        ),
      );
    }
  }

  Future<void> joinRoom(String roomCode) async {
    final normalized = roomCode.trim().toUpperCase();
    if (_state.isBusy) return;
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
      _setError('Enter the 6-character room code.');
      return;
    }
    _update(_state.copyWith(isBusy: true, clearError: true));
    try {
      final room = await repository.joinRoom(
        roomCode: normalized,
        account: account,
      );
      await _bindRoom(room);
    } catch (error) {
      _update(
        _state.copyWith(
          isBusy: false,
          errorMessage: _cleanError(error),
        ),
      );
    }
  }

  Future<void> _bindRoom(MagneticHeartRoom room) async {
    await _cancelBindings();
    _membersHydrated = false;
    _hapticPlayed = false;
    _progressHapticPlayed = false;
    _lastMovementSent = DateTime.fromMillisecondsSinceEpoch(0);
    _lastNodePersisted = DateTime.fromMillisecondsSinceEpoch(0);
    _lastBeginAttempt = DateTime.fromMillisecondsSinceEpoch(0);
    _state = _state.copyWith(
      room: room,
      members: const [],
      onlineUserIds: const <String>{},
      localIsDragging: false,
      remoteIsDragging: false,
      connectionProgress: room.isCompleted ? 1 : 0,
      isCompleted: room.isCompleted,
      revealStarted: room.isCompleted,
      latestLocalSequence: 0,
      latestRemoteSequence: 0,
      realtimeStatus: MagneticHeartRealtimeStatus.connecting,
      isBusy: true,
      clearCountdown: room.status != MagneticHeartRoomStatus.countdown,
      clearError: true,
    );
    _notify();

    final members = await repository.loadMembers(room.id);
    _applyMembers(members, hydratePositions: true);

    _roomSubscription = repository.watchRoom(room.id).listen(
      _onRoomChanged,
      onError: (Object error, StackTrace stackTrace) {
        _setError(_cleanError(error));
      },
    );
    _memberSubscription = repository.watchMembers(room.id).listen(
      (members) => _applyMembers(members),
      onError: (Object error, StackTrace stackTrace) {
        _setError(_cleanError(error));
      },
    );
    await _ensureRealtime();
    _update(_state.copyWith(isBusy: false));
  }

  void _onRoomChanged(MagneticHeartRoom? room) {
    if (room == null || room.id != _state.room?.id) {
      unawaited(_returnToLobby('That Magnetic Hearts room is no longer open.'));
      return;
    }
    if (room.status == MagneticHeartRoomStatus.abandoned) {
      unawaited(_returnToLobby('The Magnetic Hearts room was closed.'));
      return;
    }

    final previousStatus = _state.room?.status;
    final serverReset = (room.status == MagneticHeartRoomStatus.waiting ||
            room.status == MagneticHeartRoomStatus.ready) &&
        (previousStatus == MagneticHeartRoomStatus.completed ||
            previousStatus == MagneticHeartRoomStatus.playing ||
            previousStatus == MagneticHeartRoomStatus.countdown);
    if (serverReset) {
      final localIsBlue =
          _state.localMember?.nodeColor == MagneticNodeColor.blue;
      final localPosition =
          localIsBlue ? const Offset(0.22, 0.58) : const Offset(0.78, 0.58);
      final remotePosition =
          localIsBlue ? const Offset(0.78, 0.58) : const Offset(0.22, 0.58);
      final resetMembers = _state.members
          .map(
            (member) => member.copyWith(
              isReady: false,
              nodePosition: member.role == MagneticHeartRole.host
                  ? const Offset(0.22, 0.58)
                  : const Offset(0.78, 0.58),
              isDragging: false,
              lastSequence: 0,
            ),
          )
          .toList(growable: false);
      _hapticPlayed = false;
      _progressHapticPlayed = false;
      _lastBeginAttempt = DateTime.fromMillisecondsSinceEpoch(0);
      _update(
        _state.copyWith(
          room: room,
          members: resetMembers,
          localPosition: localPosition,
          remotePosition: remotePosition,
          remoteTargetPosition: remotePosition,
          localIsDragging: false,
          remoteIsDragging: false,
          connectionProgress: 0,
          isCompleted: false,
          revealStarted: false,
          latestLocalSequence: 0,
          latestRemoteSequence: 0,
          clearCountdown: true,
        ),
      );
      return;
    }

    final completed = room.isCompleted;
    _update(
      _state.copyWith(
        room: room,
        isCompleted: completed,
        revealStarted: completed || _state.revealStarted,
        connectionProgress: completed ? 1 : _state.connectionProgress,
        clearCountdown: room.status != MagneticHeartRoomStatus.countdown,
      ),
    );
    if (completed) _startReveal();
  }

  void _applyMembers(
    List<MagneticHeartMember> members, {
    bool hydratePositions = false,
  }) {
    var effectiveMembers = members;
    if (_state.room?.isActive == true &&
        _state.members.isNotEmpty &&
        members.length < _state.members.length) {
      final merged = <String, MagneticHeartMember>{
        for (final member in _state.members) member.userId: member,
        for (final member in members) member.userId: member,
      };
      effectiveMembers = merged.values.toList(growable: false)
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    }
    MagneticHeartMember? local;
    MagneticHeartMember? remote;
    for (final member in effectiveMembers) {
      if (member.userId == _state.localUserId) {
        local = member;
      } else {
        remote = member;
      }
    }
    if (local == null) {
      if (_state.members.isNotEmpty) return;
      _setError('You are not a member of this room.');
      return;
    }

    final shouldHydrate = hydratePositions || !_membersHydrated;
    _membersHydrated = true;
    final nextRemotePosition = remote?.nodePosition ?? _state.remotePosition;
    final remoteSequence = remote?.lastSequence ?? _state.latestRemoteSequence;
    _update(
      _state.copyWith(
        members: List.unmodifiable(effectiveMembers),
        localPosition:
            shouldHydrate ? local.nodePosition : _state.localPosition,
        remotePosition:
            shouldHydrate ? nextRemotePosition : _state.remotePosition,
        remoteTargetPosition:
            remoteSequence > _state.latestRemoteSequence || shouldHydrate
                ? nextRemotePosition
                : _state.remoteTargetPosition,
        remoteIsDragging: shouldHydrate ? (remote?.isDragging ?? false) : null,
        latestLocalSequence:
            shouldHydrate ? local.lastSequence : _state.latestLocalSequence,
        latestRemoteSequence:
            remoteSequence > _state.latestRemoteSequence || shouldHydrate
                ? remoteSequence
                : _state.latestRemoteSequence,
      ),
    );
    _realtime?.emitPresenceSnapshot();
    unawaited(_ensureRealtime());
  }

  Future<void> _ensureRealtime() async {
    if (_disposed || _realtime != null) return;
    final room = _state.room;
    final member = _state.localMember;
    if (room == null || member == null || room.isClosed) return;

    final realtime = MagneticHeartRealtimeService(
      room: room,
      member: member,
    );
    _realtime = realtime;
    realtime.onEvent = _onRealtimeEvent;
    realtime.onPresenceChanged = _onPresenceChanged;
    realtime.onConnectionChanged = _onRealtimeConnectionChanged;
    _update(
      _state.copyWith(
        realtimeStatus: MagneticHeartRealtimeStatus.connecting,
      ),
    );
    try {
      await realtime.connect();
    } catch (error) {
      if (identical(_realtime, realtime)) {
        _update(
          _state.copyWith(
            realtimeStatus: MagneticHeartRealtimeStatus.error,
            errorMessage: _cleanError(error),
          ),
        );
        _scheduleReconnect();
      }
    }
  }

  void _onRealtimeConnectionChanged(
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (_disposed) return;
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _reconnectTimer?.cancel();
        final wasDisconnected =
            _state.realtimeStatus != MagneticHeartRealtimeStatus.connected;
        _update(
          _state.copyWith(
            realtimeStatus: MagneticHeartRealtimeStatus.connected,
            clearError: true,
          ),
        );
        if (wasDisconnected) {
          unawaited(_sendReconnectState());
        }
      case RealtimeSubscribeStatus.channelError:
      case RealtimeSubscribeStatus.timedOut:
        _update(
          _state.copyWith(
            realtimeStatus: MagneticHeartRealtimeStatus.reconnecting,
            onlineUserIds: _onlineWithoutLocalUser(),
            localIsDragging: false,
            errorMessage: error == null ? null : _cleanError(error),
          ),
        );
        _scheduleReconnect();
      case RealtimeSubscribeStatus.closed:
        _update(
          _state.copyWith(
            realtimeStatus: MagneticHeartRealtimeStatus.disconnected,
            onlineUserIds: _onlineWithoutLocalUser(),
            localIsDragging: false,
          ),
        );
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _state.room?.isActive != true) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_disposed ||
          _state.realtimeStatus == MagneticHeartRealtimeStatus.connected) {
        return;
      }
      final old = _realtime;
      _realtime = null;
      await old?.dispose();
      await _ensureRealtime();
    });
  }

  void _onPresenceChanged(List<SinglePresenceState> states) {
    final validMembers = {
      for (final member in _state.members) member.userId: member,
    };
    final online = <String>{};
    for (final presence in states) {
      final member = validMembers[presence.key];
      if (member == null || presence.presences.isEmpty) continue;
      final hasValidPayload = presence.presences.any((entry) {
        final payload = entry.payload;
        return payload['userId']?.toString() == member.userId &&
            payload['role']?.toString() == member.role.name &&
            payload['nodeColor']?.toString() == member.nodeColor.name;
      });
      if (hasValidPayload) online.add(member.userId);
    }
    final remoteWasOnline = _state.remoteOnline;
    _update(_state.copyWith(onlineUserIds: Set.unmodifiable(online)));
    if (!remoteWasOnline && _state.remoteOnline) {
      unawaited(_sendReconnectState());
      unawaited(_refreshRoomAndMembers());
    }
  }

  Set<String> _onlineWithoutLocalUser() {
    return Set<String>.unmodifiable(
      Set<String>.from(_state.onlineUserIds)..remove(_state.localUserId),
    );
  }

  Future<void> _sendReconnectState() async {
    final realtime = _realtime;
    final room = _state.room;
    final member = _state.localMember;
    if (realtime == null || room == null || member == null) return;
    final sequence = _state.latestLocalSequence + 1;
    _update(
      _state.copyWith(
        localIsDragging: false,
        latestLocalSequence: sequence,
      ),
    );
    await realtime.sendEvent('partner_reconnected', {
      'role': member.role.name,
      'node': member.nodeColor.name,
      'x': _state.localPosition.dx,
      'y': _state.localPosition.dy,
      'isDragging': false,
      'sequence': sequence,
      'ready': member.isReady,
      'status': room.status.name,
    });
    _persistNode(force: true);
  }

  void _onRealtimeEvent(String event, Map<String, dynamic> payload) {
    final room = _state.room;
    final sender = _state.remoteMember;
    if (room == null || sender == null) return;
    if (payload['roomId']?.toString() != room.id ||
        payload['userId']?.toString() != sender.userId ||
        payload['userId']?.toString() == _state.localUserId) {
      return;
    }

    switch (event) {
      case 'node_move':
      case 'drag_start':
      case 'drag_end':
      case 'partner_reconnected':
        _applyRemoteMovement(event, payload, sender);
      case 'ready_changed':
      case 'countdown_started':
      case 'game_reset':
        unawaited(_refreshRoomAndMembers());
      case 'game_completed':
        if (sender.role != MagneticHeartRole.host) return;
        final completedRoom = room.copyWith(
          status: MagneticHeartRoomStatus.completed,
          completedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        _update(
          _state.copyWith(
            room: completedRoom,
            connectionProgress: 1,
            isCompleted: true,
            revealStarted: true,
            localIsDragging: false,
            remoteIsDragging: false,
          ),
        );
        _startReveal();
    }
  }

  void _applyRemoteMovement(
    String event,
    Map<String, dynamic> payload,
    MagneticHeartMember sender,
  ) {
    final room = _state.room;
    if (room == null ||
        !MagneticHeartRules.isOwnedMovePayload(
          payload: payload,
          roomId: room.id,
          sender: sender,
        )) {
      return;
    }
    final position = MagneticHeartRules.normalizedPositionFromPayload(payload);
    final rawSequence = payload['sequence'];
    final sequence = rawSequence is int ? rawSequence : null;
    if (position == null ||
        sequence == null ||
        !MagneticHeartRules.shouldAcceptSequence(
          incoming: sequence,
          latest: _state.latestRemoteSequence,
        )) {
      return;
    }

    final rawDragging = payload['isDragging'];
    final dragging = event == 'drag_end'
        ? false
        : event == 'drag_start'
            ? true
            : rawDragging is bool
                ? rawDragging
                : _state.remoteIsDragging;
    final reconnecting = event == 'partner_reconnected';
    _update(
      _state.copyWith(
        remotePosition: reconnecting ? position : _state.remotePosition,
        remoteTargetPosition: position,
        remoteIsDragging: dragging,
        latestRemoteSequence: sequence,
      ),
    );
  }

  Future<void> toggleReady() async {
    final room = _state.room;
    final member = _state.localMember;
    if (room == null || member == null || _readyInFlight) return;
    if (!room.isActive ||
        room.status == MagneticHeartRoomStatus.countdown ||
        room.status == MagneticHeartRoomStatus.playing) {
      return;
    }
    if (!_state.bothPlayersJoined || !_state.bothOnline) {
      _setError('Both players must be online before getting ready.');
      return;
    }

    _readyInFlight = true;
    _update(_state.copyWith(isBusy: true, clearError: true));
    try {
      final ready = !member.isReady;
      final updatedRoom = await repository.setReady(
        roomId: room.id,
        ready: ready,
      );
      _updateMemberReady(member.userId, ready);
      await _realtime?.trackPresence(ready: ready);
      await _realtime?.sendEvent('ready_changed', {
        'ready': ready,
        'role': member.role.name,
        'node': member.nodeColor.name,
      });
      _update(_state.copyWith(room: updatedRoom, isBusy: false));
      if (updatedRoom.status == MagneticHeartRoomStatus.countdown) {
        await _realtime?.sendEvent('countdown_started', {
          'playAt': updatedRoom.playAt?.toIso8601String(),
        });
      }
      await _refreshRoomAndMembers();
    } catch (error) {
      _update(
        _state.copyWith(
          isBusy: false,
          errorMessage: _cleanError(error),
        ),
      );
    } finally {
      _readyInFlight = false;
    }
  }

  void _updateMemberReady(String userId, bool ready) {
    final members = _state.members
        .map(
          (member) => member.userId == userId
              ? member.copyWith(isReady: ready)
              : member,
        )
        .toList(growable: false);
    _update(_state.copyWith(members: members));
  }

  void setCanvasSize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _canvasSize = size;
  }

  void startDrag(Offset localPosition) {
    if (!_state.canDrag || _canvasSize.isEmpty) return;
    final center = MagneticHeartRules.denormalizePosition(
      _state.localPosition,
      _canvasSize,
    );
    if ((center - localPosition).distance >
        MagneticHeartRules.nodeRadius + 18) {
      return;
    }
    _update(_state.copyWith(localIsDragging: true, clearError: true));
    _sendMovement(force: true, event: 'drag_start');
  }

  void updateDrag(Offset localPosition) {
    if (!_state.localIsDragging || !_state.canDrag || _canvasSize.isEmpty) {
      return;
    }
    final clamped = MagneticHeartRules.clampToCanvas(
      localPosition,
      _canvasSize,
    );
    final normalized = MagneticHeartRules.normalizePosition(
      clamped,
      _canvasSize,
    );
    _update(_state.copyWith(localPosition: normalized));
    _sendMovement();
  }

  void endDrag() {
    if (!_state.localIsDragging) return;
    _update(_state.copyWith(localIsDragging: false));
    _sendMovement(force: true);
    _sendMovement(force: true, event: 'drag_end');
    _persistNode(force: true);
  }

  void _sendMovement({bool force = false, String event = 'node_move'}) {
    final realtime = _realtime;
    final room = _state.room;
    final member = _state.localMember;
    if (realtime == null || room == null || member == null) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastMovementSent) <
            MagneticHeartRules.movementInterval) {
      return;
    }
    _lastMovementSent = now;
    final sequence = _state.latestLocalSequence + 1;
    _update(_state.copyWith(latestLocalSequence: sequence));

    final payload = {
      'role': member.role.name,
      'node': member.nodeColor.name,
      'x': _state.localPosition.dx,
      'y': _state.localPosition.dy,
      'isDragging': _state.localIsDragging,
      'sequence': sequence,
    };
    if (event == 'node_move') {
      unawaited(
        realtime.sendNodeMove(
          x: _state.localPosition.dx,
          y: _state.localPosition.dy,
          isDragging: _state.localIsDragging,
          sequence: sequence,
        ),
      );
    } else {
      unawaited(realtime.sendEvent(event, payload));
    }
    _persistNode();
  }

  void _persistNode({bool force = false}) {
    final room = _state.room;
    if (room == null) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastNodePersisted) <
            MagneticHeartRules.persistenceInterval) {
      return;
    }
    _lastNodePersisted = now;
    unawaited(
      repository
          .persistNodeState(
            roomId: room.id,
            x: _state.localPosition.dx,
            y: _state.localPosition.dy,
            isDragging: _state.localIsDragging,
            sequence: _state.latestLocalSequence,
          )
          .catchError((Object _) {}),
    );
  }

  void tick(Duration elapsed) {
    if (_disposed) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    final rawDelta = (elapsed - previous).inMicroseconds / 1000000;
    final delta = rawDelta.clamp(0.0, 0.05).toDouble();
    final room = _state.room;
    if (room == null) {
      _update(
        _state.copyWith(
          animationSeconds: elapsed.inMicroseconds / 1000000,
        ),
      );
      return;
    }

    final smoothed = MagneticHeartRules.smoothRemotePosition(
      current: _state.remotePosition,
      target: _state.remoteTargetPosition,
      deltaSeconds: delta,
    );
    var nextProgress = _state.connectionProgress;
    int? countdown;

    if (room.status == MagneticHeartRoomStatus.countdown) {
      countdown = MagneticHeartRules.countdownValue(
        room.playAt,
        DateTime.now(),
      );
      if (countdown == 0) unawaited(_beginGame());
    }
    if (room.status == MagneticHeartRoomStatus.playing &&
        !_state.isCompleted &&
        !_canvasSize.isEmpty) {
      nextProgress = MagneticHeartRules.calculateConnectionProgress(
        currentProgress: _state.connectionProgress,
        deltaSeconds: delta,
        bluePosition: _state.bluePosition,
        pinkPosition: _state.pinkPosition,
        canvasSize: _canvasSize,
        blueDragging: _state.blueDragging,
        pinkDragging: _state.pinkDragging,
        blueOnline: _isNodeOnline(MagneticNodeColor.blue),
        pinkOnline: _isNodeOnline(MagneticNodeColor.pink),
        gameIsPlaying: true,
      );
      if (MagneticHeartRules.shouldFinalizeCompletion(
        isHost: _state.isHost,
        alreadyCompleted: _state.isCompleted,
        completionInFlight: _completionInFlight,
        progress: nextProgress,
      )) {
        unawaited(_completeGame());
      }
      if (nextProgress >= 0.75 && !_progressHapticPlayed) {
        _progressHapticPlayed = true;
        HapticFeedback.lightImpact();
      } else if (nextProgress < 0.65) {
        _progressHapticPlayed = false;
      }
    }

    _update(
      _state.copyWith(
        remotePosition: smoothed,
        connectionProgress: _state.isCompleted ? 1 : nextProgress,
        countdownValue: countdown,
        clearCountdown: room.status != MagneticHeartRoomStatus.countdown,
        animationSeconds: elapsed.inMicroseconds / 1000000,
      ),
    );
  }

  bool _isNodeOnline(MagneticNodeColor color) {
    for (final member in _state.members) {
      if (member.nodeColor == color) {
        return _state.onlineUserIds.contains(member.userId);
      }
    }
    return false;
  }

  Future<void> _beginGame() async {
    final room = _state.room;
    final now = DateTime.now();
    if (room == null ||
        room.status != MagneticHeartRoomStatus.countdown ||
        _beginInFlight ||
        now.difference(_lastBeginAttempt) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastBeginAttempt = now;
    _beginInFlight = true;
    try {
      final updated = await repository.beginGame(room.id);
      _update(
        _state.copyWith(
          room: updated,
          clearCountdown: true,
          connectionProgress: 0,
        ),
      );
    } catch (error) {
      final message = _cleanError(error);
      if (!message.toLowerCase().contains('countdown is still running')) {
        _setError(message);
      }
    } finally {
      _beginInFlight = false;
    }
  }

  Future<void> _completeGame() async {
    final room = _state.room;
    if (room == null ||
        !_state.isHost ||
        room.status != MagneticHeartRoomStatus.playing ||
        _completionInFlight ||
        _state.isCompleted) {
      return;
    }
    _completionInFlight = true;
    try {
      final completed = await repository.completeGame(room.id);
      _update(
        _state.copyWith(
          room: completed,
          localIsDragging: false,
          remoteIsDragging: false,
          connectionProgress: 1,
          isCompleted: true,
          revealStarted: true,
        ),
      );
      await _realtime?.sendEvent('game_completed', {
        'completedAt': completed.completedAt?.toIso8601String(),
        'message': completed.revealMessage,
      });
      _persistNode(force: true);
      _startReveal();
    } catch (error) {
      _setError(_cleanError(error));
    } finally {
      _completionInFlight = false;
    }
  }

  void _startReveal() {
    if (_hapticPlayed) return;
    _hapticPlayed = true;
    HapticFeedback.heavyImpact();
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 220),
        HapticFeedback.mediumImpact,
      ),
    );
  }

  Future<void> playAgain() async {
    final room = _state.room;
    if (room == null || !room.isCompleted || _state.isBusy) return;
    _update(_state.copyWith(isBusy: true, clearError: true));
    try {
      final reset = await repository.resetGame(room.id);
      final isBlue = _state.localMember?.nodeColor == MagneticNodeColor.blue;
      final localPosition =
          isBlue ? const Offset(0.22, 0.58) : const Offset(0.78, 0.58);
      final remotePosition =
          isBlue ? const Offset(0.78, 0.58) : const Offset(0.22, 0.58);
      final resetMembers = _state.members
          .map(
            (member) => member.copyWith(
              isReady: false,
              nodePosition: member.role == MagneticHeartRole.host
                  ? const Offset(0.22, 0.58)
                  : const Offset(0.78, 0.58),
              isDragging: false,
              lastSequence: 0,
            ),
          )
          .toList(growable: false);
      _hapticPlayed = false;
      _progressHapticPlayed = false;
      _lastBeginAttempt = DateTime.fromMillisecondsSinceEpoch(0);
      _update(
        _state.copyWith(
          room: reset,
          members: resetMembers,
          localPosition: localPosition,
          remotePosition: remotePosition,
          remoteTargetPosition: remotePosition,
          localIsDragging: false,
          remoteIsDragging: false,
          connectionProgress: 0,
          isCompleted: false,
          revealStarted: false,
          latestLocalSequence: 0,
          latestRemoteSequence: 0,
          isBusy: false,
          clearCountdown: true,
        ),
      );
      if (_state.realtimeStatus != MagneticHeartRealtimeStatus.connected) {
        final old = _realtime;
        _realtime = null;
        await old?.dispose();
        await _ensureRealtime();
      }
      await _ensureRealtime();
      await _realtime?.trackPresence(ready: false);
      await _realtime?.sendEvent('game_reset', const {});
      await _refreshRoomAndMembers();
    } catch (error) {
      _update(
        _state.copyWith(
          isBusy: false,
          errorMessage: _cleanError(error),
        ),
      );
    }
  }

  Future<void> leaveRoom() async {
    final room = _state.room;
    if (room != null && room.isActive) {
      try {
        await repository.abandonRoom(room.id);
      } catch (_) {
        // Local cleanup must still happen if the network disappeared.
      }
    }
    await _cancelBindings();
    _state = MagneticHeartGameState(localUserId: _state.localUserId);
    _notify();
  }

  Future<void> setAppActive(bool active) async {
    if (!active) {
      endDrag();
      try {
        await _realtime?.untrackPresence();
      } catch (_) {
        // The channel may already be reconnecting while Android backgrounds.
      }
      final online = Set<String>.from(_state.onlineUserIds)
        ..remove(_state.localUserId);
      _update(_state.copyWith(onlineUserIds: online));
      return;
    }

    if (_realtime == null) {
      await _ensureRealtime();
    }
    try {
      if (_state.realtimeStatus == MagneticHeartRealtimeStatus.connected) {
        await _realtime?.trackPresence(
          ready: _state.localMember?.isReady ?? false,
        );
        await _sendReconnectState();
      } else {
        _scheduleReconnect();
      }
    } catch (_) {
      _update(
        _state.copyWith(
          realtimeStatus: MagneticHeartRealtimeStatus.reconnecting,
          onlineUserIds: _onlineWithoutLocalUser(),
          localIsDragging: false,
        ),
      );
      _scheduleReconnect();
    }
    await _refreshRoomAndMembers();
  }

  Future<void> _refreshRoomAndMembers() async {
    final room = _state.room;
    if (room == null || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final results = await Future.wait<Object>([
        repository.loadRoom(room.id),
        repository.loadMembers(room.id),
      ]);
      _onRoomChanged(results[0] as MagneticHeartRoom);
      _applyMembers(results[1] as List<MagneticHeartMember>);
    } catch (_) {
      // Realtime will retry; a temporary refresh failure should not end a room.
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _returnToLobby(String message) async {
    await _cancelBindings();
    _state = MagneticHeartGameState(
      localUserId: _state.localUserId,
      errorMessage: message,
    );
    _notify();
  }

  Future<void> _cancelBindings() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    await _memberSubscription?.cancel();
    _memberSubscription = null;
    final realtime = _realtime;
    _realtime = null;
    await realtime?.dispose();
    _lastTick = null;
  }

  void clearError() {
    _update(_state.copyWith(clearError: true));
  }

  void _setError(String message) {
    _update(_state.copyWith(errorMessage: message, isBusy: false));
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
  }

  void _update(MagneticHeartGameState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_cancelBindings());
    super.dispose();
  }
}
