enum GardenGrowthStage {
  seed('New seed', 'assets/garden/tile_seed.png'),
  sprouting('Sprouting', 'assets/garden/tile_sprout.png'),
  growing('Growing', 'assets/garden/tile_growing.png'),
  budding('Budding', 'assets/garden/tile_budding.png'),
  blooming('Blooming', 'assets/garden/tile_bloom.png');

  const GardenGrowthStage(this.label, this.assetPath);

  final String label;
  final String assetPath;

  static GardenGrowthStage fromGrowth(int growth) {
    if (growth >= 100) return GardenGrowthStage.blooming;
    if (growth >= 65) return GardenGrowthStage.budding;
    if (growth >= 30) return GardenGrowthStage.growing;
    if (growth > 0) return GardenGrowthStage.sprouting;
    return GardenGrowthStage.seed;
  }
}

enum GardenTimeOfDay { morning, day, sunset, night }

GardenTimeOfDay gardenTimeOfDayFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 6 && hour < 12) return GardenTimeOfDay.morning;
  if (hour >= 12 && hour < 18) return GardenTimeOfDay.day;
  if (hour >= 18 && hour < 21) return GardenTimeOfDay.sunset;
  return GardenTimeOfDay.night;
}
