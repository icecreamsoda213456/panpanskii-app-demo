import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

class SharedJournalEntry {
  const SharedJournalEntry({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.title,
    required this.body,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String username;
  final AccountMascot mascot;
  final String title;
  final String body;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isMine => supabase.auth.currentUser?.id == userId;

  factory SharedJournalEntry.fromJson(Map<String, dynamic> json) {
    return SharedJournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
      title: json['title'] as String? ?? 'Tonight',
      body: json['body'] as String? ?? '',
      entryDate: DateTime.tryParse(json['entry_date'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

class SharedJournalStore {
  static const _roomId = 'main';
  static const _columns =
      'id, room_id, user_id, username, mascot, title, body, entry_date, created_at, updated_at';

  Stream<List<SharedJournalEntry>> watchEntries() {
    return supabase
        .from('shared_journal_entries')
        .stream(primaryKey: ['id'])
        .eq('room_id', _roomId)
        .map((rows) {
          final entries =
              rows.map((row) => SharedJournalEntry.fromJson(row)).toList()
                ..sort((a, b) {
                  final byDate = b.entryDate.compareTo(a.entryDate);
                  if (byDate != 0) {
                    return byDate;
                  }
                  return b.updatedAt.compareTo(a.updatedAt);
                });
          return entries;
        });
  }

  Future<void> saveTonightEntry({
    required LocalAccount account,
    required String title,
    required String body,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before writing journal.');
    }

    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      throw const FormatException('Journal entry cannot be empty.');
    }

    final cleanTitle = title.trim().isEmpty ? 'Tonight' : title.trim();
    await supabase
        .from('shared_journal_entries')
        .upsert(
          {
            'room_id': _roomId,
            'user_id': user.id,
            'username': account.username,
            'mascot': account.mascot.name,
            'title': cleanTitle,
            'body': cleanBody,
            'entry_date': _todayKey(DateTime.now()),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'room_id,user_id,entry_date',
        )
        .select(_columns)
        .single();

    await PushNotificationService.sendPush(
      type: 'journal',
      title: 'New journal entry',
      body: '${account.username} wrote "$cleanTitle".',
    );
  }

  String _todayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
