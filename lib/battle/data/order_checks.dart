import 'package:battle_client/battle_client.dart';
import 'package:battle_map/battle_map.dart';
import 'package:battle_rules/battle_rules.dart' as rules;
import 'package:battle_team/battle/data/map_assets.dart';
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:flutter/services.dart';

/// Where the weapons' data is in the app's assets: the plan's own file.
const combatAsset = 'plan/data/combat.yaml';

/// Where the battle settings' defaults are in the app's assets.
const battleAsset = 'plan/data/battle.yaml';

/// Where the terrain tables are in the app's assets: they price a move.
const terrainAsset = 'plan/data/terrain.yaml';

/// The order pre-check (stack decision 8) from the app's assets: the plan's
/// own weapons, unit types and default storage numbers. A battle that
/// overrides a setting may differ from it; the pre-check is for display and
/// the host's answer wins (decision 3).
///
/// Throws a `GameDataException` for a file out of the format.
Future<OrderPreCheck> loadOrderPreCheck(AssetBundle bundle) async =>
    OrderPreCheck(
      combat: rules.CombatData.parse(await bundle.loadString(combatAsset)),
      units: rules.UnitsData.parse(await bundle.loadString(unitsAsset)),
      storage: rules.BattleSettings.parse(await bundle.loadString(battleAsset))
          .storage,
    );

/// The move preview (stack decision 8) on the built map [mapId] and the plan's
/// own terrain tables and unit types: the navigation model the host's loader
/// makes of the same files, searched and priced as the host does (display
/// only; the host decides). It reads the whole map into memory once: the cost
/// is measured by M7 Issue 13.
///
/// Throws a [MapFormatException] for a map out of the format, a
/// `GameDataException` for a data file out of it.
Future<MovePreviewer> loadMovePreview(AssetBundle bundle, String mapId) async {
  final terrain = rules.TerrainData.parse(
    await bundle.loadString(terrainAsset),
  );
  final map = HostMapLoader(terrain)
      .load(await loadBuiltMapAsset(bundle, mapId));
  return MovePreviewer(
    planner: NavigationPathPlanner(map: map.navigation, terrain: terrain),
    units: rules.UnitsData.parse(await bundle.loadString(unitsAsset)),
    terrain: terrain,
  );
}
