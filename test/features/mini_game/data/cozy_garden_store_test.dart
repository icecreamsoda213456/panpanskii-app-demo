import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/features/mini_game/data/cozy_garden_store.dart';
import 'package:panpanskii_app/features/mini_game/data/garden_progression.dart';

void main() {
  group('Cozy Garden effective day', () {
    final store = CozyGardenStore();

    test('uses the previous Manila date before the 6 AM boundary', () {
      expect(
        store.todayKey(now: DateTime.utc(2026, 8, 3, 21, 59)),
        '2026-08-03',
      );
    });

    test('uses the current Manila date at the 6 AM boundary', () {
      expect(
        store.todayKey(now: DateTime.utc(2026, 8, 3, 22)),
        '2026-08-04',
      );
    });

    test('normalizes non-Manila device time through UTC', () {
      expect(
        store.todayKey(
          now: DateTime.parse('2026-08-04T00:30:00-04:00'),
        ),
        '2026-08-04',
      );
    });
  });

  group('Cozy Garden plant definitions', () {
    test('keeps every plant id unique and resolvable', () {
      final ids = GardenPlantDefinition.all.map((plant) => plant.id).toSet();
      expect(ids, hasLength(GardenPlantDefinition.all.length));
      for (final plant in GardenPlantDefinition.all) {
        expect(
          GardenPlantDefinition.forId(plant.id).id,
          plant.id,
          reason: '${plant.id} must resolve back to itself',
        );
      }
    });

    test('never leaks a generic sunflower fallback for a named plant', () {
      // Every non-sunflower plant must stay visually distinct (the garden
      // component switches art on the plant id), so its id must not collapse
      // into the default sunflower.
      for (final plant in GardenPlantDefinition.all) {
        final definition = GardenPlantDefinition.forId(plant.id);
        if (plant.id != 'sunflower') {
          expect(definition.id, isNot('sunflower'));
        }
      }
    });
  });
}
