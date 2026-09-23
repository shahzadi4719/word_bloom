/// Single background image for the level map.
class WorldAssets {
  final String mapAsset;

  const WorldAssets({
    required this.mapAsset,
  });
}

final List<WorldAssets> worldAssets = [
  const WorldAssets(
    mapAsset: 'assets/images/level_map_clean.png',
  ),
];

int levelsPerWorldFor(int totalLevels) => totalLevels;

const int levelsPerChunk = 6;

WorldAssets worldAssetsForWorldIndex(int worldIndex) {
  return worldAssets[0];
}