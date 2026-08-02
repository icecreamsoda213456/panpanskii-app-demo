import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/supabase/supabase.dart';
import '../../../auth/data/local_account_store.dart';
import '../../data/photobooth_store.dart';
import '../widgets/photo_booth_strip.dart';

class PhotoBoothScreen extends StatefulWidget {
  const PhotoBoothScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<PhotoBoothScreen> createState() => _PhotoBoothScreenState();
}

class _PhotoBoothScreenState extends State<PhotoBoothScreen>
    with WidgetsBindingObserver {
  final _store = PhotoBoothStore();
  final _resultCaptureKey = GlobalKey();
  final _uploadedRoundKeys = <String>{};
  final _capturedFrames = <String, Uint8List>{};

  StreamSubscription<PhotoBoothSession?>? _sessionSubscription;
  StreamSubscription<List<PhotoBoothParticipant>>? _participantSubscription;
  StreamSubscription<List<PhotoBoothPhoto>>? _photoSubscription;
  EventsListener<RoomEvent>? _roomListener;
  Room? _room;
  Timer? _countdownTimer;
  Timer? _captureTimer;
  Future<void> _sessionQueue = Future<void>.value();

  PhotoBoothSession? _session;
  List<PhotoBoothParticipant> _participants = const [];
  List<PhotoBoothPhoto> _photos = const [];
  LocalVideoTrack? _localVideoTrack;
  RemoteVideoTrack? _remoteVideoTrack;
  String? _roomSessionId;
  String? _watchedSessionId;
  String? _resultImageSessionId;
  String? _errorMessage;
  String _selectedFrame = 'vintage';
  int _countdown = 0;
  int _resultImagePrecacheGeneration = 0;
  List<String> _resultImageUrls = const [];
  bool _appIsForeground = true;
  bool _isConnectingRoom = false;
  bool _roomReconnecting = false;
  bool _isUpdatingReady = false;
  bool _isCapturing = false;
  bool _isStartingSession = false;
  bool _isSavingResult = false;
  bool _isCancellingSession = false;
  bool _isPrecachingResultImages = false;
  bool _resultImagesReady = false;
  bool _isResultStripRendered = false;
  bool _choosingAnotherSession = false;
  String? _localResultFrameStyle;

  String? get _currentUserId => supabase.auth.currentUser?.id;

  PhotoBoothParticipant? get _myParticipant {
    final userId = _currentUserId;
    if (userId == null) return null;
    for (final participant in _participants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  String get _myFrameStyle => _myParticipant?.frameStyle ?? _selectedFrame;

  String get _resultFrameStyle => _localResultFrameStyle ?? _myFrameStyle;

  bool get _isPreparingResult =>
      _isPrecachingResultImages ||
      !_resultImagesReady ||
      !_isResultStripRendered;

  bool get _canSaveResult => !_isSavingResult && !_isPreparingResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreCurrentSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCaptureTimers(resetCountdown: false);
    _sessionSubscription?.cancel();
    _participantSubscription?.cancel();
    _photoSubscription?.cancel();
    _roomListener?.dispose();
    final room = _room;
    _roomListener = null;
    _room = null;
    if (room != null) {
      unawaited(_disposeRoom(room, null));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appIsForeground = true;
      unawaited(_resumePhotoBooth());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appIsForeground = false;
      _cancelCaptureTimers(resetCountdown: true);
    }
  }

  void _handleStreamError(Object error, [StackTrace? stackTrace]) {
    if (!mounted) return;
    setState(() => _errorMessage = _cleanError(error));
  }

  void _enqueueSession(PhotoBoothSession? session) {
    _sessionQueue = _sessionQueue.then((_) async {
      try {
        await _handleSession(session);
      } catch (error) {
        if (mounted) setState(() => _errorMessage = _cleanError(error));
      }
    });
  }

  Future<void> _restoreCurrentSession() async {
    try {
      final session = await _store.loadCurrentSessionForCurrentUser();
      if (!mounted) return;
      if (session == null) {
        await _returnToLobby(cancelSessionWatch: false);
        return;
      }
      await _applySessionUpdate(session);
    } catch (error) {
      _handleStreamError(error);
    }
  }

  Future<void> _watchCurrentSession(String sessionId) async {
    if (_watchedSessionId == sessionId && _sessionSubscription != null) return;
    await _sessionSubscription?.cancel();
    if (!mounted) return;
    _sessionSubscription = null;
    _watchedSessionId = sessionId;
    _sessionSubscription = _store.watchCurrentSession(sessionId).listen(
          _enqueueSession,
          onError: _handleStreamError,
        );
  }

  Future<void> _applySessionUpdate(PhotoBoothSession session) async {
    await _watchCurrentSession(session.id);
    _enqueueSession(session);
    await _sessionQueue;
  }

  Future<void> _handleSession(PhotoBoothSession? session) async {
    if (!mounted) return;
    if (session == null) {
      await _returnToLobby(cancelSessionWatch: true);
      return;
    }
    final previous = _session;
    if (previous != null &&
        previous.id == session.id &&
        session.updatedAt.isBefore(previous.updatedAt)) {
      return;
    }

    if (session.isCancelled) {
      await _returnToLobby(cancelSessionWatch: true);
      return;
    }

    final changedSession = previous?.id != session.id;
    if (changedSession) {
      await _cancelSessionResources();
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _errorMessage = null;
      if (session.isActive) _choosingAnotherSession = false;
      if (changedSession) {
        _participants = const [];
        _photos = const [];
      }
    });

    if (changedSession) _watchSessionData(session.id);
    if (session.isActive && _myParticipant?.sessionId == session.id) {
      _scheduleCapture(session);
    } else {
      _cancelCaptureTimers(resetCountdown: true);
      if (session.isComplete) {
        unawaited(_disconnectLiveKit());
        _queueResultImagePrecache();
      }
    }
  }

  Future<void> _cancelSessionResources() async {
    _cancelCaptureTimers(resetCountdown: true);
    _uploadedRoundKeys.clear();
    _capturedFrames.clear();
    _invalidateResultImages();
    await _participantSubscription?.cancel();
    await _photoSubscription?.cancel();
    _participantSubscription = null;
    _photoSubscription = null;
    await _disconnectLiveKit();
  }

  Future<void> _returnToLobby({required bool cancelSessionWatch}) async {
    await _cancelSessionResources();
    if (cancelSessionWatch) {
      final subscription = _sessionSubscription;
      _sessionSubscription = null;
      _watchedSessionId = null;
      await subscription?.cancel();
    }
    if (!mounted) return;
    setState(() {
      _session = null;
      _participants = const [];
      _photos = const [];
      _isCapturing = false;
      _isUpdatingReady = false;
      _choosingAnotherSession = true;
      _localResultFrameStyle = null;
    });
  }

  void _watchSessionData(String sessionId) {
    _participantSubscription = _store.watchParticipants(sessionId).listen(
      (participants) {
        if (!mounted || _session?.id != sessionId) return;
        final wasJoined = _myParticipant?.sessionId == sessionId;
        final stableParticipants =
            _mergeTransientParticipantSnapshot(participants, sessionId);
        PhotoBoothParticipant? mine;
        final currentUserId = _currentUserId;
        for (final participant in stableParticipants) {
          if (participant.userId == currentUserId) {
            mine = participant;
            break;
          }
        }
        setState(() {
          _participants = stableParticipants;
          if (mine != null) _selectedFrame = mine.frameStyle;
        });
        final session = _session;
        if (mine == null) {
          final hasServerCountdown =
              session?.status == 'countdown' || session?.status == 'capturing';
          if (hasServerCountdown && participants.length < 2) {
            // A stream refresh can briefly expose only the other participant.
            // The session row remains authoritative, so keep the live room and
            // wait for the complete participant snapshot instead of cancelling.
            _scheduleCapture(session);
            return;
          }
          _cancelCaptureTimers(resetCountdown: true);
          if (_roomSessionId == sessionId) unawaited(_disconnectLiveKit());
          return;
        }
        if (!wasJoined && session != null && session.isActive) {
          unawaited(_connectLiveKit(session));
        }
        _scheduleCapture(session);
      },
      onError: _handleStreamError,
    );
    _photoSubscription = _store.watchPhotos(sessionId).listen(
      (photos) {
        if (!mounted || _session?.id != sessionId) return;
        final currentUserId = _currentUserId;
        if (currentUserId != null) {
          for (final photo in photos) {
            if (photo.userId == currentUserId) {
              _uploadedRoundKeys
                  .add(_roundKey(photo.sessionId, photo.roundIndex));
            }
          }
        }
        setState(() => _photos = photos);
        _queueResultImagePrecache();
        _scheduleCapture(_session);
      },
      onError: _handleStreamError,
    );
  }

  List<PhotoBoothParticipant> _mergeTransientParticipantSnapshot(
    List<PhotoBoothParticipant> incoming,
    String sessionId,
  ) {
    final session = _session;
    final hasKnownMembership = _myParticipant?.sessionId == sessionId;
    final isTransientPartialSnapshot = session != null &&
        session.id == sessionId &&
        session.isActive &&
        incoming.length < 2 &&
        hasKnownMembership;
    if (!isTransientPartialSnapshot) return incoming;

    final byUserId = <String, PhotoBoothParticipant>{
      for (final participant in _participants)
        if (participant.sessionId == sessionId) participant.userId: participant,
    };
    for (final participant in incoming) {
      if (participant.sessionId == sessionId) {
        byUserId[participant.userId] = participant;
      }
    }
    final merged = byUserId.values.toList()
      ..sort((first, second) => first.joinedAt.compareTo(second.joinedAt));
    return merged;
  }

  Future<void> _connectLiveKit(
    PhotoBoothSession session, {
    bool force = false,
  }) async {
    if (!mounted ||
        !session.isActive ||
        _session?.id != session.id ||
        _myParticipant?.sessionId != session.id) {
      return;
    }
    if (_isConnectingRoom) return;
    if (!force && _room != null && _roomSessionId == session.id) return;

    _isConnectingRoom = true;
    if (mounted) setState(() => _errorMessage = null);
    try {
      await _disconnectLiveKit();
      final credentials = await _store.requestLiveKitToken(session.id);
      if (!mounted ||
          _session?.id != session.id ||
          !session.isActive ||
          _myParticipant?.sessionId != session.id) {
        return;
      }

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      final listener = _listenToRoom(room);
      _room = room;
      _roomListener = listener;
      _roomSessionId = session.id;

      await room.connect(
        credentials.serverUrl,
        credentials.participantToken,
      );
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        throw StateError('LiveKit did not create a local participant.');
      }
      await localParticipant.setMicrophoneEnabled(false);
      await localParticipant.setCameraEnabled(true);

      if (!mounted ||
          _session?.id != session.id ||
          !session.isActive ||
          _myParticipant?.sessionId != session.id) {
        await _disposeRoom(room, listener);
        return;
      }
      _syncLiveKitTracks(room);
      _scheduleCapture(_session);
    } catch (error) {
      if (mounted && _session?.id == session.id) {
        setState(() => _errorMessage = _cleanError(error));
      }
      await _disconnectLiveKit();
    } finally {
      if (mounted) {
        setState(() => _isConnectingRoom = false);
      } else {
        _isConnectingRoom = false;
      }
    }
  }

  EventsListener<RoomEvent> _listenToRoom(Room room) {
    return room.createListener()
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteVideoTrack) {
          _setRemoteTrack(room, event.track as RemoteVideoTrack);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (!mounted || !identical(_room, room)) return;
        if (event.track == _remoteVideoTrack) {
          setState(() => _remoteVideoTrack = null);
        }
      })
      ..on<LocalTrackPublishedEvent>((_) {
        _syncLiveKitTracks(room);
        _scheduleCapture(_session);
      })
      ..on<LocalTrackUnpublishedEvent>((_) => _syncLiveKitTracks(room))
      ..on<ParticipantConnectedEvent>((_) => _syncLiveKitTracks(room))
      ..on<ParticipantDisconnectedEvent>((_) => _syncLiveKitTracks(room))
      ..on<RoomReconnectingEvent>((_) {
        if (mounted && identical(_room, room)) {
          setState(() => _roomReconnecting = true);
        }
      })
      ..on<RoomReconnectedEvent>((_) {
        if (!mounted || !identical(_room, room)) return;
        setState(() => _roomReconnecting = false);
        _syncLiveKitTracks(room);
        _scheduleCapture(_session);
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted || !identical(_room, room)) return;
        setState(() {
          _roomReconnecting = false;
          _localVideoTrack = null;
          _remoteVideoTrack = null;
          _errorMessage = 'Live camera disconnected. Tap reconnect cameras.';
        });
      });
  }

  void _setRemoteTrack(Room room, RemoteVideoTrack track) {
    if (!mounted || !identical(_room, room)) return;
    if (!identical(_remoteVideoTrack, track)) {
      setState(() => _remoteVideoTrack = track);
    }
  }

  void _syncLiveKitTracks(Room room) {
    if (!mounted || !identical(_room, room)) return;
    LocalVideoTrack? localTrack;
    final localParticipant = room.localParticipant;
    if (localParticipant != null) {
      for (final publication in localParticipant.videoTrackPublications) {
        final track = publication.track;
        if (track != null) {
          localTrack = track;
          break;
        }
      }
    }

    RemoteVideoTrack? remoteTrack;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track != null) {
          remoteTrack = track;
          break;
        }
      }
      if (remoteTrack != null) break;
    }

    if (!identical(_localVideoTrack, localTrack) ||
        !identical(_remoteVideoTrack, remoteTrack)) {
      setState(() {
        _localVideoTrack = localTrack;
        _remoteVideoTrack = remoteTrack;
      });
    }
  }

  Future<void> _disconnectLiveKit() async {
    final listener = _roomListener;
    final room = _room;
    _roomListener = null;
    _room = null;
    _roomSessionId = null;
    listener?.dispose();
    if (mounted) {
      setState(() {
        _roomReconnecting = false;
        _localVideoTrack = null;
        _remoteVideoTrack = null;
      });
    }
    if (room != null) await _disposeRoom(room, null);
  }

  Future<void> _disposeRoom(
    Room room,
    EventsListener<RoomEvent>? listener,
  ) async {
    listener?.dispose();
    try {
      await room.disconnect();
    } catch (_) {
      // A partially connected room can already be closed by LiveKit.
    }
    await room.dispose();
  }

  Future<void> _resumePhotoBooth() async {
    final session = _session;
    if (!mounted ||
        session == null ||
        !session.isActive ||
        _myParticipant?.sessionId != session.id) {
      return;
    }
    final room = _room;
    if (room == null || _roomSessionId != session.id) {
      await _connectLiveKit(session);
      return;
    }
    final participant = room.localParticipant;
    if (participant != null) {
      try {
        await participant.setCameraEnabled(true);
      } catch (error) {
        if (mounted) setState(() => _errorMessage = _cleanError(error));
      }
    }
    _syncLiveKitTracks(room);
    _scheduleCapture(session);
  }

  void _cancelCaptureTimers({required bool resetCountdown}) {
    _countdownTimer?.cancel();
    _captureTimer?.cancel();
    _countdownTimer = null;
    _captureTimer = null;
    if (resetCountdown && _countdown != 0) {
      if (mounted) {
        setState(() => _countdown = 0);
      } else {
        _countdown = 0;
      }
    }
  }

  void _scheduleCapture(PhotoBoothSession? session) {
    _cancelCaptureTimers(resetCountdown: false);
    if (!mounted ||
        !_appIsForeground ||
        session == null ||
        !session.isActive ||
        _hasUploadedRound(session)) {
      return;
    }
    if ((session.status != 'countdown' && session.status != 'capturing') ||
        session.captureAt == null) {
      return;
    }

    final target = session.captureAt!;
    final sessionId = session.id;
    final roundIndex = session.currentRound;

    void updateCountdown() {
      if (!mounted ||
          _session?.id != sessionId ||
          _session?.currentRound != roundIndex) {
        return;
      }
      final remaining = target.difference(DateTime.now());
      final nextCountdown = remaining.isNegative
          ? 0
          : (remaining.inMilliseconds / Duration.millisecondsPerSecond).ceil();
      if (_countdown != nextCountdown) {
        setState(() => _countdown = nextCountdown);
      }
    }

    updateCountdown();
    if (session.status == 'countdown' && target.isAfter(DateTime.now())) {
      _countdownTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => updateCountdown(),
      );
    }
    final delay = target.difference(DateTime.now());
    _captureTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_captureCurrentRound(sessionId, roundIndex)),
    );
  }

  bool _canCapture(PhotoBoothSession session) {
    if (!mounted || !_appIsForeground || _isCapturing) return false;
    if (_session?.id != session.id ||
        _session?.currentRound != session.currentRound ||
        !session.isActive ||
        _myParticipant?.sessionId != session.id ||
        _localVideoTrack == null ||
        _hasUploadedRound(session)) {
      return false;
    }
    if (session.status != 'countdown' && session.status != 'capturing') {
      return false;
    }
    final captureAt = session.captureAt;
    return captureAt != null && !captureAt.isAfter(DateTime.now());
  }

  Future<void> _captureCurrentRound(String sessionId, int roundIndex) async {
    final session = _session;
    if (session == null ||
        session.id != sessionId ||
        session.currentRound != roundIndex ||
        !_canCapture(session)) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });
    final key = _roundKey(sessionId, roundIndex);
    try {
      // Freeze this device's camera at the synchronized countdown deadline,
      // before this phone waits on any database round-start latency.
      final bytes = _capturedFrames[key] ?? await _captureLocalFrame();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The camera frame was not ready.');
      }
      _capturedFrames[key] = bytes;

      final captureSession = await _store.beginCapture(
        sessionId: sessionId,
        roundIndex: roundIndex,
      );
      if (!mounted ||
          captureSession.id != _session?.id ||
          captureSession.currentRound != roundIndex ||
          captureSession.status != 'capturing') {
        return;
      }
      await _applySessionUpdate(captureSession);
      await _store.uploadPhoto(
        session: captureSession,
        account: widget.account,
        roundIndex: roundIndex,
        bytes: bytes,
      );
      _uploadedRoundKeys.add(key);
      _capturedFrames.remove(key);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _cleanError(error));
        _retryCapture(sessionId, roundIndex);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _retryCapture(String sessionId, int roundIndex) {
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      unawaited(_captureCurrentRound(sessionId, roundIndex));
    });
  }

  Future<Uint8List?> _captureLocalFrame() async {
    final track = _localVideoTrack;
    if (track == null) return null;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final frame = await track.mediaStreamTrack.captureFrame();
        final encodedFrame = Uint8List.fromList(frame.asUint8List());
        final png = await _encodePng(encodedFrame);
        if (png != null && png.isNotEmpty) return png;
      } catch (_) {
        // The next short retry lets Android finish exposing the camera frame.
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }

  Future<Uint8List?> _encodePng(Uint8List encodedFrame) async {
    if (encodedFrame.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(encodedFrame);
    try {
      final frame = await codec.getNextFrame();
      try {
        final png =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        return png?.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  bool _hasUploadedRound(PhotoBoothSession session) {
    final key = _roundKey(session.id, session.currentRound);
    if (_uploadedRoundKeys.contains(key)) return true;
    final currentUserId = _currentUserId;
    return currentUserId != null &&
        _photos.any(
          (photo) =>
              photo.userId == currentUserId &&
              photo.sessionId == session.id &&
              photo.roundIndex == session.currentRound,
        );
  }

  String _roundKey(String sessionId, int roundIndex) =>
      '$sessionId:$roundIndex';

  Future<void> _startOrJoinSession() async {
    if (_isStartingSession) return;
    setState(() {
      _isStartingSession = true;
      _errorMessage = null;
    });
    try {
      final session =
          await _store.createOrJoinSession(frameStyle: _selectedFrame);
      if (!mounted) return;
      await _applySessionUpdate(session);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _cleanError(error));
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  Future<void> _toggleReady(PhotoBoothSession session) async {
    if (_isUpdatingReady || session.status != 'lobby') return;
    final mine = _myParticipant;
    if (mine == null) {
      setState(
          () => _errorMessage = 'Join the Photo Booth before changing Ready.');
      return;
    }
    final nextReady = !mine.isReady;
    if (nextReady && (_localVideoTrack == null || _remoteVideoTrack == null)) {
      setState(() {
        _errorMessage =
            'Wait until both live cameras are visible before Ready.';
      });
      return;
    }
    setState(() {
      _isUpdatingReady = true;
      _errorMessage = null;
    });
    try {
      final updated = await _store.setReady(
        sessionId: session.id,
        ready: nextReady,
      );
      if (mounted) await _applySessionUpdate(updated);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _cleanError(error));
    } finally {
      if (mounted) setState(() => _isUpdatingReady = false);
    }
  }

  Future<void> _reconnectCameras() async {
    final session = _session;
    if (session == null ||
        !session.isActive ||
        _myParticipant?.sessionId != session.id) {
      return;
    }
    await _connectLiveKit(session, force: true);
  }

  Future<bool> _confirmCancelPhotoBooth(PhotoBoothSession session) async {
    if (_isCancellingSession) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2230),
        title: const Text('Leave Photo Booth?'),
        content: const Text(
          'This cancels the current booth for both of you. Your shared strip will not continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB85D6B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    return _cancelPhotoBooth(session);
  }

  Future<bool> _cancelPhotoBooth(PhotoBoothSession session) async {
    if (_isCancellingSession) return false;
    if (!session.isActive) return true;
    setState(() {
      _isCancellingSession = true;
      _errorMessage = null;
    });
    try {
      final cancelledSession = await _store.cancelSession(session.id);
      _cancelCaptureTimers(resetCountdown: true);
      await _disconnectLiveKit();
      if (!mounted) return true;
      // The cancelled session update drives both devices through the same
      // Realtime cleanup path in _handleSession.
      await _applySessionUpdate(cancelledSession);
      return true;
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _cleanError(error));
      return false;
    } finally {
      if (mounted) setState(() => _isCancellingSession = false);
    }
  }

  Future<void> _leavePhotoBoothRoute(String destination) async {
    final session = _session;
    if (session != null && session.isActive) {
      final didCancel = await _confirmCancelPhotoBooth(session);
      if (!didCancel) return;
    }
    if (mounted) context.go(destination);
  }

  void _invalidateResultImages() {
    _resultImagePrecacheGeneration += 1;
    _resultImageSessionId = null;
    _resultImageUrls = const [];
    _isPrecachingResultImages = false;
    _resultImagesReady = false;
    _isResultStripRendered = false;
  }

  void _selectResultFrame(String frameStyle) {
    if (_resultFrameStyle == frameStyle) return;
    setState(() {
      _localResultFrameStyle = frameStyle;
      _isResultStripRendered = false;
    });
    _markResultStripRenderedAfterFrame();
  }

  void _markResultStripRenderedAfterFrame([int? generation]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_resultImagesReady ||
          (generation != null &&
              generation != _resultImagePrecacheGeneration)) {
        return;
      }
      final boundary = _resultCaptureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary ||
          !boundary.hasSize ||
          boundary.size.isEmpty) {
        return;
      }
      if (!_isResultStripRendered) {
        setState(() => _isResultStripRendered = true);
      }
    });
  }

  void _queueResultImagePrecache() {
    final session = _session;
    if (!mounted || session == null || !session.isComplete) return;

    final expectedImageCount = session.totalRounds * 2;
    final imageUrls = _photos
        .where(
          (photo) =>
              photo.sessionId == session.id &&
              photo.imageUrl != null &&
              photo.imageUrl!.isNotEmpty,
        )
        .map((photo) => photo.imageUrl!)
        .toSet()
        .toList()
      ..sort();
    if (imageUrls.length != expectedImageCount) {
      if (_resultImagesReady ||
          _isPrecachingResultImages ||
          _isResultStripRendered) {
        setState(_invalidateResultImages);
      }
      return;
    }
    if (_resultImageSessionId == session.id &&
        _sameImageUrls(_resultImageUrls, imageUrls) &&
        (_resultImagesReady || _isPrecachingResultImages)) {
      return;
    }

    final generation = ++_resultImagePrecacheGeneration;
    setState(() {
      _resultImageSessionId = session.id;
      _resultImageUrls = imageUrls;
      _isPrecachingResultImages = true;
      _resultImagesReady = false;
      _isResultStripRendered = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheResultImages(session.id, imageUrls, generation));
    });
  }

  Future<void> _precacheResultImages(
    String sessionId,
    List<String> imageUrls,
    int generation,
  ) async {
    try {
      await Future.wait(
        imageUrls.map((url) => precacheImage(NetworkImage(url), context)),
      );
      if (!mounted ||
          generation != _resultImagePrecacheGeneration ||
          _session?.id != sessionId) {
        return;
      }
      setState(() {
        _isPrecachingResultImages = false;
        _resultImagesReady = true;
        _isResultStripRendered = false;
      });
      _markResultStripRenderedAfterFrame(generation);
    } catch (error) {
      if (!mounted ||
          generation != _resultImagePrecacheGeneration ||
          _session?.id != sessionId) {
        return;
      }
      setState(() {
        _isPrecachingResultImages = false;
        _resultImagesReady = false;
        _errorMessage = 'All ten photo images must load before saving.';
      });
    }
  }

  bool _sameImageUrls(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<void> _saveResultToGallery() async {
    if (!_canSaveResult) return;
    setState(() {
      _isSavingResult = true;
      _errorMessage = null;
    });
    try {
      final object = _resultCaptureKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary ||
          !object.hasSize ||
          object.size.isEmpty) {
        throw StateError('The photo strip is not ready yet.');
      }
      await WidgetsBinding.instance.endOfFrame;
      final image = await object.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The photo strip could not be prepared.');
      }
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) throw StateError('Gallery permission was not granted.');
      }
      await Gal.putImageBytes(
        bytes,
        album: 'Panpanskii',
        name: 'panpanskii-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your gallery.')),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _cleanError(error));
    } finally {
      if (mounted) setState(() => _isSavingResult = false);
    }
  }

  void _takeAnotherSession() {
    final frameStyle = _myFrameStyle;
    _cancelCaptureTimers(resetCountdown: true);
    _uploadedRoundKeys.clear();
    _capturedFrames.clear();
    _invalidateResultImages();
    unawaited(_disconnectLiveKit());
    setState(() {
      _choosingAnotherSession = true;
      _selectedFrame = frameStyle;
      _localResultFrameStyle = null;
      _errorMessage = null;
    });
  }

  String _cleanError(Object error) {
    final message = error
        .toString()
        .replaceFirst('PostgrestException: ', '')
        .replaceFirst('Bad state: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('jwt') ||
        lower.contains('not authenticated') ||
        lower.contains('session expired')) {
      return 'Your login session expired. Sign in again, then reopen Photo Booth.';
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Camera permission was denied. Allow camera access in Android settings.';
    }
    if (lower.contains('livekit') ||
        lower.contains('live camera') ||
        lower.contains('server_url')) {
      return 'Could not connect the live cameras. Check LiveKit settings and internet.';
    }
    if (lower.contains('camera frame')) {
      return 'The camera frame was not ready. Keep Photo Booth open while it retries.';
    }
    if (lower.contains('storage') || lower.contains('upload')) {
      return 'Could not upload this photo yet. Keep the app open while it retries.';
    }
    return message.isEmpty ? 'Something went wrong in Photo Booth.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final showLobby = session == null ||
        session.isCancelled ||
        (session.isComplete && _choosingAnotherSession);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leavePhotoBoothRoute('/'));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF18151D),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: showLobby
                    ? _buildLobby()
                    : session.isComplete
                        ? _buildResult(session)
                        : _buildLiveBooth(session),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Back home',
            onPressed: () => unawaited(_leavePhotoBoothRoute('/')),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHOTO BOOTH',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'A little memory, made together',
                  style: TextStyle(
                    color: Color(0xFFC8B8CB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Open gallery',
            onPressed: () =>
                unawaited(_leavePhotoBoothRoute('/photobooth-gallery')),
            icon: const Icon(Icons.photo_library_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        child: Column(
          children: [
            const Icon(
              Icons.photo_camera_front_rounded,
              color: Color(0xFFD9A8D7),
              size: 66,
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose your strip style',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your person can choose a different one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC8B8CB),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _FrameSelector(
              selectedFrame: _selectedFrame,
              onSelect: (style) => setState(() => _selectedFrame = style),
            ),
            const SizedBox(height: 28),
            if (_errorMessage != null) _ErrorMessage(message: _errorMessage!),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isStartingSession ? null : _startOrJoinSession,
              icon: _isStartingSession
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_call_rounded),
              label: Text(
                _isStartingSession ? 'Opening booth...' : 'Start or join booth',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFFD9A8D7),
                foregroundColor: const Color(0xFF2B1F2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBooth(PhotoBoothSession session) {
    final myReady = _myParticipant?.isReady ?? false;
    final partnerReady = _participants.any(
      (participant) =>
          participant.userId != _currentUserId && participant.isReady,
    );
    final waitingForCameras =
        _localVideoTrack == null || _remoteVideoTrack == null;
    final canReconnect = !_isConnectingRoom && waitingForCameras;
    final phaseMessage = session.status == 'lobby'
        ? waitingForCameras
            ? 'Waiting for both live cameras.'
            : 'Both live cameras are ready.'
        : session.status == 'countdown'
            ? 'Round ${session.currentRound + 1} of ${session.totalRounds} starts now.'
            : _isCapturing
                ? 'Capturing your camera frame...'
                : 'Waiting for both uploads for round ${session.currentRound + 1}.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF302936),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF826D89), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _LiveVideoPanel(
                                track: _localVideoTrack,
                                label: 'YOU',
                                waitingLabel: 'Connecting your camera...',
                              ),
                            ),
                            const VerticalDivider(
                              width: 2,
                              thickness: 2,
                              color: Color(0xFF18151D),
                            ),
                            Expanded(
                              child: _LiveVideoPanel(
                                track: _remoteVideoTrack,
                                label: 'YOUR PERSON',
                                waitingLabel: _roomReconnecting
                                    ? 'Reconnecting live camera...'
                                    : 'Waiting for live camera...',
                              ),
                            ),
                          ],
                        ),
                        const _RecordingOverlay(),
                        if (_countdown > 0)
                          Center(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xAA201925),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Text(
                                  '$_countdown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
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
            ),
          ),
          const SizedBox(height: 12),
          Text(
            phaseMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC8B8CB),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ReadyStatus(
            myReady: myReady,
            partnerReady: partnerReady,
          ),
          if (session.status == 'lobby') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _isUpdatingReady ? null : () => _toggleReady(session),
                icon: _isUpdatingReady
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(myReady ? Icons.close_rounded : Icons.check_rounded),
                label: Text(myReady ? 'I am not ready' : 'I am ready'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: myReady
                      ? const Color(0xFF66566D)
                      : const Color(0xFFD9A8D7),
                  foregroundColor: const Color(0xFF2B1F2E),
                ),
              ),
            ),
          ],
          if (canReconnect) ...[
            const SizedBox(height: 8),
            IconButton.filledTonal(
              tooltip: 'Reconnect cameras',
              onPressed: _reconnectCameras,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCancellingSession
                  ? null
                  : () => _confirmCancelPhotoBooth(session),
              icon: _isCancellingSession
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: const Text('Leave Photo Booth'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: const Color(0xFFF2B7C0),
                side: const BorderSide(color: Color(0xFFB85D6B)),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            _ErrorMessage(message: _errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(PhotoBoothSession session) {
    final rounds = List<int>.generate(session.totalRounds, (index) => index);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        children: [
          const Text(
            'YOUR SHARED PHOTO STRIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _resultFrameStyle.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFC8B8CB),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _ResultFrameSelector(
            selectedFrame: _resultFrameStyle,
            onSelect: _selectResultFrame,
          ),
          const SizedBox(height: 18),
          PhotoBoothStripPreview(
            child: RepaintBoundary(
              key: _resultCaptureKey,
              child: PhotoBoothStrip(
                roundIndexes: rounds,
                photos: _photos,
                frameStyle: _resultFrameStyle,
                primaryUserId: session.createdBy,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _canSaveResult ? _saveResultToGallery : null,
            icon: _isSavingResult
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _isSavingResult
                  ? 'Saving photo strip...'
                  : _isPreparingResult
                      ? 'Preparing your photo strip...'
                      : 'Save to Gallery',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF9DE2BD),
              foregroundColor: const Color(0xFF19372A),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _takeAnotherSession,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Take another strip'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFD9A8D7),
              foregroundColor: const Color(0xFF2B1F2E),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            _ErrorMessage(message: _errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _LiveVideoPanel extends StatelessWidget {
  const _LiveVideoPanel({
    required this.track,
    required this.label,
    required this.waitingLabel,
  });

  final VideoTrack? track;
  final String label;
  final String waitingLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null)
          VideoTrackRenderer(track!)
        else
          ColoredBox(
            color: const Color(0xFF312A35),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_search_rounded,
                      size: 34,
                      color: Color(0xFFD9A8D7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      waitingLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE9DDEA),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
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

class _RecordingOverlay extends StatelessWidget {
  const _RecordingOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'REC  *  PANPANSKII',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .9),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyStatus extends StatelessWidget {
  const _ReadyStatus({required this.myReady, required this.partnerReady});

  final bool myReady;
  final bool partnerReady;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ReadyIndicator(label: 'YOU', isReady: myReady)),
        const SizedBox(width: 8),
        Expanded(
          child: _ReadyIndicator(label: 'YOUR PERSON', isReady: partnerReady),
        ),
      ],
    );
  }
}

class _ReadyIndicator extends StatelessWidget {
  const _ReadyIndicator({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? const Color(0xFF9DE2BD) : const Color(0xFFC8B8CB);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isReady ? const Color(0x243FE38A) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReady ? const Color(0xFF9DE2BD) : const Color(0xFF66566D),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReady ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isReady ? '$label READY' : '$label WAITING',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameSelector extends StatelessWidget {
  const _FrameSelector({required this.selectedFrame, required this.onSelect});

  final String selectedFrame;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FrameOption(
          id: 'vintage',
          label: 'VINTAGE',
          color: const Color(0xFFFDF7E7),
          borderColor: const Color(0xFF8C5F3D),
          isSelected: selectedFrame == 'vintage',
          onTap: () => onSelect('vintage'),
        ),
        const SizedBox(width: 14),
        _FrameOption(
          id: 'sakura',
          label: 'SAKURA',
          color: const Color(0xFFFFE5EC),
          borderColor: const Color(0xFFFF7295),
          isSelected: selectedFrame == 'sakura',
          onTap: () => onSelect('sakura'),
        ),
        const SizedBox(width: 14),
        _FrameOption(
          id: 'midnight',
          label: 'MIDNIGHT',
          color: const Color(0xFF182137),
          borderColor: const Color(0xFFF4B942),
          isSelected: selectedFrame == 'midnight',
          onTap: () => onSelect('midnight'),
        ),
      ],
    );
  }
}

class _ResultFrameSelector extends StatelessWidget {
  const _ResultFrameSelector({
    required this.selectedFrame,
    required this.onSelect,
  });

  final String selectedFrame;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'vintage', label: Text('Vintage')),
        ButtonSegment(value: 'sakura', label: Text('Sakura')),
        ButtonSegment(value: 'midnight', label: Text('Midnight')),
      ],
      selected: {selectedFrame},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onSelect(selection.first);
      },
      style: SegmentedButton.styleFrom(
        foregroundColor: const Color(0xFFE8DDE8),
        selectedForegroundColor: const Color(0xFF2B1F2E),
        backgroundColor: const Color(0xFF2B2530),
        selectedBackgroundColor: const Color(0xFFD9A8D7),
        side: const BorderSide(color: Color(0xFF5A4A5F)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FrameOption extends StatelessWidget {
  const _FrameOption({
    required this.id,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String label;
  final Color color;
  final Color borderColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 68,
              height: 88,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? borderColor : Colors.transparent,
                  width: 3,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, color: borderColor, size: 26)
                  : null,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFFFB5B5),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
