import 'dart:io';

import 'package:battle_client/battle_client.dart';
import 'package:battle_rules/battle_rules.dart' as rules;

/// The order pre-check on the plan's own files (stack decision 7): tests run
/// from the app's folder, where `plan/` is.
OrderPreCheck testPreCheck() => OrderPreCheck(
  combat: rules.CombatData.parse(
    File('plan/data/combat.yaml').readAsStringSync(),
  ),
  units: rules.UnitsData.parse(File('plan/data/units.yaml').readAsStringSync()),
  storage: rules.BattleSettings.parse(
    File('plan/data/battle.yaml').readAsStringSync(),
  ).storage,
);
