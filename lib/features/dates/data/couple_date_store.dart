import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

enum CoupleDateVisibility {
  shared('Shared'),
  personal('Personal');

  const CoupleDateVisibility(this.label);

  final String label;

  static CoupleDateVisibility fromName(String value) {
    return CoupleDateVisibility.values.firstWhere(
      (visibility) => visibility.name == value,
      orElse: () => CoupleDateVisibility.shared,
    );
  }
}

enum CoupleDateCategory {
  date('Date'),
  movie('Movie'),
  game('Game'),
  food('Food'),
  other('Other');

  const CoupleDateCategory(this.label);

  final String label;

  static CoupleDateCategory fromName(String value) {
    return CoupleDateCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => CoupleDateCategory.other,
    );
  }
}

enum CoupleDateReminder {
  none('No reminder', null),
  atTime('At start time', 0),
  tenMinutes('10 minutes before', 10),
  oneHour('1 hour before', 60),
  oneDay('1 day before', 1440);

  const CoupleDateReminder(this.label, this.minutes);

  final String label;
  final int? minutes;

  static CoupleDateReminder fromMinutes(int? minutes) {
    return CoupleDateReminder.values.firstWhere(
      (reminder) => reminder.minutes == minutes,
      orElse: () => CoupleDateReminder.oneHour,
    );
  }
}

class CoupleDatePlan {
  const CoupleDatePlan({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.title,
    required this.notes,
    required this.category,
    required this.visibility,
    required this.startsAt,
    required this.reminderMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String title;
  final String notes;
  final CoupleDateCategory category;
  final CoupleDateVisibility visibility;
  final DateTime startsAt;
  final int? reminderMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMine => supabase.auth.currentUser?.id == userId;
  bool get isShared => visibility == CoupleDateVisibility.shared;

  DateTime? get reminderAt {
    final minutes = reminderMinutes;
    if (minutes == null) {
      return null;
    }
    return startsAt.subtract(Duration(minutes: minutes));
  }

  factory CoupleDatePlan.fromJson(Map<String, dynamic> json) {
    final startsAt = DateTime.tryParse(json['starts_at'] as String? ?? '');
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at'] as String? ?? '');

    return CoupleDatePlan(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      title: json['title'] as String? ?? 'Our plan',
      notes: json['notes'] as String? ?? '',
      category: CoupleDateCategory.fromName(
        json['category'] as String? ?? 'other',
      ),
      visibility: CoupleDateVisibility.fromName(
        json['visibility'] as String? ?? 'shared',
      ),
      startsAt: (startsAt ?? DateTime.now()).toLocal(),
      reminderMinutes: json['reminder_minutes'] as int?,
      createdAt: (createdAt ?? DateTime.now()).toLocal(),
      updatedAt: (updatedAt ?? DateTime.now()).toLocal(),
    );
  }
}

class CoupleDateStore {
  static const _columns =
      'id, user_id, username, mascot, title, notes, category, visibility, starts_at, reminder_minutes, created_at, updated_at';

  Stream<List<CoupleDatePlan>> watchPlans() {
    return supabase
        .from('couple_dates')
        .stream(primaryKey: ['id']).map(_mapAndSort);
  }

  Future<List<CoupleDatePlan>> loadUpcomingPlans({
    DateTime? from,
    int limit = 200,
  }) async {
    final start = (from ?? DateTime.now().subtract(const Duration(days: 1)))
        .toUtc()
        .toIso8601String();
    final rows = await supabase
        .from('couple_dates')
        .select(_columns)
        .gte('starts_at', start)
        .order('starts_at')
        .limit(limit);
    return _mapAndSort(rows);
  }

  Future<CoupleDatePlan> savePlan({
    String? id,
    required LocalAccount account,
    required String title,
    required String notes,
    required CoupleDateCategory category,
    required CoupleDateVisibility visibility,
    required CoupleDateVisibility? previousVisibility,
    required DateTime startsAt,
    required int? reminderMinutes,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before saving a plan.');
    }

    final cleanTitle = title.trim();
    final cleanNotes = notes.trim();
    if (cleanTitle.isEmpty) {
      throw const FormatException('Give this plan a name first.');
    }
    if (cleanTitle.length > 120) {
      throw const FormatException('Plan names can use up to 120 characters.');
    }
    if (cleanNotes.length > 1000) {
      throw const FormatException('Notes can use up to 1000 characters.');
    }
    if (reminderMinutes != null &&
        !const {0, 10, 60, 1440}.contains(reminderMinutes)) {
      throw const FormatException('Choose a valid reminder time.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'username': account.username,
      'mascot': account.mascot.name,
      'title': cleanTitle,
      'notes': cleanNotes,
      'category': category.name,
      'visibility': visibility.name,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final Map<String, dynamic> row;
    if (id == null) {
      row = await supabase
          .from('couple_dates')
          .insert(payload)
          .select(_columns)
          .single();
    } else {
      row = await supabase
          .from('couple_dates')
          .update(payload)
          .eq('id', id)
          .select(_columns)
          .single();
    }

    final plan = CoupleDatePlan.fromJson(row);
    if (plan.isShared) {
      await PushNotificationService.syncCoupleDateAlarm(
        planId: plan.id,
        action: 'upsert',
      );
    } else if (previousVisibility == CoupleDateVisibility.shared) {
      // An edit from Shared to Personal must remove the partner's old alarm.
      await PushNotificationService.syncCoupleDateAlarm(
        planId: plan.id,
        action: 'cancel',
      );
    }
    if (visibility == CoupleDateVisibility.shared) {
      await PushNotificationService.sendPush(
        type: 'couple_date',
        title: id == null ? 'New date plan' : 'Date plan updated',
        body: '${account.username} planned "$cleanTitle".',
      );
    }
    return plan;
  }

  Future<void> deletePlan(CoupleDatePlan plan) async {
    if (!plan.isMine) {
      throw StateError('Only the person who made this plan can delete it.');
    }

    if (plan.isShared) {
      // Send the authenticated cancellation while the row still exists so the
      // Edge Function can verify ownership before the delete.
      await PushNotificationService.syncCoupleDateAlarm(
        planId: plan.id,
        action: 'cancel',
      );
    }

    await supabase.from('couple_dates').delete().eq('id', plan.id);
    if (plan.isShared) {
      await PushNotificationService.sendPush(
        type: 'couple_date',
        title: 'Date plan cancelled',
        body: '${plan.username} cancelled "${plan.title}".',
      );
    }
  }

  List<CoupleDatePlan> _mapAndSort(List<Map<String, dynamic>> rows) {
    final plans = rows.map(CoupleDatePlan.fromJson).toList()
      ..sort((a, b) {
        final byStart = a.startsAt.compareTo(b.startsAt);
        if (byStart != 0) {
          return byStart;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return plans;
  }
}
