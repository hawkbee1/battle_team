import 'package:battle_map/battle_map.dart';
import 'package:flutter/services.dart';

/// The built map [mapId] from the app's assets (`assets/maps/<mapId>/`,
/// as `battle_map`'s builder writes it).
///
/// Throws a [MapFormatException] for a map out of the format.
Future<MapData> loadMapAsset(AssetBundle bundle, String mapId) async =>
    MapData.fromBuilt(await loadBuiltMapAsset(bundle, mapId));

/// The files of the built map [mapId], as `battle_map`'s loaders take them:
/// the 3D view makes its mesh of them, the move preview its navigation model.
Future<BuiltMapFiles> loadBuiltMapAsset(
  AssetBundle bundle,
  String mapId,
) async {
  final base = 'assets/maps/$mapId';
  final mapYaml = await bundle.loadString('$base/map.yaml');
  final spec = MapSpec.parse(mapYaml);
  final tiles = <String, TileFiles>{};
  for (final (column, row) in tilesOf(
    spec.width ?? 0,
    spec.depth ?? 0,
    spec.tileSize,
  )) {
    final tile = '$base/tiles/${column}_$row';
    tiles['${column}_$row'] = TileFiles(
      heightsPng: (await bundle.load('$tile/heights.png')).buffer.asUint8List(),
      terrainPng: (await bundle.load('$tile/terrain.png')).buffer.asUint8List(),
      objectsYaml: await bundle.loadString('$tile/objects.yaml'),
    );
  }
  return BuiltMapFiles(mapYaml: mapYaml, tiles: tiles);
}
