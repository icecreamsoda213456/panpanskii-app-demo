import '../../auth/data/local_account_store.dart';
import '../../../core/supabase/supabase.dart';

class CozyGardenState {
  const CozyGardenState({
    required this.plantType,
    required this.growth,
    required this.lastWateredBy,
    required this.wateredAt,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalHarvests,
    required this.cycleStartedAt,
    required this.lastCompletedDay,
    required this.lastHarvestedAt,
  });

  final String plantType;
  final int growth;
  final String? lastWateredBy;
  final DateTime? wateredAt;
  final int currentStreak;
  final int longestStreak;
  final int totalHarvests;
  final DateTime? cycleStartedAt;
  final DateTime? lastCompletedDay;
  final DateTime? lastHarvestedAt;

  factory CozyGardenState.fromJson(Map<String, dynamic> json) {
    return CozyGardenState(
      plantType: json['plant_type'] as String? ?? 'sunflower',
      growth: (json['growth'] as num?)?.toInt() ?? 0,
      lastWateredBy: json['last_watered_by'] as String?,
      wateredAt: _readDate(json['watered_at']),
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalHarvests: (json['total_harvests'] as num?)?.toInt() ?? 0,
      cycleStartedAt: _readDate(json['cycle_started_at']),
      lastCompletedDay: _readDate(json['last_completed_day']),
      lastHarvestedAt: _readDate(json['last_harvested_at']),
    );
  }

  static const initial = CozyGardenState(
    plantType: 'sunflower',
    growth: 0,
    lastWateredBy: null,
    wateredAt: null,
    currentStreak: 0,
    longestStreak: 0,
    totalHarvests: 0,
    cycleStartedAt: null,
    lastCompletedDay: null,
    lastHarvestedAt: null,
  );
}

class CozyGardenAction {
  const CozyGardenAction({
    required this.userId,
    required this.username,
    required this.mascot,
  });

  final String userId;
  final String username;
  final AccountMascot mascot;

  factory CozyGardenAction.fromJson(Map<String, dynamic> json) {
    return CozyGardenAction(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: AccountMascot.fromName(json['mascot'] as String? ?? 'panda'),
    );
  }
}

class CozyGardenHarvest {
  const CozyGardenHarvest({
    required this.id,
    required this.plantType,
    required this.startedAt,
    required this.harvestedAt,
    required this.finalGrowth,
    required this.streakAtHarvest,
  });

  final String id;
  final String plantType;
  final DateTime? startedAt;
  final DateTime harvestedAt;
  final int finalGrowth;
  final int? streakAtHarvest;

  factory CozyGardenHarvest.fromJson(Map<String, dynamic> json) {
    return CozyGardenHarvest(
      id: json['id'] as String? ?? '',
      plantType: json['plant_type'] as String? ?? 'sunflower',
      startedAt: _readDate(json['started_at']),
      harvestedAt: _readDate(json['harvested_at']) ?? DateTime.now(),
      finalGrowth: (json['final_growth'] as num?)?.toInt() ?? 100,
      streakAtHarvest: (json['streak_at_harvest'] as num?)?.toInt(),
    );
  }
}

class CozyGardenUnlock {
  const CozyGardenUnlock({
    required this.unlockKey,
    required this.unlockType,
    required this.unlockedAt,
    required this.unlockSource,
    required this.metadata,
  });

  final String unlockKey;
  final String unlockType;
  final DateTime unlockedAt;
  final String? unlockSource;
  final Map<String, dynamic> metadata;

  factory CozyGardenUnlock.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return CozyGardenUnlock(
      unlockKey: json['unlock_key'] as String? ?? '',
      unlockType: json['unlock_type'] as String? ?? '',
      unlockedAt: _readDate(json['unlocked_at']) ?? DateTime.now(),
      unlockSource: json['unlock_source'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }
}

class CozyGardenBonusEvent {
  const CozyGardenBonusEvent({
    required this.dayKey,
    required this.eventType,
    required this.growthBonus,
  });

  final String dayKey;
  final String eventType;
  final int growthBonus;

  factory CozyGardenBonusEvent.fromJson(Map<String, dynamic> json) {
    return CozyGardenBonusEvent(
      dayKey: json['day_key'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      growthBonus: (json['growth_bonus'] as num?)?.toInt() ?? 0,
    );
  }
}

class CozyGardenHarvestResult {
  const CozyGardenHarvestResult({required this.garden});

