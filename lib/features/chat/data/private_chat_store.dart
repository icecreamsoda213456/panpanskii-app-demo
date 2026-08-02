import '../../../core/supabase/supabase.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../auth/data/local_account_store.dart';

class PrivateChatMessage {
  const PrivateChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String message;
  final DateTime createdAt;

  bool get isMine => supabase.auth.currentUser?.id == userId;

  factory PrivateChatMessage.fromJson(Map<String, dynamic> json) {
    return PrivateChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class PrivateChatReaction {
  const PrivateChatReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.reaction,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String reaction;
  final DateTime createdAt;

  bool get isMine => supabase.auth.currentUser?.id == userId;

  factory PrivateChatReaction.fromJson(Map<String, dynamic> json) {
    return PrivateChatReaction(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      reaction: json['reaction'] as String? ?? 'love',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class PrivateChatStore {
  static const _roomId = 'main';
  static const _columns = 'id, user_id, username, mascot, message, created_at';

  Stream<List<PrivateChatMessage>> watchMessages() {
    return supabase
        .from('private_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', _roomId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) {
          final messages = rows
              .map((row) => PrivateChatMessage.fromJson(row))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Stream<List<PrivateChatReaction>> watchReactions() {
    return supabase
        .from('private_chat_reactions')
        .stream(primaryKey: ['id']).map(
      (rows) => rows.map((row) => PrivateChatReaction.fromJson(row)).toList(),
    );
  }

  Future<void> toggleReaction({
    required LocalAccount account,
    required String messageId,
    required String reaction,
    required String? currentReaction,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before reacting.');
    }

    if (currentReaction == reaction) {
      await supabase
          .from('private_chat_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', user.id);
      return;
    }

    await supabase.from('private_chat_reactions').upsert(
      {
        'message_id': messageId,
        'user_id': user.id,
        'username': account.username,
        'mascot': account.mascot.name,
        'reaction': reaction,
      },
      onConflict: 'message_id,user_id',
    );
  }

  Future<void> sendMessage({
    required LocalAccount account,
    required String message,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before chatting.');
    }

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return;
    }

    await supabase.from('private_chat_messages').insert({
      'room_id': _roomId,
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'message': cleanMessage,
    }).select(_columns);

    await PushNotificationService.sendPush(
      type: 'private_chat',
      title: 'New private chat',
      body: '${account.username}: ${_clip(cleanMessage)}',
    );
  }

  String _clip(String text) {
    const maxLength = 72;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength).trim()}...';
  }
}
