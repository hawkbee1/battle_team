import 'package:battle_client/battle_client.dart';
import 'package:battle_rules/battle_rules.dart' as rules;
import 'package:battle_team/battle/data/unit_bodies.dart';
import 'package:flutter/services.dart';

/// Where the weapons' data is in the app's assets: the plan's own file.
const combatAsset = 'plan/data/combat.yaml';

/// Where the battle settings' defaults are in the app's assets.
const battleAsset = 'plan/data/battle.yaml';

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