  final CozyGardenState garden;
}

class DailyDuoGardenBonusResult {
  const DailyDuoGardenBonusResult({
    required this.isComplete,
    required this.isMatch,
    required this.awardedGrowth,
    required this.totalDayBonus,
    required this.gardenGrowth,
  });

  final bool isComplete;
  final bool isMatch;
  final int awardedGrowth;
  final int totalDayBonus;
  final int gardenGrowth;

  factory DailyDuoGardenBonusResult.fromJson(Map<String, dynamic> json) {
    return DailyDuoGardenBonusResult(
      isComplete: json['is_complete'] as bool? ?? false,
      isMatch: json['is_match'] as bool? ?? false,
      awardedGrowth: (json['awarded_growth'] as num?)?.toInt() ?? 0,
      totalDayBonus: (json['total_day_bonus'] as num?)?.toInt() ?? 0,
      gardenGrowth: (json['garden_growth'] as num?)?.toInt() ?? 0,
    );
  }
}

class CozyGardenStore {
  Stream<CozyGardenState> watchGarden() {
    return supabase
        .from('cozy_garden_state')
        .stream(primaryKey: ['id'])
        .eq('id', 'main')
        .map((rows) => rows.isEmpty
            ? CozyGardenState.initial
            : CozyGardenState.fromJson(rows.first));
  }

  Stream<List<CozyGardenAction>> watchActions(String dayKey) {
    return supabase
        .from('cozy_garden_actions')
        .stream(primaryKey: ['id'])
        .eq('day_key', dayKey)
        .map((rows) => rows.map(CozyGardenAction.fromJson).toList());
  }

  Stream<List<CozyGardenUnlock>> watchUnlocks() {
    return supabase
        .from('cozy_garden_unlocks')
        .stream(primaryKey: ['unlock_key']).map((rows) {
      final unlocks = rows.map(CozyGardenUnlock.fromJson).toList();
      unlocks.sort((a, b) => a.unlockKey.compareTo(b.unlockKey));
      return unlocks;
    });
  }

  Stream<List<CozyGardenBonusEvent>> watchBonusEvents(String dayKey) {
    return supabase
        .from('cozy_garden_bonus_events')
        .stream(primaryKey: ['id'])
        .eq('day_key', dayKey)
        .map((rows) {
          final events = rows.map(CozyGardenBonusEvent.fromJson).toList();
          events.sort((a, b) => a.eventType.compareTo(b.eventType));
          return events;
        });
  }

  Future<List<CozyGardenHarvest>> loadHarvests() async {
    final rows = await supabase
        .from('cozy_garden_harvests')
        .select()
        .order('harvested_at', ascending: false)
        .limit(50);
    return (rows as List<dynamic>)
        .map(
          (row) => CozyGardenHarvest.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<CozyGardenState> waterGarden({
    required LocalAccount account,
    required String dayKey,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again before watering the garden.');
    }
    final response = await supabase.rpc(
      'water_cozy_garden',
      params: {
        'p_day_key': dayKey,
        'p_user_id': user.id,
        'p_username': account.username,
        'p_mascot': account.mascot.name,
      },
    );
    return CozyGardenState.fromJson(_rpcRow(response));
  }

  Future<CozyGardenHarvestResult> harvestGarden({
    required String nextPlant,
  }) async {
    final response = await supabase.rpc(
      'harvest_cozy_garden',
      params: {'p_next_plant': nextPlant},
    );
    return CozyGardenHarvestResult(
      garden: CozyGardenState.fromJson(_rpcRow(response)),
    );
  }

  Future<DailyDuoGardenBonusResult> claimDailyDuoBonus({
    required String dayKey,
  }) async {
    final response = await supabase.rpc(
      'claim_daily_duo_garden_bonus',
      params: {'p_day_key': dayKey},
    );
    return DailyDuoGardenBonusResult.fromJson(_rpcRow(response));
  }

  String todayKey({DateTime? now}) {
    final manilaNow =
        (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
    final effectiveDate = manilaNow.subtract(const Duration(hours: 6));
    final month = effectiveDate.month.toString().padLeft(2, '0');
    final day = effectiveDate.day.toString().padLeft(2, '0');
    return '${effectiveDate.year}-$month-$day';
  }
}

DateTime? _readDate(dynamic value) {
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value as String? ?? '')?.toLocal();
}

Map<String, dynamic> _rpcRow(dynamic response) {
  if (response is Map<String, dynamic>) return response;
  if (response is Map) return Map<String, dynamic>.from(response);
  if (response is List && response.isNotEmpty) return _rpcRow(response.first);
  throw StateError('The garden server returned an unexpected response.');
}
