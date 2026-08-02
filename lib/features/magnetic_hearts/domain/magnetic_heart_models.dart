import 'dart:ui';

enum MagneticHeartRoomStatus {
  waiting,
  ready,
  countdown,
  playing,
  completed,
  abandoned;

  static MagneticHeartRoomStatus fromName(String? value) {
    return MagneticHeartRoomStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MagneticHeartRoomStatus.waiting,
    );
  }
}

enum MagneticHeartRole {
  host,
  guest;

  static MagneticHeartRole fromName(String? value) {
    return MagneticHeartRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => MagneticHeartRole.guest,
    );
  }
}

enum MagneticNodeColor {
  blue,
  pink;

  static MagneticNodeColor fromName(String? value) {
    return MagneticNodeColor.values.firstWhere(
      (color) => color.name == value,
      orElse: () => MagneticNodeColor.pink,
    );
  }
}

enum MagneticHeartRealtimeStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class MagneticHeartRoom {
  const MagneticHeartRoom({
    required this.id,
    required this.topic,
    required this.roomCode,
    required this.hostUserId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
    this.revealMessage,
    this.revealImageUrl,
    this.startedAt,
    this.playAt,
    this.completedAt,
  });

  final String id;
  final String topic;
  final String roomCode;
  final String hostUserId;
  final MagneticHeartRoomStatus status;
  final String? revealMessage;
  final String? revealImageUrl;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? playAt;
  final DateTime? completedAt;
  final DateTime expiresAt;
  final DateTime updatedAt;

  bool get isHostRoom => hostUserId.isNotEmpty;
  bool get isActive =>
      status == MagneticHeartRoomStatus.waiting ||
      status == MagneticHeartRoomStatus.ready ||
      status == MagneticHeartRoomStatus.countdown ||
      status == MagneticHeartRoomStatus.playing;
  bool get isCompleted => status == MagneticHeartRoomStatus.completed;
  bool get isClosed =>
      status == MagneticHeartRoomStatus.completed ||
      status == MagneticHeartRoomStatus.abandoned;

