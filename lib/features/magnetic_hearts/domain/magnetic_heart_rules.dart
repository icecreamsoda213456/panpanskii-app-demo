import 'dart:math' as math;
import 'dart:ui';

import 'magnetic_heart_models.dart';

class MagneticHeartRules {
  const MagneticHeartRules._();

  static const holdDuration = Duration(seconds: 2);
  static const movementInterval = Duration(milliseconds: 40);
  static const persistenceInterval = Duration(milliseconds: 500);
  static const nodeRadius = 34.0;

  static Offset normalizePosition(Offset position, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return Offset.zero;
    }
    return Offset(
      (position.dx / canvasSize.width).clamp(0.0, 1.0).toDouble(),
      (position.dy / canvasSize.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  static Offset denormalizePosition(Offset position, Size canvasSize) {
    return Offset(
      position.dx.clamp(0.0, 1.0).toDouble() * canvasSize.width,
      position.dy.clamp(0.0, 1.0).toDouble() * canvasSize.height,
    );
  }

  static Offset clampToCanvas(
    Offset position,
    Size canvasSize, {
    double radius = nodeRadius,
  }) {
    if (canvasSize.width <= radius * 2 || canvasSize.height <= radius * 2) {
      return Offset(canvasSize.width / 2, canvasSize.height / 2);
    }
    return Offset(
      position.dx.clamp(radius, canvasSize.width - radius).toDouble(),
      position.dy.clamp(radius, canvasSize.height - radius).toDouble(),
    );
  }

  static bool ownsNode({
    required MagneticHeartRole role,
    required MagneticNodeColor node,
  }) {
    return (role == MagneticHeartRole.host && node == MagneticNodeColor.blue) ||
        (role == MagneticHeartRole.guest && node == MagneticNodeColor.pink);
  }

  static bool shouldAcceptSequence({
    required int incoming,
    required int latest,
  }) {
    return incoming > latest;
  }

  static bool isFiniteCoordinate(dynamic value) {
    return value is num && value.toDouble().isFinite;
  }

  static Offset? normalizedPositionFromPayload(Map<String, dynamic> payload) {
    final x = payload['x'];
    final y = payload['y'];
    if (!isFiniteCoordinate(x) || !isFiniteCoordinate(y)) return null;
    return Offset(
      (x as num).toDouble().clamp(0.0, 1.0).toDouble(),
      (y as num).toDouble().clamp(0.0, 1.0).toDouble(),
    );
  }

  static bool isOwnedMovePayload({
    required Map<String, dynamic> payload,
    required String roomId,
    required MagneticHeartMember sender,
  }) {
    if (payload['roomId']?.toString() != roomId ||
        payload['userId']?.toString() != sender.userId ||
        payload['role']?.toString() != sender.role.name ||
        payload['node']?.toString() != sender.nodeColor.name) {
      return false;
    }
    return ownsNode(role: sender.role, node: sender.nodeColor);
  }

  static double connectionThreshold(Size canvasSize) {
    return math.min(canvasSize.width, canvasSize.height) * 0.12;
  }

  static bool connectionCondition({
    required Offset bluePosition,
    required Offset pinkPosition,
    required Size canvasSize,
    required bool blueDragging,
    required bool pinkDragging,
    required bool blueOnline,
    required bool pinkOnline,
    required bool gameIsPlaying,
  }) {
    if (!gameIsPlaying ||
        !blueOnline ||
        !pinkOnline ||
        !blueDragging ||
        !pinkDragging) {
      return false;
    }
    final blue = denormalizePosition(bluePosition, canvasSize);
    final pink = denormalizePosition(pinkPosition, canvasSize);
    return (blue - pink).distance <= connectionThreshold(canvasSize);
  }

  static double calculateConnectionProgress({
    required double currentProgress,
    required double deltaSeconds,
    required Offset bluePosition,
    required Offset pinkPosition,
    required Size canvasSize,
    required bool blueDragging,
    required bool pinkDragging,
    required bool blueOnline,
    required bool pinkOnline,
    required bool gameIsPlaying,
  }) {
    if (gameIsPlaying && (!blueOnline || !pinkOnline)) {
      return currentProgress.clamp(0.0, 1.0).toDouble();
    }
    final valid = connectionCondition(
      bluePosition: bluePosition,
      pinkPosition: pinkPosition,
      canvasSize: canvasSize,
      blueDragging: blueDragging,
      pinkDragging: pinkDragging,
      blueOnline: blueOnline,
      pinkOnline: pinkOnline,
      gameIsPlaying: gameIsPlaying,
    );
    if (valid) {
      return (currentProgress +
              deltaSeconds / holdDuration.inMilliseconds * 1000)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    return (currentProgress - deltaSeconds * 1.5).clamp(0.0, 1.0).toDouble();
  }

  static bool hasValidPlayerPair(List<MagneticHeartMember> members) {
    if (members.length != 2 || members[0].userId == members[1].userId) {
      return false;
    }
    final roles = members.map((member) => member.role).toSet();
    final nodes = members.map((member) => member.nodeColor).toSet();
    return roles.length == 2 &&
        nodes.length == 2 &&
        members.every(
          (member) => ownsNode(role: member.role, node: member.nodeColor),
        );
  }

  static bool shouldFinalizeCompletion({
    required bool isHost,
    required bool alreadyCompleted,
    required bool completionInFlight,
    required double progress,
  }) {
    return isHost && !alreadyCompleted && !completionInFlight && progress >= 1;
  }

  static Offset smoothRemotePosition({
    required Offset current,
    required Offset target,
    required double deltaSeconds,
  }) {
    final amount = (deltaSeconds * 12).clamp(0.0, 1.0).toDouble();
    return Offset.lerp(current, target, amount) ?? target;
  }

  static int? countdownValue(DateTime? playAt, DateTime now) {
    if (playAt == null) return null;
    final milliseconds = playAt.difference(now.toUtc()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil().clamp(1, 3).toInt();
  }
}
