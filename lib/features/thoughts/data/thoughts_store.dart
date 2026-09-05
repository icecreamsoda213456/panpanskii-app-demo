import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

class ThoughtPost {
  const ThoughtPost({
    required this.id,
    required this.username,
    required this.mascot,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String username;
  final AccountMascot mascot;
  final String body;
  final DateTime createdAt;

  factory ThoughtPost.fromJson(Map<String, dynamic> json) {
    return ThoughtPost(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class ThoughtReactionSummary {
  const ThoughtReactionSummary({
    required this.counts,
    required this.myReaction,
  });

  final Map<String, int> counts;
  final String? myReaction;

  int get totalCount {
    return counts.values.fold<int>(0, (total, count) => total + count);
  }
}

class ThoughtComment {
  const ThoughtComment({
    required this.id,
    required this.username,
    required this.mascot,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String username;
  final AccountMascot mascot;
  final String message;
  final DateTime createdAt;

  factory ThoughtComment.fromJson(Map<String, dynamic> json) {
    return ThoughtComment(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class ThoughtsStore {
  static const _postColumns = 'id, username, mascot, body, created_at';
  static const _reactionColumns = 'reaction, user_id';
  static const _commentColumns = 'id, username, mascot, message, created_at';

  Future<List<ThoughtPost>> loadThoughts() async {
    final rows = await supabase
        .from('thought_posts')
        .select(_postColumns)
        .order('created_at', ascending: false)
        .limit(30);

    return rows.map((row) => ThoughtPost.fromJson(row)).toList();
  }

  Future<void> createThought({
    required LocalAccount account,
    required String body,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before writing thoughts.');
    }

    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      throw const FormatException('Thought cannot be empty.');
    }

    await supabase.from('thought_posts').insert({
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'body': cleanBody,
    });

    await PushNotificationService.sendPush(
      type: 'thought',
      title: 'New shared thought',
      body: '${account.username}: ${_clip(cleanBody)}',
    );
  }

  Future<ThoughtReactionSummary> loadReactionSummary(String thoughtId) async {
    final userId = supabase.auth.currentUser?.id;
    final rows = await supabase
        .from('thought_reactions')
        .select(_reactionColumns)
        .eq('thought_id', thoughtId);

    final counts = <String, int>{};
    String? myReaction;
    for (final row in rows) {
      final reaction = row['reaction'] as String? ?? '';
      if (reaction.isEmpty) {
        continue;
      }
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      if (userId != null && row['user_id'] == userId) {
        myReaction = reaction;
      }
    }

    return ThoughtReactionSummary(counts: counts, myReaction: myReaction);
  }

  Future<void> toggleReaction({
    required LocalAccount account,
    required String thoughtId,
    required String reaction,
    required String? currentReaction,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before reacting.');
    }

    if (currentReaction == reaction) {
      await supabase
          .from('thought_reactions')
          .delete()
          .eq('thought_id', thoughtId)
          .eq('user_id', user.id);
      return;
    }

    await supabase.from('thought_reactions').upsert(
      {
        'thought_id': thoughtId,
        'user_id': user.id,
        'username': account.username,
        'mascot': account.mascot.name,
        'reaction': reaction,
      },
      onConflict: 'thought_id,user_id',
    );
  }

  Future<List<ThoughtComment>> loadComments(String thoughtId) async {
    final rows = await supabase
        .from('thought_comments')
        .select(_commentColumns)
        .eq('thought_id', thoughtId)
        .order('created_at', ascending: true)
        .limit(12);

    return rows.map((row) => ThoughtComment.fromJson(row)).toList();
  }

  Future<void> addComment({
    required LocalAccount account,
    required String thoughtId,
    required String message,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before commenting.');
    }

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return;
    }

    await supabase.from('thought_comments').insert({
      'thought_id': thoughtId,
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'message': cleanMessage,
    });

    await PushNotificationService.sendPush(
      type: 'thought_comment',
      title: 'New thought comment',
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
