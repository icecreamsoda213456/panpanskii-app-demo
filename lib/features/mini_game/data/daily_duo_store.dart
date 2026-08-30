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

  /// The first Manila day that uses the five-phrasing V2 prompt bank.
  static final _v2Start = DateTime.utc(2026, 7, 28);

  DailyDuoRound roundForNow() => roundForDate(DateTime.now());

  DailyDuoRound roundForDate(DateTime date) {
    final effectiveDate = _effectiveManilaDate(date);
    final dayKey = _formatDayKey(effectiveDate);
    late final DailyDuoPrompt selected;

    if (effectiveDate.isBefore(_v2Start)) {
      selected = dailyDuoLegacyPrompts[
          _stableHash(dayKey) % dailyDuoLegacyPrompts.length];
    } else {
      final dayIndex = effectiveDate.difference(_v2Start).inDays;
      selected = dailyDuoV2Prompts[dayIndex % dailyDuoV2Prompts.length];
    }

    return DailyDuoRound(
      dayKey: dayKey,
      prompt: selected.question,
      options: selected.options,
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

  /// Daily Duo days are keyed in Manila time (UTC+8) with a 6 AM threshold,
  /// exactly like CozyGardenStore.todayKey. Both phones then always agree on
  /// "today" even when their device clocks or timezones differ, so answers,
  /// the realtime stream and the garden bonus all land on the same day instead
  /// of one phone waiting forever for a partner answer that never appears.
  ///
  /// Returns the Manila calendar date as a UTC `DateTime`, so its `.year`,
  /// `.month` and `.day` describe the Manila day while `.difference` stays
  /// safe across every timezone the phones might use.
  DateTime _effectiveManilaDate(DateTime date) {
    final manilaNow = date.toUtc().add(const Duration(hours: 8));
    return manilaNow.subtract(const Duration(hours: 6));
  }

  String _formatDayKey(DateTime effectiveDate) {
    final month = effectiveDate.month.toString().padLeft(2, '0');
    final day = effectiveDate.day.toString().padLeft(2, '0');
    return '${effectiveDate.year}-$month-$day';
  }

  int _stableHash(String value) {
    return value.codeUnits.fold<int>(0, (sum, code) => sum * 31 + code).abs();
  }
}

