import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

class PhotoBoothSession {
  const PhotoBoothSession({
    required this.id,
    required this.roomName,
    required this.createdBy,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    required this.captureAt,
    required this.createdAt,
    required this.updatedAt,
    this.participantFrameStyle,
  });

  final String id;
  final String roomName;
  final String createdBy;
  final String status;
  final int currentRound;
  final int totalRounds;
  final DateTime? captureAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? participantFrameStyle;

  bool get isComplete => status == 'complete';
  bool get isCancelled => status == 'cancelled';
  bool get isActive =>
      status == 'lobby' || status == 'countdown' || status == 'capturing';

  factory PhotoBoothSession.fromJson(Map<String, dynamic> json) {
    return PhotoBoothSession(
      id: json['id'] as String,
      roomName: json['room_name'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      status: json['status'] as String? ?? 'lobby',
      currentRound: (json['current_round'] as num?)?.toInt() ?? 0,
      totalRounds: (json['total_rounds'] as num?)?.toInt() ?? 5,
      captureAt: DateTime.tryParse(json['capture_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      participantFrameStyle: json['participant_frame_style'] as String?,
    );
  }
}

class PhotoBoothParticipant {
  const PhotoBoothParticipant({
    required this.sessionId,
    required this.userId,
    required this.frameStyle,
    required this.isReady,
    required this.joinedAt,
  });

  final String sessionId;
  final String userId;
  final String frameStyle;
  final bool isReady;
  final DateTime joinedAt;

  factory PhotoBoothParticipant.fromJson(Map<String, dynamic> json) {
    return PhotoBoothParticipant(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      frameStyle: json['frame_style'] as String? ?? 'vintage',
      isReady: json['is_ready'] as bool? ?? false,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class PhotoBoothPhoto {
  const PhotoBoothPhoto({
    required this.id,
    required this.sessionId,
    required this.roundIndex,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.storagePath,
    required this.createdAt,
    this.imageUrl,
  });

  final String id;
  final String sessionId;
  final int roundIndex;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String storagePath;
  final DateTime createdAt;
  final String? imageUrl;

  // Kept for the strip widget and any older UI callers.
  int get frameIndex => roundIndex;

  factory PhotoBoothPhoto.fromJson(
    Map<String, dynamic> json, {
    String? imageUrl,
  }) {
    return PhotoBoothPhoto(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      roundIndex: (json['round_index'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      storagePath: json['storage_path'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      imageUrl: imageUrl,
    );
  }
}

class LiveKitCredentials {
  const LiveKitCredentials({
    required this.serverUrl,
    required this.participantToken,
  });

  final String serverUrl;
  final String participantToken;
}

class PhotoBoothStore {
  static const bucket = 'photobooth-photos';

  Future<PhotoBoothSession?> loadCurrentSessionForCurrentUser() async {
    _requireUser();
    final row = await supabase.rpc('get_current_photobooth_session');
    final result = _optionalRpcRow(row);
    return result == null ? null : PhotoBoothSession.fromJson(result);
  }

  Stream<PhotoBoothSession?> watchCurrentSession(String sessionId) {
    return supabase
        .from('photobooth_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return PhotoBoothSession.fromJson(rows.single);
        });
  }

  Stream<List<PhotoBoothParticipant>> watchParticipants(String sessionId) {
    return supabase
        .from('photobooth_participants')
        .stream(primaryKey: ['session_id', 'user_id'])
        .eq('session_id', sessionId)
        .map((rows) {
          final participants = rows.map(PhotoBoothParticipant.fromJson).toList()
            ..sort(
                (first, second) => first.joinedAt.compareTo(second.joinedAt));
          return participants;
        });
  }

  Stream<List<PhotoBoothPhoto>> watchPhotos(String sessionId) {
    return supabase
        .from('photobooth_photos')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .asyncMap(_withSignedUrls);
  }

  Future<PhotoBoothSession> createOrJoinSession({
    required String frameStyle,
  }) async {
    _requireUser();
    final row = await supabase.rpc(
      'create_or_join_photobooth_session',
      params: {'p_frame_style': frameStyle},
    );
    return PhotoBoothSession.fromJson(_rpcRow(row));
  }

  Future<PhotoBoothSession> setReady({
    required String sessionId,
    required bool ready,
  }) async {
    _requireUser();
    final row = await supabase.rpc(
      'set_photobooth_participant_ready',
      params: {'p_session_id': sessionId, 'p_ready': ready},
    );
    return PhotoBoothSession.fromJson(_rpcRow(row));
  }

  Future<PhotoBoothSession> beginCapture({
    required String sessionId,
    required int roundIndex,
  }) async {
    _requireUser();
    final row = await supabase.rpc(
      'begin_photobooth_capture',
      params: {'p_session_id': sessionId, 'p_round_index': roundIndex},
    );
    return PhotoBoothSession.fromJson(_rpcRow(row));
  }

  Future<PhotoBoothSession> cancelSession(String sessionId) async {
    _requireUser();
    final row = await supabase.rpc(
      'cancel_photobooth_session',
      params: {'p_session_id': sessionId},
    );
    return PhotoBoothSession.fromJson(_rpcRow(row));
  }

  Future<LiveKitCredentials> requestLiveKitToken(String sessionId) async {
    _requireUser();
    final response = await supabase.functions.invoke(
      'livekit-token',
      body: {'session_id': sessionId},
    );
    final raw = response.data;
    if (raw is! Map) {
      throw StateError(
          'Live camera credentials were not returned by the server.');
    }
    final data = Map<String, dynamic>.from(raw);
    final serverUrl = data['server_url'] as String?;
    final participantToken = data['participant_token'] as String?;
    if (serverUrl == null ||
        serverUrl.isEmpty ||
        participantToken == null ||
        participantToken.isEmpty) {
      throw StateError(
        data['error'] as String? ??
            'Live camera credentials are incomplete. Check LiveKit setup.',
      );
    }
    return LiveKitCredentials(
      serverUrl: serverUrl,
      participantToken: participantToken,
    );
  }

  Future<void> uploadPhoto({
    required PhotoBoothSession session,
    required LocalAccount account,
    required int roundIndex,
    required Uint8List bytes,
  }) async {
    final user = _requireUser();
    final path = '${user.id}/${session.id}/round-$roundIndex.png';
    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
    await supabase.from('photobooth_photos').upsert(
      {
        'session_id': session.id,
        'round_index': roundIndex,
        'user_id': user.id,
        'username': account.username,
        'mascot': account.mascot.name,
        'storage_path': path,
      },
      onConflict: 'session_id,round_index,user_id',
    );
  }

  Future<List<PhotoBoothPhoto>> loadPhotos(String sessionId) async {
    final rows = await supabase
        .from('photobooth_photos')
        .select()
        .eq('session_id', sessionId)
        .order('round_index')
        .order('created_at');
    return _withSignedUrls(rows);
  }

  Future<List<PhotoBoothSession>> loadCompletedSessions({
    String? frameStyle,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    _requireUser();
    final start = startDate == null
        ? null
        : DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          ).toUtc();
    final end = endDate == null
        ? null
        : DateTime(
            endDate.year,
            endDate.month,
            endDate.day + 1,
          ).toUtc();
    final rows = await supabase.rpc(
      'list_completed_photobooth_sessions',
      params: {
        'p_frame_style': frameStyle,
        'p_start_at': start?.toIso8601String(),
        'p_end_at': end?.toIso8601String(),
        'p_limit': limit.clamp(1, 50),
        'p_offset': offset < 0 ? 0 : offset,
      },
    );
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
            (row) => PhotoBoothSession.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<PhotoBoothPhoto>> _withSignedUrls(
    List<Map<String, dynamic>> rows,
  ) async {
    final photos = await Future.wait(
      rows.map((row) async {
        final path = row['storage_path'] as String? ?? '';
        String? url;
        if (path.isNotEmpty) {
          try {
            url =
                await supabase.storage.from(bucket).createSignedUrl(path, 3600);
          } catch (_) {
            url = null;
          }
        }
        return PhotoBoothPhoto.fromJson(row, imageUrl: url);
      }),
    );
    photos.sort((first, second) {
      final byRound = first.roundIndex.compareTo(second.roundIndex);
      if (byRound != 0) return byRound;
      final byUser = first.userId.compareTo(second.userId);
      if (byUser != 0) return byUser;
      return first.createdAt.compareTo(second.createdAt);
    });
    return photos;
  }

  User _requireUser() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Your session expired. Please sign in again.');
    }
    return user;
  }

  Map<String, dynamic> _rpcRow(dynamic row) {
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.length == 1 && row.first is Map) {
      return Map<String, dynamic>.from(row.first as Map);
    }
    throw StateError('Photo Booth database returned an unexpected response.');
  }

  Map<String, dynamic>? _optionalRpcRow(dynamic row) {
    if (row == null || (row is List && row.isEmpty)) return null;
    return _rpcRow(row);
  }
}
