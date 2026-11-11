import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_rules/battle_rules.dart' as rules;
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/order_checks.dart';
import 'package:flutter/services.dart';

/// The ground a unit sees (stack decision 8) on the built map [mapId] and the
/// plan's own terrain tables: the navigation model the host's loader makes of
/// the same files, and `battle_rules`' vision over it (M7 Issue 9), for
/// display only: the host decides what a unit sees. It reads the whole map
/// into memory, as the move preview does: the cost is measured by M7 Issue 13.
///
/// Throws a [MapFormatException] for a map out of the format, a
/// `GameDataException` for a data file out of it.
Future<GroundSight> loadGroundSight(AssetBundle bundle, String mapId) async {
  final terrain = rules.TerrainData.parse(
    await bundle.loadString(terrainAsset),
  );
  final map = HostMapLoader(terrain)
      .load(await loadBuiltMapAsset(bundle, mapId));
  return GroundSight(map: map.navigation, terrain: terrain);
}
