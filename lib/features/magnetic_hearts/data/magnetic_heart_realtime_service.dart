import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase.dart';
import '../domain/magnetic_heart_models.dart';

typedef MagneticHeartEventCallback = void Function(
  String event,
  Map<String, dynamic> payload,
);

class MagneticHeartRealtimeService {
  MagneticHeartRealtimeService({
    required this.room,
    required this.member,
  });

  final MagneticHeartRoom room;
  final MagneticHeartMember member;

  RealtimeChannel? _channel;
  bool _disposed = false;

  MagneticHeartEventCallback? onEvent;
  void Function(List<SinglePresenceState> states)? onPresenceChanged;
  void Function(RealtimeSubscribeStatus status, Object? error)?
      onConnectionChanged;

  bool get isConnected => _channel != null && !_disposed;

  Future<void> connect() async {
    if (_channel != null || _disposed) return;

    final channel = supabase.channel(
      room.topic,
      opts: RealtimeChannelConfig(
        private: true,
        self: false,
        ack: true,
        enabled: true,
        key: member.userId,
      ),
    );
    _channel = channel;

    for (final event in const [
      'node_move',
      'drag_start',
      'drag_end',
      'ready_changed',
      'countdown_started',
      'game_completed',
      'game_reset',
      'partner_reconnected',
    ]) {
      channel.onBroadcast(
        event: event,
        callback: (payload) => onEvent?.call(event, payload),
      );
    }

    channel
        .onPresenceSync((_) => _emitPresence())
        .onPresenceJoin((_) => _emitPresence())
        .onPresenceLeave((_) => _emitPresence())
        .subscribe((status, error) async {
      if (_disposed) return;
      onConnectionChanged?.call(status, error);
      if (status == RealtimeSubscribeStatus.subscribed) {
        await trackPresence(ready: member.isReady);
      }
    });
  }

  Future<void> trackPresence({required bool ready}) async {
    final channel = _channel;
    if (channel == null || _disposed) return;
    await channel.track({
      'userId': member.userId,
      'role': member.role.name,
      'nodeColor': member.nodeColor.name,
      'ready': ready,
      'joinedAt': member.joinedAt.toIso8601String(),
      'onlineAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> untrackPresence() async {
    final channel = _channel;
    if (channel == null || _disposed) return;
    await channel.untrack();
  }

  void emitPresenceSnapshot() {
    _emitPresence();
  }

  Future<void> sendNodeMove({
    required double x,
    required double y,
    required bool isDragging,
    required int sequence,
  }) {
    return sendEvent('node_move', {
      'role': member.role.name,
      'node': member.nodeColor.name,
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'isDragging': isDragging,
      'sequence': sequence,
    });
  }

  Future<void> sendEvent(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final channel = _channel;
    if (channel == null || _disposed) return;
    await channel.sendBroadcastMessage(
      event: event,
      payload: {
        ...payload,
        'roomId': room.id,
        'userId': member.userId,
        'sentAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  void _emitPresence() {
    final channel = _channel;
    if (channel == null || _disposed) return;
    onPresenceChanged?.call(channel.presenceState());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await channel.untrack();
    } finally {
      await supabase.removeChannel(channel);
    }
  }
}
