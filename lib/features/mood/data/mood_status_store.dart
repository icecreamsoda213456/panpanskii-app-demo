import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/local_account_store.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';

class MoodStatus {
  const MoodStatus({
    required this.userId,
    required this.username,
    required this.mascot,
    required this.mood,
    required this.updatedAt,
  });

  final String userId;
  final String username;
  final AccountMascot mascot;
  final String mood;
  final DateTime updatedAt;

  factory MoodStatus.fromJson(Map<String, dynamic> json) {
    return MoodStatus(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      mood: json['mood'] as String? ?? 'calm',
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class MoodStatusStore {
  static const _cooldown = Duration(minutes: 10);
  static const _columns = 'user_id, username, mascot, mood, updated_at';
  static const _lastChangedKey = 'mood_status_last_changed_at';

  Stream<List<MoodStatus>> watchStatuses() {
    return supabase.from('mood_statuses').stream(primaryKey: ['id']).map(
        (rows) => rows.map(MoodStatus.fromJson).toList());
  }

  Future<List<MoodStatus>> loadStatuses() async {
    final rows = await supabase
        .from('mood_statuses')
        .select(_columns)
        .order('updated_at', ascending: false);
    return rows.map((row) => MoodStatus.fromJson(row)).toList();
  }

  Future<Duration?> cooldownRemaining() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_lastChangedKey);
    if (raw == null) return null;
    final lastChanged = DateTime.tryParse(raw);
    if (lastChanged == null) return null;
    final remaining = _cooldown - DateTime.now().difference(lastChanged);
    return remaining.isNegative ? null : remaining;
  }

  Future<void> setMood({
    required LocalAccount account,
    required String mood,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before setting your mood.');
    }
    final remaining = await cooldownRemaining();
    if (remaining != null) {
      throw StateError(
        'You can update your mood again in ${remaining.inMinutes + 1} minutes.',
      );
    }

    await supabase
        .from('mood_statuses')
        .upsert(
          {
            'user_id': user.id,
            'username': account.username,
            'mascot': account.mascot.name,
            'mood': mood,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id',
        )
        .select(_columns)
        .single();

    unawaited(PushNotificationService.sendPush(
      type: 'mood_status',
      title: '${account.username} shared a mood',
      body: 'Your person is feeling ${mood.toLowerCase()}.',
    ));

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastChangedKey,
      DateTime.now().toIso8601String(),
    );
  }
}
