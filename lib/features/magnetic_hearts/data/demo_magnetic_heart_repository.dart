import 'dart:async';
import 'dart:ui';

import '../../../core/demo/demo_store.dart';
import '../../auth/data/local_account_store.dart';
import '../domain/magnetic_heart_models.dart';
import 'magnetic_heart_repository.dart';

/// A local practice partner; never opens a realtime channel.
class DemoMagneticHeartRepository extends MagneticHeartRepository {
  MagneticHeartRoom? _room;
  List<MagneticHeartMember> _members = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Future<MagneticHeartRoom?> loadCurrentRoom() async => _room;

  @override
  Future<MagneticHeartRoom> createRoom(LocalAccount account) async {
    final now = DateTime.now().toUtc();
    _room = MagneticHeartRoom(
      id: '33333333-3333-4333-8333-333333333333',
      topic: 'local-practice',
      roomCode: 'DEMO01',
      hostUserId: DemoStore.userId,
      status: MagneticHeartRoomStatus.waiting,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 2)),
      revealMessage: 'Alex + Sam. Small moments, shared together.',
    );
    _members = [
      for (final profile in [DemoStore.profile, DemoStore.partner])
        MagneticHeartMember(
            roomId: _room!.id,
            userId: profile['user_id']!,
            username: profile['user_id'] == DemoStore.partnerId
                ? 'Sam (demo)'
                : 'Alex',
            mascot: profile['mascot']!,
            role: profile['user_id'] == DemoStore.userId
                ? MagneticHeartRole.host
                : MagneticHeartRole.guest,
            nodeColor: profile['user_id'] == DemoStore.userId
                ? MagneticNodeColor.blue
                : MagneticNodeColor.pink,
            isReady: profile['user_id'] == DemoStore.partnerId,
            joinedAt: now,
            lastSeenAt: now,
            nodePosition: profile['user_id'] == DemoStore.userId
                ? const Offset(.22, .58)
                : const Offset(.78, .58),
            isDragging: false,
            lastSequence: 0),
    ];
    _changes.add(null);
    return _room!;
  }

  @override
  Future<MagneticHeartRoom> joinRoom(
      {required String roomCode, required LocalAccount account}) async {
    if (roomCode.trim().toUpperCase() != 'DEMO01') {
      throw StateError('This offline practice room uses code DEMO01.');
    }
    return createRoom(account);
  }

  @override
  Future<MagneticHeartRoom> loadRoom(String roomId) async => _room!;

  @override
  Future<List<MagneticHeartMember>> loadMembers(String roomId) async =>
      List.of(_members);

  @override
  Stream<MagneticHeartRoom?> watchRoom(String roomId) =>
      Stream.multi((controller) {
        final subscription =
            _changes.stream.listen((_) => controller.add(_room));
        controller.add(_room);
        controller.onCancel = subscription.cancel;
      });

  @override
  Stream<List<MagneticHeartMember>> watchMembers(String roomId) =>
      Stream.multi((controller) {
        final subscription =
            _changes.stream.listen((_) => controller.add(List.of(_members)));
        controller.add(List.of(_members));
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<MagneticHeartRoom> setReady(
      {required String roomId, required bool ready}) async {
    _members = _members
        .map((member) => member.copyWith(
            isReady: member.userId == DemoStore.userId ? ready : true))
        .toList();
    _room = _room!.copyWith(
        status: ready
            ? MagneticHeartRoomStatus.countdown
            : MagneticHeartRoomStatus.waiting,
        playAt: DateTime.now().toUtc().add(const Duration(seconds: 3)));
    _changes.add(null);
    return _room!;
  }

  @override
  Future<MagneticHeartRoom> beginGame(String roomId) async {
    _room = _room!.copyWith(status: MagneticHeartRoomStatus.playing);
    _changes.add(null);
    return _room!;
  }

  @override
  Future<MagneticHeartRoom> completeGame(String roomId) async {
    _room = _room!.copyWith(
        status: MagneticHeartRoomStatus.completed,
        completedAt: DateTime.now().toUtc());
    _changes.add(null);
    return _room!;
  }

  @override
  Future<MagneticHeartRoom> resetGame(String roomId) =>
      createRoom(const LocalAccount(
          username: 'Alex',
          mascot: AccountMascot.panda,
          isBiometricEnabled: false));

  @override
  Future<MagneticHeartRoom> abandonRoom(String roomId) async {
    _room = _room!.copyWith(status: MagneticHeartRoomStatus.abandoned);
    _changes.add(null);
    return _room!;
  }

  @override
  Future<void> persistNodeState(
      {required String roomId,
      required double x,
      required double y,
      required bool isDragging,
      required int sequence}) async {}

  Future<void> dispose() => _changes.close();
}
