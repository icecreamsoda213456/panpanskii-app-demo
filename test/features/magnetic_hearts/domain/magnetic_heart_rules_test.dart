import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/features/magnetic_hearts/domain/magnetic_heart_models.dart';
import 'package:panpanskii_app/features/magnetic_hearts/domain/magnetic_heart_rules.dart';

void main() {
  const canvas = Size(400, 800);

  group('MagneticHeartRules coordinates', () {
    test('normalizes and denormalizes across different screen sizes', () {
      const pixels = Offset(100, 600);
      final normalized = MagneticHeartRules.normalizePosition(pixels, canvas);
      expect(normalized, const Offset(0.25, 0.75));
      expect(
        MagneticHeartRules.denormalizePosition(normalized, canvas),
        pixels,
      );
    });

    test('clamps normalized movement payload coordinates', () {
      final position = MagneticHeartRules.normalizedPositionFromPayload({
        'x': -4.0,
        'y': 8.0,
      });
      expect(position, const Offset(0, 1));
    });

    test('rejects non-finite movement coordinates', () {
      expect(
        MagneticHeartRules.normalizedPositionFromPayload({
          'x': double.nan,
          'y': 0.4,
        }),
        isNull,
      );
    });
  });

  group('MagneticHeartRules ownership and sequencing', () {
    test('host owns only blue and guest owns only pink', () {
      expect(
        MagneticHeartRules.ownsNode(
          role: MagneticHeartRole.host,
          node: MagneticNodeColor.blue,
        ),
        isTrue,
      );
      expect(
        MagneticHeartRules.ownsNode(
          role: MagneticHeartRole.host,
          node: MagneticNodeColor.pink,
        ),
        isFalse,
      );
      expect(
        MagneticHeartRules.ownsNode(
          role: MagneticHeartRole.guest,
          node: MagneticNodeColor.pink,
        ),
        isTrue,
      );
    });

    test('old and duplicate sequence messages are ignored', () {
      expect(
        MagneticHeartRules.shouldAcceptSequence(incoming: 11, latest: 10),
        isTrue,
      );
      expect(
        MagneticHeartRules.shouldAcceptSequence(incoming: 10, latest: 10),
        isFalse,
      );
      expect(
        MagneticHeartRules.shouldAcceptSequence(incoming: 9, latest: 10),
        isFalse,
      );
    });

    test('a sender cannot claim the partner node', () {
      final host = _member(
        userId: 'host-user',
        role: MagneticHeartRole.host,
        node: MagneticNodeColor.blue,
      );
      expect(
        MagneticHeartRules.isOwnedMovePayload(
          payload: const {
            'roomId': 'room-1',
            'userId': 'host-user',
            'role': 'host',
            'node': 'pink',
          },
          roomId: 'room-1',
          sender: host,
        ),
        isFalse,
      );
    });

    test('valid pair requires two distinct fixed player assignments', () {
      final host = _member(
        userId: 'host-user',
        role: MagneticHeartRole.host,
        node: MagneticNodeColor.blue,
      );
      final guest = _member(
        userId: 'guest-user',
        role: MagneticHeartRole.guest,
        node: MagneticNodeColor.pink,
      );
      expect(MagneticHeartRules.hasValidPlayerPair([host, guest]), isTrue);
      expect(MagneticHeartRules.hasValidPlayerPair([host, host]), isFalse);
      expect(
        MagneticHeartRules.hasValidPlayerPair([
          host,
          _member(
            userId: 'host-user',
            role: MagneticHeartRole.guest,
            node: MagneticNodeColor.pink,
          ),
        ]),
        isFalse,
      );
      expect(
        MagneticHeartRules.hasValidPlayerPair([
          host,
          guest,
          _member(
            userId: 'third-user',
            role: MagneticHeartRole.guest,
            node: MagneticNodeColor.pink,
          ),
        ]),
        isFalse,
      );
    });
  });

  group('MagneticHeartRules connection', () {
    test('threshold is twelve percent of the shortest canvas side', () {
      expect(MagneticHeartRules.connectionThreshold(canvas), 48);
    });

    test('both players must actively drag inside the threshold', () {
      expect(
        MagneticHeartRules.connectionCondition(
          bluePosition: const Offset(0.48, 0.5),
          pinkPosition: const Offset(0.52, 0.5),
          canvasSize: canvas,
          blueDragging: true,
          pinkDragging: false,
          blueOnline: true,
          pinkOnline: true,
          gameIsPlaying: true,
        ),
        isFalse,
      );
      expect(
        MagneticHeartRules.connectionCondition(
          bluePosition: const Offset(0.48, 0.5),
          pinkPosition: const Offset(0.52, 0.5),
          canvasSize: canvas,
          blueDragging: true,
          pinkDragging: true,
          blueOnline: true,
          pinkOnline: true,
          gameIsPlaying: true,
        ),
        isTrue,
      );
    });

    test('two continuous seconds are required for full progress', () {
      var progress = 0.0;
      for (var index = 0; index < 19; index += 1) {
        progress = _advance(progress, 0.1);
      }
      expect(progress, closeTo(0.95, 0.0001));
      progress = _advance(progress, 0.1);
      expect(progress, 1);
    });

    test('progress falls when either player releases', () {
      final progress = MagneticHeartRules.calculateConnectionProgress(
        currentProgress: 0.8,
        deltaSeconds: 0.2,
        bluePosition: const Offset(0.49, 0.5),
        pinkPosition: const Offset(0.51, 0.5),
        canvasSize: canvas,
        blueDragging: true,
        pinkDragging: false,
        blueOnline: true,
        pinkOnline: true,
        gameIsPlaying: true,
      );
      expect(progress, closeTo(0.5, 0.0001));
    });

    test('progress pauses while a player is disconnected', () {
      final progress = MagneticHeartRules.calculateConnectionProgress(
        currentProgress: 0.62,
        deltaSeconds: 1,
        bluePosition: const Offset(0.49, 0.5),
        pinkPosition: const Offset(0.51, 0.5),
        canvasSize: canvas,
        blueDragging: true,
        pinkDragging: true,
        blueOnline: true,
        pinkOnline: false,
        gameIsPlaying: true,
      );
      expect(progress, 0.62);
    });

    test('only the host can finalize and completion happens once', () {
      expect(
        MagneticHeartRules.shouldFinalizeCompletion(
          isHost: true,
          alreadyCompleted: false,
          completionInFlight: false,
          progress: 1,
        ),
        isTrue,
      );
      expect(
        MagneticHeartRules.shouldFinalizeCompletion(
          isHost: false,
          alreadyCompleted: false,
          completionInFlight: false,
          progress: 1,
        ),
        isFalse,
      );
      expect(
        MagneticHeartRules.shouldFinalizeCompletion(
          isHost: true,
          alreadyCompleted: true,
          completionInFlight: false,
          progress: 1,
        ),
        isFalse,
      );
    });
  });

  group('MagneticHeartRoom parsing', () {
    test('accepts a complete room row', () {
      final room = MagneticHeartRoom.fromJson(const {
        'id': '11111111-1111-4111-8111-111111111111',
        'topic': 'magnetic-hearts',
        'room_code': 'ABC123',
        'host_user_id': '22222222-2222-4222-8222-222222222222',
        'status': 'waiting',
        'created_at': '2026-08-02T00:00:00Z',
        'expires_at': '2026-08-02T02:00:00Z',
        'updated_at': '2026-08-02T00:00:00Z',
      });

      expect(room.id, '11111111-1111-4111-8111-111111111111');
      expect(room.roomCode, 'ABC123');
    });

    test('rejects an RPC payload without a room UUID', () {
      expect(
        () => MagneticHeartRoom.fromJson(const {
          'topic': 'magnetic-hearts',
          'room_code': 'ABC123',
          'host_user_id': '22222222-2222-4222-8222-222222222222',
          'status': 'waiting',
        }),
        throwsFormatException,
      );
    });
  });

  test('persisted member state can restore a reconnecting node', () {
    final member = MagneticHeartMember.fromJson(const {
      'room_id': 'room-1',
      'user_id': 'guest-user',
      'username': 'Koala',
      'mascot': 'koala',
      'role': 'guest',
      'node_color': 'pink',
      'is_ready': true,
      'joined_at': '2026-08-02T00:00:00Z',
      'last_seen_at': '2026-08-02T00:01:00Z',
      'node_x': 0.63,
      'node_y': 0.41,
      'is_dragging': false,
      'last_sequence': 42,
    });
    expect(member.nodePosition, const Offset(0.63, 0.41));
    expect(member.lastSequence, 42);
    expect(member.nodeColor, MagneticNodeColor.pink);
  });
}

double _advance(double current, double delta) {
  return MagneticHeartRules.calculateConnectionProgress(
    currentProgress: current,
    deltaSeconds: delta,
    bluePosition: const Offset(0.49, 0.5),
    pinkPosition: const Offset(0.51, 0.5),
    canvasSize: const Size(400, 800),
    blueDragging: true,
    pinkDragging: true,
    blueOnline: true,
    pinkOnline: true,
    gameIsPlaying: true,
  );
}

MagneticHeartMember _member({
  required String userId,
  required MagneticHeartRole role,
  required MagneticNodeColor node,
}) {
  return MagneticHeartMember(
    roomId: 'room-1',
    userId: userId,
    username: userId,
    mascot: 'panda',
    role: role,
    nodeColor: node,
    isReady: false,
    joinedAt: DateTime.utc(2026, 8, 2),
    lastSeenAt: DateTime.utc(2026, 8, 2),
    nodePosition: role == MagneticHeartRole.host
        ? const Offset(0.22, 0.58)
        : const Offset(0.78, 0.58),
    isDragging: false,
    lastSequence: 0,
  );
}
