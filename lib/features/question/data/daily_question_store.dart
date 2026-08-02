import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';
import 'daily_question_prompts.dart';

class DailyQuestion {
  const DailyQuestion({required this.question, required this.dayKey});

  final String question;
  final String dayKey;
}

class DailyQuestionComment {
  const DailyQuestionComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.message,
    required this.createdAt,
  });

  factory DailyQuestionComment.fromJson(Map<String, dynamic> json) {
    return DailyQuestionComment(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String message;
  final DateTime createdAt;
}

class DailyQuestionStore {
  static final _v2Start = DateTime.utc(2026, 7, 28);

  String? get currentUserId => supabase.auth.currentUser?.id;

  DailyQuestion questionForNow() => questionForDate(DateTime.now());

  DailyQuestion questionForDate(DateTime date) {
    final dayKey = _dayKey(date);
    final dateParts = dayKey.split('-');
    final effectiveDate = DateTime.utc(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    if (effectiveDate.isBefore(_v2Start)) {
      final index = _stableHash(dayKey) % _dailyQuestions.length;
      return DailyQuestion(question: _dailyQuestions[index], dayKey: dayKey);
    }

    final dayIndex = effectiveDate.difference(_v2Start).inDays;
    return DailyQuestion(
      question: dailyQuestionPrompts[dayIndex % dailyQuestionPrompts.length],
      dayKey: dayKey,
    );
  }

  Stream<List<DailyQuestionComment>> watchComments(String dayKey) {
    return supabase
        .from('daily_question_comments')
        .stream(primaryKey: ['id'])
        .eq('day_key', dayKey)
        .map((rows) {
          final comments =
              rows.map(DailyQuestionComment.fromJson).toList(growable: false);
          return comments..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
  }

  Future<void> addComment({
    required LocalAccount account,
    required String dayKey,
    required String message,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before answering.');
    }

    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw const FormatException('Write an answer before sending.');
    }
    if (cleanMessage.length > 600) {
      throw const FormatException('Keep your answer under 600 characters.');
    }

    await supabase.from('daily_question_comments').insert({
      'day_key': dayKey,
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'message': cleanMessage,
    });

    await PushNotificationService.sendPush(
      type: 'daily_question_comment',
      title: 'New Daily Question answer',
      body: '${account.username}: ${_clip(cleanMessage)}',
    );
  }

  Future<void> deleteComment(String commentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before deleting an answer.');
    }

    await supabase
        .from('daily_question_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', user.id);
  }

  DateTime nextRefreshAt() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 6);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  String _dayKey(DateTime date) {
    final effectiveDate =
        date.hour < 6 ? date.subtract(const Duration(days: 1)) : date;
    final month = effectiveDate.month.toString().padLeft(2, '0');
    final day = effectiveDate.day.toString().padLeft(2, '0');
    return '${effectiveDate.year}-$month-$day';
  }

  int _stableHash(String value) {
    return value.codeUnits.fold<int>(0, (sum, code) => sum * 31 + code).abs();
  }

  String _clip(String text) {
    const maxLength = 72;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength).trim()}...';
  }
}

const _dailyQuestions = <String>[
  'What is one small thing that made today feel lighter?',
  'What do you want us to remember about this season of life?',
  'What is something you are quietly proud of?',
  'What kind of rest do you need today?',
  'What is a dream you still want to make room for?',
  'When do you feel most like yourself?',
  'What is one thing you want to let go of?',
  'What makes a place feel like home to you?',
  'What is something you want to learn this year?',
  'How can I love you better this week?',
  'What memory always makes you smile?',
  'What are you grateful for right now?',
  'What would your future self thank you for?',
  'What does a good day look like for you?',
  'What is something you are looking forward to?',
  'What helps you feel safe and understood?',
  'What value do you want to live by today?',
  'What is one brave thing you can do next?',
  'Which ordinary moment do you never want to take for granted?',
  'What do you want more of in our life together?',
  'What is something your heart has been trying to say?',
  'What would you choose if you were not afraid to start small?',
  'What is one way we can make today softer for each other?',
  'What does love look like in the little things?',
  'What is a lesson life keeps teaching you lately?',
  'What do you wish people understood about you more easily?',
  'What is one boundary that helps protect your peace?',
  'What makes you feel genuinely appreciated?',
  'What is something ordinary that you find beautiful?',
  'What would you like to forgive yourself for?',
  'What kind of person are you becoming?',
  'What is one habit that makes your days better?',
  'What conversation have you been meaning to start?',
  'What makes you feel hopeful about the future?',
  'What is something you want to experience together?',
  'What is one fear you are learning to face?',
  'What part of your childhood still lives in you?',
  'What does being understood feel like to you?',
  'What is one promise you want to keep to yourself?',
  'What do you want your home to feel like?',
  'What is a kindness you still remember receiving?',
  'What do you need more courage for right now?',
  'What is one thing you would like to celebrate today?',
  'What helps you reconnect with yourself?',
  'What is something you have outgrown?',
  'What makes a relationship feel strong to you?',
  'What is one simple joy you want more of this week?',
  'What would you do with an entirely free afternoon?',
  'What is something you want to be more honest about?',
  'What kind of memories do you want us to create?',
  'What does a meaningful life look like to you?',
  'What is one thing you can do today with more patience?',
  'What is a place that changed the way you see life?',
  'What is something you admire in the person beside you?',
  'What do you want to remember when life feels difficult?',
  'What is one choice your future self may be proud of?',
  'What helps you turn a bad day around?',
  'What is something you are ready to begin?',
  'What makes you feel connected even when we are apart?',
  'What is one thing you want to say thank you for?',
  'What does emotional safety mean to you?',
  'What is a small adventure you would enjoy this month?',
  'What part of your life deserves more attention?',
  'What is something you want to make time for again?',
  'What do you hope this next chapter teaches you?',
  'What is one way we can listen to each other better?',
  'What is a dream you are not ready to give up on?',
  'What makes you feel at peace with your choices?',
  'What is something you want to learn about yourself?',
  'What would you tell yourself on a difficult morning?',
  'What is one thing that makes today worth remembering?',
];
