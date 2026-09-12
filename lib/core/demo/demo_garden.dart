import 'demo_store.dart';

/// Mirrors the growth rewards in supabase_cozy_garden_phase2.sql locally.
class DemoGarden {
  DemoGarden(this.store);
  final DemoStore store;

  Future<DemoRow> water(String day, String today) =>
      store.transaction((tables) {
        if (day != today) {
          throw StateError('Watering is only available for today.');
        }
        final garden = tables['cozy_garden_state']!.first;
        final actions = tables.putIfAbsent('cozy_garden_actions', () => []);
        if (actions.any((row) =>
            row['day_key'] == day && row['user_id'] == DemoStore.userId)) {
          throw StateError('You have already watered today.');
        }
        store.put(tables, 'cozy_garden_actions',
            {...DemoStore.profile, 'day_key': day});
        final together = actions
                .where((row) => row['day_key'] == day)
                .map((row) => row['user_id'])
                .toSet()
                .length >=
            2;
        final yesterday = DateTime.parse(day)
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        var streak = garden['current_streak'] as int;
        if (together && garden['last_completed_day'] != day) {
          streak = garden['last_completed_day'] == yesterday ? streak + 1 : 1;
          garden['last_completed_day'] = day;
          store.put(tables, 'cozy_garden_bonus_events', {
            'day_key': day,
            'event_type': 'both_watered',
            'growth_bonus': 2,
          }, keys: [
            'day_key',
            'event_type'
          ]);
        } else if (garden['last_completed_day'] != yesterday &&
            garden['last_completed_day'] != day) {
          streak = 0;
        }
        garden.addAll({
          'growth':
              ((garden['growth'] as int) + (together ? 10 : 8)).clamp(0, 100),
          'current_streak': streak,
          'longest_streak': streak > (garden['longest_streak'] as int)
              ? streak
              : garden['longest_streak'],
          'last_watered_by': DemoStore.userId,
          'watered_at': DateTime.now().toUtc().toIso8601String(),
        });
        _unlocks(tables, garden);
        return Map<String, dynamic>.from(garden);
      });

  Future<DemoRow> harvest(String nextPlant) => store.transaction((tables) {
        final garden = tables['cozy_garden_state']!.first;
        if ((garden['growth'] as int) < 100) {
          throw StateError('Let your flower reach 100% before harvesting.');
        }
        if (!(tables['cozy_garden_unlocks'] ?? [])
            .any((row) => row['unlock_key'] == 'plant:$nextPlant')) {
          throw StateError('That plant has not been unlocked yet.');
        }
        final now = DateTime.now().toUtc().toIso8601String();
        store.put(tables, 'cozy_garden_harvests', {
          'plant_type': garden['plant_type'],
          'started_at': garden['cycle_started_at'],
          'harvested_at': now,
          'final_growth': 100,
          'streak_at_harvest': garden['current_streak'],
        });
        garden.addAll({
          'plant_type': nextPlant,
          'growth': 0,
          'total_harvests': (garden['total_harvests'] as int) + 1,
          'cycle_started_at': now,
          'last_harvested_at': now
        });
        _unlocks(tables, garden);
        return Map<String, dynamic>.from(garden);
      });

  Future<DemoRow> claimBonus(String day, String today) =>
      store.transaction((tables) {
        if (day != today) {
          throw StateError('Bonuses are only available for today.');
        }
        final answers = (tables['daily_duo_answers'] ?? [])
            .where((row) => row['day_key'] == day)
            .toList();
        if (!answers.any((row) => row['user_id'] == DemoStore.userId)) {
          throw StateError('Answer today\'s Daily Duo first.');
        }
        final complete =
            answers.map((row) => row['user_id']).toSet().length >= 2;
        final match = complete &&
            answers.map((row) => row['option_index']).toSet().length == 1;
        final events = tables.putIfAbsent('cozy_garden_bonus_events', () => []);
        var awarded = 0;
        for (final reward in {
          'daily_duo_complete': complete ? 2 : 0,
          'daily_duo_match': match ? 1 : 0
        }.entries) {
          if (reward.value > 0 &&
              !events.any((row) =>
                  row['day_key'] == day && row['event_type'] == reward.key)) {
            store.put(tables, 'cozy_garden_bonus_events', {
              'day_key': day,
              'event_type': reward.key,
              'growth_bonus': reward.value
            });
            awarded += reward.value;
          }
        }
        final garden = tables['cozy_garden_state']!.first;
        garden['growth'] = ((garden['growth'] as int) + awarded).clamp(0, 100);
        return {
          'is_complete': complete,
          'is_match': match,
          'awarded_growth': awarded,
          'total_day_bonus': events
              .where((row) =>
                  row['day_key'] == day &&
                  (row['event_type'] as String).startsWith('daily_duo_'))
              .fold<int>(0, (sum, row) => sum + (row['growth_bonus'] as int)),
          'garden_growth': garden['growth']
        };
      });

  void _unlocks(DemoTables tables, DemoRow garden) {
    final harvests = garden['total_harvests'] as int;
    final streak = garden['longest_streak'] as int;
    final keys = [
      'plant:sunflower',
      if (harvests >= 1) ...['plant:sakura', 'decoration:wooden_sign'],
      if (streak >= 3) 'decoration:mushroom',
      if (streak >= 7) ...['plant:tulip', 'decoration:lantern'],
      if (harvests >= 3) ...['plant:rose', 'decoration:couple_bench']
    ];
    for (final key in keys) {
      if (!(tables['cozy_garden_unlocks'] ?? [])
          .any((row) => row['unlock_key'] == key)) {
        store.put(tables, 'cozy_garden_unlocks', {
          'unlock_key': key,
          'unlock_type': key.split(':').first,
          'unlocked_at': DateTime.now().toUtc().toIso8601String(),
          'unlock_source': 'demo_progress'
        }, keys: [
          'unlock_key'
        ]);
      }
    }
  }
}
