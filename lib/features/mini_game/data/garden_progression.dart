import 'package:flutter/material.dart';

class GardenPlantDefinition {
  const GardenPlantDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.unlockHint,
  });

  final String id;
  final String displayName;
  final IconData icon;
  final String unlockHint;

  static const sunflower = GardenPlantDefinition(
    id: 'sunflower',
    displayName: 'Sunflower',
    icon: Icons.wb_sunny_rounded,
    unlockHint: 'Unlocked',
  );

  static const sakura = GardenPlantDefinition(
    id: 'sakura',
    displayName: 'Sakura',
    icon: Icons.filter_vintage_rounded,
    unlockHint: 'Harvest your first flower',
  );

  static const tulip = GardenPlantDefinition(
    id: 'tulip',
    displayName: 'Tulip',
    icon: Icons.local_florist_rounded,
    unlockHint: 'Reach a 7-day shared streak',
  );

  static const rose = GardenPlantDefinition(
    id: 'rose',
    displayName: 'Rose',
    icon: Icons.local_florist_rounded,
    unlockHint: 'Harvest 3 flowers',
  );

  static const lavender = GardenPlantDefinition(
    id: 'lavender',
    displayName: 'Lavender',
    icon: Icons.spa_rounded,
    unlockHint: 'A future Daily Duo achievement',
  );

  static const legacyTree = GardenPlantDefinition(
    id: 'tree',
    displayName: 'Garden Tree',
    icon: Icons.park_rounded,
    unlockHint: 'Legacy garden plant',
  );

  static const all = <GardenPlantDefinition>[
    sunflower,
    sakura,
    tulip,
    rose,
    lavender,
    legacyTree,
  ];

  static GardenPlantDefinition forId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final plant in all) {
      if (plant.id == normalized) return plant;
    }
    return sunflower;
  }
}

class GardenDecorationDefinition {
  const GardenDecorationDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.unlockHint,
  });

  final String id;
  final String displayName;
  final IconData icon;
  final String unlockHint;

  static const mushroom = GardenDecorationDefinition(
    id: 'mushroom',
    displayName: 'Mushroom',
    icon: Icons.eco_rounded,
    unlockHint: 'Reach a 3-day shared streak',
  );

  static const lantern = GardenDecorationDefinition(
    id: 'lantern',
    displayName: 'Garden Lantern',
    icon: Icons.lightbulb_rounded,
    unlockHint: 'Reach a 7-day shared streak',
  );

  static const woodenSign = GardenDecorationDefinition(
    id: 'wooden_sign',
    displayName: 'Wooden Garden Sign',
    icon: Icons.label_rounded,
    unlockHint: 'Harvest your first flower',
  );

  static const coupleBench = GardenDecorationDefinition(
    id: 'couple_bench',
    displayName: 'Couple Bench',
    icon: Icons.weekend_rounded,
    unlockHint: 'Harvest 3 flowers',
  );

  static const all = <GardenDecorationDefinition>[
    mushroom,
    lantern,
    woodenSign,
    coupleBench,
  ];

  static GardenDecorationDefinition forId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final decoration in all) {
      if (decoration.id == normalized) return decoration;
    }
    return mushroom;
  }
}

String plantUnlockKey(String plantId) =>
    'plant:${plantId.trim().toLowerCase()}';

String decorationUnlockKey(String decorationId) =>
    'decoration:${decorationId.trim().toLowerCase()}';