  factory MagneticHeartRoom.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final id = _requiredText(json, 'id');
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid Magnetic Hearts room ID.');
    }
    return MagneticHeartRoom(
      id: id,
      topic: _requiredText(json, 'topic'),
      roomCode: _requiredText(json, 'room_code'),
      hostUserId: _requiredText(json, 'host_user_id'),
      status: MagneticHeartRoomStatus.fromName(json['status']?.toString()),
      revealMessage: _nullableText(json['reveal_message']),
      revealImageUrl: _nullableText(json['reveal_image_url']),
      createdAt: _date(json['created_at']) ?? now,
      startedAt: _date(json['started_at']),
      playAt: _date(json['play_at']),
      completedAt: _date(json['completed_at']),
      expiresAt: _date(json['expires_at']) ?? now.add(const Duration(hours: 2)),
      updatedAt: _date(json['updated_at']) ?? now,
    );
  }

  MagneticHeartRoom copyWith({
    MagneticHeartRoomStatus? status,
    String? revealMessage,
    String? revealImageUrl,
    DateTime? startedAt,
    DateTime? playAt,
    DateTime? completedAt,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) {
    return MagneticHeartRoom(
      id: id,
      topic: topic,
      roomCode: roomCode,
      hostUserId: hostUserId,
      status: status ?? this.status,
      revealMessage: revealMessage ?? this.revealMessage,
      revealImageUrl: revealImageUrl ?? this.revealImageUrl,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      playAt: playAt ?? this.playAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MagneticHeartMember {
  const MagneticHeartMember({
    required this.roomId,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.role,
    required this.nodeColor,
    required this.isReady,
    required this.joinedAt,
    required this.lastSeenAt,
    required this.nodePosition,
    required this.isDragging,
    required this.lastSequence,
  });

  final String roomId;
  final String userId;
  final String username;
  final String mascot;
  final MagneticHeartRole role;
  final MagneticNodeColor nodeColor;
  final bool isReady;
  final DateTime joinedAt;
  final DateTime lastSeenAt;
  final Offset nodePosition;
  final bool isDragging;
  final int lastSequence;

  factory MagneticHeartMember.fromJson(Map<String, dynamic> json) {
    final role = MagneticHeartRole.fromName(json['role']?.toString());
    final defaultPosition = role == MagneticHeartRole.host
        ? const Offset(0.22, 0.58)
        : const Offset(0.78, 0.58);
    return MagneticHeartMember(
      roomId: json['room_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString().trim().isNotEmpty == true
          ? json['username'].toString().trim()
          : 'panpanskii',
      mascot: json['mascot']?.toString() ?? 'panda',
      role: role,
      nodeColor: MagneticNodeColor.fromName(json['node_color']?.toString()),
      isReady: json['is_ready'] as bool? ?? false,
      joinedAt: _date(json['joined_at']) ?? DateTime.now().toUtc(),
      lastSeenAt: _date(json['last_seen_at']) ?? DateTime.now().toUtc(),
      nodePosition: Offset(
        _unitValue(json['node_x'], defaultPosition.dx),
        _unitValue(json['node_y'], defaultPosition.dy),
      ),
      isDragging: json['is_dragging'] as bool? ?? false,
      lastSequence: (json['last_sequence'] as num?)?.toInt() ?? 0,
    );
  }

  MagneticHeartMember copyWith({
    bool? isReady,
    DateTime? lastSeenAt,
    Offset? nodePosition,
    bool? isDragging,
    int? lastSequence,
  }) {
    return MagneticHeartMember(
      roomId: roomId,
      userId: userId,
      username: username,
      mascot: mascot,
      role: role,
      nodeColor: nodeColor,
      isReady: isReady ?? this.isReady,
      joinedAt: joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      nodePosition: nodePosition ?? this.nodePosition,
      isDragging: isDragging ?? this.isDragging,
      lastSequence: lastSequence ?? this.lastSequence,
    );
  }
}

class MagneticHeartGameState {
  const MagneticHeartGameState({
    required this.localUserId,
    this.room,
    this.members = const [],
    this.onlineUserIds = const <String>{},
    this.localPosition = const Offset(0.22, 0.58),
    this.remotePosition = const Offset(0.78, 0.58),
    this.remoteTargetPosition = const Offset(0.78, 0.58),
    this.localIsDragging = false,
    this.remoteIsDragging = false,
    this.countdownValue,
    this.connectionProgress = 0,
    this.isCompleted = false,
    this.revealStarted = false,
    this.latestLocalSequence = 0,
    this.latestRemoteSequence = 0,
    this.realtimeStatus = MagneticHeartRealtimeStatus.disconnected,
    this.isBusy = false,
    this.errorMessage,
    this.animationSeconds = 0,
  });

  final String localUserId;
  final MagneticHeartRoom? room;
  final List<MagneticHeartMember> members;
  final Set<String> onlineUserIds;
  final Offset localPosition;
  final Offset remotePosition;
  final Offset remoteTargetPosition;
  final bool localIsDragging;
  final bool remoteIsDragging;
  final int? countdownValue;
  final double connectionProgress;
  final bool isCompleted;
  final bool revealStarted;
  final int latestLocalSequence;
  final int latestRemoteSequence;
  final MagneticHeartRealtimeStatus realtimeStatus;
  final bool isBusy;
  final String? errorMessage;
  final double animationSeconds;

  MagneticHeartMember? get localMember {
    for (final member in members) {
      if (member.userId == localUserId) return member;
    }
    return null;
  }

  MagneticHeartMember? get remoteMember {
    for (final member in members) {
      if (member.userId != localUserId) return member;
    }
    return null;
  }

  bool get hasRoom => room != null;
  bool get bothPlayersJoined => members.length == 2;
  bool get localOnline => onlineUserIds.contains(localUserId);
  bool get remoteOnline {
    final remote = remoteMember;
    return remote != null && onlineUserIds.contains(remote.userId);
  }

  bool get bothOnline => localOnline && remoteOnline;
  bool get bothReady =>
      members.length == 2 && members.every((member) => member.isReady);
  bool get isHost => localMember?.role == MagneticHeartRole.host;
  bool get isPlaying => room?.status == MagneticHeartRoomStatus.playing;
  bool get canDrag =>
      isPlaying &&
      bothOnline &&
      !isCompleted &&
      realtimeStatus == MagneticHeartRealtimeStatus.connected;

  Offset get bluePosition => localMember?.nodeColor == MagneticNodeColor.blue
      ? localPosition
      : remotePosition;
  Offset get pinkPosition => localMember?.nodeColor == MagneticNodeColor.pink
      ? localPosition
      : remotePosition;
  bool get blueDragging => localMember?.nodeColor == MagneticNodeColor.blue
      ? localIsDragging
      : remoteIsDragging;
  bool get pinkDragging => localMember?.nodeColor == MagneticNodeColor.pink
      ? localIsDragging
      : remoteIsDragging;

  MagneticHeartGameState copyWith({
    MagneticHeartRoom? room,
    bool clearRoom = false,
    List<MagneticHeartMember>? members,
    Set<String>? onlineUserIds,
    Offset? localPosition,
    Offset? remotePosition,
    Offset? remoteTargetPosition,
    bool? localIsDragging,
    bool? remoteIsDragging,
    int? countdownValue,
    bool clearCountdown = false,
    double? connectionProgress,
    bool? isCompleted,
    bool? revealStarted,
    int? latestLocalSequence,
    int? latestRemoteSequence,
    MagneticHeartRealtimeStatus? realtimeStatus,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    double? animationSeconds,
  }) {
    return MagneticHeartGameState(
      localUserId: localUserId,
      room: clearRoom ? null : room ?? this.room,
      members: members ?? this.members,
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      localPosition: localPosition ?? this.localPosition,
      remotePosition: remotePosition ?? this.remotePosition,
      remoteTargetPosition: remoteTargetPosition ?? this.remoteTargetPosition,
      localIsDragging: localIsDragging ?? this.localIsDragging,
      remoteIsDragging: remoteIsDragging ?? this.remoteIsDragging,
      countdownValue:
          clearCountdown ? null : countdownValue ?? this.countdownValue,
      connectionProgress: connectionProgress ?? this.connectionProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      revealStarted: revealStarted ?? this.revealStarted,
      latestLocalSequence: latestLocalSequence ?? this.latestLocalSequence,
      latestRemoteSequence: latestRemoteSequence ?? this.latestRemoteSequence,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      animationSeconds: animationSeconds ?? this.animationSeconds,
    );
  }
}

DateTime? _date(dynamic value) {
  return value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final text = json[key]?.toString().trim() ?? '';
  if (text.isEmpty) {
    throw FormatException('Missing Magnetic Hearts room field: $key.');
  }
  return text;
}

double _unitValue(dynamic value, double fallback) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.clamp(0.0, 1.0).toDouble();
}
