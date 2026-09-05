import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';
import '../domain/magnetic_heart_models.dart';

class MagneticHeartRepository {
  static const _roomColumns =
      'id, topic, room_code, host_user_id, status, reveal_message, '
      'reveal_image_url, created_at, started_at, play_at, completed_at, '
      'expires_at, updated_at';
  static const _memberColumns =
      'room_id, user_id, username, mascot, role, node_color, is_ready, '
      'joined_at, last_seen_at, node_x, node_y, is_dragging, last_sequence';

  Future<MagneticHeartRoom?> loadCurrentRoom() async {
    _requireUser();
    await supabase.rpc('get_current_magnetic_heart_room');
    final rows = await supabase
        .from('magnetic_heart_rooms')
        .select(_roomColumns)
        .inFilter('status', const ['waiting', 'ready', 'countdown', 'playing'])
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return MagneticHeartRoom.fromJson(rows.first);
  }

  Future<MagneticHeartRoom> createRoom(LocalAccount account) async {
    _requireUser();
    await supabase.rpc(
      'create_magnetic_heart_room',
      params: {
        'p_username': account.username,
        'p_mascot': account.mascot.name,
        'p_reveal_message': 'Two hearts, one little universe.',
      },
    );
    final room = await loadCurrentRoom();
    if (room == null) {
      throw StateError('The Magnetic Hearts room could not be loaded.');
    }
    return room;
  }

  Future<MagneticHeartRoom> joinRoom({
    required String roomCode,
    required LocalAccount account,
  }) async {
    _requireUser();
    await supabase.rpc(
      'join_magnetic_heart_room',
      params: {
        'p_room_code': roomCode.trim().toUpperCase(),
        'p_username': account.username,
        'p_mascot': account.mascot.name,
      },
    );
    final row = await supabase
        .from('magnetic_heart_rooms')
        .select(_roomColumns)
        .eq('room_code', roomCode.trim().toUpperCase())
        .single();
    return MagneticHeartRoom.fromJson(row);
  }

  Future<MagneticHeartRoom> loadRoom(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    final row = await supabase
        .from('magnetic_heart_rooms')
        .select(_roomColumns)
        .eq('id', roomId)
        .single();
    return MagneticHeartRoom.fromJson(row);
  }

  Future<List<MagneticHeartMember>> loadMembers(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    final rows = await supabase
        .from('magnetic_heart_room_members')
        .select(_memberColumns)
        .eq('room_id', roomId)
        .order('joined_at');
    return rows.map(MagneticHeartMember.fromJson).toList(growable: false);
  }

  Stream<MagneticHeartRoom?> watchRoom(String roomId) {
    _requireRoomId(roomId);
    return supabase
        .from('magnetic_heart_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) =>
            rows.isEmpty ? null : MagneticHeartRoom.fromJson(rows.single));
  }

  Stream<List<MagneticHeartMember>> watchMembers(String roomId) {
    _requireRoomId(roomId);
    return supabase
        .from('magnetic_heart_room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .map((rows) {
          final members = rows.map(MagneticHeartMember.fromJson).toList()
            ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return members;
        });
  }

  Future<MagneticHeartRoom> setReady({
    required String roomId,
    required bool ready,
  }) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'set_magnetic_heart_ready',
      params: {'p_room_id': roomId, 'p_ready': ready},
    );
    return loadRoom(roomId);
  }

  Future<MagneticHeartRoom> beginGame(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'begin_magnetic_heart_game',
      params: {'p_room_id': roomId},
    );
    return loadRoom(roomId);
  }

  Future<MagneticHeartRoom> completeGame(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'complete_magnetic_heart_game',
      params: {'p_room_id': roomId},
    );
    return loadRoom(roomId);
  }

  Future<MagneticHeartRoom> resetGame(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'reset_magnetic_heart_game',
      params: {'p_room_id': roomId},
    );
    return loadRoom(roomId);
  }

  Future<MagneticHeartRoom> abandonRoom(String roomId) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'abandon_magnetic_heart_room',
      params: {'p_room_id': roomId},
    );
    return loadRoom(roomId);
  }

  Future<void> persistNodeState({
    required String roomId,
    required double x,
    required double y,
    required bool isDragging,
    required int sequence,
  }) async {
    _requireUser();
    _requireRoomId(roomId);
    await supabase.rpc(
      'persist_magnetic_heart_node_state',
      params: {
        'p_room_id': roomId,
        'p_x': x.clamp(0.0, 1.0),
        'p_y': y.clamp(0.0, 1.0),
        'p_is_dragging': isDragging,
        'p_sequence': sequence,
      },
    );
  }

  void _requireUser() {
    if (supabase.auth.currentUser == null) {
      throw StateError('Your session expired. Please sign in again.');
    }
  }

  void _requireRoomId(String roomId) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(roomId)) {
      throw StateError('The Magnetic Hearts room ID is invalid.');
    }
  }
}
