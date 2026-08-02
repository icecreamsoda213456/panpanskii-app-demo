import '../../auth/data/local_account_store.dart';
import '../../../core/supabase/supabase.dart';
import 'daily_duo_prompts.dart';

class DailyDuoRound {
  const DailyDuoRound({
    required this.dayKey,
    required this.prompt,
    required this.options,
  });

  final String dayKey;
  final String prompt;
  final List<String> options;
}

class DailyDuoAnswer {
  const DailyDuoAnswer({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.optionIndex,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final int optionIndex;
  final DateTime updatedAt;

  factory DailyDuoAnswer.fromJson(Map<String, dynamic> json) {
    return DailyDuoAnswer(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      optionIndex: (json['option_index'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class DailyDuoStore {
  static const _columns =
      'id, user_id, username, mascot, option_index, updated_at';

  DailyDuoRound roundForNow() {
    final now = DateTime.now();
    final dayKey = _dayKey(now);
    final parts = dayKey.split('-');
    final effectiveDate = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final v2Start = DateTime.utc(2026, 7, 28);

    if (effectiveDate.isBefore(v2Start)) {
      return _legacyRoundForNow();
    }

    return roundForDate(now);
  }

  DailyDuoRound roundForDate(DateTime date) {
    final dayKey = _dayKey(date);
    final parts = dayKey.split('-');
    final effectiveDate = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final v2Start = DateTime.utc(2026, 7, 28);
    late final DailyDuoPrompt selected;

    if (effectiveDate.isBefore(v2Start)) {
      selected = dailyDuoLegacyPrompts[
          _stableHash(dayKey) % dailyDuoLegacyPrompts.length];
    } else {
      final dayIndex = effectiveDate.difference(v2Start).inDays;
      selected = dailyDuoV2Prompts[dayIndex % dailyDuoV2Prompts.length];
    }

    return DailyDuoRound(
      dayKey: dayKey,
      prompt: selected.question,
      options: selected.options,
    );
  }

  DailyDuoRound _legacyRoundForNow() {
    final dayKey = _dayKey(DateTime.now());
    final round = _duoRounds[_stableHash(dayKey) % _duoRounds.length];
    return DailyDuoRound(
      dayKey: dayKey,
      prompt: round.prompt,
      options: round.options,
    );
  }

  Stream<List<DailyDuoAnswer>> watchAnswers(String dayKey) {
    return supabase
        .from('daily_duo_answers')
        .stream(primaryKey: ['id'])
        .eq('day_key', dayKey)
        .map((rows) => rows.map(DailyDuoAnswer.fromJson).toList());
  }

  Future<void> submitAnswer({
    required LocalAccount account,
    required DailyDuoRound round,
    required int optionIndex,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before playing Daily Duo.');
    }
    if (optionIndex < 0 || optionIndex >= round.options.length) {
      throw StateError('That answer is not available anymore.');
    }

    await supabase
        .from('daily_duo_answers')
        .upsert(
          {
            'day_key': round.dayKey,
            'user_id': user.id,
            'username': account.username,
            'mascot': account.mascot.name,
            'option_index': optionIndex,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'day_key,user_id',
        )
        .select(_columns)
        .single();
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
}

class _DuoRoundTemplate {
  const _DuoRoundTemplate({required this.prompt, required this.options});

  final String prompt;
  final List<String> options;
}

const _duoRounds = <_DuoRoundTemplate>[
  _DuoRoundTemplate(
    prompt: 'What would make today feel like a good day?',
    options: ['A quiet day', 'A small adventure', 'Good food', 'Time together'],
  ),
  _DuoRoundTemplate(
    prompt: 'What do you need most right now?',
    options: ['Rest', 'Encouragement', 'A laugh', 'A clear plan'],
  ),
  _DuoRoundTemplate(
    prompt: 'How should we spend a free hour together?',
    options: ['Talk', 'Watch something', 'Go outside', 'Make food'],
  ),
  _DuoRoundTemplate(
    prompt: 'What kind of support would feel best today?',
    options: ['Listen to me', 'Make me laugh', 'Give me space', 'Help me plan'],
  ),
  _DuoRoundTemplate(
    prompt: 'Which little joy should we make time for?',
    options: ['Coffee or tea', 'Music', 'A walk', 'A cozy meal'],
  ),
  _DuoRoundTemplate(
    prompt: 'What helps you reset after a busy day?',
    options: ['Silence', 'A shower', 'A hug', 'A favorite show'],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we celebrate today?',
    options: [
      'Small progress',
      'Our effort',
      'A good moment',
      'Just being here'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What would make this week feel lighter?',
    options: [
      'Better sleep',
      'Less pressure',
      'More laughter',
      'More time together'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What is the best way to reconnect?',
    options: [
      'A real conversation',
      'A shared meal',
      'A walk',
      'A little surprise'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we protect more in our routine?',
    options: ['Our rest', 'Our time', 'Our peace', 'Our fun'],
  ),
  _DuoRoundTemplate(
    prompt: 'What would you choose for a cozy night?',
    options: ['A movie', 'A long talk', 'A board game', 'Early sleep'],
  ),
  _DuoRoundTemplate(
    prompt: 'What makes you feel most appreciated?',
    options: ['Kind words', 'Quality time', 'Helpful actions', 'A surprise'],
  ),
  _DuoRoundTemplate(
    prompt: 'Where would you rather spend a free afternoon?',
    options: ['At home', 'In nature', 'Somewhere new', 'With good food'],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we do when one of us feels stressed?',
    options: ['Listen quietly', 'Give a hug', 'Make a plan', 'Give some space'],
  ),
  _DuoRoundTemplate(
    prompt: 'What kind of memory should we create soon?',
    options: ['A food trip', 'A long walk', 'A small adventure', 'A lazy day'],
  ),
  _DuoRoundTemplate(
    prompt: 'What is the best way to start the weekend?',
    options: ['Sleep in', 'Go out', 'Cook together', 'Finish errands'],
  ),
  _DuoRoundTemplate(
    prompt: 'Which little thing can improve a difficult day?',
    options: ['A message', 'A snack', 'A nap', 'A good laugh'],
  ),
  _DuoRoundTemplate(
    prompt: 'What would help us feel closer today?',
    options: [
      'Put phones away',
      'Ask a real question',
      'Share a meal',
      'Go outside'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What should our next mini adventure include?',
    options: ['New food', 'A new place', 'A photo', 'A surprise plan'],
  ),
  _DuoRoundTemplate(
    prompt: 'Which daily habit should we build together?',
    options: [
      'Morning check-in',
      'Evening walk',
      'Shared journal',
      'Gratitude pause'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What feels most comforting after a long day?',
    options: ['Silence', 'A familiar voice', 'Warm food', 'A soft blanket'],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we make more room for this month?',
    options: ['Rest', 'Play', 'Honest talks', 'New experiences'],
  ),
  _DuoRoundTemplate(
    prompt: 'If we could pause time for one hour, what would we do?',
    options: ['Talk', 'Explore', 'Rest', 'Celebrate'],
  ),
  _DuoRoundTemplate(
    prompt: 'What makes teamwork feel easy for you?',
    options: ['Clear plans', 'Patience', 'Shared effort', 'Encouragement'],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we remember during a disagreement?',
    options: ['We are a team', 'Listen first', 'Take a pause', 'Stay gentle'],
  ),
  _DuoRoundTemplate(
    prompt: 'What kind of day would you replay?',
    options: [
      'A peaceful day',
      'A funny day',
      'An adventurous day',
      'A simple day'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What is the sweetest way to reconnect after being busy?',
    options: ['A hug', 'A voice call', 'A shared meal', 'A quiet moment'],
  ),
  _DuoRoundTemplate(
    prompt: 'What should we do more often without overthinking it?',
    options: ['Take photos', 'Try new food', 'Say I love you', 'Take a walk'],
  ),
  _DuoRoundTemplate(
    prompt: 'What kind of encouragement helps you keep going?',
    options: [
      'You can do this',
      'I am here',
      'Let us do it together',
      'Take your time'
    ],
  ),
  _DuoRoundTemplate(
    prompt: 'What would make our home feel warmer?',
    options: ['More music', 'More plants', 'More cooking', 'More laughter'],
  ),
];
