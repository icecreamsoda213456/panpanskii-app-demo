import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

class SentLove {
  const SentLove({
    required this.id,
    required this.username,
    required this.mascot,
    required this.message,
    required this.createdAt,
    this.attachmentPath,
    this.attachmentUrl,
  });

  final String id;
  final String username;
  final AccountMascot mascot;
  final String message;
  final DateTime createdAt;
  final String? attachmentPath;
  final String? attachmentUrl;

  factory SentLove.fromJson(Map<String, dynamic> json,
      {String? attachmentUrl}) {
    return SentLove(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      attachmentPath: json['attachment_path'] as String?,
      attachmentUrl: attachmentUrl,
    );
  }
}

class SentLoveReactionSummary {
  const SentLoveReactionSummary({
    required this.counts,
    required this.myReaction,
    this.reactors = const [],
    this.firstReactorUsername,
    this.firstReactorMascot,
  });

  final Map<String, int> counts;
  final String? myReaction;
  final List<SentLoveReactor> reactors;
  final String? firstReactorUsername;
  final AccountMascot? firstReactorMascot;

  int get totalCount {
    return counts.values.fold<int>(0, (total, count) => total + count);
  }
}

class SentLoveReactor {
  const SentLoveReactor({
    required this.username,
    required this.mascot,
    required this.reaction,
    required this.createdAt,
  });

  final String username;
  final AccountMascot mascot;
  final String reaction;
  final DateTime createdAt;
}

class SentLoveComment {
  const SentLoveComment({
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

  factory SentLoveComment.fromJson(Map<String, dynamic> json) {
    return SentLoveComment(
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

class SendLoveStore {
  static const _bucket = 'send-love-attachments';
  static const _columns =
      'id, username, mascot, message, attachment_path, created_at';
  static const _reactionColumns =
      'reaction, user_id, username, mascot, created_at';
  static const _commentColumns = 'id, username, mascot, message, created_at';

  Future<SentLove> sendLove({
    required LocalAccount account,
    required String message,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentContentType,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before sending love.');
    }

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw const FormatException('Love letter cannot be empty.');
    }

    final attachmentPath = attachmentBytes == null
        ? null
        : await _uploadAttachment(
            userId: user.id,
            bytes: attachmentBytes,
            name: attachmentName,
            contentType: attachmentContentType,
          );

    final row = await supabase
        .from('send_love_letters')
        .insert({
          'user_id': user.id,
          'username': account.username,
          'mascot': account.mascot.name,
          'message': cleanMessage,
          'attachment_path': attachmentPath,
        })
        .select(_columns)
        .single();

    final attachmentUrl = attachmentPath == null
        ? null
        : await supabase.storage
            .from(_bucket)
            .createSignedUrl(attachmentPath, 60 * 60);

    await PushNotificationService.sendPush(
      type: 'send_love',
      title: 'New love letter',
      body: attachmentPath == null
          ? '${account.username} sent a love letter.'
          : '${account.username} sent love with a photo.',
    );

    return SentLove.fromJson(row, attachmentUrl: attachmentUrl);
  }

  Future<List<SentLove>> loadSentLoveLetters() async {
    final rows = await supabase
        .from('send_love_letters')
        .select(_columns)
        .order('created_at', ascending: false)
        .limit(30);

    final letters = <SentLove>[];
    for (final row in rows) {
      final attachmentPath = row['attachment_path'] as String?;
      final attachmentUrl = attachmentPath == null
          ? null
          : await supabase.storage
              .from(_bucket)
              .createSignedUrl(attachmentPath, 60 * 60);
      letters.add(SentLove.fromJson(row, attachmentUrl: attachmentUrl));
    }
    return letters;
  }

  Future<SentLoveReactionSummary> loadReactionSummary(String letterId) async {
    final userId = supabase.auth.currentUser?.id;
    final rows = await supabase
        .from('send_love_reactions')
        .select(_reactionColumns)
        .eq('letter_id', letterId)
        .order('created_at', ascending: true);

    final counts = <String, int>{};
    final reactors = <SentLoveReactor>[];
    String? myReaction;
    String? firstReactorUsername;
    AccountMascot? firstReactorMascot;
    for (final row in rows) {
      final reaction = row['reaction'] as String? ?? '';
      if (reaction.isEmpty) {
        continue;
      }
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      reactors.add(
        SentLoveReactor(
          username: row['username'] as String? ?? 'panpanskii',
          mascot: AccountMascot.fromName(row['mascot'] as String? ?? 'panda'),
          reaction: reaction,
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')
                  ?.toLocal() ??
              DateTime.now(),
        ),
      );
      if (userId != null && row['user_id'] == userId) {
        myReaction = reaction;
      }
      firstReactorUsername ??= row['username'] as String?;
      firstReactorMascot ??= AccountMascot.fromName(
        row['mascot'] as String? ?? 'panda',
      );
    }

    return SentLoveReactionSummary(
      counts: counts,
      myReaction: myReaction,
      reactors: reactors,
      firstReactorUsername: firstReactorUsername,
      firstReactorMascot: firstReactorMascot,
    );
  }

  Future<void> toggleReaction({
    required LocalAccount account,
    required String letterId,
    required String reaction,
    required String? currentReaction,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before reacting.');
    }

    if (currentReaction == reaction) {
      await supabase
          .from('send_love_reactions')
          .delete()
          .eq('letter_id', letterId)
          .eq('user_id', user.id);
      return;
    }

    await supabase.from('send_love_reactions').upsert(
      {
        'letter_id': letterId,
        'user_id': user.id,
        'username': account.username,
        'mascot': account.mascot.name,
        'reaction': reaction,
      },
      onConflict: 'letter_id,user_id',
    );
  }

  Future<List<SentLoveComment>> loadComments(String letterId) async {
    final rows = await supabase
        .from('send_love_comments')
        .select(_commentColumns)
        .eq('letter_id', letterId)
        .order('created_at', ascending: true)
        .limit(12);

    return rows.map((row) => SentLoveComment.fromJson(row)).toList();
  }

  Future<void> addComment({
    required LocalAccount account,
    required String letterId,
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

    await supabase.from('send_love_comments').insert({
      'letter_id': letterId,
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'message': cleanMessage,
    });

    await PushNotificationService.sendPush(
      type: 'send_love_comment',
      title: 'New love letter comment',
      body: '${account.username}: ${_clip(cleanMessage)}',
    );
  }

  Future<String> _uploadAttachment({
    required String userId,
    required Uint8List bytes,
    required String? name,
    required String? contentType,
  }) async {
    final extension = _extensionFor(name, contentType);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType ?? 'image/jpeg',
            upsert: false,
          ),
        );

    return path;
  }

  String _extensionFor(String? name, String? contentType) {
    final lowerName = name?.toLowerCase() ?? '';
    if (lowerName.endsWith('.png') || contentType == 'image/png') {
      return 'png';
    }
    if (lowerName.endsWith('.webp') || contentType == 'image/webp') {
      return 'webp';
    }
    return 'jpg';
  }

  String _clip(String text) {
    const maxLength = 72;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength).trim()}...';
  }
}
